class DeviceIdentifier {
  final String str;

  DeviceIdentifier(this.str);

  @override
  String toString() {
    return str;
  }

  @override
  int get hashCode {
    return str.toLowerCase().hashCode;
  }

  @Deprecated('Use str instead')
  String get id {
    return str;
  }

  @override
  bool operator ==(Object other) {
    return other is DeviceIdentifier && hashCode == other.hashCode;
  }
}
