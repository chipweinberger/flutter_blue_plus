// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

// Supports 16-bit, 32-bit, or 128-bit UUIDs
class Guid {
  final List<int> bytes;

  Guid.empty() : bytes = List.filled(16, 0);

  Guid.fromBytes(this.bytes) : assert(_checkLen(bytes.length), 'GUID must be 16, 32, or 128 bit.');

  Guid.fromString(String input) : bytes = _fromString(input);

  Guid(String input) : bytes = _fromString(input);

  static List<int> _fromString(String input) {
    if (input.isEmpty) {
      return List.filled(16, 0);
    }

    input = input.replaceAll('-', '');

    List<int>? bytes = _tryHexDecode(input);
    if (bytes == null) {
      throw FormatException("GUID not hex format: $input");
    }

    _checkLen(bytes.length);

    return bytes;
  }

  static bool _checkLen(int len) {
    if (!(len == 16 || len == 4 || len == 2)) {
      throw FormatException("GUID must be 16, 32, or 128 bit, yours: ${len * 8}-bit");
    }
    return true;
  }

  // 128-bit representation
  String get str128 {
    if (bytes.length == 2) {
      // 16-bit uuid
      return '0000${_hexEncode(bytes)}-0000-1000-8000-00805f9b34fb'.toLowerCase();
    }
    if (bytes.length == 4) {
      // 32-bit uuid
      return '${_hexEncode(bytes)}-0000-1000-8000-00805f9b34fb'.toLowerCase();
    }
    // 128-bit uuid
    String one = _hexEncode(bytes.sublist(0, 4));
    String two = _hexEncode(bytes.sublist(4, 6));
    String three = _hexEncode(bytes.sublist(6, 8));
    String four = _hexEncode(bytes.sublist(8, 10));
    String five = _hexEncode(bytes.sublist(10, 16));
    return "$one-$two-$three-$four-$five".toLowerCase();
  }

  // shortest representation
  String get str {
    bool starts = str128.startsWith('0000');
    bool ends = str128.contains('-0000-1000-8000-00805f9b34fb');
    if (starts && ends) {
      // 16-bit
      return str128.substring(4, 8);
    }
    if (ends) {
      // 32-bit
      return str128.substring(0, 8);
    }
    // 128-bit
    return str128;
  }

  @override
  String toString() => str;

  @override
  operator ==(other) => other is Guid && hashCode == other.hashCode;

  @override
  int get hashCode => str128.hashCode;

  @Deprecated('use str128 instead')
  String get uuid128 => str128;

  @Deprecated('use str instead')
  String get uuid => str;
}
