// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

final Guid cccdUuid = Guid("00002902-0000-1000-8000-00805f9b34fb");

class BluetoothCharacteristic {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;

  BluetoothCharacteristic({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
  });

  BluetoothCharacteristic.fromProto(BmBluetoothCharacteristic p)
      : remoteId = DeviceIdentifier(p.remoteId.toString()),
        serviceUuid = p.serviceUuid,
        secondaryServiceUuid = p.secondaryServiceUuid != null ? p.secondaryServiceUuid! : null,
        characteristicUuid = p.characteristicUuid;

  /// convenience accessor
  Guid get uuid => characteristicUuid;

  /// convenience accessor
  BluetoothDevice get device => BluetoothDevice(remoteId: remoteId);

  /// Get Properties from known services
  CharacteristicProperties get properties {
    return _bmchr != null ? CharacteristicProperties.fromProto(_bmchr!.properties) : CharacteristicProperties();
  }

  /// Get Descriptors from known services
  List<BluetoothDescriptor> get descriptors {
    return _bmchr != null ? _bmchr!.descriptors.map((d) => BluetoothDescriptor.fromProto(d)).toList() : [];
  }

  /// this variable is updated:
  ///   - anytime `read()` is called
  ///   - anytime `write()` is called
  ///   - anytime a notification arrives (if subscribed)
  ///   - when the device is disconnected it is cleared
  List<int> get lastValue {
    String key = "$serviceUuid:$characteristicUuid";
    return FlutterBluePlus._lastChrs[remoteId]?[key] ?? [];
  }

  /// this stream emits values:
  ///   - anytime `read()` is called
  ///   - anytime `write()` is called
  ///   - anytime a notification arrives (if subscribed)
  ///   - and when first listened to, it re-emits the last value for convenience
  Stream<List<int>> get lastValueStream => FlutterBluePlus._methodStream.stream
      .where((m) => m.method == "OnCharacteristicReceived" || m.method == "OnCharacteristicWritten")
      .map((m) => m.arguments)
      .map((args) => BmCharacteristicData.fromMap(args))
      .where((p) => p.remoteId == remoteId.toString())
      .where((p) => p.serviceUuid == serviceUuid)
      .where((p) => p.characteristicUuid == characteristicUuid)
      .where((p) => p.success == true)
      .map((c) => c.value)
      .newStreamWithInitialValue(lastValue);

  /// this stream emits values:
  ///   - anytime `read()` is called
  ///   - anytime a notification arrives (if subscribed)
  Stream<List<int>> get onValueReceived => FlutterBluePlus._methodStream.stream
      .where((m) => m.method == "OnCharacteristicReceived")
      .map((m) => m.arguments)
      .map((args) => BmCharacteristicData.fromMap(args))
      .where((p) => p.remoteId == remoteId.toString())
      .where((p) => p.serviceUuid == serviceUuid)
      .where((p) => p.characteristicUuid == characteristicUuid)
      .where((p) => p.success == true)
      .map((c) => c.value);

  /// return true if we're subscribed to this characteristic
  ///   -  you can subscribe using setNotifyValue(true)
  bool get isNotifying {
    var cccd = descriptors._firstWhereOrNull((d) => d.descriptorUuid == cccdUuid);
    if (cccd == null) {
      return false;
    }
    var hasNotify = cccd.lastValue.isNotEmpty && (cccd.lastValue[0] & 0x01) > 0;
    var hasIndicate = cccd.lastValue.isNotEmpty && (cccd.lastValue[0] & 0x02) > 0;
    return hasNotify || hasIndicate;
  }

  /// read a characteristic
  Future<List<int>> read({int timeout = 15}) async {
    // check connected
    if (device.isConnected == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "readCharacteristic", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    // return value
    List<int> responseValue = [];

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
          .map((args) => BmCharacteristicData.fromMap(args))
          .where((p) => p.remoteId == request.remoteId)
          .where((p) => p.serviceUuid == request.serviceUuid)
          .where((p) => p.characteristicUuid == request.characteristicUuid);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmCharacteristicData> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('readCharacteristic', request.toMap());

      // wait for response
      BmCharacteristicData response = await futureResponse
          .fbpEnsureAdapterIsOn("readCharacteristic")
          .fbpEnsureDeviceIsConnected(device, "readCharacteristic")
          .fbpTimeout(timeout, "readCharacteristic");

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException(_nativeError, "readCharacteristic", response.errorCode, response.errorString);
      }

      // set return value
      responseValue = response.value;
    } finally {
      mtx.give();
    }

    return responseValue;
  }

  /// Writes a characteristic.
  ///  - [withoutResponse]: the write is not guaranteed and always returns immediately with success.
  ///  - [withResponse]: the write returns error on failure
  ///  - [allowLongWrite]: if set, larger writes > MTU are allowed (up to 512 bytes).
  ///       This should be used with caution.
  ///         1. it can only be used *with* response
  ///         2. the peripheral device must support the 'long write' ble protocol.
  ///         3. Interrupted transfers can leave the characteristic in a partially written state
  ///         4. If the mtu is small, it is very very slow.
  Future<void> write(List<int> value,
      {bool withoutResponse = false, bool allowLongWrite = false, int timeout = 15}) async {
    //  check args
    if (withoutResponse && allowLongWrite) {
      throw ArgumentError("cannot longWrite withoutResponse, not allowed on iOS or Android");
    }

    // check connected
    if (device.isConnected == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "writeCharacteristic", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    try {
      final writeType = withoutResponse ? BmWriteType.withoutResponse : BmWriteType.withResponse;

      var request = BmWriteCharacteristicRequest(
        remoteId: remoteId.toString(),
        characteristicUuid: characteristicUuid,
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        writeType: writeType,
        allowLongWrite: allowLongWrite,
        value: value,
      );

      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnCharacteristicWritten")
          .map((m) => m.arguments)
          .map((args) => BmCharacteristicData.fromMap(args))
          .where((p) => p.remoteId == request.remoteId)
          .where((p) => p.serviceUuid == request.serviceUuid)
          .where((p) => p.characteristicUuid == request.characteristicUuid);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmCharacteristicData> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('writeCharacteristic', request.toMap());

      // wait for response so that we can:
      //  1. check for success (writeWithResponse)
      //  2. wait until the packet has been sent, to prevent iOS & Android dropping packets (writeWithoutResponse)
      BmCharacteristicData response = await futureResponse
          .fbpEnsureAdapterIsOn("writeCharacteristic")
          .fbpEnsureDeviceIsConnected(device, "writeCharacteristic")
          .fbpTimeout(timeout, "writeCharacteristic");

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException(_nativeError, "writeCharacteristic", response.errorCode, response.errorString);
      }

      return Future.value();
    } finally {
      mtx.give();
    }
  }

  /// Sets notifications or indications for the characteristic.
  ///   - If a characteristic supports both notifications and indications,
  ///     we use notifications. This is a limitation of CoreBluetooth on iOS.
  ///   - [forceIndications] Android Only. force indications to be used instead of notifications.
  Future<bool> setNotifyValue(bool notify, {int timeout = 15, bool forceIndications = false}) async {
    // check connected
    if (device.isConnected == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "setNotifyValue", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // check
    if (Platform.isMacOS || Platform.isIOS) {
      assert(forceIndications == false, "iOS & macOS do not support forcing indications");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    try {
      var request = BmSetNotifyValueRequest(
        remoteId: remoteId.toString(),
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        characteristicUuid: characteristicUuid,
        forceIndications: forceIndications,
        enable: notify,
      );

      // Notifications & Indications are configured by writing to the
      // Client Characteristic Configuration Descriptor (CCCD)
      Stream<BmDescriptorData> responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDescriptorWritten")
          .map((m) => m.arguments)
          .map((args) => BmDescriptorData.fromMap(args))
          .where((p) => p.remoteId == request.remoteId)
          .where((p) => p.serviceUuid == request.serviceUuid)
          .where((p) => p.characteristicUuid == request.characteristicUuid)
          .where((p) => p.descriptorUuid == cccdUuid);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmDescriptorData> futureResponse = responseStream.first;

      // invoke
      bool hasCCCD = await FlutterBluePlus._invokeMethod('setNotifyValue', request.toMap());

      // wait for CCCD descriptor to be written?
      if (hasCCCD) {
        BmDescriptorData response = await futureResponse
            .fbpEnsureAdapterIsOn("setNotifyValue")
            .fbpEnsureDeviceIsConnected(device, "setNotifyValue")
            .fbpTimeout(timeout, "setNotifyValue");

        // failed?
        if (!response.success) {
          throw FlutterBluePlusException(_nativeError, "setNotifyValue", response.errorCode, response.errorString);
        }
      }
    } finally {
      mtx.give();
    }

    return true;
  }

  /// look through known services
  BmBluetoothCharacteristic? get _bmchr {
    if (FlutterBluePlus._knownServices[remoteId] != null) {
      for (var s in FlutterBluePlus._knownServices[remoteId]!.services) {
        if (s.serviceUuid == serviceUuid) {
          for (var c in s.characteristics) {
            if (c.characteristicUuid == uuid) {
              return c;
            }
          }
        }
      }
    }
    return null;
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
