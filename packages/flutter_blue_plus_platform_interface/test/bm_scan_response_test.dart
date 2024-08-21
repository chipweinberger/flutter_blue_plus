import 'package:collection/collection.dart';
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
            'deserializes the advertisements property',
            () {
              final advertisements = [
                {
                  'remote_id': 'str',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': {},
                  'service_uuids': [],
                }
              ];

              expect(
                BmScanResponse.fromMap({
                  'advertisements': advertisements,
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).advertisements,
                equals(
                  advertisements.map(
                    (advertisement) {
                      return BmScanAdvertisement.fromMap(advertisement);
                    },
                  ),
                ),
              );
            },
          );

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
                equals([]),
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

      group(
        'hashCode',
        () {
          test(
            'returns the hash code',
            () {
              final advertisements = <BmScanAdvertisement>[];
              final success = true;
              final errorCode = 0;
              final errorString = '';

              expect(
                BmScanResponse(
                  advertisements: advertisements,
                  success: success,
                  errorCode: errorCode,
                  errorString: errorString,
                ).hashCode,
                equals(
                  const ListEquality<BmScanAdvertisement>()
                          .hash(advertisements) ^
                      success.hashCode ^
                      errorCode.hashCode ^
                      errorString.hashCode,
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
                BmScanResponse(
                      advertisements: [],
                      success: true,
                      errorCode: 0,
                      errorString: '',
                    ) ==
                    BmScanResponse(
                      advertisements: [],
                      success: false,
                      errorCode: 0,
                      errorString: '',
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmScanResponse(
                      advertisements: [],
                      success: true,
                      errorCode: 0,
                      errorString: '',
                    ) ==
                    BmScanResponse(
                      advertisements: [],
                      success: true,
                      errorCode: 0,
                      errorString: '',
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
            'serializes the services property',
            () {
              final advertisements = [
                BmScanAdvertisement(
                  remoteId: DeviceIdentifier('str'),
                  connectable: true,
                  manufacturerData: {},
                  serviceData: {},
                  serviceUuids: [],
                  rssi: 0,
                ),
              ];

              expect(
                BmScanResponse(
                  advertisements: advertisements,
                  success: true,
                  errorCode: 0,
                  errorString: '',
                ).toMap(),
                containsPair(
                  'advertisements',
                  equals(
                    advertisements.map(
                      (advertisement) {
                        return advertisement.toMap();
                      },
                    ),
                  ),
                ),
              );
            },
          );

          test(
            'serializes the success property as 0 if it is false',
            () {
              expect(
                BmScanResponse(
                  advertisements: [],
                  success: false,
                  errorCode: 0,
                  errorString: '',
                ).toMap(),
                containsPair(
                  'success',
                  equals(0),
                ),
              );
            },
          );

          test(
            'serializes the success property as 1 if it is true',
            () {
              expect(
                BmScanResponse(
                  advertisements: [],
                  success: true,
                  errorCode: 0,
                  errorString: '',
                ).toMap(),
                containsPair(
                  'success',
                  equals(1),
                ),
              );
            },
          );
        },
      );
    },
  );
}
