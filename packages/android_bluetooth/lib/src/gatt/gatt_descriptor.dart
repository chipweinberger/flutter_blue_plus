import 'dart:typed_data';

import 'gatt_characteristic.dart';
import 'gatt_characteristic_properties.dart';
import 'gatt_service.dart';

final class BluetoothGattDescriptor {
  BluetoothGattDescriptor({
    required this.characteristicInstanceId,
    required this.characteristicPermissions,
    required this.characteristicProperties,
    required this.characteristicUuid,
    required this.permissions,
    required this.serviceIncludedServiceUuids,
    required this.serviceIncludedServices,
    required this.serviceInstanceId,
    required this.serviceIsPrimary,
    required this.serviceUuid,
    required this.uuid,
    required this.value,
    required this.characteristicValue,
    required this.characteristicWriteType,
  });

  factory BluetoothGattDescriptor.fromMap(
    Map<Object?, Object?> map, {
    BluetoothGattCharacteristic? fallbackCharacteristic,
  }) {
    return BluetoothGattDescriptor(
      characteristicInstanceId: map['characteristicInstanceId'] as int? ?? fallbackCharacteristic?.instanceId ?? -1,
      characteristicPermissions: map['characteristicPermissions'] as int? ?? fallbackCharacteristic?.permissions ?? 0,
      characteristicProperties: BluetoothGattCharacteristicProperties.fromMap(
        map['characteristicProperties'] as Map<Object?, Object?>? ??
            (fallbackCharacteristic != null
                ? <Object?, Object?>{
                    'authenticatedSignedWrites': fallbackCharacteristic.properties.authenticatedSignedWrites,
                    'broadcast': fallbackCharacteristic.properties.broadcast,
                    'extendedProperties': fallbackCharacteristic.properties.extendedProperties,
                    'indicate': fallbackCharacteristic.properties.indicate,
                    'notify': fallbackCharacteristic.properties.notify,
                    'read': fallbackCharacteristic.properties.read,
                    'write': fallbackCharacteristic.properties.write,
                    'writeWithoutResponse': fallbackCharacteristic.properties.writeWithoutResponse,
                  }
                : const {}),
      ),
      characteristicUuid: map['characteristicUuid'] as String? ?? fallbackCharacteristic?.uuid ?? '',
      permissions: map['permissions'] as int? ?? 0,
      serviceIncludedServiceUuids: (map['serviceIncludedServiceUuids'] as List<Object?>? ??
              fallbackCharacteristic?.serviceIncludedServiceUuids ??
              const [])
          .cast<String>(),
      serviceIncludedServices: (map['serviceIncludedServices'] as List<Object?>? ?? const [])
          .cast<Map<Object?, Object?>>()
          .map(BluetoothGattService.fromMap)
          .toList(),
      serviceInstanceId: map['serviceInstanceId'] as int? ?? fallbackCharacteristic?.serviceInstanceId ?? -1,
      serviceIsPrimary: map['serviceIsPrimary'] as bool? ?? fallbackCharacteristic?.serviceIsPrimary ?? true,
      serviceUuid: map['serviceUuid'] as String? ?? fallbackCharacteristic?.serviceUuid ?? '',
      uuid: map['uuid'] as String,
      value: map['value'] as Uint8List?,
      characteristicValue: map['characteristicValue'] as Uint8List? ?? fallbackCharacteristic?.value,
      characteristicWriteType: map['characteristicWriteType'] as int? ?? fallbackCharacteristic?.writeType ?? 0,
    );
  }

  final int characteristicInstanceId;
  final int characteristicPermissions;
  final BluetoothGattCharacteristicProperties characteristicProperties;
  final String characteristicUuid;
  final int permissions;
  final List<String> serviceIncludedServiceUuids;
  final List<BluetoothGattService> serviceIncludedServices;
  final int serviceInstanceId;
  final bool serviceIsPrimary;
  final String serviceUuid;
  final String uuid;
  Uint8List? value;
  final Uint8List? characteristicValue;
  final int characteristicWriteType;

  String getUuid() {
    return uuid;
  }

  int getPermissions() {
    return permissions;
  }

  Uint8List? getValue() {
    return value;
  }

  bool setValue(Uint8List value) {
    this.value = value;
    return true;
  }

  BluetoothGattCharacteristic getCharacteristic() {
    return BluetoothGattCharacteristic(
      descriptors: [this],
      instanceId: characteristicInstanceId,
      permissions: characteristicPermissions,
      properties: characteristicProperties,
      serviceIncludedServiceUuids: serviceIncludedServiceUuids,
      serviceIncludedServices: serviceIncludedServices,
      serviceInstanceId: serviceInstanceId,
      serviceIsPrimary: serviceIsPrimary,
      serviceUuid: serviceUuid,
      uuid: characteristicUuid,
      value: characteristicValue,
      writeType: characteristicWriteType,
    );
  }
}
