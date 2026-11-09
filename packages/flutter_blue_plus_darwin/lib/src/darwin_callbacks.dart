part of '../flutter_blue_plus_darwin.dart';

base mixin _PeripheralCallbacks on _DarwinBackend, _DiscoveryOperations {
  void _onCharacteristicRead(_PeripheralState state, cb.DidUpdateValueForCharacteristicResult event) {
    // Preserve the former decoder's rejection of missing characteristic values.
    final value = event.value;
    if (value == null) return;
    final identity = _CharacteristicIdentity.fromNative(state.peripheral, event.characteristic);
    _onCharacteristicReceivedController.add(identity.characteristicValue(value, event.error));
  }

  void _onCharacteristicWritten(_PeripheralState state, cb.DidWriteValueForCharacteristicResult event) {
    final identity = _CharacteristicIdentity.fromNative(state.peripheral, event.characteristic);
    final value = state.characteristicWrites.remove(event.characteristic) ?? Uint8List(0);
    _onCharacteristicWrittenController.add(identity.characteristicValue(value, event.error));
  }

  void _onDescriptorRead(_PeripheralState state, cb.DidUpdateValueForDescriptorResult event) {
    final descriptor = event.descriptor;
    final identity = _CharacteristicIdentity.fromNative(state.peripheral, descriptor.characteristic!);
    _onDescriptorReadController
        .add(identity.descriptorValue(_guid(descriptor.uuid), _descriptorBytes(event.value), event.error));
  }

  void _onDescriptorWritten(_PeripheralState state, cb.DidWriteValueForDescriptorResult event) {
    final descriptor = event.descriptor;
    final identity = _CharacteristicIdentity.fromNative(state.peripheral, descriptor.characteristic!);
    final value = state.descriptorWrites.remove(descriptor) ?? Uint8List(0);
    _onDescriptorWrittenController.add(identity.descriptorValue(_guid(descriptor.uuid), value, event.error));
  }

  void _onReadRssi(_PeripheralState state, cb.DidReadRssiResult event) {
    _onReadRssiController.add(BmReadRssiResult(
        remoteId: DeviceIdentifier(_remoteId(state.peripheral)),
        rssi: event.rssi ?? 0,
        success: event.error == null,
        errorCode: event.error?.code.rawValue ?? 0,
        errorString: event.error?.localizedDescription ?? 'success'));
  }

  void _onNotificationState(
      _PeripheralState state, cb.CBCharacteristic characteristic, bool notifying, cb.CBError? error) {
    var value = 0;
    if (notifying) {
      if (characteristic.properties.contains(cb.CBCharacteristicProperties.indicate)) value = 2;
      if (characteristic.properties.contains(cb.CBCharacteristicProperties.notify)) value = 1;
    }
    final identity = _CharacteristicIdentity.fromNative(state.peripheral, characteristic);
    // Preserve FBP's four-byte CCCD callback and notify-bit precedence.
    _onDescriptorWrittenController.add(identity.descriptorValue(Guid('2902'), _intBytes(value), error));
  }

  void _onWriteReady(_PeripheralState state) {
    final request = state.writeWithoutResponse;
    if (request == null) return;
    final target = _CharacteristicIdentity(request.remoteId, request.primaryServiceUuid, request.serviceUuid,
        request.characteristicUuid, request.instanceId);
    try {
      final characteristic = _locateCharacteristic('writeCharacteristic', state.peripheral, target);
      final identity = _CharacteristicIdentity.fromNative(state.peripheral, characteristic);
      _onCharacteristicWrittenController.add(identity.characteristicValue(Uint8List.fromList(request.value), null));
    } on PlatformException {
      // The reference ignores readiness for a characteristic that no longer exists.
    }
  }

  @override
  void _watchPeripheral(cb.CBPeripheral peripheral) {
    final id = _remoteId(peripheral);
    if (_states.containsKey(id)) return;
    final state = _PeripheralState(peripheral);
    _states[id] = state;
    void listen<T>(Stream<T> stream, void Function(T) callback) {
      state.subscriptions.add(stream.listen((event) {
        if (!_disposed && _connected.containsKey(id) && identical(_states[id], state)) callback(event);
      }, onError: _reportBackgroundError));
    }

    listen(peripheral.onDidDiscoverServices, (event) => _onServices(state, event));
    listen(peripheral.onDidDiscoverCharacteristicsForService, (event) => _onCharacteristics(state, event));
    listen(peripheral.onDidDiscoverIncludedServicesForService, (event) => _onIncludedServices(state, event));
    listen(peripheral.onDidDiscoverDescriptorsForCharacteristic, (event) => _onDescriptors(state, event));
    listen(peripheral.onDidUpdateValueForCharacteristic, (event) => _onCharacteristicRead(state, event));
    listen(peripheral.onDidWriteValueForCharacteristic, (event) => _onCharacteristicWritten(state, event));
    listen(peripheral.onDidUpdateValueForDescriptor, (event) => _onDescriptorRead(state, event));
    listen(peripheral.onDidWriteValueForDescriptor, (event) => _onDescriptorWritten(state, event));
    listen(peripheral.onDidReadRSSI, (event) => _onReadRssi(state, event));
    listen(
        peripheral.onDidUpdateNotificationStateForCharacteristic,
        (event) => _onNotificationState(
            state, event.characteristic, event.isNotifying ?? event.characteristic.isNotifying, event.error));
    listen(peripheral.onPeripheralIsReadyToSendWriteWithoutResponse, (_) => _onWriteReady(state));
  }

  @override
  void _restoreServices(cb.CBPeripheral peripheral) {
    final state = _states[_remoteId(peripheral)]!;
    _onServices(
        state, cb.DidDiscoverServicesResult(peripheral: peripheral, services: peripheral.services, error: null));
    for (final service in peripheral.services ?? <cb.CBService>[]) {
      for (final c in service.characteristics ?? <cb.CBCharacteristic>[]) {
        if (c.isNotifying) _onNotificationState(state, c, c.isNotifying, null);
      }
    }
  }
}
