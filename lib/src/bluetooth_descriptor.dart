// Copyright 2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDescriptor {
  static final Guid cccd = Guid("00002902-0000-1000-8000-00805f9b34fb");

  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;

  // convenience accessor
  Guid get uuid => descriptorUuid;

  List<int> lastValue = [];

  // same as onValueReceived, but the stream immediately starts
  // with lastValue as its first value to not cause delay
  Stream<List<int>> get lastValueStream => onValueReceived.newStreamWithInitialValue(lastValue);

  // this stream is pushed to whenever:
  //  - descriptor.read() succeeds
  //  - descriptor.write() succeeds
  Stream<List<int>> get onValueReceived => FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDescriptorResponse")
          .map((m) => m.arguments)
          .map((buffer) => BmOnDescriptorResponse.fromMap(buffer))
          .where((p) => (p.remoteId == remoteId.toString()))
          .where((p) => (p.descriptorUuid == descriptorUuid))
          .where((p) => (p.characteristicUuid == characteristicUuid))
          .where((p) => (p.serviceUuid == serviceUuid))
          .where((p) => (p.success == true))
          .map((p) {
        lastValue = p.value; // cache latest value
        return p.value;
      });

  BluetoothDescriptor.fromProto(BmBluetoothDescriptor p)
      : remoteId = DeviceIdentifier(p.remoteId),
        serviceUuid = p.serviceUuid,
        characteristicUuid = p.characteristicUuid,
        descriptorUuid = p.descriptorUuid;

  /// Retrieves the value of a specified descriptor
  Future<List<int>> read({int timeout = 15}) async {
    List<int> readValue = [];

    // check & wait if bonding
    await BluetoothDevice._waitIfBonding(remoteId);

    // Only allow a single read to be underway at any time, per-characteristic, per-device.
    // Otherwise, there would be multiple in-flight requests and we wouldn't know which response is for us.
    String key = remoteId.str + ":" + characteristicUuid.toString() + ":writeDesc";
    _Mutex readMutex = await _MutexFactory.getMutexForKey(key);
    await readMutex.take();

    try {
      var request = BmReadDescriptorRequest(
        remoteId: remoteId.toString(),
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        characteristicUuid: characteristicUuid,
        descriptorUuid: descriptorUuid,
      );

      Stream<BmOnDescriptorResponse> responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDescriptorResponse")
          .map((m) => m.arguments)
          .map((buffer) => BmOnDescriptorResponse.fromMap(buffer))
          .where((p) => (p.type == BmOnDescriptorResponseType.read))
          .where((p) => (p.remoteId == request.remoteId))
          .where((p) => (p.serviceUuid == request.serviceUuid))
          .where((p) => (p.characteristicUuid == request.characteristicUuid))
          .where((p) => (p.descriptorUuid == request.descriptorUuid));

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmOnDescriptorResponse> futureResponse = responseStream.first;

      await FlutterBluePlus._invokeMethod('readDescriptor', request.toMap());

      BmOnDescriptorResponse response = await futureResponse.timeout(Duration(seconds: timeout));

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException("readDescriptor", response.errorCode, response.errorString);
      }

      readValue = response.value;
    } finally {
      readMutex.give();
    }

    return readValue;
  }

  /// Writes the value of a descriptor
  Future<void> write(List<int> value, {int timeout = 15}) async {
    // check & wait if bonding
    await BluetoothDevice._waitIfBonding(remoteId);

    // Only allow a single write to be underway at any time, per-characteristic, per-device.
    // Otherwise, there would be multiple in-flight requests and we wouldn't know which response is for us.
    String key = remoteId.str + ":" + characteristicUuid.toString() + ":writeDesc";
    _Mutex writeMutex = await _MutexFactory.getMutexForKey(key);
    await writeMutex.take();

    try {
      var request = BmWriteDescriptorRequest(
        remoteId: remoteId.toString(),
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        characteristicUuid: characteristicUuid,
        descriptorUuid: descriptorUuid,
        value: value,
      );

      Stream<BmOnDescriptorResponse> responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDescriptorResponse")
          .map((m) => m.arguments)
          .map((buffer) => BmOnDescriptorResponse.fromMap(buffer))
          .where((p) => (p.type == BmOnDescriptorResponseType.write))
          .where((p) => (p.remoteId == request.remoteId))
          .where((p) => (p.serviceUuid == request.serviceUuid))
          .where((p) => (p.characteristicUuid == request.characteristicUuid))
          .where((p) => (p.descriptorUuid == request.descriptorUuid));

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmOnDescriptorResponse> futureResponse = responseStream.first;

      await FlutterBluePlus._invokeMethod('writeDescriptor', request.toMap());

      BmOnDescriptorResponse response = await futureResponse.timeout(Duration(seconds: timeout));

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException("writeDescriptor", response.errorCode, response.errorString);
      }
    } finally {
      writeMutex.give();
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
