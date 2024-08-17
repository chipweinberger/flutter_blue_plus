import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmBluetoothService',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the characteristics property as [] if it is null',
            () {
              expect(
                BmBluetoothService.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'is_primary': 1,
                  'characteristics': null,
                  'included_services': [],
                }).characteristics,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the included services property as [] if it is null',
            () {
              expect(
                BmBluetoothService.fromMap({
                  'remote_id': '',
                  'service_uuid': '0102',
                  'is_primary': 1,
                  'characteristics': [],
                  'included_services': null,
                }).includedServices,
                isEmpty,
              );
            },
          );
        },
      );
    },
  );
}
