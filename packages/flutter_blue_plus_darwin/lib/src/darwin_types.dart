part of '../flutter_blue_plus_darwin.dart';

final class _Discovery {
  final requestedServices = <cb.CBService>{};
  final pendingCharacteristics = <cb.CBService>{};
  final pendingIncludedServices = <cb.CBService>{};
  final pendingDescriptors = <cb.CBCharacteristic>{};
  cb.CBError? error;

  bool get isComplete =>
      pendingCharacteristics.isEmpty && pendingIncludedServices.isEmpty && pendingDescriptors.isEmpty;

  void recordError(cb.CBError? failure) {
    if (failure?.domain == 'CBErrorDomain' && failure?.code == cb.CBErrorCode.uuidNotAllowed) return;
    error ??= failure;
  }
}

final class _PeripheralState {
  _PeripheralState(this.peripheral);

  final cb.CBPeripheral peripheral;
  final subscriptions = <StreamSubscription<Object?>>[];
  final characteristicWrites = <cb.CBCharacteristic, Uint8List>{};
  final descriptorWrites = <cb.CBDescriptor, Uint8List>{};
  BmWriteCharacteristicRequest? writeWithoutResponse;
  _Discovery? discovery;
  _MtuMonitor? mtuMonitor;
  Object connectionToken = Object();

  void clearOperations() {
    // Pending queries must not resume writes on a later connection.
    connectionToken = Object();
    unawaited(mtuMonitor?.cancel());
    mtuMonitor = null;
    discovery = null;
    characteristicWrites.clear();
    descriptorWrites.clear();
    writeWithoutResponse = null;
  }
}

final class _CharacteristicIdentity {
  const _CharacteristicIdentity(
      this.remoteId, this.primaryServiceUuid, this.serviceUuid, this.characteristicUuid, this.instanceId);

  factory _CharacteristicIdentity.fromNative(cb.CBPeripheral peripheral, cb.CBCharacteristic characteristic) {
    final primary = _primaryService(peripheral, characteristic);
    return _CharacteristicIdentity(
        DeviceIdentifier(_remoteId(peripheral)),
        primary == null ? null : _guid(primary.uuid),
        _guid(characteristic.service!.uuid),
        _guid(characteristic.uuid),
        _instanceId(peripheral, characteristic));
  }

  final DeviceIdentifier remoteId;
  final Guid? primaryServiceUuid;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final int instanceId;

  BmBluetoothDescriptor descriptor(Guid uuid) => BmBluetoothDescriptor(
      remoteId: remoteId,
      primaryServiceUuid: primaryServiceUuid,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      instanceId: instanceId,
      descriptorUuid: uuid);

  BmCharacteristicData characteristicValue(List<int> value, cb.CBError? error) => BmCharacteristicData(
      remoteId: remoteId,
      primaryServiceUuid: primaryServiceUuid,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      instanceId: instanceId,
      value: value,
      success: error == null,
      errorCode: error?.code.rawValue ?? 0,
      errorString: error?.localizedDescription ?? 'success');

  BmDescriptorData descriptorValue(Guid descriptorUuid, List<int> value, cb.CBError? error) => BmDescriptorData(
      remoteId: remoteId,
      primaryServiceUuid: primaryServiceUuid,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      instanceId: instanceId,
      descriptorUuid: descriptorUuid,
      value: value,
      success: error == null,
      errorCode: error?.code.rawValue ?? 0,
      errorString: error?.localizedDescription ?? 'success');
}
