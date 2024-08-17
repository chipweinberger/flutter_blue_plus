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
              final properties = BmCharacteristicProperties.fromMap({
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
              });

              expect(
                properties.broadcast,
                isFalse,
              );
              expect(
                properties.read,
                isFalse,
              );
              expect(
                properties.writeWithoutResponse,
                isFalse,
              );
              expect(
                properties.write,
                isFalse,
              );
              expect(
                properties.notify,
                isFalse,
              );
              expect(
                properties.indicate,
                isFalse,
              );
              expect(
                properties.authenticatedSignedWrites,
                isFalse,
              );
              expect(
                properties.extendedProperties,
                isFalse,
              );
              expect(
                properties.notifyEncryptionRequired,
                isFalse,
              );
              expect(
                properties.indicateEncryptionRequired,
                isFalse,
              );
            },
          );

          test(
            'deserializes the properties as true if they are 1',
            () {
              final properties = BmCharacteristicProperties.fromMap({
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
              });

              expect(
                properties.broadcast,
                isTrue,
              );
              expect(
                properties.read,
                isTrue,
              );
              expect(
                properties.writeWithoutResponse,
                isTrue,
              );
              expect(
                properties.write,
                isTrue,
              );
              expect(
                properties.notify,
                isTrue,
              );
              expect(
                properties.indicate,
                isTrue,
              );
              expect(
                properties.authenticatedSignedWrites,
                isTrue,
              );
              expect(
                properties.extendedProperties,
                isTrue,
              );
              expect(
                properties.notifyEncryptionRequired,
                isTrue,
              );
              expect(
                properties.indicateEncryptionRequired,
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
                containsPair('broadcast', equals(0)),
              );
              expect(
                map,
                containsPair('read', equals(0)),
              );
              expect(
                map,
                containsPair('write_without_response', equals(0)),
              );
              expect(
                map,
                containsPair('write', equals(0)),
              );
              expect(
                map,
                containsPair('notify', equals(0)),
              );
              expect(
                map,
                containsPair('indicate', equals(0)),
              );
              expect(
                map,
                containsPair('authenticated_signed_writes', equals(0)),
              );
              expect(
                map,
                containsPair('extended_properties', equals(0)),
              );
              expect(
                map,
                containsPair('notify_encryption_required', equals(0)),
              );
              expect(
                map,
                containsPair('indicate_encryption_required', equals(0)),
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
                containsPair('broadcast', equals(1)),
              );
              expect(
                map,
                containsPair('read', equals(1)),
              );
              expect(
                map,
                containsPair('write_without_response', equals(1)),
              );
              expect(
                map,
                containsPair('write', equals(1)),
              );
              expect(
                map,
                containsPair('notify', equals(1)),
              );
              expect(
                map,
                containsPair('indicate', equals(1)),
              );
              expect(
                map,
                containsPair('authenticated_signed_writes', equals(1)),
              );
              expect(
                map,
                containsPair('extended_properties', equals(1)),
              );
              expect(
                map,
                containsPair('notify_encryption_required', equals(1)),
              );
              expect(
                map,
                containsPair('indicate_encryption_required', equals(1)),
              );
            },
          );
        },
      );
    },
  );
}
