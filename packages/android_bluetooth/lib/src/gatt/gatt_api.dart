import 'dart:typed_data';

import '../device/device.dart';
import '../internal/channels.dart';
import 'gatt_characteristic.dart';
import 'gatt_descriptor.dart';
import 'gatt_events.dart';
import 'gatt_service.dart';
import 'gatt_types.dart';

final class BluetoothGattApi {
  BluetoothGattApi._();

  static Stream<BluetoothGattCharacteristicChangedEvent>? _characteristicChanged;
  static Stream<BluetoothGattCharacteristicReadEvent>? _characteristicRead;
  static Stream<BluetoothGattCharacteristicWriteEvent>? _characteristicWritten;
  static Stream<BluetoothGattConnectionStateChangedEvent>? _connectionStateChanged;
  static Stream<BluetoothGattDescriptorReadEvent>? _descriptorRead;
  static Stream<BluetoothGattDescriptorWriteEvent>? _descriptorWritten;
  static Stream<BluetoothGattMtuChangedEvent>? _mtuChanged;
  static Stream<BluetoothGattPhyChangedEvent>? _phyRead;
  static Stream<BluetoothGattPhyChangedEvent>? _phyUpdated;
  static Stream<BluetoothGattReliableWriteCompletedEvent>? _reliableWriteCompleted;
  static Stream<BluetoothGattRemoteRssiReadEvent>? _remoteRssiRead;
  static Stream<BluetoothGattServicesDiscoveredEvent>? _servicesDiscovered;

  static Future<bool> connect(
    String address, {
    bool autoConnect = false,
    BluetoothGattHandler? handler,
    int? transport,
    int? phy,
  }) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('connectGatt', {
          'address': address,
          'autoConnect': autoConnect,
          if (handler != null) 'handler': handler.toMap(),
          if (transport != null) 'transport': transport,
          if (phy != null) 'phy': phy,
        })) ??
        false;
  }

  static Future<bool> disconnect(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('disconnectGatt', address)) ?? false;
  }

  static Future<bool> close(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('closeGatt', address)) ?? false;
  }

  static Future<BluetoothDevice?> getDevice(String address) async {
    final device = await BluetoothChannels.method.invokeMapMethod<Object?, Object?>('getGattDevice', address);
    if (device == null) {
      return null;
    }
    return BluetoothDevice.fromMap(device);
  }

  static Future<List<BluetoothGattService>> getServices(String address) async {
    final services = await BluetoothChannels.method.invokeListMethod<Map<Object?, Object?>>(
      'getGattServices',
      address,
    );
    return (services ?? const []).map(BluetoothGattService.fromMap).toList();
  }

  static Future<BluetoothGattService?> getService(String address, String serviceUuid) async {
    final service = await BluetoothChannels.method.invokeMapMethod<Object?, Object?>('getGattService', {
      'address': address,
      'serviceUuid': serviceUuid,
    });
    if (service == null) {
      return null;
    }
    return BluetoothGattService.fromMap(service);
  }

  static Future<BluetoothGattCharacteristic?> getCharacteristic(
    String address, {
    required int serviceInstanceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    final characteristic = await BluetoothChannels.method.invokeMapMethod<Object?, Object?>(
      'getGattCharacteristic',
      {
        'address': address,
        'serviceInstanceId': serviceInstanceId,
        'serviceUuid': serviceUuid,
        'characteristicUuid': characteristicUuid,
      },
    );
    if (characteristic == null) {
      return null;
    }
    return BluetoothGattCharacteristic.fromMap(characteristic);
  }

  static Future<BluetoothGattDescriptor?> getDescriptor(
    String address, {
    required int serviceInstanceId,
    required String serviceUuid,
    required int characteristicInstanceId,
    required String characteristicUuid,
    required String descriptorUuid,
  }) async {
    final descriptor = await BluetoothChannels.method.invokeMapMethod<Object?, Object?>('getGattDescriptor', {
      'address': address,
      'serviceInstanceId': serviceInstanceId,
      'serviceUuid': serviceUuid,
      'characteristicInstanceId': characteristicInstanceId,
      'characteristicUuid': characteristicUuid,
      'descriptorUuid': descriptorUuid,
    });
    if (descriptor == null) {
      return null;
    }
    return BluetoothGattDescriptor.fromMap(descriptor);
  }

  static Future<BluetoothGattService?> getCharacteristicService(
    String address, {
    required int serviceInstanceId,
    required String serviceUuid,
    required int characteristicInstanceId,
    required String characteristicUuid,
  }) async {
    final service = await BluetoothChannels.method.invokeMapMethod<Object?, Object?>(
      'getGattCharacteristicService',
      {
        'address': address,
        'serviceInstanceId': serviceInstanceId,
        'serviceUuid': serviceUuid,
        'characteristicInstanceId': characteristicInstanceId,
        'characteristicUuid': characteristicUuid,
      },
    );
    if (service == null) {
      return null;
    }
    return BluetoothGattService.fromMap(service);
  }

  static Future<BluetoothGattCharacteristic?> getDescriptorCharacteristic(
    String address, {
    required int serviceInstanceId,
    required String serviceUuid,
    required int characteristicInstanceId,
    required String characteristicUuid,
    required String descriptorUuid,
  }) async {
    final characteristic = await BluetoothChannels.method.invokeMapMethod<Object?, Object?>(
      'getGattDescriptorCharacteristic',
      {
        'address': address,
        'serviceInstanceId': serviceInstanceId,
        'serviceUuid': serviceUuid,
        'characteristicInstanceId': characteristicInstanceId,
        'characteristicUuid': characteristicUuid,
        'descriptorUuid': descriptorUuid,
      },
    );
    if (characteristic == null) {
      return null;
    }
    return BluetoothGattCharacteristic.fromMap(characteristic);
  }

  static Future<bool> discoverServices(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('discoverGattServices', address)) ?? false;
  }

  static Future<bool> requestMtu(String address, int mtu) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('requestGattMtu', {
          'address': address,
          'mtu': mtu,
        })) ??
        false;
  }

  static Future<bool> requestConnectionPriority(
    String address,
    BluetoothGattConnectionPriority connectionPriority,
  ) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('requestGattConnectionPriority', {
          'address': address,
          'connectionPriority': connectionPriority.value,
        })) ??
        false;
  }

  static Future<bool> readPhy(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('readGattPhy', address)) ?? false;
  }

  static Future<bool> setPreferredPhy(
    String address, {
    required BluetoothGattPhy txPhy,
    required BluetoothGattPhy rxPhy,
    required int phyOptions,
  }) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('setGattPreferredPhy', {
          'address': address,
          'txPhy': txPhy.value,
          'rxPhy': rxPhy.value,
          'phyOptions': phyOptions,
        })) ??
        false;
  }

  static Future<bool> beginReliableWrite(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('beginGattReliableWrite', address)) ?? false;
  }

  static Future<bool> executeReliableWrite(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('executeGattReliableWrite', address)) ?? false;
  }

  static Future<bool> abortReliableWrite(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('abortGattReliableWrite', address)) ?? false;
  }

  static Future<bool> readRemoteRssi(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('readGattRemoteRssi', address)) ?? false;
  }

  static Future<bool> setCharacteristicNotification(
    String address,
    BluetoothGattCharacteristicId characteristic,
    bool enabled,
  ) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('setGattCharacteristicNotification', {
          'address': address,
          ...characteristic.toMap(),
          'enabled': enabled,
        })) ??
        false;
  }

  static Future<bool> readCharacteristic(
    String address,
    BluetoothGattCharacteristicId characteristic,
  ) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('readGattCharacteristic', {
          'address': address,
          ...characteristic.toMap(),
        })) ??
        false;
  }

  static Future<bool> setCharacteristicWriteType(
    String address,
    BluetoothGattCharacteristicId characteristic,
    int writeType,
  ) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('setGattCharacteristicWriteType', {
          'address': address,
          ...characteristic.toMap(),
          'writeType': writeType,
        })) ??
        false;
  }

  static Future<bool> setCharacteristicValue(
    String address,
    BluetoothGattCharacteristicId characteristic,
    Uint8List value,
  ) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('setGattCharacteristicValue', {
          'address': address,
          ...characteristic.toMap(),
          'value': value,
        })) ??
        false;
  }

  static Future<bool> writeCharacteristic(
    String address,
    BluetoothGattCharacteristicId characteristic,
    Uint8List? value, {
    bool withoutResponse = false,
    int? writeType,
  }) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('writeGattCharacteristic', {
          'address': address,
          ...characteristic.toMap(),
          if (value != null) 'value': value,
          if (writeType != null) 'writeType': writeType,
          if (writeType == null) 'withoutResponse': withoutResponse,
        })) ??
        false;
  }

  static Future<bool> readDescriptor(
    String address,
    BluetoothGattDescriptorId descriptor,
  ) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('readGattDescriptor', {
          'address': address,
          ...descriptor.toMap(),
        })) ??
        false;
  }

  static Future<bool> setDescriptorValue(
    String address,
    BluetoothGattDescriptorId descriptor,
    Uint8List value,
  ) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('setGattDescriptorValue', {
          'address': address,
          ...descriptor.toMap(),
          'value': value,
        })) ??
        false;
  }

  static Future<bool> writeDescriptor(
    String address,
    BluetoothGattDescriptorId descriptor,
    Uint8List? value,
  ) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('writeGattDescriptor', {
          'address': address,
          ...descriptor.toMap(),
          if (value != null) 'value': value,
        })) ??
        false;
  }

  static Future<BluetoothGattConnectionState> getConnectionState(String address) async {
    final stateName = await BluetoothChannels.method.invokeMethod<String>('getGattConnectionState', address);
    return BluetoothGattConnectionState.values.byName(stateName ?? 'unknown');
  }

  static Stream<BluetoothGattConnectionStateChangedEvent> get onConnectionStateChanged {
    return _connectionStateChanged ??=
        BluetoothChannels.gattConnectionStateChanged.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattConnectionStateChangedEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattCharacteristicChangedEvent> get onCharacteristicChanged {
    return _characteristicChanged ??=
        BluetoothChannels.gattCharacteristicChanged.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattCharacteristicChangedEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattCharacteristicReadEvent> get onCharacteristicRead {
    return _characteristicRead ??=
        BluetoothChannels.gattCharacteristicRead.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattCharacteristicReadEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattCharacteristicWriteEvent> get onCharacteristicWrite {
    return _characteristicWritten ??=
        BluetoothChannels.gattCharacteristicWrite.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattCharacteristicWriteEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattServicesDiscoveredEvent> get onServicesDiscovered {
    return _servicesDiscovered ??=
        BluetoothChannels.gattServicesDiscovered.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattServicesDiscoveredEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattMtuChangedEvent> get onMtuChanged {
    return _mtuChanged ??= BluetoothChannels.gattMtuChanged.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattMtuChangedEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattPhyChangedEvent> get onPhyRead {
    return _phyRead ??= BluetoothChannels.gattPhyRead.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattPhyChangedEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattPhyChangedEvent> get onPhyUpdated {
    return _phyUpdated ??= BluetoothChannels.gattPhyUpdate.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattPhyChangedEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattReliableWriteCompletedEvent> get onReliableWriteCompleted {
    return _reliableWriteCompleted ??=
        BluetoothChannels.gattReliableWriteCompleted.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattReliableWriteCompletedEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattRemoteRssiReadEvent> get onRemoteRssiRead {
    return _remoteRssiRead ??= BluetoothChannels.gattRemoteRssiRead.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattRemoteRssiReadEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattDescriptorReadEvent> get onDescriptorRead {
    return _descriptorRead ??= BluetoothChannels.gattDescriptorRead.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattDescriptorReadEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothGattDescriptorWriteEvent> get onDescriptorWrite {
    return _descriptorWritten ??= BluetoothChannels.gattDescriptorWrite.receiveBroadcastStream().map((dynamic event) {
      return BluetoothGattDescriptorWriteEvent.fromMap(event as Map<Object?, Object?>);
    });
  }
}
