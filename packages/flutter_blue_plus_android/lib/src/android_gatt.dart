part of '../flutter_blue_plus_android.dart';

base mixin _GattOperations on _AndroidBackend {
  ab.BluetoothGattDescriptor _descriptor(_Attribute attribute, String uuid) {
    final descriptor = attribute.characteristic.getDescriptor(uuid);
    if (descriptor != null) return descriptor;
    // Legacy readDescriptor also reports writeDescriptor for a missing descriptor.
    _fail('writeDescriptor',
        'descriptor not found on characteristic. (desc: $uuid chr: ${attribute.characteristicUuid})');
  }

  (_Connection, _Attribute) _resolveAttribute(String method, _GattTarget target) {
    final connection = _connected(method, target.remoteId.str);
    return (connection, connection.graph.locate(method, target));
  }

  Uint8List? _copyReceivedValue(Uint8List? value) => value == null ? null : Uint8List.fromList(value);

  void _checkWriteStatus(String method, String nativeMethod, int status) {
    if (status == ab.BluetoothGatt.gattSuccess) return;
    final result = _capabilities.apiLevel >= 33 ? '$status : ${_bluetoothStatus(status)}' : 'false';
    _fail(method, 'gatt.$nativeMethod() returned $result');
  }

  void _checkCharacteristicWrite(ab.BluetoothGattCharacteristic characteristic, int length, int mtu,
      {required bool noResponse, required bool allowLongWrite}) {
    final property = noResponse
        ? ab.BluetoothGattCharacteristic.propertyWriteNoResponse
        : ab.BluetoothGattCharacteristic.propertyWrite;
    if (characteristic.properties & property == 0) {
      _fail('writeCharacteristic',
          'The ${noResponse ? 'WRITE_NO_RESPONSE' : 'WRITE'} property is not supported by this BLE characteristic');
    }
    final max = noResponse || !allowLongWrite ? math.min(mtu - 3, _maximumAttributeLength) : _maximumAttributeLength;
    if (length <= max) return;
    final type = noResponse ? 'withoutResponse' : 'withResponse, ${allowLongWrite ? 'allowLongWrite' : 'noLongWrite'}';
    _fail('writeCharacteristic', 'data longer than allowed. dataLen: $length > max: $max ($type)');
  }

  Uint8List _notificationValue(ab.BluetoothGattCharacteristic characteristic,
      {required bool enable, required bool forceIndications}) {
    if (!enable) return ab.BluetoothGattDescriptor.disableNotificationValue;
    final notify = characteristic.properties & ab.BluetoothGattCharacteristic.propertyNotify != 0;
    final indicate = characteristic.properties & ab.BluetoothGattCharacteristic.propertyIndicate != 0;
    if (!notify && !indicate) {
      _fail('setNotifyValue', 'neither NOTIFY nor INDICATE properties are supported by this BLE characteristic');
    }
    if (forceIndications && !indicate) _fail('setNotifyValue', 'INDICATE not supported by this BLE characteristic');
    if (forceIndications || !notify) return ab.BluetoothGattDescriptor.enableIndicationValue;
    return ab.BluetoothGattDescriptor.enableNotificationValue;
  }

  Future<bool> _submitGattRequest(
      String method, DeviceIdentifier remoteId, Future<bool> Function(ab.BluetoothGatt) submit,
      {String? nativeMethod, Object? arguments}) {
    final address = remoteId.str;
    return _run(method, () async {
      final gatt = _connected(method, address).gatt!;
      if (!await submit(gatt)) _fail(method, 'gatt.${nativeMethod ?? method}() returned false');
      return true;
    }, arguments: arguments);
  }

  Future<void> _writeDescriptor(String method, _Connection connection, _Attribute attribute,
      ab.BluetoothGattDescriptor descriptor, Uint8List value) async {
    _writes[attribute.writeKey(connection.remoteId, _shortUuid(descriptor.uuid))] = value;
    final status = await connection.gatt!.writeDescriptor(descriptor, value);
    _checkWriteStatus(method, 'writeDescriptor', status);
  }

  void _connectionCallback(_Connection connection, ab.GattConnectionStateChangeResult event) {
    final state = event.newState;
    if (state != ab.BluetoothProfile.stateDisconnected && state != ab.BluetoothProfile.stateConnected) return;
    if (state == ab.BluetoothProfile.stateConnected && connection.connected) return;
    connection.connecting = false;
    connection.connected = state == ab.BluetoothProfile.stateConnected;
    if (connection.connected) connection.mtu = _defaultMtu;
    if (!connection.connected && (!connection.autoConnect || connection.explicitDisconnect)) {
      _connections.remove(connection.remoteId);
      unawaited(connection.subscription?.cancel());
      unawaited(connection.gatt!.close());
    }
    _emitConnectionState(connection,
        connection.connected ? BmConnectionStateEnum.connected : BmConnectionStateEnum.disconnected, event.status);
  }

  void _characteristicCallback(_Connection connection, ab.BluetoothGattCallback event, int status) {
    final address = connection.remoteId;
    final characteristic = event.characteristic!;
    final attribute = connection.graph.callback(characteristic);
    final write = event is ab.GattCharacteristicWriteResult;
    if (!write && attribute.serviceUuid == '1801' && attribute.characteristicUuid == '2a05') {
      _emit('OnServicesReset', _onServicesResetController, _deviceMap(event.device ?? ab.BluetoothDevice(address)),
          BmBluetoothDevice.fromMap);
    }
    final value = write ? _writes.remove(attribute.writeKey(address)) ?? Uint8List(0) : _copyReceivedValue(event.value);
    _emit(
        write ? 'OnCharacteristicWritten' : 'OnCharacteristicReceived',
        write ? _onCharacteristicWrittenController : _onCharacteristicReceivedController,
        {...attribute.identity(address), ..._gattStatus(status), 'value': value},
        BmCharacteristicData.fromMap);
  }

  void _descriptorCallback(_Connection connection, ab.BluetoothGattCallback event, int status) {
    final address = connection.remoteId;
    final descriptor = event.descriptor!;
    final attribute = connection.graph.callback(descriptor.characteristic!);
    final uuid = _shortUuid(descriptor.uuid);
    final write = event is ab.GattDescriptorWriteResult;
    final value =
        write ? _writes.remove(attribute.writeKey(address, uuid)) ?? Uint8List(0) : _copyReceivedValue(event.value);
    _emit(
        write ? 'OnDescriptorWritten' : 'OnDescriptorRead',
        write ? _onDescriptorWrittenController : _onDescriptorReadController,
        {...attribute.identity(address), ..._gattStatus(status), 'descriptor_uuid': uuid, 'value': value},
        BmDescriptorData.fromMap);
  }

  @override
  void _gattCallback(_Connection connection, ab.BluetoothGattCallback event) {
    if (!identical(_connections[connection.remoteId], connection)) return;
    final status = event.status ?? ab.BluetoothGatt.gattSuccess;
    late final common = {'remote_id': connection.remoteId, ..._gattStatus(status)};
    switch (event) {
      case ab.GattConnectionStateChangeResult():
        _connectionCallback(connection, event);
      case ab.GattServicesDiscoveredResult():
        // Android returns the current graph even on discovery failure.
        connection.graph = _AttributeGraph(event.services, connection.graph);
        _emit(
            'OnDiscoveredServices',
            _onDiscoveredServicesController,
            {
              ...common,
              'services': connection.graph.toMap(connection.remoteId),
            },
            BmDiscoverServicesResult.fromMap);
      case ab.GattMtuChangedResult():
        connection.mtu = event.mtu;
        _emit(
            'OnMtuChanged',
            _onMtuChangedController,
            {
              ...common,
              'mtu': event.mtu,
            },
            BmMtuChangedResponse.fromMap);
      case ab.GattReadRemoteRssiResult():
        _emit(
            'OnReadRssi',
            _onReadRssiController,
            {
              ...common,
              'rssi': event.rssi,
            },
            BmReadRssiResult.fromMap);
      case ab.GattCharacteristicReadResult():
      case ab.GattCharacteristicChangedResult():
      case ab.GattCharacteristicWriteResult():
        _characteristicCallback(connection, event, status);
      case ab.GattDescriptorReadResult():
      case ab.GattDescriptorWriteResult():
        _descriptorCallback(connection, event, status);
      default:
        // FBP resets services on 1801/2a05 only, not Android's newer callback.
        break;
    }
  }

  @override
  Future<bool> discoverServices(BmDiscoverServicesRequest request) =>
      _submitGattRequest('discoverServices', request.remoteId, (gatt) => gatt.discoverServices(),
          arguments: request.remoteId.str);

  @override
  Future<bool> clearGattCache(BmClearGattCacheRequest request) {
    final address = request.remoteId.str;
    return _run('clearGattCache', () async {
      // Legacy returns true if reflection succeeded, irrespective of its boolean.
      await _connected('clearGattCache', address).gatt!.refresh();
      return true;
    }, arguments: address);
  }

  @override
  Future<bool> readRssi(BmReadRssiRequest request) =>
      _submitGattRequest('readRssi', request.remoteId, (gatt) => gatt.readRemoteRssi(),
          nativeMethod: 'readRemoteRssi', arguments: request.remoteId.str);

  @override
  Future<bool> requestMtu(BmMtuChangeRequest request) =>
      _submitGattRequest('requestMtu', request.remoteId, (gatt) => gatt.requestMtu(request.mtu),
          arguments: request.toMap());

  @override
  Future<bool> requestConnectionPriority(BmConnectionPriorityRequest request) => _submitGattRequest(
      'requestConnectionPriority',
      request.remoteId,
      (gatt) => gatt.requestConnectionPriority(request.connectionPriority.index),
      arguments: request.toMap());

  @override
  Future<bool> setPreferredPhy(BmPreferredPhy request) => _run('setPreferredPhy', () async {
        _requirePhy('setPreferredPhy');
        final gatt = _connected('setPreferredPhy', request.remoteId.str).gatt!;
        await gatt.setPreferredPhy(request.txPhy, request.rxPhy, phyOptions: request.phyOptions);
        return true;
      }, arguments: request.toMap());

  @override
  Future<bool> readCharacteristic(BmReadCharacteristicRequest request) {
    final target = _GattTarget(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    return _run('readCharacteristic', () async {
      final (connection, attribute) = _resolveAttribute('readCharacteristic', target);
      final characteristic = attribute.characteristic;
      if (characteristic.properties & ab.BluetoothGattCharacteristic.propertyRead == 0) {
        _fail('readCharacteristic', 'The READ property is not supported by this BLE characteristic');
      }
      if (!await connection.gatt!.readCharacteristic(characteristic)) {
        _fail('readCharacteristic', 'gatt.readCharacteristic() returned false');
      }
      return true;
    }, arguments: target.toMap());
  }

  @override
  Future<bool> readDescriptor(BmReadDescriptorRequest request) {
    final target = _GattTarget(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    final uuid = request.descriptorUuid.str;
    return _run('readDescriptor', () async {
      final (connection, attribute) = _resolveAttribute('readDescriptor', target);
      final descriptor = _descriptor(attribute, uuid);
      if (!await connection.gatt!.readDescriptor(descriptor)) {
        _fail('readDescriptor', 'gatt.readDescriptor() returned false');
      }
      return true;
    }, arguments: {...target.toMap(), 'descriptor_uuid': uuid});
  }

  @override
  Future<bool> writeDescriptor(BmWriteDescriptorRequest request) {
    final target = _GattTarget(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    final uuid = request.descriptorUuid.str;
    final value = Uint8List.fromList(request.value);
    return _run('writeDescriptor', () async {
      final (connection, attribute) = _resolveAttribute('writeDescriptor', target);
      final descriptor = _descriptor(attribute, uuid);
      if (value.length > connection.mtu - 3) {
        _fail(
            'writeDescriptor', 'data longer than mtu allows. dataLength: ${value.length}> max: ${connection.mtu - 3}');
      }
      await _writeDescriptor('writeDescriptor', connection, attribute, descriptor, value);
      return true;
    }, arguments: {...target.toMap(), 'descriptor_uuid': uuid, 'value': value});
  }

  @override
  Future<bool> setNotifyValue(BmSetNotifyValueRequest request) {
    final target = _GattTarget(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    return _run('setNotifyValue', () async {
      final (connection, attribute) = _resolveAttribute('setNotifyValue', target);
      final characteristic = attribute.characteristic;
      final enable = request.enable;
      final gatt = connection.gatt!;
      if (!await gatt.setCharacteristicNotification(characteristic, enable)) {
        _fail('setNotifyValue', 'gatt.setCharacteristicNotification($enable) returned false');
      }
      final cccd = characteristic.getDescriptor(_cccd);
      if (cccd == null) return false;
      final value = _notificationValue(characteristic, enable: enable, forceIndications: request.forceIndications);
      await _writeDescriptor('setNotifyValue', connection, attribute, cccd, value);
      return true;
    }, arguments: {...target.toMap(), 'force_indications': request.forceIndications, 'enable': request.enable});
  }

  @override
  Future<bool> writeCharacteristic(BmWriteCharacteristicRequest request) {
    final target = _GattTarget(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    final value = Uint8List.fromList(request.value);
    return _run('writeCharacteristic', () async {
      final (connection, attribute) = _resolveAttribute('writeCharacteristic', target);
      final characteristic = attribute.characteristic;
      final noResponse = request.writeType == BmWriteType.withoutResponse;
      _checkCharacteristicWrite(characteristic, value.length, connection.mtu,
          noResponse: noResponse, allowLongWrite: request.allowLongWrite);
      _writes[attribute.writeKey(target.remoteId.str)] = value;
      final status = await connection.gatt!.writeCharacteristic(characteristic, value,
          writeType: noResponse
              ? ab.BluetoothGattCharacteristic.writeTypeNoResponse
              : ab.BluetoothGattCharacteristic.writeTypeDefault);
      _checkWriteStatus('writeCharacteristic', 'writeCharacteristic', status);
      return true;
    }, arguments: {
      ...target.toMap(),
      'write_type': request.writeType.index,
      'allow_long_write': request.allowLongWrite ? 1 : 0,
      'value': value
    });
  }
}
