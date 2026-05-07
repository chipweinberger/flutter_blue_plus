part of '../core_bluetooth.dart';

final class CBErrorCode {
  const CBErrorCode._(this.rawValue);

  static const unknown = CBErrorCode._(0);
  static const invalidParameters = CBErrorCode._(1);
  static const invalidHandle = CBErrorCode._(2);
  static const notConnected = CBErrorCode._(3);
  static const outOfSpace = CBErrorCode._(4);
  static const operationCancelled = CBErrorCode._(5);
  static const connectionTimeout = CBErrorCode._(6);
  static const peripheralDisconnected = CBErrorCode._(7);
  static const uuidNotAllowed = CBErrorCode._(8);
  static const alreadyAdvertising = CBErrorCode._(9);
  static const connectionFailed = CBErrorCode._(10);
  static const connectionLimitReached = CBErrorCode._(11);
  static const unknownDevice = CBErrorCode._(12);
  static const operationNotSupported = CBErrorCode._(13);
  static const peerRemovedPairingInformation = CBErrorCode._(14);

  factory CBErrorCode.fromRawValue(int rawValue) {
    return switch (rawValue) {
      1 => invalidParameters,
      2 => invalidHandle,
      3 => notConnected,
      4 => outOfSpace,
      5 => operationCancelled,
      6 => connectionTimeout,
      7 => peripheralDisconnected,
      8 => uuidNotAllowed,
      9 => alreadyAdvertising,
      10 => connectionFailed,
      11 => connectionLimitReached,
      12 => unknownDevice,
      13 => operationNotSupported,
      14 => peerRemovedPairingInformation,
      0 || _ => unknown,
    };
  }

  final int rawValue;

  @override
  bool operator ==(Object other) => other is CBErrorCode && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;
}
