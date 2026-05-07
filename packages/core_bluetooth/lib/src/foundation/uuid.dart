part of '../core_bluetooth.dart';

typedef UUIDBytes = (
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
);

final class UUID {
  UUID(String uuidString)
      : uuidString = _normalizeUuidString(uuidString),
        uuid = _uuidBytesFromString(uuidString);

  UUID.fromBytes(UUIDBytes bytes)
      : uuid = bytes,
        uuidString = _uuidStringFromBytes(bytes);

  final UUIDBytes uuid;
  final String uuidString;

  @override
  bool operator ==(Object other) {
    return other is UUID && other.uuidString == uuidString;
  }

  @override
  int get hashCode => uuidString.hashCode;

  @override
  String toString() => uuidString;
}

String _normalizeUuidString(String uuidString) {
  final lowercased = uuidString.toLowerCase();
  final hex = lowercased.replaceAll('-', '');
  if (hex.length != 32) {
    throw FormatException('Invalid UUID string: $uuidString');
  }

  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}

UUIDBytes _uuidBytesFromString(String uuidString) {
  final normalized = _normalizeUuidString(uuidString).replaceAll('-', '');
  final values = List<int>.generate(
    16,
    (index) => int.parse(normalized.substring(index * 2, index * 2 + 2), radix: 16),
    growable: false,
  );

  return (
    values[0],
    values[1],
    values[2],
    values[3],
    values[4],
    values[5],
    values[6],
    values[7],
    values[8],
    values[9],
    values[10],
    values[11],
    values[12],
    values[13],
    values[14],
    values[15],
  );
}

String _uuidStringFromBytes(UUIDBytes bytes) {
  final values = [
    bytes.$1,
    bytes.$2,
    bytes.$3,
    bytes.$4,
    bytes.$5,
    bytes.$6,
    bytes.$7,
    bytes.$8,
    bytes.$9,
    bytes.$10,
    bytes.$11,
    bytes.$12,
    bytes.$13,
    bytes.$14,
    bytes.$15,
    bytes.$16,
  ];
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
