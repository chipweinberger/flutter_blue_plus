// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothCharacteristic {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final CharacteristicProperties properties;
  final List<BluetoothDescriptor> descriptors;

  // convenience accessor
  Guid get uuid => characteristicUuid;

  final _Mutex _readWriteMutex = _Mutex();

  /// this variable is updated:
  ///   - *live* if you call onValueReceived.listen() or lastValueStream.listen()
  ///   - *once* if you call read()
  List<int> lastValue;

  BluetoothCharacteristic.fromProto(BmBluetoothCharacteristic p)
      : remoteId = DeviceIdentifier(p.remoteId.toString()),
        serviceUuid = p.serviceUuid,
        secondaryServiceUuid = p.secondaryServiceUuid != null ? p.secondaryServiceUuid! : null,
        characteristicUuid = p.characteristicUuid,
        descriptors = p.descriptors.map((d) => BluetoothDescriptor.fromProto(d)).toList(),
        properties = CharacteristicProperties.fromProto(p.properties),
        lastValue = p.value;

  // same as onValueReceived, but the stream starts
  // with lastValue as its first value (to not cause delay)
  Stream<List<int>> get lastValueStream => onValueReceived.newStreamWithInitialValue(lastValue);

  // this stream is updated:
  //   1. after read() is called
  //   2. when a notification arrives
  Stream<List<int>> get onValueReceived => FlutterBluePlus.instance._methodStream
          .where((m) => m.method == "OnCharacteristicReceived")
          .map((m) => m.arguments)
          .map((buffer) => BmOnCharacteristicReceived.fromMap(buffer))
          .where((p) => p.remoteId == remoteId.toString())
          .where((p) => p.serviceUuid == serviceUuid)
          .where((p) => p.characteristicUuid == characteristicUuid)
          .where((p) => p.success == true)
          .map((c) {
        lastValue = c.value; // Update cache of lastValue
        return c.value;
      });

  bool get isNotifying {
    try {
      var cccd = descriptors.singleWhere((d) => d.descriptorUuid == BluetoothDescriptor.cccd);
      var hasNotify = cccd.lastValue.isNotEmpty && (cccd.lastValue[0] & 0x01) > 0;
      var hasIndicate = cccd.lastValue.isNotEmpty && (cccd.lastValue[0] & 0x02) > 0;
      return hasNotify || hasIndicate;
    } catch (e) {
      return false;
    }
  }

  /// Retrieves the value of the characteristic
  Future<List<int>> read({int timeout = 15}) async {
    List<int> responseValue = [];

    // Only allow a single read or write operation
    // at a time, to prevent race conditions.
    await _readWriteMutex.synchronized(() async {
      var request = BmReadCharacteristicRequest(
        remoteId: remoteId.toString(),
        characteristicUuid: characteristicUuid,
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
      );

      FlutterBluePlus.instance._log(
          LogLevel.info,
          'remoteId: ${remoteId.toString()}'
          'characteristicUuid: ${characteristicUuid.toString()}'
          'serviceUuid: ${serviceUuid.toString()}');

      var responseStream = FlutterBluePlus.instance._methodStream
          .where((m) => m.method == "OnCharacteristicReceived")
          .map((m) => m.arguments)
          .map((buffer) => BmOnCharacteristicReceived.fromMap(buffer))
          .where((p) => p.remoteId == request.remoteId)
          .where((p) => p.serviceUuid == request.serviceUuid)
          .where((p) => p.characteristicUuid == request.characteristicUuid);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmOnCharacteristicReceived> futureResponse = responseStream.first;

      await FlutterBluePlus.instance._channel.invokeMethod('readCharacteristic', request.toMap());

      BmOnCharacteristicReceived response = await futureResponse.timeout(Duration(seconds: timeout));

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException("charactersticReadFail", response.errorCode, response.errorString);
      }

      // cache latest value
      lastValue = response.value;

      // set return value
      responseValue = response.value;
    }).catchError((e, stacktrace) {
      throw Exception("$e $stacktrace");
    });

    return responseValue;
  }

  /// Writes the value of a characteristic.
  /// [CharacteristicWriteType.withoutResponse]: the write is not
  /// guaranteed and will return immediately with success.
  /// [CharacteristicWriteType.withResponse]: the method will return after the
  /// write operation has either passed or failed.
  Future<void> write(List<int> value, {bool withoutResponse = false, int timeout = 15}) async {
    // Only allow a single read or write operation
    // at a time, to prevent race conditions.
    await _readWriteMutex.synchronized(() async {
      final writeType = withoutResponse ? BmWriteType.withoutResponse : BmWriteType.withResponse;

      var request = BmWriteCharacteristicRequest(
        remoteId: remoteId.toString(),
        characteristicUuid: characteristicUuid,
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        writeType: writeType,
        value: value,
      );

      if (writeType == BmWriteType.withResponse) {
        var responseStream = FlutterBluePlus.instance._methodStream
            .where((m) => m.method == "OnCharacteristicWritten")
            .map((m) => m.arguments)
            .map((buffer) => BmOnCharacteristicWritten.fromMap(buffer))
            .where((p) => p.remoteId == request.remoteId)
            .where((p) => p.serviceUuid == request.serviceUuid)
            .where((p) => p.characteristicUuid == request.characteristicUuid);

        // Start listening now, before invokeMethod, to ensure we don't miss the response
        Future<BmOnCharacteristicWritten> futureResponse = responseStream.first;

        await FlutterBluePlus.instance._channel.invokeMethod('writeCharacteristic', request.toMap());

        // wait for response, so that we can check for success
        BmOnCharacteristicWritten response = await futureResponse.timeout(Duration(seconds: timeout));

        // failed?
        if (!response.success) {
          throw FlutterBluePlusException("charactersticWriteFail", response.errorCode, response.errorString);
        }

        return Future.value();
      } else {
        // invoke without waiting for reply
        return FlutterBluePlus.instance._channel.invokeMethod('writeCharacteristic', request.toMap());
      }
    }).catchError((e, stacktrace) {
      throw Exception("$e $stacktrace");
    });
  }

  /// Sets notifications or indications for the value of a specified characteristic
  Future<bool> setNotifyValue(bool notify, {int timeout = 15}) async {
    var request = BmSetNotificationRequest(
      remoteId: remoteId.toString(),
      serviceUuid: serviceUuid,
      secondaryServiceUuid: null,
      characteristicUuid: characteristicUuid,
      enable: notify,
    );

    // Notifications & Indications are configured by writing to the
    // Client Characteristic Configuration Descriptor (CCCD)
    Stream<BmOnDescriptorResponse> responseStream = FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "OnDescriptorResponse")
        .map((m) => m.arguments)
        .map((buffer) => BmOnDescriptorResponse.fromMap(buffer))
        .where((p) => p.type == BmOnDescriptorResponseType.write)
        .where((p) => p.remoteId == request.remoteId)
        .where((p) => p.serviceUuid == request.serviceUuid)
        .where((p) => p.characteristicUuid == request.characteristicUuid)
        .where((p) => p.descriptorUuid == BluetoothDescriptor.cccd);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BmOnDescriptorResponse> futureResponse = responseStream.first;

    await FlutterBluePlus.instance._channel.invokeMethod('setNotification', request.toMap());

    // wait for response, so that we can check for success
    BmOnDescriptorResponse response = await futureResponse.timeout(Duration(seconds: timeout));

    // failed?
    if (!response.success) {
      throw FlutterBluePlusException("setNotifyValueFail", response.errorCode, response.errorString);
    }

    // verify notifications were actually set correctly
    var cccd = response.value;
    var hasNotify = cccd.isNotEmpty && (cccd[0] & 0x01) > 0;
    var hasIndicate = cccd.isNotEmpty && (cccd[0] & 0x02) > 0;
    var isEnabled = hasNotify || hasIndicate;
    if (notify != isEnabled) {
      throw FlutterBluePlusException("setNotifyValueFail", -1, "notifications were not updated");
    }

    return notify == isEnabled;
  }

  @override
  String toString() {
    return 'BluetoothCharacteristic{'
        'remoteId: $remoteId, '
        'serviceUuid: $serviceUuid, '
        'secondaryServiceUuid: $secondaryServiceUuid, '
        'characteristicUuid: $characteristicUuid, '
        'descriptors: $descriptors, '
        'properties: $properties, '
        'value: $lastValue'
        '}';
  }

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get deviceId => remoteId;

  @Deprecated('Use lastValueStream instead')
  Stream<List<int>> get value => lastValueStream;

  @Deprecated('Use onValueReceived instead')
  Stream<List<int>> get onValueChangedStream => onValueReceived;
}

class CharacteristicProperties {
  final bool broadcast;
  final bool read;
  final bool writeWithoutResponse;
  final bool write;
  final bool notify;
  final bool indicate;
  final bool authenticatedSignedWrites;
  final bool extendedProperties;
  final bool notifyEncryptionRequired;
  final bool indicateEncryptionRequired;

  const CharacteristicProperties(
      {this.broadcast = false,
      this.read = false,
      this.writeWithoutResponse = false,
      this.write = false,
      this.notify = false,
      this.indicate = false,
      this.authenticatedSignedWrites = false,
      this.extendedProperties = false,
      this.notifyEncryptionRequired = false,
      this.indicateEncryptionRequired = false});

  CharacteristicProperties.fromProto(BmCharacteristicProperties p)
      : broadcast = p.broadcast,
        read = p.read,
        writeWithoutResponse = p.writeWithoutResponse,
        write = p.write,
        notify = p.notify,
        indicate = p.indicate,
        authenticatedSignedWrites = p.authenticatedSignedWrites,
        extendedProperties = p.extendedProperties,
        notifyEncryptionRequired = p.notifyEncryptionRequired,
        indicateEncryptionRequired = p.indicateEncryptionRequired;

  @override
  String toString() {
    return 'CharacteristicProperties{'
        'broadcast: $broadcast, '
        'read: $read, '
        'writeWithoutResponse: $writeWithoutResponse, '
        'write: $write, '
        'notify: $notify, '
        'indicate: $indicate, '
        'authenticatedSignedWrites: $authenticatedSignedWrites, '
        'extendedProperties: $extendedProperties, '
        'notifyEncryptionRequired: $notifyEncryptionRequired, '
        'indicateEncryptionRequired: $indicateEncryptionRequired'
        '}';
  }
}
