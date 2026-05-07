final class BluetoothGattCharacteristicProperties {
  const BluetoothGattCharacteristicProperties({
    required this.authenticatedSignedWrites,
    required this.broadcast,
    required this.extendedProperties,
    required this.indicate,
    required this.notify,
    required this.read,
    required this.write,
    required this.writeWithoutResponse,
  });

  factory BluetoothGattCharacteristicProperties.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattCharacteristicProperties(
      authenticatedSignedWrites: map['authenticatedSignedWrites'] as bool? ?? false,
      broadcast: map['broadcast'] as bool? ?? false,
      extendedProperties: map['extendedProperties'] as bool? ?? false,
      indicate: map['indicate'] as bool? ?? false,
      notify: map['notify'] as bool? ?? false,
      read: map['read'] as bool? ?? false,
      write: map['write'] as bool? ?? false,
      writeWithoutResponse: map['writeWithoutResponse'] as bool? ?? false,
    );
  }

  final bool authenticatedSignedWrites;
  final bool broadcast;
  final bool extendedProperties;
  final bool indicate;
  final bool notify;
  final bool read;
  final bool write;
  final bool writeWithoutResponse;

  bool getAuthenticatedSignedWrites() {
    return authenticatedSignedWrites;
  }

  bool getBroadcast() {
    return broadcast;
  }

  bool getExtendedProperties() {
    return extendedProperties;
  }

  bool getIndicate() {
    return indicate;
  }

  bool getNotify() {
    return notify;
  }

  bool getRead() {
    return read;
  }

  bool getWrite() {
    return write;
  }

  bool getWriteWithoutResponse() {
    return writeWithoutResponse;
  }
}
