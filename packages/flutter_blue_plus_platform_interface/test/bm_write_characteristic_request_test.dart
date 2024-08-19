import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmWriteCharacteristicRequest',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the characteristic uuid property',
            () {
              final characteristicUuid = '0102';

              expect(
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': characteristicUuid,
                  'write_type': 0,
                  'allow_long_write': 0,
                  'value': '',
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
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'secondary_service_uuid': secondaryServiceUuid,
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'allow_long_write': 0,
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
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'allow_long_write': 0,
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
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': serviceUuid,
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'allow_long_write': 0,
                  'value': '',
                }).serviceUuid,
                equals(Guid(serviceUuid)),
              );
            },
          );

          test(
            'deserializes the allow long write property as false if it is 0',
            () {
              expect(
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'allow_long_write': 0,
                  'value': '',
                }).allowLongWrite,
                isFalse,
              );
            },
          );

          test(
            'deserializes the allow long write property as true if it is not 0',
            () {
              expect(
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'allow_long_write': 1,
                  'value': '',
                }).allowLongWrite,
                isTrue,
              );
            },
          );

          test(
            'deserializes the value property',
            () {
              final value = '010203';

              expect(
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'allow_long_write': 0,
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
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'write_type': 0,
                  'allow_long_write': 0,
                  'value': null,
                }).value,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the write type property',
            () {
              final writeType = BmWriteType.withResponse;

              expect(
                BmWriteCharacteristicRequest.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'write_type': writeType.index,
                  'allow_long_write': 0,
                  'value': '',
                }).writeType,
                equals(writeType),
              );
            },
          );

          test(
            'throws a range error if the write type property index is out of range',
            () {
              expect(
                () {
                  BmWriteCharacteristicRequest.fromMap({
                    'remote_id': 'str',
                    'service_uuid': '0102',
                    'characteristic_uuid': '0102',
                    'write_type': 2,
                    'allow_long_write': 0,
                    'value': '',
                  });
                },
                throwsRangeError,
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
              final writeType = BmWriteType.withResponse;
              final allowLongWrite = false;
              final value = <int>[];

              expect(
                BmWriteCharacteristicRequest(
                  remoteId: remoteId,
                  serviceUuid: serviceUuid,
                  secondaryServiceUuid: secondaryServiceUuid,
                  characteristicUuid: characteristicUuid,
                  writeType: writeType,
                  allowLongWrite: allowLongWrite,
                  value: value,
                ).hashCode,
                equals(
                  remoteId.hashCode ^
                      serviceUuid.hashCode ^
                      secondaryServiceUuid.hashCode ^
                      characteristicUuid.hashCode ^
                      writeType.hashCode ^
                      allowLongWrite.hashCode ^
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
                BmWriteCharacteristicRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      writeType: BmWriteType.withResponse,
                      allowLongWrite: false,
                      value: [],
                    ) ==
                    BmWriteCharacteristicRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      secondaryServiceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      writeType: BmWriteType.withResponse,
                      allowLongWrite: false,
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
                BmWriteCharacteristicRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      writeType: BmWriteType.withResponse,
                      allowLongWrite: false,
                      value: [],
                    ) ==
                    BmWriteCharacteristicRequest(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      writeType: BmWriteType.withResponse,
                      allowLongWrite: false,
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
                BmWriteCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: characteristicUuid,
                  writeType: BmWriteType.withResponse,
                  allowLongWrite: false,
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
            'serializes the remote id property',
            () {
              final remoteId = DeviceIdentifier('str');

              expect(
                BmWriteCharacteristicRequest(
                  remoteId: remoteId,
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  writeType: BmWriteType.withResponse,
                  allowLongWrite: false,
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
                BmWriteCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  secondaryServiceUuid: secondaryServiceUuid,
                  characteristicUuid: Guid('0102'),
                  writeType: BmWriteType.withResponse,
                  allowLongWrite: false,
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
                BmWriteCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  secondaryServiceUuid: null,
                  characteristicUuid: Guid('0102'),
                  writeType: BmWriteType.withResponse,
                  allowLongWrite: false,
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
                BmWriteCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: serviceUuid,
                  characteristicUuid: Guid('0102'),
                  writeType: BmWriteType.withResponse,
                  allowLongWrite: false,
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
            'serializes the success property as 0 if it is false',
            () {
              expect(
                BmWriteCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  writeType: BmWriteType.withResponse,
                  allowLongWrite: false,
                  value: [],
                ).toMap(),
                containsPair(
                  'allow_long_write',
                  equals(0),
                ),
              );
            },
          );

          test(
            'serializes the success property as 1 if it is true',
            () {
              expect(
                BmWriteCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  writeType: BmWriteType.withResponse,
                  allowLongWrite: true,
                  value: [],
                ).toMap(),
                containsPair(
                  'allow_long_write',
                  equals(1),
                ),
              );
            },
          );

          test(
            'serializes the write type property',
            () {
              final writeType = BmWriteType.withResponse;

              expect(
                BmWriteCharacteristicRequest(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  writeType: writeType,
                  allowLongWrite: false,
                  value: [],
                ).toMap(),
                containsPair(
                  'write_type',
                  equals(writeType.index),
                ),
              );
            },
          );
        },
      );
    },
  );
}
