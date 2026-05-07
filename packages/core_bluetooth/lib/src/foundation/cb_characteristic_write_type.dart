part of '../core_bluetooth.dart';

enum CBCharacteristicWriteType {
  withResponse(0),
  withoutResponse(1);

  const CBCharacteristicWriteType(this.rawValue);

  final int rawValue;
}
