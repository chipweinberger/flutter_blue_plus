import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmScanResponse',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the advertisements property as [] if it is null',
            () {
              expect(
                BmScanResponse.fromMap({
                  'advertisements': null,
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).advertisements,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the success property as false if it is 0',
            () {
              expect(
                BmScanResponse.fromMap({
                  'advertisements': [],
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
                BmScanResponse.fromMap({
                  'advertisements': [],
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
                BmScanResponse.fromMap({
                  'advertisements': [],
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
