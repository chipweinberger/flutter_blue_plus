# core_bluetooth

A clean Dart wrapper around Apple's CoreBluetooth framework for iOS and macOS.

Both central mode and peripheral mode are supported.

## Status

✅ Fully implemented.

Apple CoreBluetooth symbol names are the primary public API. Helper wrapper
types exist where Dart needs them, but they intentionally do not use the `CB`
prefix.

## Example

The package includes a working example app:

```sh
cd ./example
flutter run
```

## Usage - Central Mode

For connecting to devices.

### Initialize Central Manager

Use the shared app-wide manager:

```dart
final central = CBCentralManager.shared;
```

Or configure the shared manager before first use:

```dart
CBCentralManager.ensureShared(
  options: const CentralManagerOptions(
    showPowerAlert: true,
    restoreIdentifier: "my_restore_id",
  ),
);

final central = CBCentralManager.shared;
```

Or create an isolated manager:

```dart
final central = CBCentralManager.createIsolated(
  options: const CentralManagerOptions(
    showPowerAlert: true,
    restoreIdentifier: "my_restore_id",
  ),
);
```

### Bluetooth On & Off

```dart
final central = CBCentralManager.shared;

final subscription = central.onDidUpdateState.listen((state) {
  print(state);
  if (state == CBManagerState.poweredOn) {
    // start scanning, connecting, etc
  }
});
```

### Scan for Devices

```dart
final subscription = central.onDidDiscoverPeripheral.listen((result) {
  print(result.peripheral.identifier.uuidString);
  print(result.advertisementData.localName);
  print(result.rssi);
});

await central.scanForPeripherals(
  withServices: [CBUUID("180D")],
  options: const CentralManagerScanOptions(
    allowDuplicates: true,
  ),
);

await central.stopScan();
```

### Connect to a Device

```dart
await central.connect(peripheral);
```

```dart
await central.cancelPeripheralConnection(peripheral);
```

### Discover Services

```dart
final subscription = peripheral.onDidDiscoverServices.listen((result) {
  print(result.services);
});

await peripheral.discoverServices();
```

### Iterate Services & Characteristics

```dart
for (final service in peripheral.services ?? const <CBService>[]) {
  print('service: ${service.uuid.uuidString}');

  for (final characteristic in service.characteristics ?? const <CBCharacteristic>[]) {
    print('  characteristic: ${characteristic.uuid.uuidString}');

    for (final descriptor in characteristic.descriptors ?? const <CBDescriptor>[]) {
      print('    descriptor: ${descriptor.uuid.uuidString}');
    }
  }
}
```

### Read, Write, and Notify

```dart
await peripheral.readValue(characteristic);

await peripheral.writeValue(
  Uint8List.fromList([0x01, 0x02]),
  forAttribute: characteristic,
  type: CBCharacteristicWriteType.withResponse,
);

await peripheral.setNotifyValue(true, characteristic);

final subscription = peripheral.onDidUpdateValueForCharacteristic.listen((result) {
  print(result.characteristic.value);
});
```

### L2CAP

```dart
final subscription = peripheral.onDidOpenL2CAPChannel.listen((result) async {
  final channel = result.channel;
  if (channel == null) {
    return;
  }

  final incoming = await channel.inputStream.read();
  print(incoming);

  await channel.outputStream.write(Uint8List.fromList([0x01, 0x02]));
});

await peripheral.openL2CAPChannel(1234);
```

## Usage - Peripheral Mode

For advertising yourself as a device.

### Initialize Peripheral Manager

Use the shared app-wide manager:

```dart
final peripheralManager = CBPeripheralManager.shared;
```

Or configure the shared manager before first use:

```dart
CBPeripheralManager.ensureShared(
  options: const PeripheralManagerOptions(
    showPowerAlert: true,
    restoreIdentifier: "my_restore_id",
  ),
);

final peripheralManager = CBPeripheralManager.shared;
```

Or create an isolated manager:

```dart
final peripheralManager = CBPeripheralManager.createIsolated(
  options: const PeripheralManagerOptions(
    showPowerAlert: true,
    restoreIdentifier: "my_restore_id",
  ),
);
```

### Start Advertising

```dart
final peripheralManager = CBPeripheralManager.shared;

final service = CBMutableService.type(
  type: CBUUID("1234"),
  primary: true,
);

final characteristic = CBMutableCharacteristic.type(
  type: CBUUID("ABCD"),
  properties: const CBCharacteristicProperties(
    CBCharacteristicProperties.read.rawValue | CBCharacteristicProperties.notify.rawValue,
  ),
  value: null,
  permissions: CBAttributePermissions.readable,
);

service.characteristics = [characteristic];

await peripheralManager.add(service);

await peripheralManager.startAdvertising(
  const PeripheralManagerAdvertisingData(
    localName: "core_bluetooth",
    serviceUUIDs: [CBUUID("1234")],
  ),
);
```

### Peripheral Read / Write Requests

```dart
final readSubscription = peripheralManager.onDidReceiveReadRequest.listen((result) async {
  final request = result.request;

  request.value = Uint8List.fromList([0x01, 0x02, 0x03]);

  await peripheralManager.respond(
    to: request,
    withResult: CBATTErrorCode.success,
  );
});

final writeSubscription = peripheralManager.onDidReceiveWriteRequests.listen((result) async {
  for (final request in result.requests) {
    print(request.value);
  }
});
```

### Update Subscribed Centrals

```dart
final didSend = await peripheralManager.updateValue(
  Uint8List.fromList([0x10, 0x20]),
  forCharacteristic: characteristic,
  onSubscribedCentrals: null,
);

print(didSend);
```

### Peripheral L2CAP

```dart
final publishSubscription = peripheralManager.onDidPublishL2CAPChannel.listen((result) {
  print(result.psm);
});

final openSubscription = peripheralManager.onDidOpenL2CAPChannel.listen((result) async {
  final channel = result.channel;
  if (channel == null) {
    return;
  }

  await channel.outputStream.write(Uint8List.fromList([0x10, 0x20]));
});

await peripheralManager.publishL2CAPChannel(withEncryption: false);
```

## Contract

Below is the CoreBluetooth API map we should treat as the contract.

Legend:

- `✅` fully implemented

## Top-Level Framework

- `✅` `CBManager`
- `✅` `CBPeer`
- `✅` `CBUUID`
- `✅` `CBError`
- `✅` `CBATTRequest`
- `✅` `CBL2CAPChannel`
- `✅` `CBL2CAPPSM`

## Central Role

- `✅` `CBCentralManager`
- `✅` `CBCentralManagerDelegate`
- `✅` `CBCentral`
- `✅` `CBConnectionEvent`

### `CBCentralManager`

- `✅` `shared`
- `✅` `ensureShared(options: ...)`
- `✅` `createIsolated()`
- `✅` `var delegate`
- `✅` `var isScanning`
- `✅` `class func supports(_ feature: CBCentralManager.Feature) -> Bool`
- `✅` `struct CBCentralManager.Feature`
- `✅` `func scanForPeripherals(withServices:options:)`
- `✅` `func stopScan()`
- `✅` `func retrievePeripherals(withIdentifiers:)`
- `✅` `func retrieveConnectedPeripherals(withServices:)`
- `✅` `func connect(_:options:)`
- `✅` `func cancelPeripheralConnection(_:)`
- `✅` `func registerForConnectionEvents(options:)`
- `✅` `class var authorization`
- `✅` inherited from `CBManager`: `var state`

### `CBCentralManagerDelegate`

- `✅` `centralManagerDidUpdateState(_:)`
- `✅` `centralManager(_:willRestoreState:)`
- `✅` `centralManager(_:didDiscover:advertisementData:rssi:)`
- `✅` `centralManager(_:didConnect:)`
- `✅` `centralManager(_:didFailToConnect:error:)`
- `✅` `centralManager(_:didDisconnectPeripheral:error:)`
- `✅` `centralManager(_:didDisconnectPeripheral:timestamp:isReconnecting:error:)`
- `✅` `centralManager(_:connectionEventDidOccur:for:)`
- `✅` `centralManager(_:didUpdateANCSAuthorizationFor:)`

### `CBCentral`

- `✅` inherits `CBPeer`
- `✅` `var maximumUpdateValueLength`

## Peripheral Role

- `✅` `CBPeripheral`
- `✅` `CBPeripheralDelegate`
- `✅` `CBPeripheralManager`
- `✅` `CBPeripheralManagerDelegate`

### `CBPeripheral`

- `✅` `var delegate`
- `✅` `var name`
- `✅` `var identifier`
- `✅` `var state`
- `✅` `var services`
- `✅` `var ancsAuthorized`
- `✅` `var canSendWriteWithoutResponse`
- `✅` `func readRSSI()`
- `✅` `func discoverServices(_:)`
- `✅` `func discoverIncludedServices(_:for:)`
- `✅` `func discoverCharacteristics(_:for:)`
- `✅` `func discoverDescriptors(for:)`
- `✅` `func readValue(for: CBCharacteristic)`
- `✅` `func readValue(for: CBDescriptor)`
- `✅` `func writeValue(_:for: CBCharacteristic,type:)`
- `✅` `func writeValue(_:for: CBDescriptor)`
- `✅` `func setNotifyValue(_:for:)`
- `✅` `func maximumWriteValueLength(for:)`
- `✅` `func openL2CAPChannel(_:)`

### `CBPeripheralDelegate`

- `✅` `peripheralDidUpdateName(_:)`
- `✅` `peripheral(_:didModifyServices:)`
- `✅` `peripheral(_:didReadRSSI:error:)`
- `✅` `peripheral(_:didDiscoverServices:)`
- `✅` `peripheral(_:didDiscoverIncludedServicesFor:error:)`
- `✅` `peripheral(_:didDiscoverCharacteristicsFor:error:)`
- `✅` `peripheral(_:didDiscoverDescriptorsFor:error:)`
- `✅` `peripheral(_:didUpdateValueFor:error:)` for `CBCharacteristic`
- `✅` `peripheral(_:didUpdateValueFor:error:)` for `CBDescriptor`
- `✅` `peripheral(_:didWriteValueFor:error:)` for `CBCharacteristic`
- `✅` `peripheral(_:didWriteValueFor:error:)` for `CBDescriptor`
- `✅` `peripheral(_:didUpdateNotificationStateFor:error:)`
- `✅` `peripheralIsReady(toSendWriteWithoutResponse:)`
- `✅` `peripheral(_:didOpen:error:)`

### `CBPeripheralManager`

- `✅` `shared`
- `✅` `ensureShared(options: ...)`
- `✅` `createIsolated()`
- `✅` `init()`
- `✅` `init(delegate:queue:)`
- `✅` `init(delegate:queue:options:)`
- `✅` `var delegate`
- `✅` `var isAdvertising`
- `✅` `func add(_:)`
- `✅` `func remove(_:)`
- `✅` `func removeAllServices()`
- `✅` `func startAdvertising(_:)`
- `✅` `func stopAdvertising()`
- `✅` `func updateValue(_:for:onSubscribedCentrals:) -> Bool`
- `✅` `func respond(to:withResult:)`
- `✅` `func setDesiredConnectionLatency(_:for:)`
- `✅` `func publishL2CAPChannel(withEncryption:)`
- `✅` `func unpublishL2CAPChannel(_:)`
- `✅` `class var authorization`
- `✅` inherited from `CBManager`: `var state`

### `CBPeripheralManagerDelegate`

- `✅` `peripheralManagerDidUpdateState(_:)`
- `✅` `peripheralManager(_:willRestoreState:)`
- `✅` `peripheralManagerDidStartAdvertising(_:error:)`
- `✅` `peripheralManager(_:didAdd:error:)`
- `✅` `peripheralManager(_:central:didSubscribeTo:)`
- `✅` `peripheralManager(_:central:didUnsubscribeFrom:)`
- `✅` `peripheralManagerIsReady(toUpdateSubscribers:)`
- `✅` `peripheralManager(_:didReceiveRead:)`
- `✅` `peripheralManager(_:didReceiveWrite:)`
- `✅` `peripheralManager(_:didPublishL2CAPChannel:error:)`
- `✅` `peripheralManager(_:didUnpublishL2CAPChannel:error:)`
- `✅` `peripheralManager(_:didOpen:error:)`

## GATT Model Types

- `✅` `CBAttribute`
- `✅` `CBService`
- `✅` `CBMutableService`
- `✅` `CBCharacteristic`
- `✅` `CBMutableCharacteristic`
- `✅` `CBDescriptor`
- `✅` `CBMutableDescriptor`

### `CBAttribute`

- `✅` `var uuid`

### `CBService`

- `✅` `var peripheral`
- `✅` `var isPrimary`
- `✅` `var includedServices`
- `✅` `var characteristics`

### `CBMutableService`

- `✅` writable versions of service properties

### `CBCharacteristic`

- `✅` `var service`
- `✅` `var value`
- `✅` `var descriptors`
- `✅` `var properties`
- `✅` `var isNotifying`
- `✅` `var isBroadcasted`

### `CBMutableCharacteristic`

- `✅` `init(type:properties:value:permissions:)`

### `CBDescriptor`

- `✅` `var characteristic`
- `✅` `var value`

### `CBMutableDescriptor`

- `✅` `init(type:value:)`

## Supporting Enums / Option Sets / Constants

- `✅` `CBManagerState`
- `✅` `CBManagerAuthorization`
- `✅` `CBPeripheralState`
- `✅` `CBCharacteristicWriteType`
- `✅` `CBCentralManager.Feature`
- `✅` `CBCharacteristicProperties`
- `✅` `CBAttributePermissions`
- `✅` `CBPeripheralManagerConnectionLatency`
- `✅` `CBATTError.Code`
- `✅` advertisement-data keys
- `✅` peripheral-scanning option keys
- `✅` peripheral-connection option keys
- `✅` peripheral-manager initialization option keys
- `✅` peripheral-manager restoration keys
- `✅` central-manager restoration keys
- `✅` connection-event matching option keys
