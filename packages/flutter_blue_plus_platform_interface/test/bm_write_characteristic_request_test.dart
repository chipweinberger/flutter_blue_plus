import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmWriteCharacteristicRequest',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the secondary service uuid property as [0x01,0x02] if it is 0102',
            () {
              expect(
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'value': '',
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
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'value': '',
                }).secondaryServiceUuid,
                isNull,
              );
            },
          );

          test(
            'deserializes the value property as [0x01,0x02] if it is 0102',
            () {
              expect(
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'value': '0102',
                }).value,
                orderedEquals([
                  0x01,
                  0x02,
                ]),
              );
            },
          );

          test(
            'deserializes the value property as [] if it is null',
            () {
              expect(
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'value': null,
                }).value,
                orderedEquals([]),
              );
            },
          );

          test(
            'deserializes the write type property',
            () {
              expect(
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'value': null,
                }).writeType,
                equals(BmWriteType.withResponse),
              );
            },
          );

          test(
            'throws a range error if the write type property index is out of range',
            () {
              expect(
                () {
                  BmWriteCharacteristicRequest.fromMap({
                    'remote_id': '',
                    'service_uuid': '0102',
                    'secondary_service_uuid': null,
                    'characteristic_uuid': '0102',
                    'write_type': 2,
                    'value': null,
                  });
                },
                throwsRangeError,
              );
            },
          );
        },
      );

      group(
        'toMap',
        () {
          test(
            'serializes the write type property',
            () {
              expect(
                BmWriteCharacteristicRequest(
                  remoteId: DeviceIdentifier(''),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  writeType: BmWriteType.withResponse,
                  allowLongWrite: false,
                  value: [],
                ).toMap(),
                containsPair('write_type', 0),
              );
            },
          );
        },
      );
    },
  );
}
