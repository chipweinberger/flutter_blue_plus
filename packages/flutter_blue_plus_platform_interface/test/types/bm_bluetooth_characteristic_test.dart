import 'package:collection/collection.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmBluetoothCharacteristic',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the characteristic uuid property',
            () {
              final characteristicUuid = '0102';

              expect(
                BmBluetoothCharacteristic.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': characteristicUuid,
                  'descriptors': [],
                  'properties': {},
                }).characteristicUuid,
                equals(Guid(characteristicUuid)),
              );
            },
          );

          test(
            'deserializes the descriptors property',
            () {
              final descriptors = [
                {
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptor_uuid': '0102',
                },
              ];

              expect(
                BmBluetoothCharacteristic.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptors': descriptors,
                  'properties': {},
                }).descriptors,
                equals(
                  descriptors.map(
                    (descriptor) {
                      return BmBluetoothDescriptor.fromMap(descriptor);
                    },
                  ),
                ),
              );
            },
          );

          test(
            'deserializes the descriptors property as [] if it is null',
            () {
              expect(
                BmBluetoothCharacteristic.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptors': null,
                  'properties': {},
                }).descriptors,
                equals([]),
              );
            },
          );

          test(
            'deserializes the properties property properties as false if it is null',
            () {
              expect(
                BmBluetoothCharacteristic.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptors': [],
                  'properties': null,
                }).properties,
                equals(
                  BmCharacteristicProperties(
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
              );
            },
          );

          test(
            'deserializes the remote id property',
            () {
              final remoteId = 'str';

              expect(
                BmBluetoothCharacteristic.fromMap({
                  'remote_id': remoteId,
                  'service_uuid': '0102',
                  'characteristic_uuid': '0102',
                  'descriptors': [],
                  'properties': {},
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
                BmBluetoothCharacteristic.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'secondary_service_uuid': secondaryServiceUuid,
                  'characteristic_uuid': '0102',
                  'descriptors': [],
                  'properties': {},
                }).secondaryServiceUuid,
                equals(Guid(secondaryServiceUuid)),
              );
            },
          );

          test(
            'deserializes the secondary service uuid property as null if it is null',
            () {
              expect(
                BmBluetoothCharacteristic.fromMap({
                  'remote_id': 'str',
                  'service_uuid': '0102',
                  'secondary_service_uuid': null,
                  'characteristic_uuid': '0102',
                  'descriptors': [],
                  'properties': {},
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
                BmBluetoothCharacteristic.fromMap({
                  'remote_id': 'str',
                  'service_uuid': serviceUuid,
                  'characteristic_uuid': '0102',
                  'descriptors': [],
                  'properties': {},
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
              final descriptors = <BmBluetoothDescriptor>[];
              final properties = BmCharacteristicProperties(
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
              );

              expect(
                BmBluetoothCharacteristic(
                  remoteId: remoteId,
                  serviceUuid: serviceUuid,
                  secondaryServiceUuid: secondaryServiceUuid,
                  characteristicUuid: characteristicUuid,
                  descriptors: descriptors,
                  properties: properties,
                ).hashCode,
                equals(
                  remoteId.hashCode ^
                      serviceUuid.hashCode ^
                      secondaryServiceUuid.hashCode ^
                      characteristicUuid.hashCode ^
                      const ListEquality<BmBluetoothDescriptor>()
                          .hash(descriptors) ^
                      properties.hashCode,
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
                    ) ==
                    BmBluetoothCharacteristic(
                      remoteId: DeviceIdentifier('str'),
                      serviceUuid: Guid('0102'),
                      secondaryServiceUuid: Guid('0102'),
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
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
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
                    ) ==
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
                BmBluetoothCharacteristic(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: characteristicUuid,
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
                ).toMap(),
                containsPair(
                  'characteristic_uuid',
                  equals(characteristicUuid.str),
                ),
              );
            },
          );

          test(
            'serializes the descriptors property',
            () {
              final descriptors = [
                BmBluetoothDescriptor(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptorUuid: Guid('0102'),
                ),
              ];

              expect(
                BmBluetoothCharacteristic(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptors: descriptors,
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
                ).toMap(),
                containsPair(
                  'descriptors',
                  equals(
                    descriptors.map(
                      (descriptor) {
                        return descriptor.toMap();
                      },
                    ),
                  ),
                ),
              );
            },
          );

          test(
            'serializes the properties property',
            () {
              final properties = BmCharacteristicProperties(
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
              );

              expect(
                BmBluetoothCharacteristic(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  characteristicUuid: Guid('0102'),
                  descriptors: [],
                  properties: properties,
                ).toMap(),
                containsPair(
                  'properties',
                  equals(properties.toMap()),
                ),
              );
            },
          );

          test(
            'serializes the remote id property',
            () {
              final remoteId = DeviceIdentifier('str');

              expect(
                BmBluetoothCharacteristic(
                  remoteId: remoteId,
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
                BmBluetoothCharacteristic(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  secondaryServiceUuid: secondaryServiceUuid,
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
                BmBluetoothCharacteristic(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: Guid('0102'),
                  secondaryServiceUuid: null,
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
                BmBluetoothCharacteristic(
                  remoteId: DeviceIdentifier('str'),
                  serviceUuid: serviceUuid,
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
