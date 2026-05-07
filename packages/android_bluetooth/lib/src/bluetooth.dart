import 'dart:typed_data';

import 'adapter/adapter.dart';
import 'adapter/adapter_api.dart';
import 'adapter/adapter_state.dart';
import 'adapter/permission_api.dart';
import 'device/device.dart';
import 'device/device_api.dart';
import 'device/device_types.dart';
import 'gatt/gatt_api.dart';
import 'gatt/gatt.dart';
import 'gatt/gatt_characteristic.dart';
import 'gatt/gatt_descriptor.dart';
import 'gatt/gatt_events.dart';
import 'gatt/gatt_service.dart';
import 'gatt/gatt_types.dart';
import 'manager/manager_api.dart';
import 'manager/manager.dart';
import 'scan/scan_api.dart';
import 'scan/scan_filter.dart';
import 'scan/le_scanner.dart';
import 'scan/scan_result.dart';
import 'scan/scan_settings.dart';
import 'scan/scan_types.dart';
import 'socket/server_socket.dart';
import 'socket/server_socket_api.dart';
import 'socket/socket.dart';
import 'socket/socket_api.dart';

final class Bluetooth {
  Bluetooth._();

  static Future<bool> isSupported() async {
    return BluetoothAdapterApi.isSupported();
  }

  static Future<bool> hasBluetoothConnectPermission() async {
    return BluetoothPermissionApi.hasBluetoothConnectPermission();
  }

  static Future<bool> hasBluetoothScanPermission() async {
    return BluetoothPermissionApi.hasBluetoothScanPermission();
  }

  static Future<bool> isEnabled() async {
    return BluetoothAdapterApi.isEnabled();
  }

  static Future<bool> enable() async {
    return BluetoothAdapterApi.enable();
  }

  static Future<bool> disable() async {
    return BluetoothAdapterApi.disable();
  }

  static Future<BluetoothAdapter?> getBluetoothAdapter() async {
    return (await BluetoothAdapterApi.isSupported()) ? BluetoothAdapter.instance : null;
  }

  static Future<String?> getAdapterName() async {
    return BluetoothAdapterApi.getAdapterName();
  }

  static Future<String?> getAdapterAddress() async {
    return BluetoothAdapterApi.getAdapterAddress();
  }

  static Future<bool> setAdapterName(String name) async {
    return BluetoothAdapterApi.setAdapterName(name);
  }

  static Future<BluetoothLeScanner?> getBluetoothLeScanner() async {
    return BluetoothAdapterApi.getBluetoothLeScanner();
  }

  static Future<bool> isOffloadedFilteringSupported() async {
    return BluetoothAdapterApi.isOffloadedFilteringSupported();
  }

  static Future<bool> isOffloadedScanBatchingSupported() async {
    return BluetoothAdapterApi.isOffloadedScanBatchingSupported();
  }

  static Future<bool> isLe2MPhySupported() async {
    return BluetoothAdapterApi.isLe2MPhySupported();
  }

  static Future<bool> isLeCodedPhySupported() async {
    return BluetoothAdapterApi.isLeCodedPhySupported();
  }

  static Future<BluetoothAdapterState> getAdapterState() async {
    return BluetoothAdapterApi.getAdapterState();
  }

  static Stream<BluetoothAdapterState> get onAdapterStateChanged {
    return BluetoothAdapterApi.onAdapterStateChanged;
  }

  static Future<bool> checkBluetoothAddress(String address) async {
    return BluetoothAdapterApi.checkBluetoothAddress(address);
  }

  static Future<List<BluetoothDevice>> getConnectedDevices() async {
    return BluetoothManagerApi.getConnectedDevices();
  }

  static Future<List<BluetoothDevice>> getDevicesMatchingConnectionStates(List<int> states) async {
    return BluetoothManagerApi.getDevicesMatchingConnectionStates(states);
  }

  static Future<BluetoothManager?> getBluetoothManager() async {
    return (await BluetoothAdapterApi.isSupported()) ? BluetoothManager.instance : null;
  }

  static Future<BluetoothGattConnectionState> getGattConnectionState(String address) async {
    return BluetoothGattApi.getConnectionState(address);
  }

  static BluetoothGatt getBluetoothGatt(String address) {
    return BluetoothGatt(address);
  }

  static Future<bool> connectGatt(
    String address, {
    bool autoConnect = false,
    BluetoothGattHandler? handler,
    int? transport,
    int? phy,
  }) async {
    return BluetoothGattApi.connect(
      address,
      autoConnect: autoConnect,
      handler: handler,
      transport: transport,
      phy: phy,
    );
  }

  static Future<bool> disconnectGatt(String address) async {
    return BluetoothGattApi.disconnect(address);
  }

  static Future<bool> closeGatt(String address) async {
    return BluetoothGattApi.close(address);
  }

  static Future<BluetoothDevice?> getGattDevice(String address) async {
    return BluetoothGattApi.getDevice(address);
  }

  static Future<List<BluetoothGattService>> getGattServices(String address) async {
    return BluetoothGattApi.getServices(address);
  }

  static Future<BluetoothGattService?> getGattService(String address, String serviceUuid) async {
    return BluetoothGattApi.getService(address, serviceUuid);
  }

  static Future<BluetoothGattCharacteristic?> getGattCharacteristic(
    String address, {
    required int serviceInstanceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    return BluetoothGattApi.getCharacteristic(
      address,
      serviceInstanceId: serviceInstanceId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
    );
  }

  static Future<BluetoothGattDescriptor?> getGattDescriptor(
    String address, {
    required int serviceInstanceId,
    required String serviceUuid,
    required int characteristicInstanceId,
    required String characteristicUuid,
    required String descriptorUuid,
  }) async {
    return BluetoothGattApi.getDescriptor(
      address,
      serviceInstanceId: serviceInstanceId,
      serviceUuid: serviceUuid,
      characteristicInstanceId: characteristicInstanceId,
      characteristicUuid: characteristicUuid,
      descriptorUuid: descriptorUuid,
    );
  }

  static Future<BluetoothGattService?> getGattCharacteristicService(
    String address, {
    required int serviceInstanceId,
    required String serviceUuid,
    required int characteristicInstanceId,
    required String characteristicUuid,
  }) async {
    return BluetoothGattApi.getCharacteristicService(
      address,
      serviceInstanceId: serviceInstanceId,
      serviceUuid: serviceUuid,
      characteristicInstanceId: characteristicInstanceId,
      characteristicUuid: characteristicUuid,
    );
  }

  static Future<BluetoothGattCharacteristic?> getGattDescriptorCharacteristic(
    String address, {
    required int serviceInstanceId,
    required String serviceUuid,
    required int characteristicInstanceId,
    required String characteristicUuid,
    required String descriptorUuid,
  }) async {
    return BluetoothGattApi.getDescriptorCharacteristic(
      address,
      serviceInstanceId: serviceInstanceId,
      serviceUuid: serviceUuid,
      characteristicInstanceId: characteristicInstanceId,
      characteristicUuid: characteristicUuid,
      descriptorUuid: descriptorUuid,
    );
  }

  static Future<bool> discoverGattServices(String address) async {
    return BluetoothGattApi.discoverServices(address);
  }

  static Future<bool> requestGattMtu(String address, int mtu) async {
    return BluetoothGattApi.requestMtu(address, mtu);
  }

  static Future<bool> requestGattConnectionPriority(
    String address,
    BluetoothGattConnectionPriority connectionPriority,
  ) async {
    return BluetoothGattApi.requestConnectionPriority(address, connectionPriority);
  }

  static Future<bool> readGattPhy(String address) async {
    return BluetoothGattApi.readPhy(address);
  }

  static Future<bool> setGattPreferredPhy(
    String address, {
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

  static Future<bool> beginGattReliableWrite(String address) async {
    return BluetoothGattApi.beginReliableWrite(address);
  }

  static Future<bool> executeGattReliableWrite(String address) async {
    return BluetoothGattApi.executeReliableWrite(address);
  }

  static Future<bool> abortGattReliableWrite(String address) async {
    return BluetoothGattApi.abortReliableWrite(address);
  }

  static Future<bool> readGattRemoteRssi(String address) async {
    return BluetoothGattApi.readRemoteRssi(address);
  }

  static Future<bool> setGattCharacteristicNotification(
    String address,
    BluetoothGattCharacteristicId characteristic,
    bool enabled,
  ) async {
    return BluetoothGattApi.setCharacteristicNotification(address, characteristic, enabled);
  }

  static Future<bool> readGattCharacteristic(
    String address,
    BluetoothGattCharacteristicId characteristic,
  ) async {
    return BluetoothGattApi.readCharacteristic(address, characteristic);
  }

  static Future<bool> setGattCharacteristicWriteType(
    String address,
    BluetoothGattCharacteristicId characteristic,
    int writeType,
  ) async {
    return BluetoothGattApi.setCharacteristicWriteType(address, characteristic, writeType);
  }

  static Future<bool> setGattCharacteristicValue(
    String address,
    BluetoothGattCharacteristicId characteristic,
    Uint8List value,
  ) async {
    return BluetoothGattApi.setCharacteristicValue(address, characteristic, value);
  }

  static Future<bool> writeGattCharacteristic(
    String address,
    BluetoothGattCharacteristicId characteristic,
    Uint8List value, {
    bool withoutResponse = false,
  }) async {
    return BluetoothGattApi.writeCharacteristic(
      address,
      characteristic,
      value,
      withoutResponse: withoutResponse,
    );
  }

  static Future<bool> readGattDescriptor(
    String address,
    BluetoothGattDescriptorId descriptor,
  ) async {
    return BluetoothGattApi.readDescriptor(address, descriptor);
  }

  static Future<bool> setGattDescriptorValue(
    String address,
    BluetoothGattDescriptorId descriptor,
    Uint8List value,
  ) async {
    return BluetoothGattApi.setDescriptorValue(address, descriptor, value);
  }

  static Future<bool> writeGattDescriptor(
    String address,
    BluetoothGattDescriptorId descriptor,
    Uint8List value,
  ) async {
    return BluetoothGattApi.writeDescriptor(address, descriptor, value);
  }

  static Future<BluetoothDevice?> getRemoteLeDevice(
    String address,
    BluetoothAddressType addressType,
  ) async {
    return BluetoothAdapterApi.getRemoteLeDevice(address, addressType);
  }

  static Future<BluetoothBondState> getBondState(String address) async {
    return BluetoothDeviceApi.getBondState(address);
  }

  static Future<String?> getAddress(String address) async {
    return BluetoothDeviceApi.getAddress(address);
  }

  static Future<bool> createBond(String address) async {
    return BluetoothDeviceApi.createBond(address);
  }

  static Future<bool> setPin(String address, Uint8List pin) async {
    return BluetoothDeviceApi.setPin(address, pin);
  }

  static Future<bool> setPairingConfirmation(String address, bool confirm) async {
    return BluetoothDeviceApi.setPairingConfirmation(address, confirm);
  }

  static Future<BluetoothSocket?> createL2capChannel(String address, int psm) async {
    return BluetoothSocketApi.createL2capChannel(
      address,
      psm,
      insecure: false,
    );
  }

  static Future<BluetoothSocket?> createInsecureL2capChannel(String address, int psm) async {
    return BluetoothSocketApi.createL2capChannel(
      address,
      psm,
      insecure: true,
    );
  }

  static Future<BluetoothServerSocket?> listenUsingL2capChannel() async {
    return BluetoothServerSocketApi.listenUsingL2capChannel(insecure: false);
  }

  static Future<BluetoothServerSocket?> listenUsingInsecureL2capChannel() async {
    return BluetoothServerSocketApi.listenUsingL2capChannel(insecure: true);
  }

  static Future<String?> getName(String address) async {
    return BluetoothDeviceApi.getName(address);
  }

  static Future<BluetoothDeviceType> getDeviceType(String address) async {
    return BluetoothDeviceApi.getDeviceType(address);
  }

  static Stream<BluetoothBondStateChangedEvent> get onBondStateChanged {
    return BluetoothDeviceApi.onBondStateChanged;
  }

  static Future<List<String>> getUuids(String address) async {
    return BluetoothDeviceApi.getUuids(address);
  }

  static Future<bool> removeBond(String address) async {
    return BluetoothDeviceApi.removeBond(address);
  }

  static Stream<BluetoothGattConnectionStateChangedEvent> get onGattConnectionStateChanged {
    return BluetoothGattApi.onConnectionStateChanged;
  }

  static Stream<BluetoothGattCharacteristicChangedEvent> get onGattCharacteristicChanged {
    return BluetoothGattApi.onCharacteristicChanged;
  }

  static Stream<BluetoothGattCharacteristicReadEvent> get onGattCharacteristicRead {
    return BluetoothGattApi.onCharacteristicRead;
  }

  static Stream<BluetoothGattCharacteristicWriteEvent> get onGattCharacteristicWrite {
    return BluetoothGattApi.onCharacteristicWrite;
  }

  static Stream<BluetoothGattServicesDiscoveredEvent> get onGattServicesDiscovered {
    return BluetoothGattApi.onServicesDiscovered;
  }

  static Stream<BluetoothGattMtuChangedEvent> get onGattMtuChanged {
    return BluetoothGattApi.onMtuChanged;
  }

  static Stream<BluetoothGattPhyChangedEvent> get onGattPhyRead {
    return BluetoothGattApi.onPhyRead;
  }

  static Stream<BluetoothGattPhyChangedEvent> get onGattPhyUpdated {
    return BluetoothGattApi.onPhyUpdated;
  }

  static Stream<BluetoothGattReliableWriteCompletedEvent> get onGattReliableWriteCompleted {
    return BluetoothGattApi.onReliableWriteCompleted;
  }

  static Stream<BluetoothGattRemoteRssiReadEvent> get onGattRemoteRssiRead {
    return BluetoothGattApi.onRemoteRssiRead;
  }

  static Stream<BluetoothGattDescriptorReadEvent> get onGattDescriptorRead {
    return BluetoothGattApi.onDescriptorRead;
  }

  static Stream<BluetoothGattDescriptorWriteEvent> get onGattDescriptorWrite {
    return BluetoothGattApi.onDescriptorWrite;
  }

  static Future<bool> startScan({
    List<BluetoothScanFilter> filters = const [],
    BluetoothScanSettings settings = const BluetoothScanSettings(),
  }) async {
    return BluetoothScanApi.startScan(
      filters: filters,
      settings: settings,
    );
  }

  static Future<bool> stopScan() async {
    return BluetoothScanApi.stopScan();
  }

  static Future<bool> flushPendingScanResults() async {
    return BluetoothScanApi.flushPendingScanResults();
  }

  static Future<bool> isScanning() async {
    return BluetoothScanApi.isScanning();
  }

  static Stream<BluetoothScanResult> get onScanResult {
    return BluetoothScanApi.onScanResult;
  }

  static Stream<BluetoothScanBatchResultsEvent> get onBatchScanResults {
    return BluetoothScanApi.onBatchScanResults;
  }

  static Stream<BluetoothScanFailedEvent> get onScanFailed {
    return BluetoothScanApi.onScanFailed;
  }
}
