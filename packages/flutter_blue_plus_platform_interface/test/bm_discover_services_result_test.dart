import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmDiscoverServicesResult',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the services property as [] if it is null',
            () {
              expect(
                BmDiscoverServicesResult.fromMap({
                  'remote_id': '',
                  'services': null,
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).services,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the success property as false if it is 0',
            () {
              expect(
                BmDiscoverServicesResult.fromMap({
                  'remote_id': '',
                  'services': [],
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
                BmDiscoverServicesResult.fromMap({
                  'remote_id': '',
                  'services': [],
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
                BmDiscoverServicesResult.fromMap({
                  'remote_id': '',
                  'services': [],
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
