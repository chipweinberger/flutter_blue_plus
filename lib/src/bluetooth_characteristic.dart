// Copyright 2023, Charles Weinberger & Paul DeMarco.
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

  // same as onValueReceived, but the stream immediately starts
  // with lastValue as its first value to not cause delay
  Stream<List<int>> get lastValueStream => onValueReceived.newStreamWithInitialValue(lastValue);

  // this stream is updated:
  //   - after read() is called
  //   - when a notification arrives
  Stream<List<int>> get onValueReceived => FlutterBluePlus._methodStream.stream
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

  /// read a characteristic
  Future<List<int>> read({int timeout = 15}) async {
    List<int> responseValue = [];

    // check & wait if bonding
    await BluetoothDevice._waitIfBonding(remoteId);

    // Only allows a single read to be underway at any time, per-characteristic, per-device.
    // Otherwise, there would be multiple in-flight reads and we wouldn't know which response is which.
    String key = remoteId.str + ":" + characteristicUuid.toString() + ":readChr";
    _Mutex readMutex = await _MutexFactory.getMutexForKey(key);
    await readMutex.take();

    try {
      var request = BmReadCharacteristicRequest(
        remoteId: remoteId.toString(),
        characteristicUuid: characteristicUuid,
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
      );

      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnCharacteristicReceived")
          .map((m) => m.arguments)
          .map((buffer) => BmOnCharacteristicReceived.fromMap(buffer))
          .where((p) => p.remoteId == request.remoteId)
          .where((p) => p.serviceUuid == request.serviceUuid)
          .where((p) => p.characteristicUuid == request.characteristicUuid);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmOnCharacteristicReceived> futureResponse = responseStream.first;

      await FlutterBluePlus._invokeMethod('readCharacteristic', request.toMap());

      BmOnCharacteristicReceived response = await futureResponse.timeout(Duration(seconds: timeout));

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException("readCharacteristic", response.errorCode, response.errorString);
      }

      // cache latest value
      lastValue = response.value;

      // set return value
      responseValue = response.value;
    } finally {
      readMutex.give();
    }

    return responseValue;
  }

  /// Writes a characteristic.
  ///  - [withoutResponse]: the write is not guaranteed and always returns immediately with success.
  ///  - [withResponse]: the write returns error on failure
  Future<void> write(List<int> value, {bool withoutResponse = false, int timeout = 15}) async {
    // check & wait if bonding
    await BluetoothDevice._waitIfBonding(remoteId);

    // Only allows a single write to be underway at any time, per-characteristic, per-device.
    // Otherwise, there would be multiple in-flight writes and we wouldn't know which response is which.
    String key = remoteId.str + ":" + characteristicUuid.toString() + ":writeChr";
    _Mutex writeMutex = await _MutexFactory.getMutexForKey(key);
    await writeMutex.take();

    // edge case: In order to avoid dropped packets, whenever we do a writeWithoutResponse, we
    // wait for the device to say it is ready for more again before we return from this function,
    // that way the next time we call write(writeWithoutResponse:true) we know the device is already
    // ready and will not drop the packet. This 'ready' signal is per-device, so we can only have
    // 1 writeWithoutResponse request in-flight at a time, per device.
    _Mutex deviceReady = await _MutexFactory.getMutexForKey(remoteId.str + ":withoutResp");
    if (withoutResponse) {
      await deviceReady.take();
    }

    try {
      final writeType = withoutResponse ? BmWriteType.withoutResponse : BmWriteType.withResponse;

      var request = BmWriteCharacteristicRequest(
        remoteId: remoteId.toString(),
        characteristicUuid: characteristicUuid,
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        writeType: writeType,
        value: value,
      );

      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnCharacteristicWritten")
          .map((m) => m.arguments)
          .map((buffer) => BmOnCharacteristicWritten.fromMap(buffer))
          .where((p) => p.remoteId == request.remoteId)
          .where((p) => p.serviceUuid == request.serviceUuid)
          .where((p) => p.characteristicUuid == request.characteristicUuid);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmOnCharacteristicWritten> futureResponse = responseStream.first;

      await FlutterBluePlus._invokeMethod('writeCharacteristic', request.toMap());

      // wait for response so that we can:
      //  1. check for success (writeWithResponse)
      //  2. wait until the packet has been sent, to prevent iOS & Android dropping packets (writeWithoutResponse)
      BmOnCharacteristicWritten response = await futureResponse.timeout(Duration(seconds: timeout));

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException("writeCharacteristic", response.errorCode, response.errorString);
      }

      return Future.value();
    } finally {
      writeMutex.give();
      if (withoutResponse) {
        deviceReady.give();
      }
    }
  }

  /// Sets notifications or indications for the characteristic.
  ///   - If a characteristic supports both notifications and indications,
  ///     we'll use notifications. This is a limitation of CoreBluetooth on iOS.
  Future<bool> setNotifyValue(bool notify, {int timeout = 15}) async {
    // check & wait if bonding
    await BluetoothDevice._waitIfBonding(remoteId);

    var request = BmSetNotificationRequest(
      remoteId: remoteId.toString(),
      serviceUuid: serviceUuid,
      secondaryServiceUuid: null,
      characteristicUuid: characteristicUuid,
      enable: notify,
    );

    // Notifications & Indications are configured by writing to the
    // Client Characteristic Configuration Descriptor (CCCD)
    Stream<BmOnDescriptorResponse> responseStream = FlutterBluePlus._methodStream.stream
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

    await FlutterBluePlus._invokeMethod('setNotification', request.toMap());

    // wait for response, so that we can check for success
    BmOnDescriptorResponse response = await futureResponse.timeout(Duration(seconds: timeout));

    // failed?
    if (!response.success) {
      throw FlutterBluePlusException("setNotifyValue", response.errorCode, response.errorString);
    }

    // verify notifications were actually set correctly
    var cccd = response.value;
    var hasNotify = cccd.isNotEmpty && (cccd[0] & 0x01) > 0;
    var hasIndicate = cccd.isNotEmpty && (cccd[0] & 0x02) > 0;
    var isEnabled = hasNotify || hasIndicate;
    if (notify != isEnabled) {
      throw FlutterBluePlusException("setNotifyValue", -1, "notifications were not updated");
    }

    // update descriptor
    for (var d in descriptors) {
      if (d.uuid == BluetoothDescriptor.cccd) {
        d.lastValue = response.value;
      }
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
