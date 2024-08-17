import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmCharacteristicData',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the secondary service uuid property as [0x01,0x02] if it is 0102',
            () {
              expect(
                BmDescriptorData.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
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
                BmDescriptorData.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).secondaryServiceUuid,
                isNull,
              );
            },
          );

          test(
            'deserializes the success property as false if it is 0',
            () {
              expect(
                BmDescriptorData.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': 0,
                  'error_code': 0,
                  'error_string': '',
                }).success,
                isFalse,
              );
            },
          );

          test(
            'deserializes the success property as true if it is null',
            () {
              expect(
                BmDescriptorData.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': null,
                  'error_code': 0,
                  'error_string': '',
                }).success,
                isTrue,
              );
            },
          );

          test(
            'deserializes the success property as true if it is not 0',
            () {
              expect(
                BmDescriptorData.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).success,
                isTrue,
              );
            },
          );

          test(
            'deserializes the value property as [0x01,0x02,0x03] if it is 010203',
            () {
              expect(
                BmDescriptorData.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '010203',
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
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
                BmDescriptorData.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': null,
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
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
