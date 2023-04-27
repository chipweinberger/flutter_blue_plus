

part of flutter_blue_plus;

String hexEncode(List<int> numbers) {
  return numbers.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
}

List<int> hexDecode(String hex) {
  List<int> numbers = [];
  for (int i = 0; i < hex.length; i += 2) {
    String hexPart = hex.substring(i, i + 2);
    int num = int.parse(hexPart, radix: 16);
    numbers.add(num);
  }
  return numbers;
}

int compareAsciiLowerCase(String a, String b) {
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
