import 'package:flutter/services.dart';

final class BluetoothChannels {
  BluetoothChannels._();

  static const method = MethodChannel('android_bluetooth/methods');
  static const adapterStateChanged = EventChannel('android_bluetooth/adapter_state_changed');
  static const bondStateChanged = EventChannel('android_bluetooth/bond_state_changed');
  static const gattCharacteristicChanged = EventChannel('android_bluetooth/gatt_characteristic_changed');
  static const gattCharacteristicRead = EventChannel('android_bluetooth/gatt_characteristic_read');
  static const gattCharacteristicWrite = EventChannel('android_bluetooth/gatt_characteristic_write');
  static const gattConnectionStateChanged = EventChannel('android_bluetooth/gatt_connection_state_changed');
  static const gattDescriptorRead = EventChannel('android_bluetooth/gatt_descriptor_read');
  static const gattDescriptorWrite = EventChannel('android_bluetooth/gatt_descriptor_write');
  static const gattMtuChanged = EventChannel('android_bluetooth/gatt_mtu_changed');
  static const gattPhyRead = EventChannel('android_bluetooth/gatt_phy_read');
  static const gattPhyUpdate = EventChannel('android_bluetooth/gatt_phy_update');
  static const gattReliableWriteCompleted = EventChannel('android_bluetooth/gatt_reliable_write_completed');
  static const gattRemoteRssiRead = EventChannel('android_bluetooth/gatt_remote_rssi_read');
  static const gattServicesDiscovered = EventChannel('android_bluetooth/gatt_services_discovered');
  static const scanBatchResults = EventChannel('android_bluetooth/scan_batch_results');
  static const scanFailed = EventChannel('android_bluetooth/scan_failed');
  static const scanResults = EventChannel('android_bluetooth/scan_results');
}
