import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmReadRssiResult',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the success property as false if it is 0',
            () {
              expect(
                BmReadRssiResult.fromMap({
                  'remote_id': '',
                  'rssi': 0,
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
                BmReadRssiResult.fromMap({
                  'remote_id': '',
                  'rssi': 0,
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
                BmReadRssiResult.fromMap({
                  'remote_id': '',
                  'rssi': 0,
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).success,
                isTrue,
              );
            },
          );
        },
      );
    },
  );
}
