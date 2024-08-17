import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmBluetoothCharacteristic',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the properties property properties as false if it is null',
            () {
              final properties = BmBluetoothCharacteristic.fromMap({
                'remote_id': '',
                'service_uuid': '0102',
                'characteristic_uuid': '0102',
                'properties': null,
              }).properties;

              expect(properties.broadcast, isFalse);
              expect(properties.read, isFalse);
              expect(properties.writeWithoutResponse, isFalse);
              expect(properties.write, isFalse);
              expect(properties.notify, isFalse);
              expect(properties.indicate, isFalse);
              expect(properties.authenticatedSignedWrites, isFalse);
              expect(properties.extendedProperties, isFalse);
              expect(properties.notifyEncryptionRequired, isFalse);
              expect(properties.indicateEncryptionRequired, isFalse);
            },
          );

          test(
            'deserializes the secondary service uuid property as [0x01,0x02] if it is 0102',
            () {
              expect(
                BmBluetoothCharacteristic.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'properties': {},
                }).secondaryServiceUuid?.bytes,
                orderedEquals([
                  0x01,
                  0x02,
                ]),
              );
            },
          );

          test(
            'deserializes the secondary service uuid property as null if it is null',
            () {
              expect(
                BmBluetoothCharacteristic.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'properties': {},
                }).secondaryServiceUuid,
                isNull,
              );
            },
          );
        },
      );
    },
  );
}
