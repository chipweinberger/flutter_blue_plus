part of '../flutter_blue_plus_darwin.dart';

cb.CBDescriptor _descriptor(String method, cb.CBCharacteristic characteristic, Guid uuid) {
  for (final descriptor in characteristic.descriptors ?? <cb.CBDescriptor>[]) {
    if (_guid(descriptor.uuid) == uuid) return descriptor;
  }
  _fail(method, "descriptor not found in characteristic (desc: '$uuid', chr: '${characteristic.uuid.uuidString}')");
}

cb.CBCharacteristic _locateCharacteristic(String method, cb.CBPeripheral peripheral, _CharacteristicIdentity target) {
  final services = _matchingServices(peripheral, target.primaryServiceUuid, target.serviceUuid);
  if (services.isEmpty) {
    _fail(
        method,
        target.primaryServiceUuid == null
            ? "primary service not found '${target.serviceUuid}'"
            : "secondary service not found '${target.serviceUuid}' (primary service ${target.primaryServiceUuid})");
  }
  final candidates = services.length <= 1
      ? (services.first.characteristics ?? <cb.CBCharacteristic>[])
          .where((c) => _guid(c.uuid) == target.characteristicUuid)
          .toList()
      : services.expand((s) => s.characteristics ?? <cb.CBCharacteristic>[]).toList();
  final index = target.instanceId;
  if (index >= 0 && index < candidates.length && _guid(candidates[index].uuid) == target.characteristicUuid) {
    return candidates[index];
  }
  _fail(method,
      "characteristic not found in service (chr: '${target.characteristicUuid}', svc: '${target.serviceUuid}')");
}

base mixin _GattOperations on _DarwinBackend {
  (_PeripheralState, cb.CBCharacteristic) _resolve(String method, _CharacteristicIdentity target) {
    final state = _connectedState(method, target.remoteId);
    return (state, _locateCharacteristic(method, state.peripheral, target));
  }

  @override
  Future<bool> readCharacteristic(BmReadCharacteristicRequest request) {
    final target = _CharacteristicIdentity(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    return _run(() async {
      final (state, characteristic) = _resolve('readCharacteristic', target);
      if (!characteristic.properties.contains(cb.CBCharacteristicProperties.read)) {
        // Retain the original backend's error code, including this historical name.
        _fail('writeCharacteristic', 'The READ property is not supported by this BLE characteristic');
      }
      await state.peripheral.readValue(characteristic);
      return true;
    });
  }

  @override
  Future<bool> readDescriptor(BmReadDescriptorRequest request) {
    final target = _CharacteristicIdentity(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    return _run(() async {
      final (state, characteristic) = _resolve('readDescriptor', target);
      await state.peripheral.readValue(_descriptor('readDescriptor', characteristic, request.descriptorUuid));
      return true;
    });
  }

  @override
  Future<bool> setNotifyValue(BmSetNotifyValueRequest request) {
    final target = _CharacteristicIdentity(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    return _run(() async {
      final (state, characteristic) = _resolve('setNotifyValue', target);
      final properties = characteristic.properties;
      if (!properties.contains(cb.CBCharacteristicProperties.notify) &&
          !properties.contains(cb.CBCharacteristicProperties.indicate)) {
        _fail('setNotifyValue', 'neither NOTIFY nor INDICATE properties are supported by this BLE characteristic');
      }
      await state.peripheral.setNotifyValue(request.enable, characteristic);
      return true;
    });
  }

  @override
  Future<bool> writeDescriptor(BmWriteDescriptorRequest request) {
    final target = _CharacteristicIdentity(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    final value = Uint8List.fromList(request.value);
    return _run(() async {
      final state = _connectedState('writeDescriptor', request.remoteId);
      final connection = state.connectionToken;
      final max = await _maximumPayload(state.peripheral);
      _connectedState('writeDescriptor', request.remoteId, connectionToken: connection);
      if (value.length > max) {
        _fail('writeDescriptor', 'data is longer than MTU allows. dataLen: ${value.length} > maxDataLen: $max');
      }
      final characteristic = _locateCharacteristic('writeDescriptor', state.peripheral, target);
      final descriptor = _descriptor('writeDescriptor', characteristic, request.descriptorUuid);
      state.descriptorWrites[descriptor] = value;
      await state.peripheral.writeValue(value, forAttribute: descriptor);
      return true;
    });
  }

  @override
  Future<bool> writeCharacteristic(BmWriteCharacteristicRequest request) {
    final target = _CharacteristicIdentity(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    final value = Uint8List.fromList(request.value);
    return _run(() async {
      final state = _connectedState('writeCharacteristic', request.remoteId);
      final connection = state.connectionToken;
      final noResponse = request.writeType == BmWriteType.withoutResponse;
      final max = await _maximumPayload(state.peripheral, longWrite: !noResponse && request.allowLongWrite);
      _connectedState('writeCharacteristic', request.remoteId, connectionToken: connection);
      if (value.length > max) {
        final mode = noResponse
            ? 'withoutResponse'
            : 'withResponse, ${request.allowLongWrite ? 'allowLongWrite' : 'noLongWrite'}';
        _fail('writeCharacteristic', 'data longer than allowed. dataLen: ${value.length} > max: $max ($mode)');
      }
      if (noResponse) {
        final ready = await state.peripheral.getCanSendWriteWithoutResponse();
        _connectedState('writeCharacteristic', request.remoteId, connectionToken: connection);
        if (!ready) _fail('writeCharacteristic', 'canSendWriteWithoutResponse is false. you must slow down');
      }
      final characteristic = _locateCharacteristic('writeCharacteristic', state.peripheral, target);
      final property =
          noResponse ? cb.CBCharacteristicProperties.writeWithoutResponse : cb.CBCharacteristicProperties.write;
      if (!characteristic.properties.contains(property)) {
        _fail('writeCharacteristic',
            'The ${noResponse ? 'WRITE_NO_RESPONSE' : 'WRITE'} property is not supported by this BLE characteristic');
      }
      state.characteristicWrites[characteristic] = value;
      if (noResponse) {
        state.writeWithoutResponse = BmWriteCharacteristicRequest(
            remoteId: request.remoteId,
            primaryServiceUuid: request.primaryServiceUuid,
            serviceUuid: request.serviceUuid,
            characteristicUuid: request.characteristicUuid,
            instanceId: request.instanceId,
            value: value,
            writeType: request.writeType,
            allowLongWrite: request.allowLongWrite);
      }
      await state.peripheral.writeValue(value,
          forAttribute: characteristic,
          type: noResponse ? cb.CBCharacteristicWriteType.withoutResponse : cb.CBCharacteristicWriteType.withResponse);
      return true;
    });
  }
}
