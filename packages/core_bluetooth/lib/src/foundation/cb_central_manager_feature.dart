part of '../core_bluetooth.dart';

final class CBCentralManagerFeature {
  const CBCentralManagerFeature(this.rawValue);

  static const extendedScanAndConnect = CBCentralManagerFeature(1 << 0);

  final int rawValue;

  bool contains(CBCentralManagerFeature value) {
    return (rawValue & value.rawValue) == value.rawValue;
  }
}
