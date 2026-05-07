part of '../core_bluetooth.dart';

final class CBATTErrorCode {
  const CBATTErrorCode(this.rawValue);

  static const success = CBATTErrorCode(0);
  static const invalidHandle = CBATTErrorCode(1);
  static const readNotPermitted = CBATTErrorCode(2);
  static const writeNotPermitted = CBATTErrorCode(3);
  static const invalidPdu = CBATTErrorCode(4);
  static const insufficientAuthentication = CBATTErrorCode(5);
  static const requestNotSupported = CBATTErrorCode(6);
  static const invalidOffset = CBATTErrorCode(7);
  static const insufficientAuthorization = CBATTErrorCode(8);
  static const prepareQueueFull = CBATTErrorCode(9);
  static const attributeNotFound = CBATTErrorCode(10);
  static const attributeNotLong = CBATTErrorCode(11);
  static const insufficientEncryptionKeySize = CBATTErrorCode(12);
  static const invalidAttributeValueLength = CBATTErrorCode(13);
  static const unlikelyError = CBATTErrorCode(14);
  static const insufficientEncryption = CBATTErrorCode(15);
  static const unsupportedGroupType = CBATTErrorCode(16);
  static const insufficientResources = CBATTErrorCode(17);

  final int rawValue;

  @override
  bool operator ==(Object other) {
    return other is CBATTErrorCode && other.rawValue == rawValue;
  }

  @override
  int get hashCode => rawValue.hashCode;
}
