import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmReadCharacteristicRequest',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the characteristic uuid property',
            () {
              final characteristicUuid = '0102';

              expect(
                BmReadCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': characteristicUuid,
                }).characteristicUuid,
                equals(Guid(characteristicUuid)),
              );
            },
          );

          test(
            'deserializes the secondary service uuid property',
            () {
              final secondaryServiceUuid = '0102';

              expect(
                BmReadCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'secondary_service_uuid': secondaryServiceUuid,
                  'characteristic_uuid': '0102',
                }).secondaryServiceUuid,
                equals(Guid(secondaryServiceUuid)),
              );
            },
          );

          test(
            'deserializes the secondary service uuid property as null if it is null',
            () {
              expect(
                BmReadCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                }).secondaryServiceUuid,
                isNull,
              );
            },
          );

          test(
            'deserializes the service uuid property',
            () {
              final serviceUuid = '0102';

              expect(
                BmReadCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': serviceUuid,
                  'characteristic_uuid': '0102',
                }).serviceUuid,
                equals(Guid(serviceUuid)),
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
              final secondaryServiceUuid = null;
              final characteristicUuid = Guid('0102');

              expect(
                BmReadCharacteristicRequest(
                  remoteId: remoteId,
                  serviceUuid: serviceUuid,
                  secondaryServiceUuid: secondaryServiceUuid,
                  characteristicUuid: characteristicUuid,
                ).hashCode,
                equals(
                  remoteId.hashCode ^
                      serviceUuid.hashCode ^
                      secondaryServiceUuid.hashCode ^
                      characteristicUuid.hashCode,
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
                BmReadCharacteristicRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                    ) ==
                    BmReadCharacteristicRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      secondaryServiceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmReadCharacteristicRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                    ) ==
                    BmReadCharacteristicRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
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
            'serializes the characteristic uuid property',
            () {
              final characteristicUuid = Guid('0102');

              expect(
                BmReadCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: characteristicUuid,
                ).toMap(),
                containsPair(
                  'characteristic_uuid',
                  equals(characteristicUuid.str),
                ),
              );
            },
          );

          test(
            'serializes the remote id property',
            () {
              final remoteId = DeviceIdentifier('str');

              expect(
                BmReadCharacteristicRequest(
                  remoteId: remoteId,
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                ).toMap(),
                containsPair(
                  'remote_id',
                  equals(remoteId.str),
                ),
              );
            },
          );

          test(
            'serializes the secondary service uuid property',
            () {
              final secondaryServiceUuid = Guid('0102');

              expect(
                BmReadCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  secondaryServiceUuid: secondaryServiceUuid,
                  characteristicUuid: Guid('0102'),
                ).toMap(),
                containsPair(
                  'secondary_service_uuid',
                  equals(secondaryServiceUuid.str),
                ),
              );
            },
          );

          test(
            'serializes the secondary service uuid property as null if it is null',
            () {
              expect(
                BmReadCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  secondaryServiceUuid: null,
                  characteristicUuid: Guid('0102'),
                ).toMap(),
                containsPair(
                  'secondary_service_uuid',
                  isNull,
                ),
              );
            },
          );

          test(
            'serializes the service uuid property',
            () {
              final serviceUuid = Guid('0102');

              expect(
                BmReadCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: serviceUuid,
                  characteristicUuid: Guid('0102'),
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
