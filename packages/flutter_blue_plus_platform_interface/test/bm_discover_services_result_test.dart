import 'package:collection/collection.dart';
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
            'deserializes the remote id property',
            () {
              final remoteId = 'str';

              expect(
                BmDiscoverServicesResult.fromMap({
                  'remote_id': remoteId,
                  'services': [],
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).remoteId,
                equals(DeviceIdentifier(remoteId)),
              );
            },
          );

          test(
            'deserializes the services property',
            () {
              final services = [
                {
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'is_primary': 1,
                  'characteristics': [],
                  'included_services': [],
                }
              ];

              expect(
                BmDiscoverServicesResult.fromMap({
                  'remote_id': 'str',
                  'services': services,
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).services,
                equals(
                  services.map(
                    (service) {
                      return BmBluetoothService.fromMap(service);
                    },
                  ),
                ),
              );
            },
          );

          test(
            'deserializes the services property as [] if it is null',
            () {
              expect(
                BmDiscoverServicesResult.fromMap({
                  'remote_id': 'str',
                  'services': null,
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).services,
                equals([]),
              );
            },
          );

          test(
            'deserializes the success property as false if it is 0',
            () {
              expect(
                BmDiscoverServicesResult.fromMap({
                  'remote_id': 'str',
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
                  'remote_id': 'str',
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
                  'remote_id': 'str',
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

      group(
        'hashCode',
        () {
          test(
            'returns the hash code',
            () {
              final remoteId = DeviceIdentifier('str');
              final services = <BmBluetoothService>[];
              final success = true;
              final errorCode = 0;
              final errorString = '';

              expect(
                BmDiscoverServicesResult(
                  remoteId: remoteId,
                  services: services,
                  success: success,
                  errorCode: errorCode,
                  errorString: errorString,
                ).hashCode,
                equals(
                  remoteId.hashCode ^
                      const ListEquality<BmBluetoothService>().hash(services) ^
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
                BmDiscoverServicesResult(
                      remoteId: DeviceIdentifier('str'),
                      services: [],
                      success: true,
                      errorCode: 0,
                      errorString: '',
                    ) ==
                    BmDiscoverServicesResult(
                      remoteId: DeviceIdentifier('str'),
                      services: [],
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
                BmDiscoverServicesResult(
                      remoteId: DeviceIdentifier('str'),
                      services: [],
                      success: true,
                      errorCode: 0,
                      errorString: '',
                    ) ==
                    BmDiscoverServicesResult(
                      remoteId: DeviceIdentifier('str'),
                      services: [],
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
            'serializes the remote id property',
            () {
              final remoteId = DeviceIdentifier('str');

              expect(
                BmDiscoverServicesResult(
                  remoteId: remoteId,
                  services: [],
                  success: true,
                  errorCode: 0,
                  errorString: '',
                ).toMap(),
                containsPair(
                  'remote_id',
                  equals(remoteId.str),
                ),
              );
            },
          );

          test(
            'serializes the services property',
            () {
              final services = [
                BmBluetoothService(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  isPrimary: true,
                  characteristics: [],
                  includedServices: [],
                ),
              ];

              expect(
                BmDiscoverServicesResult(
                  remoteId: DeviceIdentifier('str'),
                  services: services,
                  success: true,
                  errorCode: 0,
                  errorString: '',
                ).toMap(),
                containsPair(
                  'services',
                  equals(
                    services.map(
                      (service) {
                        return service.toMap();
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
                BmDiscoverServicesResult(
                  remoteId: DeviceIdentifier('str'),
                  services: [],
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
                BmDiscoverServicesResult(
                  remoteId: DeviceIdentifier('str'),
                  services: [],
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
