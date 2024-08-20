import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmWriteDescriptorRequest',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the characteristic uuid property',
            () {
              final characteristicUuid = '0102';

              expect(
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': characteristicUuid,
                  'descriptor_uuid': '0102',
                  'value': '',
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
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': descriptorUuid,
                  'value': '',
                }).descriptorUuid,
                equals(Guid(descriptorUuid)),
              );
            },
          );

          test(
            'deserializes the secondary service uuid property',
            () {
              final secondaryServiceUuid = '0102';

              expect(
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'secondary_service_uuid': secondaryServiceUuid,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                }).secondaryServiceUuid,
                equals(Guid(secondaryServiceUuid)),
              );
            },
          );

          test(
            'deserializes the secondary service uuid property as null if it is null',
            () {
              expect(
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
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
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': serviceUuid,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                }).serviceUuid,
                equals(Guid(serviceUuid)),
              );
            },
          );

          test(
            'deserializes the value property',
            () {
              final value = '010203';

              expect(
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': value,
                }).value,
                equals(hex.decode(value)),
              );
            },
          );

          test(
            'deserializes the value property as [] if it is null',
            () {
              expect(
                BmWriteDescriptorRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': null,
                }).value,
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
              final serviceUuid = Guid('0102');
              final secondaryServiceUuid = null;
              final characteristicUuid = Guid('0102');
              final descriptorUuid = Guid('0102');
              final value = <int>[];

              expect(
                BmWriteDescriptorRequest(
                  remoteId: remoteId,
                  serviceUuid: serviceUuid,
                  secondaryServiceUuid: secondaryServiceUuid,
                  characteristicUuid: characteristicUuid,
                  descriptorUuid: descriptorUuid,
                  value: value,
                ).hashCode,
                equals(
                  remoteId.hashCode ^
                      serviceUuid.hashCode ^
                      secondaryServiceUuid.hashCode ^
                      characteristicUuid.hashCode ^
                      descriptorUuid.hashCode ^
                      const ListEquality<int>().hash(value),
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
                BmWriteDescriptorRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                      value: [],
                    ) ==
                    BmWriteDescriptorRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      secondaryServiceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                      value: [],
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmWriteDescriptorRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                      value: [],
                    ) ==
                    BmWriteDescriptorRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                      value: [],
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
                BmWriteDescriptorRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: characteristicUuid,
                  descriptorUuid: Guid('0102'),
                  value: [],
                ).toMap(),
                containsPair(
                  'characteristic_uuid',
                  equals(characteristicUuid.str),
                ),
              );
            },
          );

          test(
            'serializes the characteristic uuid property',
            () {
              final descriptorUuid = Guid('0102');

              expect(
                BmWriteDescriptorRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: descriptorUuid,
                  value: [],
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
                BmWriteDescriptorRequest(
                  remoteId: remoteId,
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: [],
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
                BmWriteDescriptorRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  secondaryServiceUuid: secondaryServiceUuid,
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: [],
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
                BmWriteDescriptorRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  secondaryServiceUuid: null,
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: [],
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
                BmWriteDescriptorRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: serviceUuid,
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: [],
                ).toMap(),
                containsPair(
                  'service_uuid',
                  equals(serviceUuid.str),
                ),
              );
            },
          );

          test(
            'serializes the value property',
            () {
              final value = [0x01, 0x02, 0x03];

              expect(
                BmWriteDescriptorRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: value,
                ).toMap(),
                containsPair(
                  'value',
                  hex.encode(value),
                ),
              );
            },
          );
        },
      );
    },
  );
}
