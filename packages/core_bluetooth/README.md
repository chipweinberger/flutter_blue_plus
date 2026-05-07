# core_bluetooth

A clean Dart wrapper around Apple's CoreBluetooth framework for iOS and macOS.

Both central mode and peripheral mode are supported.

## Status

✅ Fully implemented.

Apple CoreBluetooth symbol names are the primary public API. Helper wrapper
types exist where Dart needs them, but they intentionally do not use the `CB`
prefix.

`UUID` and `CBUUID` reject non-hexadecimal strings with `FormatException` in Dart,
before native calls. Valid uppercase, lowercase, short Bluetooth UUIDs and full
UUIDs keep their existing normalization and equality behavior.
`UUID.fromBytes` requires all 16 integers to be in 0–255 and throws `RangeError`
for an out-of-range value.

`CBUUID.data` returns an independent `Uint8List` copy. Editing that buffer does
not change the UUID's bytes, string, equality or hash.

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

When used with FlutterBluePlus, initialize FBP first. Its Darwin backend exposes
this same shared manager through `FlutterBluePlusDarwin.centralManager` and
tracked peripherals through `FlutterBluePlusDarwin.getPeripheral(remoteId)`.
Native streams can have additional listeners; coordinate GATT requests and
connection lifetime with FBP. See [FBP compatibility](docs/flutter_blue_plus_compatibility.md).

Or create an isolated manager:

```dart
final central = CBCentralManager.createIsolated(
  options: const CentralManagerOptions(
    showPowerAlert: true,
    restoreIdentifier: "my_restore_id",
  ),
);
```

Await `central.dispose()` when finished with an isolated manager. Operations on a
disposed manager, including those waiting for initialization, fail with `StateError`.
Delayed scan or retrieval replies cannot restore state on a disposed manager.
The same disposal guard applies to its `CBPeripheral` objects: discovery, GATT,
RSSI and L2CAP-open requests cannot be submitted after disposal starts. In-flight
write-limit and write-readiness queries fail with `StateError` if disposal starts
before their reply, without updating cached readiness.

Exceptions from buffered startup delegate callbacks use the same zone error
reporting as later delegate callbacks. Successful native creation still completes
`ready`, and the manager remains owned and usable until `dispose()` releases it.

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

After `scanForPeripherals` completes, `isScanning` reflects native scanning activity.
A scan request made while Bluetooth is unavailable does not mark the manager as
scanning. Older scan/stop replies cannot overwrite newer operations or power-off.

To reduce platform-channel traffic, optionally sample discoveries natively:

```dart
await central.scanForPeripherals(
  options: const CentralManagerScanOptions(allowDuplicates: true),
  advertisementDivisor: 3,
);
```

This package extension delivers the first native discovery per device, then every
third discovery, before creating channel payloads. Apple service filtering and
duplicate-scanning options remain unchanged. The default divisor is 1; valid values
are 1–2147483647. Each manager owns its counters, reset on every scan submission.
All discoveries received from Apple count, including those rejected later by an
application's Dart filters. A first matching advertisement is therefore not
guaranteed when the divisor is greater than 1. This package exposes no custom name,
manufacturer-data or other software scan filters.

`AdvertisementData` exposes `serviceUUIDs`, `overflowServiceUUIDs` and
`solicitedServiceUUIDs` separately. Optional UUID lists are `null` when absent
from the native advertisement and empty when explicitly reported as empty.

### Connect to a Device

```dart
await central.connect(peripheral);
```

```dart
await central.cancelPeripheralConnection(peripheral);
```

### Discover Services

Discovery collections preserve native `nil` as Dart `null`, including services,
included services, characteristics and descriptors. An empty list remains empty;
it is distinct from a collection that has not been discovered or is unavailable
after a native error. Snapshots with explicit `null` clear the corresponding cache,
while omitted fields leave previously received values unchanged.

Service, characteristic and descriptor handles are opaque identifiers. They stay
stable while their native object is alive; replacement objects receive new handles
even if the allocator reuses a memory address. Do not parse handles or use them as
native pointers. Identity lookup does not keep retired native objects alive.

A disconnect, or an adapter transition away from powered-on, clears the peripheral's GATT cache: `services` becomes `null`, cached
notification flags become false and old native attribute handles are rejected.
Rediscover services after reconnecting. The `CBPeripheral` object keeps its identity
across those connections; retained service/characteristic/descriptor objects belong
to the connection in which they were discovered.

Adapter-state callbacks observe peripherals as disconnected and scanning stopped.
Below `poweredOff`, native peripheral objects are invalid; retrieve or discover the
peripheral again after recovery before using its Dart wrapper.

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

  try {
    final incoming = await channel.inputStream.read();
    print(incoming);
    await channel.outputStream.write(Uint8List.fromList([0x01, 0x02]));
  } finally {
    await channel.inputStream.close();
    await channel.outputStream.close();
  }
});

await peripheral.openL2CAPChannel(1234);
```

Use the PSM supplied by the peer. Opening or unpublishing a channel requires a
whole integer in the native 16-bit range `0..65535`; invalid values fail with
`invalid_args` before calling CoreBluetooth.

Read results cross the platform channel as compact byte data. The returned
`Uint8List` remains an independent buffer with a zero byte offset.
`maxLength` is an upper bound: each native read uses at most 64 KiB of scratch
space and may return fewer bytes. Larger requests, including the maximum Dart
integer, return partial chunks without allocating the entire requested size.
Read again to consume remaining data; reads do not preserve message boundaries.

Close both streams when finished to release the native channel. Closing one stream
leaves the other usable. Disposing the final owning central or peripheral manager
also closes both streams and releases the channel. Further operations on a released
channel report the existing `invalid_args` platform error.

Each stream processes I/O in order on its own background run loop. For a positive
read size, empty bytes mean clean EOF. Read failures throw `PlatformException`
with code `stream_error`, a native message, and NSError `domain`/`code` in
`details` when available. Closing a stream cancels operations waiting for data or
space with `stream_closed`; the close future waits for native cleanup. Reads and
writes remain independent, and writes return the native byte count, which can be
partial or -1 on failure.

## Usage - Peripheral Mode

Power-off or reset clears the manager's published `services`; explicitly add them
again after the manager returns to `poweredOn`. Leaving `poweredOn` also clears
cached subscriptions and retires unanswered native ATT requests. These changes
take effect before the adapter-state callback, without synthetic unsubscribe events.

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

Local services and pending ATT requests belong to their peripheral manager. Use
that manager to remove services, update characteristic values and respond to
requests. `removeAllServices()` and `dispose()` clean up that manager's local GATT
objects. Disposal also releases its unanswered ATT requests.

Await `peripheralManager.ready` for native initialization; `isInitialized` reports
whether creation has completed. A subsequent operation can retry a failed
creation. After awaiting `dispose()`, accessing `CBPeripheralManager.shared`
creates a fresh manager. Operations on the disposed object throw `StateError`.

After Flutter hot restart, `CBPeripheralManager.shared` reattaches to its existing
native manager. Await `ready` to recover its current advertising state and
published `services`, including attribute handles and subscribed centrals. Pending
service additions remain pending until their native callbacks arrive. Buffered
requests can resolve the recovered characteristics; stopping advertising or
disposing the shared manager controls the original native registration.
Reattachment does not emit a synthetic state-restoration callback. The native
manager keeps its original options; dispose it before creating one with different
options. Explicitly constructed and isolated managers keep independent native
registrations.

Service removals affect the registrations present when the native request is
submitted. A newer add, including re-adding the same service object, survives an
older removal's delayed reply. Failed removals keep the service cache intact;
late add callbacks remain observable without restoring removed registrations.

Local characteristic permissions, including encryption requirements, are retained
in publication and restoration snapshots and when a removed service is published
again. For local Presentation Format (`0x2904`) descriptors, supply a `Uint8List`
value; the wrapper converts those bytes to native `Data`. User Description
(`0x2901`) descriptors use a `String` value.
Missing or incorrectly typed values for these descriptors cause `add()` to fail
with a `PlatformException` whose code is `invalid_args`. New service graphs are
checked before native construction, so a rejected descriptor creates no partial
registrations. Correct the value and retry `add()` with the same service object.

If re-adding a previously published service fails, the existing publication and
its attribute handles remain usable. A failed first add is cleaned up. Explicit
removal, power-off/reset or disposal still retires the publication, and late add
callbacks cannot restore it.

Publishing a parent reuses included native services already owned by the same
manager, preserving their service and attribute handles. Client references also
identify services whose add callback has not arrived yet, and repeated references
within a new graph share one native service. Live service handles from another
manager are rejected. Removed graphs can be published again as fresh native objects.

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
  if (result.requests.isEmpty) {
    return;
  }
  for (final request in result.requests) {
    print(request.value);
  }
  await peripheralManager.respond(
    to: result.requests.first,
    withResult: CBATTErrorCode.success,
  );
});
```

Treat each write callback as one atomic batch: validate every request before
applying any writes, then respond once. On failure, respond using the request
that failed and its error code. Replying retires every request handle in that
batch; additional replies report `invalid_args`.

Read, write and subscription callbacks also resolve characteristics in nested
included services, using the same characteristic objects tracked by the manager.
When restored services include the same native service through multiple roots,
those roots share one Dart service object and its characteristics and descriptors.
Retained native handles keep their existing Dart objects across restoration updates.
Subscription changes are visible through every root, including after another root
is removed.

### Update Subscribed Centrals

```dart
final didSend = await peripheralManager.updateValue(
  Uint8List.fromList([0x10, 0x20]),
  forCharacteristic: characteristic,
  onSubscribedCentrals: null,
);

print(didSend);
```

`onSubscribedCentrals: null` updates all subscribers. An explicit list selects
only its subscribed centrals; an empty list selects nobody. Empty selections and
lists with no matching subscribers are forwarded as empty native lists.

### Connection Latency

`setDesiredConnectionLatency` accepts centrals received through ATT read/write
requests, subscription callbacks, restored subscribed characteristics or a server
L2CAP channel's `peer`. A notification subscription is not required. You can use
the central after answering its ATT request; the manager retains the native
central separately from the request. Observed centrals belong to their manager
and are released when it leaves the powered-on state or is disposed. CoreBluetooth
decides whether to honor the requested latency.

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

  try {
    await channel.outputStream.write(Uint8List.fromList([0x10, 0x20]));
  } finally {
    await channel.inputStream.close();
    await channel.outputStream.close();
  }
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
