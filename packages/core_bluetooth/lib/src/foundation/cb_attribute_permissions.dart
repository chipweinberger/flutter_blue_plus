part of '../core_bluetooth.dart';

final class CBAttributePermissions {
  const CBAttributePermissions(this.rawValue);

  static const readEncryptionRequired = CBAttributePermissions(0x04);
  static const readable = CBAttributePermissions(0x01);
  static const writeEncryptionRequired = CBAttributePermissions(0x08);
  static const writeable = CBAttributePermissions(0x02);

  final int rawValue;

  bool get hasReadEncryptionRequired => contains(readEncryptionRequired);
  bool get hasReadable => contains(readable);
  bool get hasWriteEncryptionRequired => contains(writeEncryptionRequired);
  bool get hasWriteable => contains(writeable);

  bool contains(CBAttributePermissions value) {
    return (rawValue & value.rawValue) == value.rawValue;
  }
}
