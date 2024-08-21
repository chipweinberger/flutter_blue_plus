class BmCharacteristicProperties {
  bool broadcast;
  bool read;
  bool writeWithoutResponse;
  bool write;
  bool notify;
  bool indicate;
  bool authenticatedSignedWrites;
  bool extendedProperties;
  bool notifyEncryptionRequired;
  bool indicateEncryptionRequired;

  BmCharacteristicProperties({
    required this.broadcast,
    required this.read,
    required this.writeWithoutResponse,
    required this.write,
    required this.notify,
    required this.indicate,
    required this.authenticatedSignedWrites,
    required this.extendedProperties,
    required this.notifyEncryptionRequired,
    required this.indicateEncryptionRequired,
  });

  factory BmCharacteristicProperties.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmCharacteristicProperties(
      broadcast: json['broadcast'] == 1,
      read: json['read'] == 1,
      writeWithoutResponse: json['write_without_response'] == 1,
      write: json['write'] == 1,
      notify: json['notify'] == 1,
      indicate: json['indicate'] == 1,
      authenticatedSignedWrites: json['authenticated_signed_writes'] == 1,
      extendedProperties: json['extended_properties'] == 1,
      notifyEncryptionRequired: json['notify_encryption_required'] == 1,
      indicateEncryptionRequired: json['indicate_encryption_required'] == 1,
    );
  }

  @override
  int get hashCode {
    return broadcast.hashCode ^
        read.hashCode ^
        writeWithoutResponse.hashCode ^
        write.hashCode ^
        notify.hashCode ^
        indicate.hashCode ^
        authenticatedSignedWrites.hashCode ^
        extendedProperties.hashCode ^
        notifyEncryptionRequired.hashCode ^
        indicateEncryptionRequired.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmCharacteristicProperties && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'broadcast': broadcast ? 1 : 0,
      'read': read ? 1 : 0,
      'write_without_response': writeWithoutResponse ? 1 : 0,
      'write': write ? 1 : 0,
      'notify': notify ? 1 : 0,
      'indicate': indicate ? 1 : 0,
      'authenticated_signed_writes': authenticatedSignedWrites ? 1 : 0,
      'extended_properties': extendedProperties ? 1 : 0,
      'notify_encryption_required': notifyEncryptionRequired ? 1 : 0,
      'indicate_encryption_required': indicateEncryptionRequired ? 1 : 0,
    };
  }
}
