part of '../core_bluetooth.dart';

final class CBATTRequest {
  CBATTRequest({
    required this.central,
    required this.characteristic,
    required this.offset,
    this.value,
    String? handle,
  }) : _handle = handle;

  final CBCentral central;
  final CBCharacteristic characteristic;
  final int offset;
  final String? _handle;
  Uint8List? value;
}
