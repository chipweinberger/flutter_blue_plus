import 'gatt_characteristic.dart';

final class BluetoothGattService {
  const BluetoothGattService({
    required this.characteristics,
    required this.includedServices,
    required this.includedServiceUuids,
    required this.instanceId,
    required this.isPrimary,
    required this.uuid,
  });

  factory BluetoothGattService.fromMap(Map<Object?, Object?> map) {
    final uuid = map['uuid'] as String;
    final instanceId = map['instanceId'] as int;
    final isPrimary = map['isPrimary'] as bool;
    final includedServiceUuids = (map['includedServiceUuids'] as List<Object?>? ?? const []).cast<String>();
    final includedServices = (map['includedServices'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>()
        .map(BluetoothGattService.fromMap)
        .toList();

    final characteristics = (map['characteristics'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>()
        .map(
          (characteristicMap) => BluetoothGattCharacteristic.fromMap(
            characteristicMap,
            fallbackServiceUuid: uuid,
            fallbackServiceInstanceId: instanceId,
            fallbackServiceIsPrimary: isPrimary,
            fallbackIncludedServices: includedServices,
            fallbackIncludedServiceUuids: includedServiceUuids,
          ),
        )
        .toList();

    return BluetoothGattService(
      characteristics: characteristics,
      includedServices: includedServices.isNotEmpty
          ? includedServices
          : includedServiceUuids
              .map(
                (includedServiceUuid) => BluetoothGattService(
                  characteristics: const [],
                  includedServices: const [],
                  includedServiceUuids: const [],
                  instanceId: -1,
                  isPrimary: true,
                  uuid: includedServiceUuid,
                ),
              )
              .toList(),
      includedServiceUuids: includedServiceUuids,
      instanceId: instanceId,
      isPrimary: isPrimary,
      uuid: uuid,
    );
  }

  final List<BluetoothGattCharacteristic> characteristics;
  final List<BluetoothGattService> includedServices;
  final List<String> includedServiceUuids;
  final int instanceId;
  final bool isPrimary;
  final String uuid;

  String getUuid() {
    return uuid;
  }

  int getInstanceId() {
    return instanceId;
  }

  int getType() {
    return isPrimary ? 0 : 1;
  }

  List<BluetoothGattService> getIncludedServices() {
    return includedServices;
  }

  List<BluetoothGattCharacteristic> getCharacteristics() {
    return characteristics;
  }

  BluetoothGattCharacteristic? getCharacteristic(String uuid) {
    for (final characteristic in characteristics) {
      if (characteristic.uuid.toLowerCase() == uuid.toLowerCase()) {
        return characteristic;
      }
    }
    return null;
  }
}
