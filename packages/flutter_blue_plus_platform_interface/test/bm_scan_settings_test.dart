import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmScanSettings',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the with services property as [] if it is null',
            () {
              expect(
                BmScanSettings.fromMap({
                  'with_services': null,
                  'with_remote_ids': [],
                  'with_names': [],
                  'with_keywords': [],
                  'with_msd': [],
                  'with_service_data': [],
                  'continuous_updates': false,
                  'continuous_divisor': 1,
                  'android_legacy': false,
                  'android_scan_mode': 0,
                  'android_uses_fine_location': false,
                }).withServices,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the with remote ids property as [] if it is null',
            () {
              expect(
                BmScanSettings.fromMap({
                  'with_services': [],
                  'with_remote_ids': null,
                  'with_names': [],
                  'with_keywords': [],
                  'with_msd': [],
                  'with_service_data': [],
                  'continuous_updates': false,
                  'continuous_divisor': 1,
                  'android_legacy': false,
                  'android_scan_mode': 0,
                  'android_uses_fine_location': false,
                }).withRemoteIds,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the with names property as [] if it is null',
            () {
              expect(
                BmScanSettings.fromMap({
                  'with_services': [],
                  'with_remote_ids': [],
                  'with_names': null,
                  'with_keywords': [],
                  'with_msd': [],
                  'with_service_data': [],
                  'continuous_updates': false,
                  'continuous_divisor': 1,
                  'android_legacy': false,
                  'android_scan_mode': 0,
                  'android_uses_fine_location': false,
                }).withNames,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the with keywords property as [] if it is null',
            () {
              expect(
                BmScanSettings.fromMap({
                  'with_services': [],
                  'with_remote_ids': [],
                  'with_names': [],
                  'with_keywords': null,
                  'with_msd': [],
                  'with_service_data': [],
                  'continuous_updates': false,
                  'continuous_divisor': 1,
                  'android_legacy': false,
                  'android_scan_mode': 0,
                  'android_uses_fine_location': false,
                }).withKeywords,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the with msd property as [] if it is null',
            () {
              expect(
                BmScanSettings.fromMap({
                  'with_services': [],
                  'with_remote_ids': [],
                  'with_names': [],
                  'with_keywords': [],
                  'with_msd': null,
                  'with_service_data': [],
                  'continuous_updates': false,
                  'continuous_divisor': 1,
                  'android_legacy': false,
                  'android_scan_mode': 0,
                  'android_uses_fine_location': false,
                }).withMsd,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the with service data property as [] if it is null',
            () {
              expect(
                BmScanSettings.fromMap({
                  'with_services': [],
                  'with_remote_ids': [],
                  'with_names': [],
                  'with_keywords': [],
                  'with_msd': [],
                  'with_service_data': null,
                  'continuous_updates': false,
                  'continuous_divisor': 1,
                  'android_legacy': false,
                  'android_scan_mode': 0,
                  'android_uses_fine_location': false,
                }).withServiceData,
                isEmpty,
              );
            },
          );
        },
      );
    },
  );
}
