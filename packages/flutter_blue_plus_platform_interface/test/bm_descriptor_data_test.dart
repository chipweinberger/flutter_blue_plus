import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmDescriptorData',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the characteristic uuid property',
            () {
              final characteristicUuid = '0102';

              expect(
                BmDescriptorData.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': characteristicUuid,
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
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
                BmDescriptorData.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': descriptorUuid,
                  'value': '',
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
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
                BmDescriptorData.fromMap({
                  'remote_id': remoteId,
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).remoteId,
                equals(DeviceIdentifier(remoteId)),
              );
            },
          );

          test(
            'deserializes the secondary service uuid property',
            () {
              final secondaryServiceUuid = '0102';

              expect(
                BmDescriptorData.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'secondary_service_uuid': secondaryServiceUuid,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).secondaryServiceUuid,
                equals(Guid(secondaryServiceUuid)),
              );
            },
          );

          test(
            'deserializes the secondary service uuid property as null if it is null',
            () {
              expect(
                BmDescriptorData.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
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
                BmDescriptorData.fromMap({
                  'remote_id': 'str',
                  'service_uuid': serviceUuid,
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': 0,
                  'error_code': 0,
                  'error_string': '',
                }).serviceUuid,
                equals(Guid(serviceUuid)),
              );
            },
          );

          test(
            'deserializes the success property as false if it is 0',
            () {
              expect(
                BmDescriptorData.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
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
                BmDescriptorData.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
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
                BmDescriptorData.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': '',
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).success,
                isTrue,
              );
            },
          );

          test(
            'deserializes the value property',
            () {
              final value = '010203';

              expect(
                BmDescriptorData.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': value,
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
                }).value,
                equals(hex.decode(value)),
              );
            },
          );

          test(
            'deserializes the value property as [] if it is null',
            () {
              expect(
                BmDescriptorData.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                  'value': null,
                  'success': 1,
                  'error_code': 0,
                  'error_string': '',
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
              final success = true;
              final errorCode = 0;
              final errorString = '';

              expect(
                BmDescriptorData(
                  remoteId: remoteId,
                  serviceUuid: serviceUuid,
                  secondaryServiceUuid: secondaryServiceUuid,
                  characteristicUuid: characteristicUuid,
                  descriptorUuid: descriptorUuid,
                  value: value,
                  success: success,
                  errorCode: errorCode,
                  errorString: errorString,
                ).hashCode,
                equals(
                  remoteId.hashCode ^
                      serviceUuid.hashCode ^
                      secondaryServiceUuid.hashCode ^
                      characteristicUuid.hashCode ^
                      descriptorUuid.hashCode ^
                      const ListEquality<int>().hash(value) ^
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
                BmDescriptorData(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                      value: [],
                      success: true,
                      errorCode: 0,
                      errorString: '',
                    ) ==
                    BmDescriptorData(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                      value: [],
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
                BmDescriptorData(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                      value: [],
                      success: true,
                      errorCode: 0,
                      errorString: '',
                    ) ==
                    BmDescriptorData(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      characteristicUuid: Guid('0102'),
                      descriptorUuid: Guid('0102'),
                      value: [],
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
            'serializes the characteristic uuid property',
            () {
              final characteristicUuid = Guid('0102');

              expect(
                BmDescriptorData(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: characteristicUuid,
                  descriptorUuid: Guid('0102'),
                  value: [],
                  success: true,
                  errorCode: 0,
                  errorString: '',
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
                BmDescriptorData(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: descriptorUuid,
                  value: [],
                  success: true,
                  errorCode: 0,
                  errorString: '',
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
                BmDescriptorData(
                  remoteId: remoteId,
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: [],
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
            'serializes the secondary service uuid property',
            () {
              final secondaryServiceUuid = Guid('0102');

              expect(
                BmDescriptorData(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  secondaryServiceUuid: secondaryServiceUuid,
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: [],
                  success: true,
                  errorCode: 0,
                  errorString: '',
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
                BmDescriptorData(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  secondaryServiceUuid: null,
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: [],
                  success: true,
                  errorCode: 0,
                  errorString: '',
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
                BmDescriptorData(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: serviceUuid,
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: [],
                  success: true,
                  errorCode: 0,
                  errorString: '',
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
                BmDescriptorData(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: [],
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
                BmDescriptorData(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: [],
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

          test(
            'serializes the value property',
            () {
              final value = [0x01, 0x02, 0x03];

              expect(
                BmDescriptorData(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                  value: value,
                  success: true,
                  errorCode: 0,
                  errorString: '',
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
