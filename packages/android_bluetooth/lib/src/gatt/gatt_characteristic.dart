import 'dart:typed_data';

import 'gatt_characteristic_properties.dart';
import 'gatt_descriptor.dart';
import 'gatt_service.dart';

final class BluetoothGattCharacteristic {
  BluetoothGattCharacteristic({
    required this.descriptors,
    required this.instanceId,
    required this.permissions,
    required this.properties,
    required this.serviceIncludedServiceUuids,
    required this.serviceIncludedServices,
    required this.serviceInstanceId,
    required this.serviceIsPrimary,
    required this.serviceUuid,
    required this.uuid,
    required this.value,
    required this.writeType,
  });

  factory BluetoothGattCharacteristic.fromMap(
    Map<Object?, Object?> map, {
    String? fallbackServiceUuid,
    int? fallbackServiceInstanceId,
    bool? fallbackServiceIsPrimary,
    List<BluetoothGattService> fallbackIncludedServices = const [],
    List<String> fallbackIncludedServiceUuids = const [],
  }) {
    final serviceUuid = map['serviceUuid'] as String? ?? fallbackServiceUuid ?? '';
    final serviceInstanceId = map['serviceInstanceId'] as int? ?? fallbackServiceInstanceId ?? -1;
    final serviceIsPrimary = map['serviceIsPrimary'] as bool? ?? fallbackServiceIsPrimary ?? true;
    final serviceIncludedServiceUuids =
        (map['serviceIncludedServiceUuids'] as List<Object?>? ?? fallbackIncludedServiceUuids).cast<String>();
    final serviceIncludedServices = (map['serviceIncludedServices'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>()
        .map(BluetoothGattService.fromMap)
        .toList();

    final characteristic = BluetoothGattCharacteristic(
      descriptors: const [],
      instanceId: map['instanceId'] as int,
      permissions: map['permissions'] as int? ?? 0,
      properties: BluetoothGattCharacteristicProperties.fromMap(
        map['properties'] as Map<Object?, Object?>? ?? const {},
      ),
      serviceIncludedServiceUuids: serviceIncludedServiceUuids,
      serviceIncludedServices: serviceIncludedServices.isNotEmpty ? serviceIncludedServices : fallbackIncludedServices,
      serviceInstanceId: serviceInstanceId,
      serviceIsPrimary: serviceIsPrimary,
      serviceUuid: serviceUuid,
      uuid: map['uuid'] as String,
      value: map['value'] as Uint8List?,
      writeType: map['writeType'] as int? ?? 0,
    );

    characteristic.descriptors = (map['descriptors'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>()
        .map((descriptorMap) => BluetoothGattDescriptor.fromMap(descriptorMap, fallbackCharacteristic: characteristic))
        .toList();
    return characteristic;
  }

  List<BluetoothGattDescriptor> descriptors;
  final int instanceId;
  final int permissions;
  final BluetoothGattCharacteristicProperties properties;
  final List<String> serviceIncludedServiceUuids;
  final List<BluetoothGattService> serviceIncludedServices;
  final int serviceInstanceId;
  final bool serviceIsPrimary;
  final String serviceUuid;
  final String uuid;
  Uint8List? value;
  int writeType;

  String getUuid() {
    return uuid;
  }

  int getInstanceId() {
    return instanceId;
  }

  BluetoothGattCharacteristicProperties getProperties() {
    return properties;
  }

  int getPermissions() {
    return permissions;
  }

  int getWriteType() {
    return writeType;
  }

  void setWriteType(int writeType) {
    this.writeType = writeType;
  }

  List<BluetoothGattDescriptor> getDescriptors() {
    return descriptors;
  }

  BluetoothGattDescriptor? getDescriptor(String uuid) {
    for (final descriptor in descriptors) {
      if (descriptor.uuid.toLowerCase() == uuid.toLowerCase()) {
        return descriptor;
      }
    }
    return null;
  }

  Uint8List? getValue() {
    return value;
  }

  bool setValue(Uint8List value) {
    this.value = value;
    return true;
  }

  BluetoothGattService getService() {
    return BluetoothGattService(
      characteristics: [this],
      includedServices: serviceIncludedServices,
      includedServiceUuids: serviceIncludedServiceUuids,
      instanceId: serviceInstanceId,
      isPrimary: serviceIsPrimary,
      uuid: serviceUuid,
    );
  }
}
