part of '../core_bluetooth.dart';

enum CBPeripheralManagerConnectionLatency {
  low(0),
  medium(1),
  high(2);

  const CBPeripheralManagerConnectionLatency(this.rawValue);

  final int rawValue;
}
