import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmCharacteristicProperties',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the properties as false if they are not 1',
            () {
              expect(
                BmCharacteristicProperties.fromMap({
                  'broadcast': 0,
                  'read': 0,
                  'write_without_response': 0,
                  'write': 0,
                  'notify': 0,
                  'indicate': 0,
                  'authenticated_signed_writes': 0,
                  'extended_properties': 0,
                  'notify_encryption_required': 0,
                  'indicate_encryption_required': 0,
                }),
                equals(
                  BmCharacteristicProperties(
                    broadcast: false,
                    read: false,
                    writeWithoutResponse: false,
                    write: false,
                    notify: false,
                    indicate: false,
                    authenticatedSignedWrites: false,
                    extendedProperties: false,
                    notifyEncryptionRequired: false,
                    indicateEncryptionRequired: false,
                  ),
                ),
              );
            },
          );

          test(
            'deserializes the properties as true if they are 1',
            () {
              expect(
                BmCharacteristicProperties.fromMap({
                  'broadcast': 1,
                  'read': 1,
                  'write_without_response': 1,
                  'write': 1,
                  'notify': 1,
                  'indicate': 1,
                  'authenticated_signed_writes': 1,
                  'extended_properties': 1,
                  'notify_encryption_required': 1,
                  'indicate_encryption_required': 1,
                }),
                equals(
                  BmCharacteristicProperties(
                    broadcast: true,
                    read: true,
                    writeWithoutResponse: true,
                    write: true,
                    notify: true,
                    indicate: true,
                    authenticatedSignedWrites: true,
                    extendedProperties: true,
                    notifyEncryptionRequired: true,
                    indicateEncryptionRequired: true,
                  ),
                ),
              );
            },
          );
        },
      );

      group(
        'hashCode',
        () {
          test(
            'returns the hash code',
            () {
              final broadcast = false;
              final read = false;
              final writeWithoutResponse = false;
              final write = false;
              final notify = false;
              final indicate = false;
              final authenticatedSignedWrites = false;
              final extendedProperties = false;
              final notifyEncryptionRequired = false;
              final indicateEncryptionRequired = false;

              expect(
                BmCharacteristicProperties(
                  broadcast: broadcast,
                  read: read,
                  writeWithoutResponse: writeWithoutResponse,
                  write: write,
                  notify: notify,
                  indicate: indicate,
                  authenticatedSignedWrites: authenticatedSignedWrites,
                  extendedProperties: extendedProperties,
                  notifyEncryptionRequired: notifyEncryptionRequired,
                  indicateEncryptionRequired: indicateEncryptionRequired,
                ).hashCode,
                equals(
                  broadcast.hashCode ^
                      read.hashCode ^
                      writeWithoutResponse.hashCode ^
                      write.hashCode ^
                      notify.hashCode ^
                      indicate.hashCode ^
                      authenticatedSignedWrites.hashCode ^
                      extendedProperties.hashCode ^
                      notifyEncryptionRequired.hashCode ^
                      indicateEncryptionRequired.hashCode,
                ),
              );
            },
          );
        },
      );

      group(
        '==',
        () {
          test(
            'returns false if they are not equal',
            () {
              expect(
                BmCharacteristicProperties(
                      broadcast: false,
                      read: false,
                      writeWithoutResponse: false,
                      write: false,
                      notify: false,
                      indicate: false,
                      authenticatedSignedWrites: false,
                      extendedProperties: false,
                      notifyEncryptionRequired: false,
                      indicateEncryptionRequired: false,
                    ) ==
                    BmCharacteristicProperties(
                      broadcast: true,
                      read: false,
                      writeWithoutResponse: false,
                      write: false,
                      notify: false,
                      indicate: false,
                      authenticatedSignedWrites: false,
                      extendedProperties: false,
                      notifyEncryptionRequired: false,
                      indicateEncryptionRequired: false,
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmCharacteristicProperties(
                      broadcast: false,
                      read: false,
                      writeWithoutResponse: false,
                      write: false,
                      notify: false,
                      indicate: false,
                      authenticatedSignedWrites: false,
                      extendedProperties: false,
                      notifyEncryptionRequired: false,
                      indicateEncryptionRequired: false,
                    ) ==
                    BmCharacteristicProperties(
                      broadcast: false,
                      read: false,
                      writeWithoutResponse: false,
                      write: false,
                      notify: false,
                      indicate: false,
                      authenticatedSignedWrites: false,
                      extendedProperties: false,
                      notifyEncryptionRequired: false,
                      indicateEncryptionRequired: false,
                    ),
                isTrue,
              );
            },
          );
        },
      );

      group(
        'toMap',
        () {
          test(
            'serializes the properties as 0 if they are false',
            () {
              final map = BmCharacteristicProperties(
                broadcast: false,
                read: false,
                writeWithoutResponse: false,
                write: false,
                notify: false,
                indicate: false,
                authenticatedSignedWrites: false,
                extendedProperties: false,
                notifyEncryptionRequired: false,
                indicateEncryptionRequired: false,
              ).toMap();

              expect(
                map,
                containsPair(
                  'broadcast',
                  equals(0),
                ),
              );
              expect(
                map,
                containsPair(
                  'read',
                  equals(0),
                ),
              );
              expect(
                map,
                containsPair(
                  'write_without_response',
                  equals(0),
                ),
              );
              expect(
                map,
                containsPair(
                  'write',
                  equals(0),
                ),
              );
              expect(
                map,
                containsPair(
                  'notify',
                  equals(0),
                ),
              );
              expect(
                map,
                containsPair(
                  'indicate',
                  equals(0),
                ),
              );
              expect(
                map,
                containsPair(
                  'authenticated_signed_writes',
                  equals(0),
                ),
              );
              expect(
                map,
                containsPair(
                  'extended_properties',
                  equals(0),
                ),
              );
              expect(
                map,
                containsPair(
                  'notify_encryption_required',
                  equals(0),
                ),
              );
              expect(
                map,
                containsPair(
                  'indicate_encryption_required',
                  equals(0),
                ),
              );
            },
          );

          test(
            'serializes the properties as 1 if they are true',
            () {
              final map = BmCharacteristicProperties(
                broadcast: true,
                read: true,
                writeWithoutResponse: true,
                write: true,
                notify: true,
                indicate: true,
                authenticatedSignedWrites: true,
                extendedProperties: true,
                notifyEncryptionRequired: true,
                indicateEncryptionRequired: true,
              ).toMap();

              expect(
                map,
                containsPair(
                  'broadcast',
                  equals(1),
                ),
              );
              expect(
                map,
                containsPair(
                  'read',
                  equals(1),
                ),
              );
              expect(
                map,
                containsPair(
                  'write_without_response',
                  equals(1),
                ),
              );
              expect(
                map,
                containsPair(
                  'write',
                  equals(1),
                ),
              );
              expect(
                map,
                containsPair(
                  'notify',
                  equals(1),
                ),
              );
              expect(
                map,
                containsPair(
                  'indicate',
                  equals(1),
                ),
              );
              expect(
                map,
                containsPair(
                  'authenticated_signed_writes',
                  equals(1),
                ),
              );
              expect(
                map,
                containsPair(
                  'extended_properties',
                  equals(1),
                ),
              );
              expect(
                map,
                containsPair(
                  'notify_encryption_required',
                  equals(1),
                ),
              );
              expect(
                map,
                containsPair(
                  'indicate_encryption_required',
                  equals(1),
                ),
              );
            },
          );
        },
      );
    },
  );
}
