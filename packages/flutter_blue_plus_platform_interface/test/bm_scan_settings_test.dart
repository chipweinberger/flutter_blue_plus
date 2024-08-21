import 'package:collection/collection.dart';
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
            'deserializes the with keywords property',
            () {
              final withKeywords = [
                'keyword',
              ];

              expect(
                BmScanSettings.fromMap({
                  'with_services': [],
                  'with_remote_ids': [],
                  'with_names': [],
                  'with_keywords': withKeywords,
                  'with_msd': [],
                  'with_service_data': [],
                  'continuous_updates': false,
                  'continuous_divisor': 1,
                  'android_legacy': false,
                  'android_scan_mode': 0,
                  'android_uses_fine_location': false,
                }).withKeywords,
                equals(withKeywords),
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
                equals([]),
              );
            },
          );

          test(
            'deserializes the with msd property',
            () {
              final withMsd = [
                {
                  'manufacturer_id': 0,
                  'data': '',
                  'mask': '',
                },
              ];

              expect(
                BmScanSettings.fromMap({
                  'with_services': [],
                  'with_remote_ids': [],
                  'with_names': [],
                  'with_keywords': [],
                  'with_msd': withMsd,
                  'with_service_data': [],
                  'continuous_updates': false,
                  'continuous_divisor': 1,
                  'android_legacy': false,
                  'android_scan_mode': 0,
                  'android_uses_fine_location': false,
                }).withMsd,
                equals(
                  withMsd.map(
                    (manufacturerData) {
                      return BmMsdFilter.fromMap(manufacturerData);
                    },
                  ),
                ),
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
                equals([]),
              );
            },
          );

          test(
            'deserializes the with names property',
            () {
              final withNames = [
                'name',
              ];

              expect(
                BmScanSettings.fromMap({
                  'with_services': [],
                  'with_remote_ids': [],
                  'with_names': withNames,
                  'with_keywords': [],
                  'with_msd': [],
                  'with_service_data': [],
                  'continuous_updates': false,
                  'continuous_divisor': 1,
                  'android_legacy': false,
                  'android_scan_mode': 0,
                  'android_uses_fine_location': false,
                }).withNames,
                equals(withNames),
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
                equals([]),
              );
            },
          );

          test(
            'deserializes the with remote ids property',
            () {
              final withRemoteIds = [
                'str',
              ];

              expect(
                BmScanSettings.fromMap({
                  'with_services': [],
                  'with_remote_ids': withRemoteIds,
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
                equals(withRemoteIds),
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
                equals([]),
              );
            },
          );

          test(
            'deserializes the with service data property',
            () {
              final withServiceData = [
                {
                  'service': '0102',
                  'data': '010203',
                  'mask': '010203',
                },
              ];

              expect(
                BmScanSettings.fromMap({
                  'with_services': [],
                  'with_remote_ids': [],
                  'with_names': [],
                  'with_keywords': [],
                  'with_msd': [],
                  'with_service_data': withServiceData,
                  'continuous_updates': false,
                  'continuous_divisor': 1,
                  'android_legacy': false,
                  'android_scan_mode': 0,
                  'android_uses_fine_location': false,
                }).withServiceData,
                equals(
                  withServiceData.map(
                    (serviceData) {
                      return BmServiceDataFilter.fromMap(serviceData);
                    },
                  ),
                ),
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
                equals([]),
              );
            },
          );

          test(
            'deserializes the with services property',
            () {
              final withServices = [
                '0102',
              ];

              expect(
                BmScanSettings.fromMap({
                  'with_services': withServices,
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
                equals(
                  withServices.map(
                    (service) {
                      return Guid(service);
                    },
                  ),
                ),
              );
            },
          );

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
                equals([]),
              );
            },
          );
        },
      );

      group(
        'hashCode',
        () {
          test(
            'returns the hash code',
            () {
              final withServices = <Guid>[];
              final withRemoteIds = <String>[];
              final withNames = <String>[];
              final withKeywords = <String>[];
              final withMsd = <BmMsdFilter>[];
              final withServiceData = <BmServiceDataFilter>[];
              final continuousUpdates = false;
              final continuousDivisor = 1;
              final androidLegacy = false;
              final androidScanMode = 0;
              final androidUsesFineLocation = false;

              expect(
                BmScanSettings(
                  withServices: withServices,
                  withRemoteIds: withRemoteIds,
                  withNames: withNames,
                  withKeywords: withKeywords,
                  withMsd: withMsd,
                  withServiceData: withServiceData,
                  continuousUpdates: continuousUpdates,
                  continuousDivisor: continuousDivisor,
                  androidLegacy: androidLegacy,
                  androidScanMode: androidScanMode,
                  androidUsesFineLocation: androidUsesFineLocation,
                ).hashCode,
                equals(
                  const ListEquality<Guid>().hash(withServices) ^
                      const ListEquality<String>().hash(withRemoteIds) ^
                      const ListEquality<String>().hash(withNames) ^
                      const ListEquality<String>().hash(withKeywords) ^
                      const ListEquality<BmMsdFilter>().hash(withMsd) ^
                      const ListEquality<BmServiceDataFilter>()
                          .hash(withServiceData) ^
                      continuousUpdates.hashCode ^
                      continuousDivisor.hashCode ^
                      androidLegacy.hashCode ^
                      androidScanMode.hashCode ^
                      androidUsesFineLocation.hashCode,
                ),
              );
            },
          );
        },
      );

      group(
        '==',
        () {
          test(
            'returns false if they are not equal',
            () {
              expect(
                BmScanSettings(
                      withServices: [],
                      withRemoteIds: [],
                      withNames: [],
                      withKeywords: [],
                      withMsd: [],
                      withServiceData: [],
                      continuousUpdates: false,
                      continuousDivisor: 1,
                      androidLegacy: false,
                      androidScanMode: 0,
                      androidUsesFineLocation: false,
                    ) ==
                    BmScanSettings(
                      withServices: [],
                      withRemoteIds: [],
                      withNames: [],
                      withKeywords: [],
                      withMsd: [],
                      withServiceData: [],
                      continuousUpdates: true,
                      continuousDivisor: 1,
                      androidLegacy: false,
                      androidScanMode: 0,
                      androidUsesFineLocation: false,
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmScanSettings(
                      withServices: [],
                      withRemoteIds: [],
                      withNames: [],
                      withKeywords: [],
                      withMsd: [],
                      withServiceData: [],
                      continuousUpdates: false,
                      continuousDivisor: 1,
                      androidLegacy: false,
                      androidScanMode: 0,
                      androidUsesFineLocation: false,
                    ) ==
                    BmScanSettings(
                      withServices: [],
                      withRemoteIds: [],
                      withNames: [],
                      withKeywords: [],
                      withMsd: [],
                      withServiceData: [],
                      continuousUpdates: false,
                      continuousDivisor: 1,
                      androidLegacy: false,
                      androidScanMode: 0,
                      androidUsesFineLocation: false,
                    ),
                isTrue,
              );
            },
          );
        },
      );

      group(
        'toMap',
        () {
          test(
            'serializes the with msd property',
            () {
              final withMsd = [
                BmMsdFilter(
                  0,
                  [],
                  [],
                ),
              ];

              expect(
                BmScanSettings(
                  withServices: [],
                  withRemoteIds: [],
                  withNames: [],
                  withKeywords: [],
                  withMsd: withMsd,
                  withServiceData: [],
                  continuousUpdates: false,
                  continuousDivisor: 1,
                  androidLegacy: false,
                  androidScanMode: 0,
                  androidUsesFineLocation: false,
                ).toMap(),
                containsPair(
                  'with_msd',
                  equals(
                    withMsd.map(
                      (manufacturerData) {
                        return manufacturerData.toMap();
                      },
                    ),
                  ),
                ),
              );
            },
          );

          test(
            'serializes the with service data property',
            () {
              final withServiceData = [
                BmServiceDataFilter(
                  Guid('0102'),
                  [],
                  [],
                ),
              ];

              expect(
                BmScanSettings(
                  withServices: [],
                  withRemoteIds: [],
                  withNames: [],
                  withKeywords: [],
                  withMsd: [],
                  withServiceData: withServiceData,
                  continuousUpdates: false,
                  continuousDivisor: 1,
                  androidLegacy: false,
                  androidScanMode: 0,
                  androidUsesFineLocation: false,
                ).toMap(),
                containsPair(
                  'with_service_data',
                  equals(
                    withServiceData.map(
                      (serviceData) {
                        return serviceData.toMap();
                      },
                    ),
                  ),
                ),
              );
            },
          );

          test(
            'serializes the with services property',
            () {
              final withServices = [
                Guid('0102'),
              ];

              expect(
                BmScanSettings(
                  withServices: withServices,
                  withRemoteIds: [],
                  withNames: [],
                  withKeywords: [],
                  withMsd: [],
                  withServiceData: [],
                  continuousUpdates: false,
                  continuousDivisor: 1,
                  androidLegacy: false,
                  androidScanMode: 0,
                  androidUsesFineLocation: false,
                ).toMap(),
                containsPair(
                  'with_services',
                  equals(
                    withServices.map(
                      (service) {
                        return service.str;
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}
