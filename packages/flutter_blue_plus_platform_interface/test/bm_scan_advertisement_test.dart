import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmScanAdvertisement',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the manufacturer data property',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': '',
                  'connectable': 1,
                  'manufacturer_data': {
                    1: '010203',
                  },
                  'service_data': {},
                  'service_uuids': [],
                }).manufacturerData,
                containsPair(
                  1,
                  orderedEquals([
                    0x01,
                    0x02,
                    0x03,
                  ]),
                ),
              );
            },
          );

          test(
            'deserializes the manufacturer data property as {} if it is null',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': '',
                  'connectable': 1,
                  'manufacturer_data': null,
                  'service_data': {},
                  'service_uuids': [],
                }).manufacturerData,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the service data property',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': '',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': {
                    '0102': '010203',
                  },
                  'service_uuids': [],
                }).serviceData,
                containsPair(
                  Guid('0102'),
                  orderedEquals([
                    0x01,
                    0x02,
                    0x03,
                  ]),
                ),
              );
            },
          );

          test(
            'deserializes the service data property as {} if it is null',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': '',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': null,
                  'service_uuids': [],
                }).serviceData,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the service uuids property',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': '',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': {},
                  'service_uuids': [
                    '0102',
                  ],
                }).serviceUuids,
                orderedEquals([
                  Guid('0102'),
                ]),
              );
            },
          );

          test(
            'deserializes the service uuids property as [] if it is null',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': '',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': {},
                  'service_uuids': null,
                }).serviceUuids,
                isEmpty,
              );
            },
          );
        },
      );
    },
  );
}
