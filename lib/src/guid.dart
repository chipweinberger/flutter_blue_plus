// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class Guid {
  final List<int> _bytes;
  final int _hashCode;

  Guid._internal(List<int> bytes)
      : _bytes = bytes,
        _hashCode = _calcHashCode(bytes);

  Guid(String input) : this._internal(_fromString(input));

  Guid.fromMac(String input) : this._internal(_fromMacString(input));

  Guid.empty() : this._internal(List.filled(16, 0));

  static List<int> _fromMacString(String input) {
    input = _removeNonHexCharacters(input);
    final bytes = _hexDecode(input);

    if (bytes.length != 6) {
      throw FormatException("The format is invalid: $input");
    }

    return bytes + List<int>.filled(10, 0);
  }

  static List<int> _fromString(String input) {
    input = _removeNonHexCharacters(input);
    final bytes = _hexDecode(input);

    if (bytes.length != 16) {
      throw const FormatException("The format is invalid");
    }

    return bytes;
  }

  static String _removeNonHexCharacters(String sourceString) {
    return String.fromCharCodes(sourceString.runes.where((r) =>
            (r >= 48 && r <= 57) || // characters 0 to 9
            (r >= 65 && r <= 70) || // characters A to F
            (r >= 97 && r <= 102) // characters a to f
        ));
  }

  static int _calcHashCode(List<int> bytes) {
    const int prime1 = 9007199254740881;
    const int prime2 = 8388880508472777;
    int hash = 0;
    for (int value in bytes) {
      hash = (hash * prime1 + value) % prime2;
    }
    return hash;
  }

  @override
  String toString() {
    String one = _hexEncode(_bytes.sublist(0, 4));
    String two = _hexEncode(_bytes.sublist(4, 6));
    String three = _hexEncode(_bytes.sublist(6, 8));
    String four = _hexEncode(_bytes.sublist(8, 10));
    String five = _hexEncode(_bytes.sublist(10, 16));
    return "$one-$two-$three-$four-$five";
  }

  String toMac() {
    String one = _hexEncode(_bytes.sublist(0, 1));
    String two = _hexEncode(_bytes.sublist(1, 2));
    String three = _hexEncode(_bytes.sublist(2, 3));
    String four = _hexEncode(_bytes.sublist(3, 4));
    String five = _hexEncode(_bytes.sublist(4, 5));
    String six = _hexEncode(_bytes.sublist(5, 6));
    return "$one:$two:$three:$four:$five:$six".toUpperCase();
  }

  List<int> toByteArray() {
    return _bytes;
  }

  @override
  operator ==(other) => other is Guid && hashCode == other.hashCode;

  @override
  int get hashCode => _hashCode;
}
