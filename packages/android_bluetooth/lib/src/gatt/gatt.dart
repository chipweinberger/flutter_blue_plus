import 'dart:typed_data';

import '../device/device.dart';
import 'gatt_api.dart';
import 'gatt_service.dart';
import 'gatt_events.dart';
import 'gatt_types.dart';

final class BluetoothGatt {
  const BluetoothGatt(this.address);

  final String address;

  Future<bool> close() async {
    return BluetoothGattApi.close(address);
  }

  Future<bool> disconnect() async {
    return BluetoothGattApi.disconnect(address);
  }

  Future<BluetoothDevice?> getDevice() async {
    return BluetoothGattApi.getDevice(address);
  }

  Future<List<BluetoothGattService>> getServices() async {
    return BluetoothGattApi.getServices(address);
  }

  Future<BluetoothGattService?> getService(String serviceUuid) async {
    return BluetoothGattApi.getService(address, serviceUuid);
  }

  Future<bool> discoverServices() async {
    return BluetoothGattApi.discoverServices(address);
  }

  Future<bool> requestMtu(int mtu) async {
    return BluetoothGattApi.requestMtu(address, mtu);
  }

  Future<bool> requestConnectionPriority(BluetoothGattConnectionPriority connectionPriority) async {
    return BluetoothGattApi.requestConnectionPriority(address, connectionPriority);
  }

  Future<bool> readPhy() async {
    return BluetoothGattApi.readPhy(address);
  }

  Future<bool> setPreferredPhy({
    required BluetoothGattPhy txPhy,
    required BluetoothGattPhy rxPhy,
    required int phyOptions,
  }) async {
    return BluetoothGattApi.setPreferredPhy(
      address,
      txPhy: txPhy,
      rxPhy: rxPhy,
      phyOptions: phyOptions,
    );
  }

  Future<bool> beginReliableWrite() async {
    return BluetoothGattApi.beginReliableWrite(address);
  }

  Future<bool> executeReliableWrite() async {
    return BluetoothGattApi.executeReliableWrite(address);
  }

  Future<bool> abortReliableWrite() async {
    return BluetoothGattApi.abortReliableWrite(address);
  }

  Future<bool> readRemoteRssi() async {
    return BluetoothGattApi.readRemoteRssi(address);
  }

  Future<bool> setCharacteristicNotification(
    BluetoothGattCharacteristicId characteristic,
    bool enabled,
  ) async {
    return BluetoothGattApi.setCharacteristicNotification(address, characteristic, enabled);
  }

  Future<bool> readCharacteristic(BluetoothGattCharacteristicId characteristic) async {
    return BluetoothGattApi.readCharacteristic(address, characteristic);
  }

  Future<bool> writeCharacteristic(
    BluetoothGattCharacteristicId characteristic, {
    Uint8List? value,
    bool withoutResponse = false,
    int? writeType,
  }) async {
    return BluetoothGattApi.writeCharacteristic(
      address,
      characteristic,
      value,
      withoutResponse: withoutResponse,
      writeType: writeType,
    );
  }

  Future<bool> readDescriptor(BluetoothGattDescriptorId descriptor) async {
    return BluetoothGattApi.readDescriptor(address, descriptor);
  }

  Future<bool> writeDescriptor(
    BluetoothGattDescriptorId descriptor, {
    Uint8List? value,
  }) async {
    return BluetoothGattApi.writeDescriptor(address, descriptor, value);
  }

  Future<BluetoothGattConnectionState> getConnectionState() async {
    return BluetoothGattApi.getConnectionState(address);
  }

  Stream<BluetoothGattConnectionStateChangedEvent> get onConnectionStateChanged {
    return BluetoothGattApi.onConnectionStateChanged.where((event) => event.address == address);
  }

  Stream<BluetoothGattCharacteristicChangedEvent> get onCharacteristicChanged {
    return BluetoothGattApi.onCharacteristicChanged.where((event) => event.address == address);
  }

  Stream<BluetoothGattCharacteristicReadEvent> get onCharacteristicRead {
    return BluetoothGattApi.onCharacteristicRead.where((event) => event.address == address);
  }

  Stream<BluetoothGattCharacteristicWriteEvent> get onCharacteristicWrite {
    return BluetoothGattApi.onCharacteristicWrite.where((event) => event.address == address);
  }

  Stream<BluetoothGattServicesDiscoveredEvent> get onServicesDiscovered {
    return BluetoothGattApi.onServicesDiscovered.where((event) => event.address == address);
  }

  Stream<BluetoothGattMtuChangedEvent> get onMtuChanged {
    return BluetoothGattApi.onMtuChanged.where((event) => event.address == address);
  }

  Stream<BluetoothGattPhyChangedEvent> get onPhyRead {
    return BluetoothGattApi.onPhyRead.where((event) => event.address == address);
  }

  Stream<BluetoothGattPhyChangedEvent> get onPhyUpdated {
    return BluetoothGattApi.onPhyUpdated.where((event) => event.address == address);
  }

  Stream<BluetoothGattReliableWriteCompletedEvent> get onReliableWriteCompleted {
    return BluetoothGattApi.onReliableWriteCompleted.where((event) => event.address == address);
  }

  Stream<BluetoothGattRemoteRssiReadEvent> get onRemoteRssiRead {
    return BluetoothGattApi.onRemoteRssiRead.where((event) => event.address == address);
  }

  Stream<BluetoothGattDescriptorReadEvent> get onDescriptorRead {
    return BluetoothGattApi.onDescriptorRead.where((event) => event.address == address);
  }

  Stream<BluetoothGattDescriptorWriteEvent> get onDescriptorWrite {
    return BluetoothGattApi.onDescriptorWrite.where((event) => event.address == address);
  }
}
