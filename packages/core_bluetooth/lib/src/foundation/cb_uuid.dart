part of '../core_bluetooth.dart';

final class CBUUID {
  CBUUID(String uuidString)
      : uuidString = _normalizeBluetoothUuidString(uuidString),
        _data = _uuidDataFromString(uuidString),
        _canonicalUuidString = _expandBluetoothUuidString(uuidString);

  CBUUID.string(String theString) : this(theString);

  CBUUID.fromData(Uint8List data)
      : _data = Uint8List.fromList(data),
        uuidString = _uuidStringFromData(data),
        _canonicalUuidString = _expandBluetoothUuidString(_uuidStringFromData(data));

  CBUUID.data(Uint8List theData) : this.fromData(theData);

  CBUUID.fromNSUUID(UUID nsuuid)
      : uuidString = nsuuid.uuidString,
        _data = _uuidDataFromString(nsuuid.uuidString),
        _canonicalUuidString = _expandBluetoothUuidString(nsuuid.uuidString);

  CBUUID.nsuuid(UUID theUUID) : this.fromNSUUID(theUUID);

  final Uint8List _data;
  final String uuidString;
  final String _canonicalUuidString;

  /// An independent byte copy. Editing it does not change this UUID.
  Uint8List get data => Uint8List.fromList(_data);

  @override
  bool operator ==(Object other) {
    return other is CBUUID && other._canonicalUuidString == _canonicalUuidString;
  }

  @override
  int get hashCode => _canonicalUuidString.hashCode;

  @override
  String toString() => uuidString;
}

String _expandBluetoothUuidString(String uuidString) {
  final normalized = _normalizeBluetoothUuidString(uuidString);
  final hex = normalized.replaceAll('-', '');
  return switch (hex.length) {
    4 => '0000$hex-0000-1000-8000-00805f9b34fb',
    8 => '$hex-0000-1000-8000-00805f9b34fb',
    32 => '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}',
    _ => throw FormatException('Invalid Bluetooth UUID string: $uuidString'),
  };
}

String _normalizeBluetoothUuidString(String uuidString) {
  final lowercased = uuidString.toLowerCase();
  final hex = lowercased.replaceAll('-', '');
  if (_invalidUuidCharacter.hasMatch(hex)) {
    throw FormatException('Invalid Bluetooth UUID string: $uuidString');
  }

  return switch (hex.length) {
    4 || 8 => hex,
    32 => '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}',
    _ => throw FormatException('Invalid Bluetooth UUID string: $uuidString'),
  };
}

Uint8List _uuidDataFromString(String uuidString) {
  final normalized = _normalizeBluetoothUuidString(uuidString).replaceAll('-', '');
  return Uint8List.fromList(
    List<int>.generate(
      normalized.length ~/ 2,
      (index) => int.parse(normalized.substring(index * 2, index * 2 + 2), radix: 16),
      growable: false,
    ),
  );
}

String _uuidStringFromData(Uint8List data) {
  final hex = data.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return switch (data.length) {
    2 || 4 => hex,
    16 => '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}',
    _ => throw FormatException('Invalid Bluetooth UUID data length: ${data.length}'),
  };
}
