import 'package:collection/collection.dart';
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
            'deserializes the characteristics property',
            () {
              final characteristics = [
                {
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'descriptors': [],
                  'properties': {},
                },
              ];

              expect(
                BmBluetoothService.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'is_primary': 1,
                  'characteristics': characteristics,
                  'included_services': [],
                }).characteristics,
                equals(
                  characteristics.map(
                    (characteristic) {
                      return BmBluetoothCharacteristic.fromMap(characteristic);
                    },
                  ),
                ),
              );
            },
          );

          test(
            'deserializes the characteristics property as [] if it is null',
            () {
              expect(
                BmBluetoothService.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'is_primary': 1,
                  'characteristics': null,
                  'included_services': [],
                }).characteristics,
                equals([]),
              );
            },
          );

          test(
            'deserializes the included services property',
            () {
              final includedServices = [
                {
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'is_primary': 1,
                  'characteristics': [],
                  'included_services': [],
                },
              ];

              expect(
                BmBluetoothService.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'is_primary': 1,
                  'characteristics': [],
                  'included_services': includedServices,
                }).includedServices,
                equals(
                  includedServices.map(
                    (includedService) {
                      return BmBluetoothService.fromMap(includedService);
                    },
                  ),
                ),
              );
            },
          );

          test(
            'deserializes the included services property as [] if it is null',
            () {
              expect(
                BmBluetoothService.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'is_primary': 1,
                  'characteristics': [],
                  'included_services': null,
                }).includedServices,
                equals([]),
              );
            },
          );

          test(
            'deserializes the remote id property',
            () {
              final remoteId = 'str';

              expect(
                BmBluetoothService.fromMap({
                  'remote_id': remoteId,
                  'service_uuid': '0102',
                  'is_primary': 1,
                  'characteristics': [],
                  'included_services': null,
                }).remoteId,
                equals(DeviceIdentifier(remoteId)),
              );
            },
          );

          test(
            'deserializes the service uuid property',
            () {
              final serviceUuid = '0102';

              expect(
                BmBluetoothService.fromMap({
                  'remote_id': 'str',
                  'service_uuid': serviceUuid,
                  'is_primary': 1,
                  'characteristics': [],
                  'included_services': null,
                }).serviceUuid,
                equals(Guid(serviceUuid)),
              );
            },
          );

          test(
            'deserializes the is primary property as false if it is not 1',
            () {
              expect(
                BmBluetoothService.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'is_primary': 0,
                  'characteristics': [],
                  'included_services': null,
                }).isPrimary,
                isFalse,
              );
            },
          );

          test(
            'deserializes the is primary property as true if it is 1',
            () {
              expect(
                BmBluetoothService.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'is_primary': 1,
                  'characteristics': [],
                  'included_services': null,
                }).isPrimary,
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
              final serviceUuid = Guid('0102');
              final isPrimary = true;
              final characteristics = <BmBluetoothCharacteristic>[];
              final includedServices = <BmBluetoothService>[];

              expect(
                BmBluetoothService(
                  remoteId: remoteId,
                  serviceUuid: serviceUuid,
                  isPrimary: isPrimary,
                  characteristics: characteristics,
                  includedServices: includedServices,
                ).hashCode,
                equals(
                  remoteId.hashCode ^
                      serviceUuid.hashCode ^
                      isPrimary.hashCode ^
                      const ListEquality<BmBluetoothCharacteristic>()
                          .hash(characteristics) ^
                      const ListEquality<BmBluetoothService>()
                          .hash(includedServices),
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
                BmBluetoothService(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      isPrimary: true,
                      characteristics: [],
                      includedServices: [],
                    ) ==
                    BmBluetoothService(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      isPrimary: false,
                      characteristics: [],
                      includedServices: [],
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmBluetoothService(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      isPrimary: true,
                      characteristics: [],
                      includedServices: [],
                    ) ==
                    BmBluetoothService(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      isPrimary: true,
                      characteristics: [],
                      includedServices: [],
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
            'serializes the characteristics property',
            () {
              final characteristics = [
                BmBluetoothCharacteristic(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptors: [],
                  properties: BmCharacteristicProperties(
                    broadcast: false,
                    read: false,
                    writeWithoutResponse: false,
                    write: false,
                    notify: false,
                    indicate: false,
                    authenticatedSignedWrites: false,
                    extendedProperties: false,
                    notifyEncryptionRequired: false,
                    indicateEncryptionRequired: false,
                  ),
                ),
              ];

              expect(
                BmBluetoothService(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  isPrimary: true,
                  characteristics: characteristics,
                  includedServices: [],
                ).toMap(),
                containsPair(
                  'characteristics',
                  equals(
                    characteristics.map(
                      (characteristic) {
                        return characteristic.toMap();
                      },
                    ),
                  ),
                ),
              );
            },
          );

          test(
            'serializes the included services property',
            () {
              final includedServices = [
                BmBluetoothService(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  isPrimary: true,
                  characteristics: [],
                  includedServices: [],
                ),
              ];

              expect(
                BmBluetoothService(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  isPrimary: true,
                  characteristics: [],
                  includedServices: includedServices,
                ).toMap(),
                containsPair(
                  'included_services',
                  equals(
                    includedServices.map(
                      (includedService) {
                        return includedService.toMap();
                      },
                    ),
                  ),
                ),
              );
            },
          );

          test(
            'serializes the is primary property as 0 if it is false',
            () {
              expect(
                BmBluetoothService(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  isPrimary: false,
                  characteristics: [],
                  includedServices: [],
                ).toMap(),
                containsPair(
                  'is_primary',
                  equals(0),
                ),
              );
            },
          );

          test(
            'serializes the is primary property as 1 if it is true',
            () {
              expect(
                BmBluetoothService(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  isPrimary: true,
                  characteristics: [],
                  includedServices: [],
                ).toMap(),
                containsPair(
                  'is_primary',
                  equals(1),
                ),
              );
            },
          );

          test(
            'serializes the remote id property',
            () {
              final remoteId = DeviceIdentifier('str');

              expect(
                BmBluetoothService(
                  remoteId: remoteId,
                  serviceUuid: Guid('0102'),
                  isPrimary: true,
                  characteristics: [],
                  includedServices: [],
                ).toMap(),
                containsPair(
                  'remote_id',
                  equals(remoteId.str),
                ),
              );
            },
          );

          test(
            'serializes the service uuid property',
            () {
              final serviceUuid = Guid('0102');

              expect(
                BmBluetoothService(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: serviceUuid,
                  isPrimary: true,
                  characteristics: [],
                  includedServices: [],
                ).toMap(),
                containsPair(
                  'service_uuid',
                  equals(serviceUuid.str),
                ),
              );
            },
          );
        },
      );
    },
  );
}
