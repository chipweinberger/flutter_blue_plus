part of '../core_bluetooth.dart';

final class CBCharacteristicProperties {
  const CBCharacteristicProperties(this.rawValue);

  static const authenticatedSignedWrites = CBCharacteristicProperties(0x40);
  static const broadcast = CBCharacteristicProperties(0x01);
  static const extendedProperties = CBCharacteristicProperties(0x80);
  static const indicate = CBCharacteristicProperties(0x20);
  static const indicateEncryptionRequired = CBCharacteristicProperties(0x200);
  static const notify = CBCharacteristicProperties(0x10);
  static const notifyEncryptionRequired = CBCharacteristicProperties(0x100);
  static const read = CBCharacteristicProperties(0x02);
  static const write = CBCharacteristicProperties(0x08);
  static const writeWithoutResponse = CBCharacteristicProperties(0x04);

  final int rawValue;

  bool get hasAuthenticatedSignedWrites => contains(authenticatedSignedWrites);
  bool get hasBroadcast => contains(broadcast);
  bool get hasExtendedProperties => contains(extendedProperties);
  bool get hasIndicate => contains(indicate);
  bool get hasIndicateEncryptionRequired => contains(indicateEncryptionRequired);
  bool get hasNotify => contains(notify);
  bool get hasNotifyEncryptionRequired => contains(notifyEncryptionRequired);
  bool get hasRead => contains(read);
  bool get hasWrite => contains(write);
  bool get hasWriteWithoutResponse => contains(writeWithoutResponse);

  bool contains(CBCharacteristicProperties value) {
    return (rawValue & value.rawValue) == value.rawValue;
  }
}
