// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDescriptor extends BluetoothValueAttribute {
  final BluetoothCharacteristic characteristic;

  BluetoothDescriptor.fromProto(BmBluetoothDescriptor p, BluetoothCharacteristic characteristic)
      : characteristic = characteristic,
        super(device: characteristic.device, uuid: p.uuid);

  @override
  BluetoothAttribute? get _parentAttribute => characteristic;

  /// convenience accessor
  Guid get descriptorUuid => uuid;

  /// Retrieves the value of a specified descriptor
  Future<List<int>> read({int timeout = 15}) async {
    // check connected
    if (device.isDisconnected) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "readDescriptor", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    try {
      var request = BmReadDescriptorRequest(
        remoteId: remoteId,
        identifier: identifierPath,
      );

      // Invoke
      final futureResponse = FlutterBluePlus._invokeMethodAndWaitForEvent<OnDescriptorReadEvent>(
        'readDescriptor',
        request.toMap(),
        (e) => e.descriptor == this,
      );

      // wait for response
      OnDescriptorReadEvent response = await futureResponse
          .fbpEnsureAdapterIsOn("readDescriptor")
          .fbpEnsureDeviceIsConnected(device, "readDescriptor")
          .fbpTimeout(timeout, "readDescriptor");

      // failed?
      response.ensureSuccess("readDescriptor");

      return response.value;
    } finally {
      mtx.give();
    }
  }

  /// Writes the value of a descriptor
  Future<void> write(List<int> value, {int timeout = 15}) async {
    // check connected
    if (device.isDisconnected) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "writeDescriptor", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    try {
      var request = BmWriteDescriptorRequest(
        remoteId: remoteId,
        identifier: identifierPath,
        value: value,
      );

      // invoke
      final futureResponse = FlutterBluePlus._invokeMethodAndWaitForEvent<OnDescriptorWrittenEvent>(
        'writeDescriptor',
        request.toMap(),
        (e) => e.descriptor == this,
      );

      // wait for response
      OnDescriptorWrittenEvent response = await futureResponse
          .fbpEnsureAdapterIsOn("writeDescriptor")
          .fbpEnsureDeviceIsConnected(device, "writeDescriptor")
          .fbpTimeout(timeout, "writeDescriptor");

      // failed?
      response.ensureSuccess("writeDescriptor");
    } finally {
      mtx.give();
    }
  }

  @override
  String toString() {
    return 'BluetoothDescriptor{'
        'remoteId: $remoteId, '
        'uuid: $uuid, '
        'characteristicUuid: ${characteristic.uuid}, '
        'lastValue: $lastValue'
        '}';
  }
}
