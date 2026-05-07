import 'dart:typed_data';

import 'gatt_service.dart';
import 'gatt_types.dart';

final class BluetoothGattCharacteristicChangedEvent {
  const BluetoothGattCharacteristicChangedEvent({
    required this.address,
    required this.characteristic,
    required this.value,
  });

  factory BluetoothGattCharacteristicChangedEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattCharacteristicChangedEvent(
      address: map['address'] as String,
      characteristic: BluetoothGattCharacteristicId(
        characteristicInstanceId: map['characteristicInstanceId'] as int,
        characteristicUuid: map['characteristicUuid'] as String,
        serviceInstanceId: map['serviceInstanceId'] as int,
        serviceUuid: map['serviceUuid'] as String,
      ),
      value: map['value'] as Uint8List?,
    );
  }

  final String address;
  final BluetoothGattCharacteristicId characteristic;
  final Uint8List? value;
}

final class BluetoothGattCharacteristicReadEvent {
  const BluetoothGattCharacteristicReadEvent({
    required this.address,
    required this.characteristic,
    required this.success,
    required this.status,
    required this.value,
  });

  factory BluetoothGattCharacteristicReadEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattCharacteristicReadEvent(
      address: map['address'] as String,
      characteristic: BluetoothGattCharacteristicId(
        characteristicInstanceId: map['characteristicInstanceId'] as int,
        characteristicUuid: map['characteristicUuid'] as String,
        serviceInstanceId: map['serviceInstanceId'] as int,
        serviceUuid: map['serviceUuid'] as String,
      ),
      success: map['success'] as bool? ?? false,
      status: map['status'] as int? ?? -1,
      value: map['value'] as Uint8List?,
    );
  }

  final String address;
  final BluetoothGattCharacteristicId characteristic;
  final bool success;
  final int status;
  final Uint8List? value;
}

final class BluetoothGattCharacteristicWriteEvent {
  const BluetoothGattCharacteristicWriteEvent({
    required this.address,
    required this.characteristic,
    required this.success,
    required this.status,
    required this.value,
  });

  factory BluetoothGattCharacteristicWriteEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattCharacteristicWriteEvent(
      address: map['address'] as String,
      characteristic: BluetoothGattCharacteristicId(
        characteristicInstanceId: map['characteristicInstanceId'] as int,
        characteristicUuid: map['characteristicUuid'] as String,
        serviceInstanceId: map['serviceInstanceId'] as int,
        serviceUuid: map['serviceUuid'] as String,
      ),
      success: map['success'] as bool? ?? false,
      status: map['status'] as int? ?? -1,
      value: map['value'] as Uint8List?,
    );
  }

  final String address;
  final BluetoothGattCharacteristicId characteristic;
  final bool success;
  final int status;
  final Uint8List? value;
}

final class BluetoothGattConnectionStateChangedEvent {
  const BluetoothGattConnectionStateChangedEvent({
    required this.address,
    required this.connectionState,
    required this.status,
  });

  factory BluetoothGattConnectionStateChangedEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattConnectionStateChangedEvent(
      address: map['address'] as String,
      connectionState: BluetoothGattConnectionState.values.byName(map['connectionState'] as String? ?? 'unknown'),
      status: map['status'] as int? ?? -1,
    );
  }

  final String address;
  final BluetoothGattConnectionState connectionState;
  final int status;
}

final class BluetoothGattDescriptorReadEvent {
  const BluetoothGattDescriptorReadEvent({
    required this.address,
    required this.descriptor,
    required this.success,
    required this.status,
    required this.value,
  });

  factory BluetoothGattDescriptorReadEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattDescriptorReadEvent(
      address: map['address'] as String,
      descriptor: BluetoothGattDescriptorId(
        characteristic: BluetoothGattCharacteristicId(
          characteristicInstanceId: map['characteristicInstanceId'] as int,
          characteristicUuid: map['characteristicUuid'] as String,
          serviceInstanceId: map['serviceInstanceId'] as int,
          serviceUuid: map['serviceUuid'] as String,
        ),
        descriptorUuid: map['descriptorUuid'] as String,
      ),
      success: map['success'] as bool? ?? false,
      status: map['status'] as int? ?? -1,
      value: map['value'] as Uint8List?,
    );
  }

  final String address;
  final BluetoothGattDescriptorId descriptor;
  final bool success;
  final int status;
  final Uint8List? value;
}

final class BluetoothGattDescriptorWriteEvent {
  const BluetoothGattDescriptorWriteEvent({
    required this.address,
    required this.descriptor,
    required this.success,
    required this.status,
    required this.value,
  });

  factory BluetoothGattDescriptorWriteEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattDescriptorWriteEvent(
      address: map['address'] as String,
      descriptor: BluetoothGattDescriptorId(
        characteristic: BluetoothGattCharacteristicId(
          characteristicInstanceId: map['characteristicInstanceId'] as int,
          characteristicUuid: map['characteristicUuid'] as String,
          serviceInstanceId: map['serviceInstanceId'] as int,
          serviceUuid: map['serviceUuid'] as String,
        ),
        descriptorUuid: map['descriptorUuid'] as String,
      ),
      success: map['success'] as bool? ?? false,
      status: map['status'] as int? ?? -1,
      value: map['value'] as Uint8List?,
    );
  }

  final String address;
  final BluetoothGattDescriptorId descriptor;
  final bool success;
  final int status;
  final Uint8List? value;
}

final class BluetoothGattMtuChangedEvent {
  const BluetoothGattMtuChangedEvent({
    required this.address,
    required this.mtu,
    required this.success,
    required this.status,
  });

  factory BluetoothGattMtuChangedEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattMtuChangedEvent(
      address: map['address'] as String,
      mtu: map['mtu'] as int? ?? 0,
      success: map['success'] as bool? ?? false,
      status: map['status'] as int? ?? -1,
    );
  }

  final String address;
  final int mtu;
  final bool success;
  final int status;
}

final class BluetoothGattPhyChangedEvent {
  const BluetoothGattPhyChangedEvent({
    required this.address,
    required this.rxPhy,
    required this.success,
    required this.status,
    required this.txPhy,
  });

  factory BluetoothGattPhyChangedEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattPhyChangedEvent(
      address: map['address'] as String,
      rxPhy: map['rxPhy'] as int? ?? 0,
      success: map['success'] as bool? ?? false,
      status: map['status'] as int? ?? -1,
      txPhy: map['txPhy'] as int? ?? 0,
    );
  }

  final String address;
  final int rxPhy;
  final bool success;
  final int status;
  final int txPhy;
}

final class BluetoothGattReliableWriteCompletedEvent {
  const BluetoothGattReliableWriteCompletedEvent({
    required this.address,
    required this.success,
    required this.status,
  });

  factory BluetoothGattReliableWriteCompletedEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattReliableWriteCompletedEvent(
      address: map['address'] as String,
      success: map['success'] as bool? ?? false,
      status: map['status'] as int? ?? -1,
    );
  }

  final String address;
  final bool success;
  final int status;
}

final class BluetoothGattRemoteRssiReadEvent {
  const BluetoothGattRemoteRssiReadEvent({
    required this.address,
    required this.rssi,
    required this.success,
    required this.status,
  });

  factory BluetoothGattRemoteRssiReadEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothGattRemoteRssiReadEvent(
      address: map['address'] as String,
      rssi: map['rssi'] as int? ?? 0,
      success: map['success'] as bool? ?? false,
      status: map['status'] as int? ?? -1,
    );
  }

  final String address;
  final int rssi;
  final bool success;
  final int status;
}

final class BluetoothGattServicesDiscoveredEvent {
  const BluetoothGattServicesDiscoveredEvent({
    required this.address,
    required this.services,
    required this.success,
    required this.status,
  });

  factory BluetoothGattServicesDiscoveredEvent.fromMap(Map<Object?, Object?> map) {
    final services = (map['services'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>()
        .map(BluetoothGattService.fromMap)
        .toList();

    return BluetoothGattServicesDiscoveredEvent(
      address: map['address'] as String,
      services: services,
      success: map['success'] as bool? ?? false,
      status: map['status'] as int? ?? -1,
    );
  }

  final String address;
  final List<BluetoothGattService> services;
  final bool success;
  final int status;
}
