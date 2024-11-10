// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

abstract class BluetoothAttribute {
  final BluetoothDevice device;
  final Guid uuid;
  final int? index;

  BluetoothAttribute({
    required this.device,
    required this.uuid,
    this.index,
  });

  DeviceIdentifier get remoteId => device.remoteId;

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get deviceId => remoteId;

  BluetoothAttribute? get _parentAttribute => null;

  String get identifier => "$uuid:$index";

  String get identifierPath =>
      _parentAttribute != null ? "${_parentAttribute!.identifierPath}/$identifier" : identifier;
}

abstract class BluetoothValueAttribute extends BluetoothAttribute {
  List<int> _lastValue = [];

  BluetoothValueAttribute({
    required BluetoothDevice device,
    required Guid uuid,
    int? index,
  }) : super(device: device, uuid: uuid, index: index);

  /// this variable is updated:
  ///   - anytime `read()` is called
  ///   - anytime `write()` is called
  ///   - anytime a notification arrives (characteristics, if subscribed)
  ///   - when the device is disconnected it is cleared
  List<int> get lastValue => _lastValue;

  /// this stream emits values:
  ///   - anytime `read()` is called
  ///   - anytime `write()` is called
  ///   - anytime a notification arrives (characteristics, if subscribed)
  ///   - and when first listened to, it re-emits the last value for convenience
  Stream<List<int>> get lastValueStream => FlutterBluePlus._methodStream.stream
      .where((e) =>
          e is OnCharacteristicReceivedEvent ||
          e is OnCharacteristicWrittenEvent ||
          e is OnDescriptorReadEvent ||
          e is OnDescriptorWrittenEvent)
      .map((e) => e as GetAttributeValueMixin)
      .where((e) => e.attribute == this)
      .map((e) => e.value)
      .newStreamWithInitialValue(lastValue);

  /// this stream emits values:
  ///   - anytime `read()` is called
  ///   - anytime a notification arrives (if subscribed)
  Stream<List<int>> get onValueReceived => FlutterBluePlus._methodStream.stream
      .where((e) => e is OnCharacteristicReceivedEvent || e is OnDescriptorReadEvent)
      .map((e) => e as GetAttributeValueMixin)
      .where((e) => e.attribute == this)
      .map((e) => e.value);

  @Deprecated('Use onValueReceived instead')
  Stream<List<int>> get value => onValueReceived;

  @Deprecated('Use onValueReceived instead')
  Stream<List<int>> get onValueChangedStream => onValueReceived;
}
