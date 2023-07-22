// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDescriptor {
  static final Guid cccd = Guid("00002902-0000-1000-8000-00805f9b34fb");

  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;

  final _Mutex _readWriteMutex = _Mutex();

  List<int> lastValue = [];

  // same as onValueReceived, but the stream starts
  // with lastValue as its first value (so to not cause delay)
  Stream<List<int>> get lastValueStream => onValueReceived.newStreamWithInitialValue(lastValue);

  // this stream is pushed to whenever:
  //  1. the descriptor is successfully read
  //  2. the descriptor is successfully written
  Stream<List<int>> get onValueReceived => FlutterBluePlus.instance._methodStream
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

    // Only allow a single read or write operation
    // at a time, to prevent race conditions.
    await _readWriteMutex.synchronized(() async {
      var request = BmReadDescriptorRequest(
        remoteId: remoteId.toString(),
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        characteristicUuid: characteristicUuid,
        descriptorUuid: descriptorUuid,
      );

      Stream<BmOnDescriptorResponse> responseStream = FlutterBluePlus.instance._methodStream
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

      await FlutterBluePlus.instance._channel.invokeMethod('readDescriptor', request.toMap());

      BmOnDescriptorResponse response = await futureResponse.timeout(Duration(seconds: timeout));

      // failure?
      if (!response.success) {
        throw FlutterBluePlusException("readDescriptorFail", response.errorCode, response.errorString);
      }

      readValue = response.value;
    }).catchError((e, stacktrace) {
      throw Exception("$e $stacktrace");
    });

    return readValue;
  }

  /// Writes the value of a descriptor
  Future<void> write(List<int> value, {int timeout = 15}) async {
    // Only allow a single read or write operation
    // at a time, to prevent race conditions.
    await _readWriteMutex.synchronized(() async {
      var request = BmWriteDescriptorRequest(
        remoteId: remoteId.toString(),
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        characteristicUuid: characteristicUuid,
        descriptorUuid: descriptorUuid,
        value: value,
      );

      Stream<BmOnDescriptorResponse> responseStream = FlutterBluePlus.instance._methodStream
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

      await FlutterBluePlus.instance._channel.invokeMethod('writeDescriptor', request.toMap());

      BmOnDescriptorResponse response = await futureResponse.timeout(Duration(seconds: timeout));

      // failure?
      if (!response.success) {
        throw FlutterBluePlusException("writeDescriptorFail", response.errorCode, response.errorString);
      }
    }).catchError((e, stacktrace) {
      throw Exception("$e $stacktrace");
    });

    return Future.value();
  }

  @override
  String toString() {
    return 'BluetoothDescriptor{'
        'descriptorUuid: $descriptorUuid, '
        'remoteId: $remoteId, '
        'serviceUuid: $serviceUuid, '
        'characteristicUuid: $characteristicUuid, '
        'lastValue: $lastValue'
        '}';
  }

  @Deprecated('Use onValueReceived instead')
  Stream<List<int>> get value => onValueReceived;

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get deviceId => remoteId;

  @Deprecated('Use descriptorUuid instead')
  Guid get uuid => descriptorUuid;
}
