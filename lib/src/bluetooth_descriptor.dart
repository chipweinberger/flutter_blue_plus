// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDescriptor {
  static final Guid cccd = Guid("00002902-0000-1000-8000-00805f9b34fb");

  final Guid uuid;
  final DeviceIdentifier deviceId;
  final Guid serviceUuid;
  final Guid characteristicUuid;

  final BehaviorSubject<List<int>> _value;
  Stream<List<int>> get value => _value.stream;

  List<int> get lastValue => _value.latestValue;

  final Mutex _readWriteMutex = Mutex();

  BluetoothDescriptor.fromProto(protos.BluetoothDescriptor p)
      : uuid = Guid(p.uuid),
        deviceId = DeviceIdentifier(p.remoteId),
        serviceUuid = Guid(p.serviceUuid),
        characteristicUuid = Guid(p.characteristicUuid),
        _value = BehaviorSubject(p.value);

  /// Retrieves the value of a specified descriptor
  Future<List<int>> read() async {

    List<int> readValue = [];

    // Only allow a single read or write operation
    // at a time, to prevent race conditions.
    await _readWriteMutex.synchronized(() async {

      var request = protos.ReadDescriptorRequest.create()
        ..remoteId = deviceId.toString()
        ..descriptorUuid = uuid.toString()
        ..characteristicUuid = characteristicUuid.toString()
        ..serviceUuid = serviceUuid.toString();

      Stream<protos.ReadDescriptorResponse> responseStream =
          FlutterBluePlus.instance._methodStream
              .where((m) => m.method == "ReadDescriptorResponse")
              .map((m) => m.arguments)
              .map((buffer) => protos.ReadDescriptorResponse.fromBuffer(buffer))
              .where((p) =>
                  (p.request.remoteId == request.remoteId) &&
                  (p.request.descriptorUuid == request.descriptorUuid) &&
                  (p.request.characteristicUuid == request.characteristicUuid) &&
                  (p.request.serviceUuid == request.serviceUuid));

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<protos.ReadDescriptorResponse> futureResponse = responseStream.first;

      await FlutterBluePlus.instance._channel
        .invokeMethod('readDescriptor', request.writeToBuffer());

      protos.ReadDescriptorResponse response = await futureResponse;

      readValue = response.value;

      _value.add(readValue);
    });

    return readValue;
  }


  /// Writes the value of a descriptor
  Future<void> write(List<int> value) async {

    // Only allow a single read or write operation
    // at a time, to prevent race conditions.
    await _readWriteMutex.synchronized(() async {

      var request = protos.WriteDescriptorRequest.create()
        ..remoteId = deviceId.toString()
        ..descriptorUuid = uuid.toString()
        ..characteristicUuid = characteristicUuid.toString()
        ..serviceUuid = serviceUuid.toString()
        ..value = value;

      Stream<protos.WriteDescriptorResponse> responseStream =
          FlutterBluePlus.instance._methodStream
              .where((m) => m.method == "WriteDescriptorResponse")
              .map((m) => m.arguments)
              .map((buffer) => protos.WriteDescriptorResponse.fromBuffer(buffer))
              .where((p) =>
                  (p.request.remoteId == request.remoteId) &&
                  (p.request.descriptorUuid == request.descriptorUuid) &&
                  (p.request.characteristicUuid == request.characteristicUuid) &&
                  (p.request.serviceUuid == request.serviceUuid));

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<protos.WriteDescriptorResponse> futureResponse = responseStream.first;

      await FlutterBluePlus.instance._channel
            .invokeMethod('writeDescriptor', request.writeToBuffer());

      protos.WriteDescriptorResponse response = await futureResponse;

      if (!response.success) {
        throw Exception('Failed to write the descriptor');
      }

      _value.add(value);

      return Future.value();
    });
  }


  @override
  String toString() {
    return 'BluetoothDescriptor{uuid: $uuid, deviceId: $deviceId, serviceUuid: $serviceUuid, characteristicUuid: $characteristicUuid, value: ${_value.value}}';
  }
}
