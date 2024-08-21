import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_blue_plus_platform_interface/src/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmScanAdvertisement',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the connectable property as false if it is not 1',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': 'str',
                  'connectable': 0,
                  'manufacturer_data': {},
                  'service_data': {},
                  'service_uuids': [],
                  'rssi': 0,
                }).connectable,
                isFalse,
              );
            },
          );

          test(
            'deserializes the connectable property as true if it is 1',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': 'str',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': {},
                  'service_uuids': [],
                  'rssi': 0,
                }).connectable,
                isTrue,
              );
            },
          );

          test(
            'deserializes the manufacturer data property',
            () {
              final manufacturerData = {
                1: '010203',
              };

              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': 'str',
                  'connectable': 1,
                  'manufacturer_data': manufacturerData,
                  'service_data': {},
                  'service_uuids': [],
                  'rssi': 0,
                }).manufacturerData,
                equals(
                  manufacturerData.map(
                    (key, value) {
                      return MapEntry(key, hex.decode(value));
                    },
                  ),
                ),
              );
            },
          );

          test(
            'deserializes the manufacturer data property as {} if it is null',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': 'str',
                  'connectable': 1,
                  'manufacturer_data': null,
                  'service_data': {},
                  'service_uuids': [],
                  'rssi': 0,
                }).manufacturerData,
                equals({}),
              );
            },
          );

          test(
            'deserializes the remote id property',
            () {
              final remoteId = 'str';

              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': remoteId,
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': {},
                  'service_uuids': [],
                  'rssi': 0,
                }).remoteId,
                equals(DeviceIdentifier(remoteId)),
              );
            },
          );

          test(
            'deserializes the rssi property',
            () {
              final rssi = 0;

              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': 'str',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': {},
                  'service_uuids': [],
                  'rssi': rssi,
                }).rssi,
                equals(rssi),
              );
            },
          );

          test(
            'deserializes the rssi property as 0 if it is null',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': 'str',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': {},
                  'service_uuids': [],
                  'rssi': null,
                }).rssi,
                equals(0),
              );
            },
          );

          test(
            'deserializes the service data property',
            () {
              final serviceData = {
                '0102': '010203',
              };

              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': 'str',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': serviceData,
                  'service_uuids': [],
                  'rssi': 0,
                }).serviceData,
                equals(
                  serviceData.map(
                    (key, value) {
                      return MapEntry(Guid(key), hex.decode(value));
                    },
                  ),
                ),
              );
            },
          );

          test(
            'deserializes the service data property as {} if it is null',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': 'str',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': null,
                  'service_uuids': [],
                  'rssi': 0,
                }).serviceData,
                equals({}),
              );
            },
          );

          test(
            'deserializes the service uuids property',
            () {
              final serviceUuids = [
                '0102',
              ];

              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': 'str',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': {},
                  'service_uuids': serviceUuids,
                  'rssi': 0,
                }).serviceUuids,
                equals(
                  serviceUuids.map(
                    (serviceUuid) {
                      return Guid(serviceUuid);
                    },
                  ),
                ),
              );
            },
          );

          test(
            'deserializes the service uuids property as [] if it is null',
            () {
              expect(
                BmScanAdvertisement.fromMap({
                  'remote_id': 'str',
                  'connectable': 1,
                  'manufacturer_data': {},
                  'service_data': {},
                  'service_uuids': null,
                  'rssi': 0,
                }).serviceUuids,
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
              final remoteId = DeviceIdentifier('str');
              final platformName = null;
              final advName = null;
              final connectable = true;
              final txPowerLevel = 0;
              final appearance = 0;
              final manufacturerData = <int, List<int>>{};
              final serviceData = <Guid, List<int>>{};
              final serviceUuids = <Guid>[];
              final rssi = 0;

              expect(
                BmScanAdvertisement(
                  remoteId: remoteId,
                  platformName: platformName,
                  advName: advName,
                  connectable: connectable,
                  txPowerLevel: txPowerLevel,
                  appearance: appearance,
                  manufacturerData: manufacturerData,
                  serviceData: serviceData,
                  serviceUuids: serviceUuids,
                  rssi: rssi,
                ).hashCode,
                equals(
                  remoteId.hashCode ^
                      platformName.hashCode ^
                      advName.hashCode ^
                      connectable.hashCode ^
                      txPowerLevel.hashCode ^
                      appearance.hashCode ^
                      const MapEquality<int, List<int>>()
                          .hash(manufacturerData) ^
                      const MapEquality<Guid, List<int>>().hash(serviceData) ^
                      const ListEquality<Guid>().hash(serviceUuids) ^
                      rssi.hashCode,
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
                BmScanAdvertisement(
                      remoteId: DeviceIdentifier('str'),
                      connectable: true,
                      manufacturerData: {},
                      serviceData: {},
                      serviceUuids: [],
                      rssi: 0,
                    ) ==
                    BmScanAdvertisement(
                      remoteId: DeviceIdentifier('str'),
                      connectable: false,
                      manufacturerData: {},
                      serviceData: {},
                      serviceUuids: [],
                      rssi: 0,
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmScanAdvertisement(
                      remoteId: DeviceIdentifier('str'),
                      connectable: true,
                      manufacturerData: {},
                      serviceData: {},
                      serviceUuids: [],
                      rssi: 0,
                    ) ==
                    BmScanAdvertisement(
                      remoteId: DeviceIdentifier('str'),
                      connectable: true,
                      manufacturerData: {},
                      serviceData: {},
                      serviceUuids: [],
                      rssi: 0,
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
            'serializes the connectable property as 0 if it is false',
            () {
              expect(
                BmScanAdvertisement(
                  remoteId: DeviceIdentifier('str'),
                  connectable: false,
                  manufacturerData: {},
                  serviceData: {},
                  serviceUuids: [],
                  rssi: 0,
                ).toMap(),
                containsPair(
                  'connectable',
                  equals(0),
                ),
              );
            },
          );

          test(
            'serializes the connectable property as 1 if it is true',
            () {
              expect(
                BmScanAdvertisement(
                  remoteId: DeviceIdentifier('str'),
                  connectable: true,
                  manufacturerData: {},
                  serviceData: {},
                  serviceUuids: [],
                  rssi: 0,
                ).toMap(),
                containsPair(
                  'connectable',
                  equals(1),
                ),
              );
            },
          );

          test(
            'serializes the manufacturer data property',
            () {
              final manufacturerData = {
                0: [0x01, 0x02, 0x03],
              };

              expect(
                BmScanAdvertisement(
                  remoteId: DeviceIdentifier('str'),
                  connectable: true,
                  manufacturerData: manufacturerData,
                  serviceData: {},
                  serviceUuids: [],
                  rssi: 0,
                ).toMap(),
                containsPair(
                  'manufacturer_data',
                  equals(
                    manufacturerData.map(
                      (key, value) {
                        return MapEntry(key, hex.encode(value));
                      },
                    ),
                  ),
                ),
              );
            },
          );

          test(
            'serializes the remote id property',
            () {
              final remoteId = DeviceIdentifier('str');

              expect(
                BmScanAdvertisement(
                  remoteId: remoteId,
                  connectable: true,
                  manufacturerData: {},
                  serviceData: {},
                  serviceUuids: [],
                  rssi: 0,
                ).toMap(),
                containsPair(
                  'remote_id',
                  equals(remoteId.str),
                ),
              );
            },
          );

          test(
            'serializes the service data property',
            () {
              final serviceData = {
                Guid('0102'): [0x01, 0x02, 0x03],
              };

              expect(
                BmScanAdvertisement(
                  remoteId: DeviceIdentifier('str'),
                  connectable: true,
                  manufacturerData: {},
                  serviceData: serviceData,
                  serviceUuids: [],
                  rssi: 0,
                ).toMap(),
                containsPair(
                  'service_data',
                  equals(
                    serviceData.map(
                      (key, value) {
                        return MapEntry(key.str, hex.encode(value));
                      },
                    ),
                  ),
                ),
              );
            },
          );

          test(
            'serializes the service uuids property',
            () {
              final serviceUuids = [
                Guid('0102'),
              ];

              expect(
                BmScanAdvertisement(
                  remoteId: DeviceIdentifier('str'),
                  connectable: true,
                  manufacturerData: {},
                  serviceData: {},
                  serviceUuids: serviceUuids,
                  rssi: 0,
                ).toMap(),
                containsPair(
                  'service_uuids',
                  equals(
                    serviceUuids.map(
                      (serviceUuid) {
                        return serviceUuid.str;
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
