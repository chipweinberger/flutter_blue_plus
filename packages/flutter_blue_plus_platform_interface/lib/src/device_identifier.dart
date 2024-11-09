class DeviceIdentifier {
  final String str;

  const DeviceIdentifier(this.str);

  @override
  String toString() => str;

  @override
  int get hashCode => str.hashCode;

  @override
  bool operator ==(other) => other is DeviceIdentifier && _compareAsciiLowerCase(str, other.str) == 0;

  @Deprecated('Use str instead')
  String get id => str;
}

int _compareAsciiLowerCase(String a, String b) {
  const int upperCaseA = 0x41;
  const int upperCaseZ = 0x5a;
  const int asciiCaseBit = 0x20;
  var defaultResult = 0;
  for (var i = 0; i < a.length; i++) {
    if (i >= b.length) return 1;
    var aChar = a.codeUnitAt(i);
    var bChar = b.codeUnitAt(i);
    if (aChar == bChar) continue;
    var aLowerCase = aChar;
    var bLowerCase = bChar;
    // Upper case if ASCII letters.
    if (upperCaseA <= bChar && bChar <= upperCaseZ) {
      bLowerCase += asciiCaseBit;
    }
    if (upperCaseA <= aChar && aChar <= upperCaseZ) {
      aLowerCase += asciiCaseBit;
    }
    if (aLowerCase != bLowerCase) return (aLowerCase - bLowerCase).sign;
    if (defaultResult == 0) defaultResult = aChar - bChar;
  }
  if (b.length > a.length) return -1;
  return defaultResult.sign;
}
