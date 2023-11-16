// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDescriptor {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;

  BluetoothDescriptor({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
  });

  BluetoothDescriptor.fromProto(BmBluetoothDescriptor p)
      : remoteId = DeviceIdentifier(p.remoteId),
        serviceUuid = p.serviceUuid,
        characteristicUuid = p.characteristicUuid,
        descriptorUuid = p.descriptorUuid;

  /// convenience accessor
  Guid get uuid => descriptorUuid;

  /// convenience accessor
  BluetoothDevice get device => BluetoothDevice(remoteId: remoteId);

  /// this variable is updated:
  ///   - anytime `read()` is called
  ///   - anytime `write()` is called
  ///   - when the device is disconnected it is cleared
  List<int> get lastValue {
    String key = "$serviceUuid:$characteristicUuid:$descriptorUuid";
    return FlutterBluePlus._lastDescs[remoteId]?[key] ?? [];
  }

  /// this stream emits values:
  ///   - anytime `read()` is called
  ///   - anytime `write()` is called
  ///   - and when first listened to, it re-emits the last value for convenience
  Stream<List<int>> get lastValueStream => FlutterBluePlus._methodStream.stream
      .where((m) => m.method == "OnDescriptorRead" || m.method == "OnDescriptorWritten")
      .map((m) => m.arguments)
      .map((args) => BmDescriptorData.fromMap(args))
      .where((p) => p.remoteId == remoteId.toString())
      .where((p) => p.characteristicUuid == characteristicUuid)
      .where((p) => p.serviceUuid == serviceUuid)
      .where((p) => p.descriptorUuid == descriptorUuid)
      .where((p) => p.success == true)
      .map((p) => p.value)
      .newStreamWithInitialValue(lastValue);

  /// this stream emits values:
  ///   - anytime `read()` is called
  Stream<List<int>> get onValueReceived => FlutterBluePlus._methodStream.stream
      .where((m) => m.method == "OnDescriptorRead")
      .map((m) => m.arguments)
      .map((args) => BmDescriptorData.fromMap(args))
      .where((p) => p.remoteId == remoteId.toString())
      .where((p) => p.characteristicUuid == characteristicUuid)
      .where((p) => p.serviceUuid == serviceUuid)
      .where((p) => p.descriptorUuid == descriptorUuid)
      .where((p) => p.success == true)
      .map((p) => p.value);

  /// Retrieves the value of a specified descriptor
  Future<List<int>> read({int timeout = 15}) async {
    // check connected
    if (device.isConnected == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "readDescriptor", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    // return value
    List<int> readValue = [];

    try {
      var request = BmReadDescriptorRequest(
        remoteId: remoteId.toString(),
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        characteristicUuid: characteristicUuid,
        descriptorUuid: descriptorUuid,
      );

      Stream<BmDescriptorData> responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDescriptorRead")
          .map((m) => m.arguments)
          .map((args) => BmDescriptorData.fromMap(args))
          .where((p) => p.remoteId == request.remoteId)
          .where((p) => p.serviceUuid == request.serviceUuid)
          .where((p) => p.characteristicUuid == request.characteristicUuid)
          .where((p) => p.descriptorUuid == request.descriptorUuid);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmDescriptorData> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('readDescriptor', request.toMap());

      // wait for response
      BmDescriptorData response = await futureResponse
          .fbpEnsureAdapterIsOn("readDescriptor")
          .fbpEnsureDeviceIsConnected(device, "readDescriptor")
          .fbpTimeout(timeout, "readDescriptor");

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException(_nativeError, "readDescriptor", response.errorCode, response.errorString);
      }

      readValue = response.value;
    } finally {
      mtx.give();
    }

    return readValue;
  }

  /// Writes the value of a descriptor
  Future<void> write(List<int> value, {int timeout = 15}) async {
    // check connected
    if (device.isConnected == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "writeDescriptor", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    try {
      var request = BmWriteDescriptorRequest(
        remoteId: remoteId.toString(),
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        characteristicUuid: characteristicUuid,
        descriptorUuid: descriptorUuid,
        value: value,
      );

      Stream<BmDescriptorData> responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDescriptorWritten")
          .map((m) => m.arguments)
          .map((args) => BmDescriptorData.fromMap(args))
          .where((p) => p.remoteId == request.remoteId)
          .where((p) => p.serviceUuid == request.serviceUuid)
          .where((p) => p.characteristicUuid == request.characteristicUuid)
          .where((p) => p.descriptorUuid == request.descriptorUuid);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmDescriptorData> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('writeDescriptor', request.toMap());

      // wait for response
      BmDescriptorData response = await futureResponse
          .fbpEnsureAdapterIsOn("writeDescriptor")
          .fbpEnsureDeviceIsConnected(device, "writeDescriptor")
          .fbpTimeout(timeout, "writeDescriptor");

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException(_nativeError, "writeDescriptor", response.errorCode, response.errorString);
      }
    } finally {
      mtx.give();
    }

    return Future.value();
  }

  @override
  String toString() {
    return 'BluetoothDescriptor{'
        'remoteId: $remoteId, '
        'serviceUuid: $serviceUuid, '
        'characteristicUuid: $characteristicUuid, '
        'descriptorUuid: $descriptorUuid, '
        'lastValue: $lastValue'
        '}';
  }

  @Deprecated('Use onValueReceived instead')
  Stream<List<int>> get value => onValueReceived;

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get deviceId => remoteId;
}
