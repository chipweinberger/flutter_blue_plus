# android_bluetooth

A thin Dart wrapper around the Android BLE central / GATT client / L2CAP
surface used by `flutter_blue_plus`.

## Scope

This package is intentionally focused on Android APIs that a normal BLE central
app may reasonably need:

- BLE adapter/device access
- GATT client access
- LE scanning
- L2CAP client/server socket access

It is not trying to mirror the entire Android Bluetooth framework.

## Out of Scope

These are intentionally excluded from the package contract:

- BLE peripheral mode
  - `BluetoothLeAdvertiser`
  - `Advertise*`
  - `AdvertisingSet*`
  - `PeriodicAdvertisingParameters*`
  - `TransportBlock`
  - `TransportDiscoveryData`
  - `BluetoothGattServer`
  - `BluetoothGattServerCallback`
- profile/audio/health/HID families
- classic discovery and RFCOMM-specific APIs
- broad Android Bluetooth metadata families

## In Scope

- `BluetoothManager`
- `BluetoothAdapter` (BLE-central subset)
- `BluetoothDevice` (BLE / GATT / L2CAP subset)
- `BluetoothGatt`
- `BluetoothGattCallback`
- `BluetoothGattService`
- `BluetoothGattCharacteristic`
- `BluetoothGattDescriptor`
- `BluetoothLeScanner`
- `ScanCallback`
- `ScanResult`
- `ScanRecord`
- `ScanFilter`
- `ScanFilter.Builder`
- `ScanSettings`
- `ScanSettings.Builder`
- `BluetoothSocket`
- `BluetoothServerSocket`
- `BluetoothSocketException`

## `BluetoothManager`

- `✅` `getAdapter()`
- `✅` GATT-connected device queries used by this package

## `BluetoothAdapter`

Curated BLE-central subset.

- `✅` `isEnabled()`
- `✅` `getState()`
- `✅` `getName()`
- `✅` `setName(String name)`
- `✅` `getAddress()`
- `✅` `getRemoteLeDevice(String address, int addressType)`
- `✅` `getBluetoothLeScanner()`
- `✅` `isOffloadedFilteringSupported()`
- `✅` `isOffloadedScanBatchingSupported()`
- `✅` `isLe2MPhySupported()`
- `✅` `isLeCodedPhySupported()`
- `✅` `enable()`
- `✅` `disable()`
- `✅` `listenUsingL2capChannel()`
- `✅` `listenUsingInsecureL2capChannel()`
- `✅` `checkBluetoothAddress(String address)`

## `BluetoothDevice`

Curated BLE / GATT / L2CAP subset.

- `✅` `getAddress()`
- `✅` `getName()`
- `✅` `getType()`
- `✅` `getBondState()`
- `✅` `getUuids()`
- `✅` `createBond()`
- `✅` `removeBond()`
- `✅` `connectGatt(Context context, boolean autoConnect, BluetoothGattCallback callback)`
- `✅` `connectGatt(Context context, boolean autoConnect, BluetoothGattCallback callback, int transport)`
- `✅` `connectGatt(Context context, boolean autoConnect, BluetoothGattCallback callback, int transport, int phy)`
- `✅` `connectGatt(Context context, boolean autoConnect, BluetoothGattCallback callback, int transport, int phy, Handler handler)`
- `✅` `setPin(byte[] pin)`
- `✅` `setPairingConfirmation(boolean confirm)`
- `✅` `createL2capChannel(int psm)`
- `✅` `createInsecureL2capChannel(int psm)`

## `BluetoothGatt`

- `✅` `discoverServices()`
- `✅` `getServices()`
- `✅` `disconnect()`
- `✅` `close()`
- `✅` `readCharacteristic(BluetoothGattCharacteristic characteristic)`
- `✅` `writeCharacteristic(BluetoothGattCharacteristic characteristic)`
- `✅` `readDescriptor(BluetoothGattDescriptor descriptor)`
- `✅` `writeDescriptor(BluetoothGattDescriptor descriptor)`
- `✅` `setCharacteristicNotification(BluetoothGattCharacteristic characteristic, boolean enable)`
- `✅` `readRemoteRssi()`
- `✅` `requestMtu(int mtu)`
- `✅` `requestConnectionPriority(int connectionPriority)`
- `✅` `readPhy()`
- `✅` `setPreferredPhy(int txPhy, int rxPhy, int phyOptions)`
- `✅` `beginReliableWrite()`
- `✅` `executeReliableWrite()`
- `✅` `abortReliableWrite()`

## `BluetoothGattCallback`

- `✅` `onConnectionStateChange(BluetoothGatt gatt, int status, int newState)`
- `✅` `onServicesDiscovered(BluetoothGatt gatt, int status)`
- `✅` `onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)`
- `✅` `onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)`
- `✅` `onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic)`
- `✅` `onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)`
- `✅` `onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)`
- `✅` `onReliableWriteCompleted(BluetoothGatt gatt, int status)`
- `✅` `onReadRemoteRssi(BluetoothGatt gatt, int rssi, int status)`
- `✅` `onMtuChanged(BluetoothGatt gatt, int mtu, int status)`
- `✅` `onPhyRead(BluetoothGatt gatt, int txPhy, int rxPhy, int status)`
- `✅` `onPhyUpdate(BluetoothGatt gatt, int txPhy, int rxPhy, int status)`

## `BluetoothGattService`

- `✅` `getUuid()`
- `✅` `getInstanceId()`
- `✅` `getType()`
- `✅` `getCharacteristics()`
- `✅` `getCharacteristic(UUID uuid)`

## `BluetoothGattCharacteristic`

- `✅` `getUuid()`
- `✅` `getInstanceId()`
- `✅` `getProperties()`
- `✅` `getPermissions()`
- `✅` `getWriteType()`
- `✅` `setWriteType(int writeType)`
- `✅` `getValue()`
- `✅` `setValue(byte[] value)`
- `✅` `getService()`
- `✅` `getDescriptors()`
- `✅` `getDescriptor(UUID uuid)`

## `BluetoothGattDescriptor`

- `✅` `getUuid()`
- `✅` `getPermissions()`
- `✅` `getValue()`
- `✅` `setValue(byte[] value)`
- `✅` `getCharacteristic()`

## `BluetoothLeScanner`

- `✅` `startScan(ScanCallback callback)`
- `✅` `startScan(List<ScanFilter> filters, ScanSettings settings, ScanCallback callback)`
- `✅` `stopScan(ScanCallback callback)`
- `✅` `flushPendingScanResults(ScanCallback callback)`

## `ScanCallback`

- `✅` `onScanResult(int callbackType, ScanResult result)`
- `✅` `onBatchScanResults(List<ScanResult> results)`
- `✅` `onScanFailed(int errorCode)`

## `ScanResult`

- `✅` `getDevice()`
- `✅` `getRssi()`
- `✅` `getScanRecord()`
- `✅` `getTimestampNanos()`
- `✅` `getCallbackType()`
- `✅` `isConnectable()`
- `✅` `isLegacy()`
- `✅` `getPrimaryPhy()`
- `✅` `getSecondaryPhy()`
- `✅` `getAdvertisingSid()`
- `✅` `getTxPower()`
- `✅` `getPeriodicAdvertisingInterval()`

## `ScanRecord`

- `✅` `getAdvertiseFlags()`
- `✅` `getTxPowerLevel()`
- `✅` `getDeviceName()`
- `✅` `getBytes()`
- `✅` `getManufacturerSpecificData()`
- `✅` `getServiceData()`
- `✅` `getServiceUuids()`
- `✅` `getServiceSolicitationUuids()`
- `✅` `getAppearance()`
- `✅` `getAdvertisingDataMap()`

## `ScanFilter`

- `✅` builder-configurable filter surface tracked by this package

## `ScanFilter.Builder`

- `✅` tracked builder surface used by this package

## `ScanSettings`

- `✅` builder-configurable scan-settings surface tracked by this package

## `ScanSettings.Builder`

- `✅` tracked builder surface used by this package

## `BluetoothSocket`

L2CAP-focused use is in scope.

- `✅` `connect()`
- `✅` `close()`
- `✅` `isConnected()`
- `✅` `getConnectionType()`
- `✅` `getMaxReceivePacketSize()`
- `✅` `getMaxTransmitPacketSize()`
- `✅` `getInputStream()`
- `✅` `getOutputStream()`
- `✅` `getRemoteDevice()`

## `BluetoothServerSocket`

L2CAP-focused use is in scope.

- `✅` `accept()`
- `✅` `accept(int timeout)`
- `✅` `close()`
- `✅` `getPsm()`

## `BluetoothSocketException`

- `✅` `BluetoothSocketException(int errorCode, String message)`
- `✅` `BluetoothSocketException(int errorCode)`
- `✅` `getErrorCode()`
- `✅` error-code constants
