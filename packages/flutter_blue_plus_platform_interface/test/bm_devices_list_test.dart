import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmDevicesList',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the devices property as [] if it is null',
            () {
              expect(
                BmDevicesList.fromMap({
                  'devices': null,
                }).devices,
                isEmpty,
              );
            },
          );
        },
      );
    },
  );
}
