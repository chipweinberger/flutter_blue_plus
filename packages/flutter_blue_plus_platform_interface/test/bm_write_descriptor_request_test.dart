import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmWriteDescriptorRequest',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the secondary service uuid property as [0x01,0x02] if it is 0102',
            () {
              expect(
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
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
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                }).secondaryServiceUuid,
                isNull,
              );
            },
          );

          test(
            'deserializes the value property as [0x01,0x02,0x03] if it is 010203',
            () {
              expect(
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '010203',
                }).value,
                orderedEquals([
                  0x01,
                  0x02,
                  0x03,
                ]),
              );
            },
          );

          test(
            'deserializes the value property as [] if it is null',
            () {
              expect(
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': null,
                }).value,
                isEmpty,
              );
            },
          );
        },
      );
    },
  );
}
