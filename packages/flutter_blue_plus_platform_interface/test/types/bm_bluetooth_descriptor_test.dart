import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmBluetoothDescriptor',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the characteristic uuid property',
            () {
              final characteristicUuid = '0102';

              expect(
                BmBluetoothDescriptor.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': characteristicUuid,
                  'descriptor_uuid': '0102',
                }).characteristicUuid,
                equals(Guid(characteristicUuid)),
              );
            },
          );

          test(
            'deserializes the descriptor uuid property',
            () {
              final descriptorUuid = '0102';

              expect(
                BmBluetoothDescriptor.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': descriptorUuid,
                }).descriptorUuid,
                equals(Guid(descriptorUuid)),
              );
            },
          );

          test(
            'deserializes the remote id property',
            () {
              final remoteId = 'str';

              expect(
                BmBluetoothDescriptor.fromMap({
                  'remote_id': remoteId,
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
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
                BmBluetoothDescriptor.fromMap({
                  'remote_id': 'str',
                  'service_uuid': serviceUuid,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
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
              final characteristicUuid = Guid('0102');
              final descriptorUuid = Guid('0102');

              expect(
                BmBluetoothDescriptor(
                  remoteId: remoteId,
                  serviceUuid: serviceUuid,
                  characteristicUuid: characteristicUuid,
                  descriptorUuid: descriptorUuid,
                ).hashCode,
                equals(
                  remoteId.hashCode ^
                      serviceUuid.hashCode ^
                      characteristicUuid.hashCode ^
                      descriptorUuid.hashCode,
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
                BmBluetoothDescriptor(
                      remoteId: DeviceIdentifier('str1'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                    ) ==
                    BmBluetoothDescriptor(
                      remoteId: DeviceIdentifier('str2'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmBluetoothDescriptor(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                    ) ==
                    BmBluetoothDescriptor(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
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
                BmBluetoothDescriptor(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: characteristicUuid,
                  descriptorUuid: Guid('0102'),
                ).toMap(),
                containsPair(
                  'characteristic_uuid',
                  equals(characteristicUuid.str),
                ),
              );
            },
          );

          test(
            'serializes the descriptor uuid property',
            () {
              final descriptorUuid = Guid('0102');

              expect(
                BmBluetoothDescriptor(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: descriptorUuid,
                ).toMap(),
                containsPair(
                  'descriptor_uuid',
                  equals(descriptorUuid.str),
                ),
              );
            },
          );

          test(
            'serializes the remote id property',
            () {
              final remoteId = DeviceIdentifier('str');

              expect(
                BmBluetoothDescriptor(
                  remoteId: remoteId,
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
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
                BmBluetoothDescriptor(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: serviceUuid,
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
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
