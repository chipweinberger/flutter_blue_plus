# android_bluetooth

Native Android Bluetooth Low Energy APIs for Dart and Flutter. Android's class names and operation semantics are the public API, following the approach of `core_bluetooth`.

Includes central and peripheral roles, GATT client/server, scanning, advertising, LE L2CAP, bonding and ACL events, companion integration, background hooks and raw BLE ranging. Classic profiles, HID, audio, RFCOMM, Wi-Fi and UWB are outside the package.

Requires Android API 21+. Dart/Flutter bounds match FlutterBluePlus’s Android backend (Dart 3.0+, Flutter 3.7+). Native compilation follows the host Flutter compile SDK when its plugin extension is available; older Flutter hosts default to SDK 33. SDK 33 and 36 are checked. Building with SDK 36 enables BLE ranging and the newer companion presence callback; these optional sources are excluded on older build SDKs. Set `androidBluetoothCompileSdk=36` in the host’s `gradle.properties` to opt in when needed. The library declares no third-party Dart or Android production dependencies beyond the Flutter and platform SDKs; its external packages are development/test tools. Features introduced later are guarded at runtime. The example uses API 23+ to match current Flutter's Android minimum. API 36.1 controls are called reflectively so building does not require a minor-version SDK. See [the complete contract](docs/api_contract.md) for included members, version requirements and intentional exclusions.

## Operation contract

* A successful method call means Android accepted/submitted the request, unless the native operation is synchronous. Completion comes through the corresponding callback stream.
* Native `boolean` request results and integer status codes are preserved. `BluetoothStatusCodes.success` means accepted. Before API 33, write/notify booleans are normalized to `success` or `errorUnknown`.
* GATT operations are not automatically queued, retried, chunked, subscribed or rediscovered. Await the relevant completion before submitting another operation on that registration. Subscribe before submitting requests.
* Every GATT registration and attribute has its own native handle. Duplicate UUIDs are supported. Rediscovery, Service Changed, successful cache refresh and service removal invalidate affected handles. Late server requests preserve their callback metadata without restoring removed attribute handles. Never carry attributes between registrations.
* Callbacks arriving without an owner listener are queued in order, with no fixed event-count limit or idle-owner eviction. Replay is deferred to a microtask so typed listeners installed in the same synchronous block all receive their matching startup callbacks. Later subscriptions follow normal broadcast semantics. Paused subscriptions use Dart's normal stream buffering. Global `AndroidBluetooth.events` is a live broadcast stream; its listeners do not drain owner queues, and owner replay does not rebroadcast globally. Consume the streams or dispose registrations when finished: memory usage follows the amount of unconsumed data. Individual callback streams filter the owner's shared stream; use `events` to consume every callback.
* Every close/stop operation on a registration is idempotent, including concurrent calls. Operations after closing starts fail locally. GATT/scans/sockets finish at close; advertising sets and started ranging sessions deliver their terminal callback before their streams finish. Ranging sessions without an outstanding start finish after native close without generating a callback. Cleanup can be retried after a native failure.
* Callback streams expose operation-specific result types, e.g. `onCharacteristicRead` yields `GattCharacteristicReadResult`. Required fields are non-null. The combined `events` stream remains a union of those results. Native integer statuses remain open to future values.
* Received maps/lists/bytes are read-only snapshots; copy them if you need mutable application data. Locally constructed GATT services/characteristics retain mutable builder lists.
* `PlatformException` codes include `unsupported`, `restricted_api`, `permission_denied`, `invalid_argument`, `invalid_state`, `io_error`, `activity_detached`, `engine_detached`, `engine_restarted` and `android_error`. Native callback statuses remain callback data, rather than becoming method exceptions.

Outstanding method calls fail with `engine_detached` or `engine_restarted` when their native engine session ends. Cleanup completes each call once; queued or late worker replies cannot complete it again. Activity-only detach uses `activity_detached` for pending permission/enable calls. Dialog request codes are allocated per attempt, so results from an old enable dialog, permission prompt or companion chooser cannot answer a new request after restart or reattachment.

Import the package alongside Dart's standard async/byte types:

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:android_bluetooth/android_bluetooth.dart';
```

## Permissions and adapter

The library manifest is intentionally empty. Applications own all permission, feature and optional component declarations, and the plugin does **not** prompt automatically. Add the permissions your application uses:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<!-- Only for advertising -->
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<!-- Scanning on Android 6–11 -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
<!-- Add these only when using the corresponding features -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
<uses-permission android:name="android.permission.REQUEST_OBSERVE_COMPANION_DEVICE_PRESENCE" />
<uses-permission android:name="android.permission.RANGING" />
```

If scan results are used to derive location on Android 12+, also declare/request the appropriate location permission without the API-30 limit. The plugin does not assert `neverForLocation`, because that assertion can filter BLE advertisements. Apps may choose it explicitly in their merged manifest.

```dart
// API level/support are available before CONNECT is granted. Protected capability
// fields are null while permissionRequired is true; query again after granting.
final capabilities = await AndroidBluetooth.capabilities;
final permissions = capabilities.apiLevel >= 31
    ? ['BLUETOOTH_SCAN', 'BLUETOOTH_CONNECT', 'BLUETOOTH_ADVERTISE']
    : ['ACCESS_FINE_LOCATION'];
final granted = await AndroidBluetooth.requestPermissions(
  permissions.map((name) => 'android.permission.$name').toList(),
);
if (granted.values.any((value) => !value)) return;

final adapter = BluetoothAdapter.shared;
if (!await adapter.isEnabled) await adapter.requestEnable();
```

Permission requests, the enable dialog and companion association require an attached Activity. Android and device policy still decide which operations are allowed. `enable`/`disable` expose the deprecated native results; ordinary Android 13+ apps should use the system enable dialog/settings.

## Scan

```dart
final scanner = BluetoothLeScanner.shared;
final subscription = scanner.events.listen((event) {
  if (event.errorCode != null) print('Scan error: ${event.errorCode}');
  for (final result in event.results) {
    print('${result.device.address}: ${result.rssi} dBm');
    print(result.scanRecord?.advertisingData); // all raw AD structures
  }
});
await scanner.startScan(
  filters: [const ScanFilter(serviceUuid: '180D')],
  settings: const ScanSettings(scanMode: ScanSettings.scanModeLowLatency),
);
await scanner.stopScan();
await subscription.cancel();
```

`startScan` owns the default callback registration. `startScanSession` creates an independent `BluetoothScan` with its own filters, settings, events, flush and stop methods. Android's throttling and hardware limits apply to both. Batch results remain batches; data fields and nanosecond timestamps are preserved. Raw AD parsing preserves repeated types and unknown structures.

## GATT client

```dart
final device = BluetoothAdapter.shared.getRemoteDevice('AA:BB:CC:DD:EE:FF');
final gatt = await device.connectGatt(autoConnect: false);
final connected = Completer<void>();
final discovered = Completer<BluetoothGattCallback>();
final subscription = gatt.events.listen((event) {
  print('${event.type}: ${event.status}');
  if (event.type == 'onConnectionStateChange' &&
      event.status == 0 && event.newState == BluetoothProfile.stateConnected && !connected.isCompleted) {
    connected.complete();
  }
  if (event.type == 'onServicesDiscovered' && !discovered.isCompleted) discovered.complete(event);
  if (event.type == 'onCharacteristicChanged') print(event.value);
});

// Apply application timeouts and cancel pending subscriptions on rejection/disconnection.
await connected.future.timeout(const Duration(seconds: 30));
if (!await gatt.discoverServices()) throw StateError('Discovery rejected');
final result = await discovered.future;
if (result.status != BluetoothGatt.gattSuccess) throw StateError('Discovery failed');
for (final service in result.services) {
  for (final characteristic in service.characteristics) {
    print('${service.uuid} ${characteristic.uuid} ${characteristic.instanceId}');
  }
}

await gatt.disconnect(); // ends connection, registration may reconnect
await gatt.close();      // releases registration permanently
await subscription.cancel();
```

Use one `gatt.events` listener installed immediately after `connectGatt` to handle connection, discovery and operation callbacks in a state machine. The separate streams are convenience views of that stream. The example demonstrates this without competing connection listeners.

Android's `setCharacteristicNotification` changes **local routing** only. Write the remote Client Characteristic Configuration Descriptor (UUID `2902`) separately with `enableNotificationValue`, `enableIndicationValue` or `disableNotificationValue`, and await `onDescriptorWrite`. Android 14+ requests an ATT MTU of 517 on the first MTU request; the resulting MTU still depends on the peer. Preferred PHY and connection priority are requests, not guarantees. Transport is explicitly LE on API 23+; API 21–22 first try the hidden LE overload and fall back to the default overload if unavailable.

## GATT server and advertising

```dart
final characteristic = BluetoothGattCharacteristic(
  'FFF1',
  BluetoothGattCharacteristic.propertyRead | BluetoothGattCharacteristic.propertyWrite,
  BluetoothGattCharacteristic.permissionRead | BluetoothGattCharacteristic.permissionWrite,
);
final service = BluetoothGattService('FFF0', characteristics: [characteristic]);
final server = await BluetoothManager.shared.openGattServer();
final subscription = server.events.listen((event) async {
  if (event.type == 'onCharacteristicReadRequest') {
    await server.sendResponse(event.device!, event.requestId!, BluetoothGatt.gattSuccess,
        offset: event.offset!, value: Uint8List.fromList([42]));
  }
});
final added = server.onServiceAdded.first;
if (!await server.addService(service)) throw StateError('Service rejected');
if ((await added).status != 0) throw StateError('Service registration failed');
final advertisement = await BluetoothLeAdvertiser.shared.startAdvertising(
  data: const AdvertiseData(serviceUuids: ['FFF0']),
);
final advertiseSubscription = advertisement.events.listen((event) => print(event.type));
// Later:
await advertisement.stop();
await server.close();
await subscription.cancel();
await advertiseSubscription.cancel();
```

The application owns attribute values, offsets, per-client CCCD subscriptions and prepared-write transactions. For general values, slice read responses at the requested offset or return `gattInvalidOffset`. Respond to writes only when `responseNeeded` is true. `onExecuteWrite` signals whether to commit/abort accumulated prepared writes. Send indications using `notifyCharacteristicChanged(confirm: true, ...)` and await `onNotificationSent` before another notification/indication. Advertising and the GATT server have independent lifetimes.

`startAdvertisingSet` exposes extended and periodic advertising. Wait for `onAdvertisingSetStarted` before updating/enabling the returned set. Every advertising-set callback is available on `AdvertisingSet.events`, including parameter/data updates and periodic advertising enablement.

## LE L2CAP

API 29+. The PSM is dynamic and must be exchanged through your protocol, often a GATT characteristic. L2CAP can be used without an application GATT client.

```dart
final listener = await BluetoothAdapter.shared.listenUsingL2capChannel();
print('Publish PSM ${listener.psm} to the peer');
final incoming = await listener.accept(timeoutMillis: 30000);

// On the connecting device:
final outgoing = await device.createL2capChannel(peerPsm);
await outgoing.connect();
await outgoing.write(Uint8List.fromList([1, 2, 3]));
final bytes = await incoming.read(maxLength: 4096);

await outgoing.close();
await incoming.close();
await listener.close();
```

Secure and insecure variants are exposed. API 36 `BluetoothSocketSettings` allows independent authentication/encryption requirements and LE-only socket creation/listening. There are no RFCOMM socket factories.

Blocking connect/accept/read/write/flush operations run off the UI thread. `close` cancels outstanding native I/O. One read and one write can run concurrently; overlapping reads, overlapping writes/flushes and overlapping accepts are rejected. Await each write to preserve order. Reads can be partial; empty bytes signal EOF. Implement application framing yourself.

## Device events and bonding

```dart
final subscription = device.events.listen((event) {
  if (event.type == BluetoothDevice.actionAclConnected) print(event.transport);
  if (event.type == BluetoothDevice.actionBondStateChanged) print(event.bondState);
});
await device.createBond();
final updatedDevice = await device.refresh();
print(updatedDevice.bondState);
```

Device properties are snapshots; `refresh` obtains a new snapshot. ACL is the underlying Android-managed connection and is distinct from a GATT registration's connection state. Observe GATT callbacks to know whether your client connected. ACL events can also describe BR/EDR on a dual-mode device: inspect the transport extra rather than assuming every event is LE.

`createBond(pin: ...)` atomically arms a one-shot PIN before submission. `setPinForNextPairing(pin)` also allows prearming separately; pass null to cancel it. The receiver applies it synchronously and clears it on use, disconnect, terminal bond state, adapter shutdown or engine reset. `onPairingPinSet` reports acceptance without exposing the PIN. Pairing UI remains subject to Android policy. `setPin` and `setPairingConfirmation` expose native results but cannot bypass platform permission restrictions. `getIdentityAddressWithType` requires privileged permission. `BluetoothDevice.removeBond` and `BluetoothGatt.refresh` are explicitly best-effort hidden APIs. Prefer the public API-36 `CompanionDeviceManager.removeBond` for associated devices.

## Background and companion integration

`startBackgroundScan(id: ..., filters: [...])` uses an explicit mutable PendingIntent on API 26+. Keep the integer ID so another engine/process can call `stopBackgroundScan`. These scans intentionally survive engine detachment.

Background scan/presence events use an in-memory queue with no fixed event-count limit. While no Flutter engine is listening, events stay in the Android process. When a listener connects, queued events are sent in order and removed from the native queue. Live events go to all currently listening engines. Dart owner streams buffer callbacks until an owner listener subscribes, as described above.

The queue survives Flutter hot restart and engine detachment while the Android process remains alive. Process death loses buffered events. Applications that need persistence can store events themselves. Malformed background scan payloads are logged under `AndroidBluetooth` and reported to attached event listeners as `PlatformException(code: 'background_error')`; event streams continue afterward.

Flutter hot restart closes ephemeral GATT/socket/scan/advertising/ranging registrations before Dart restarts, rejects late results from the old generation, and clears stale native startup callbacks. An old accept cannot register a new socket into the restarted session. PendingIntent scans, the process-local background queue, and an explicitly started foreground service survive this reset.

`CompanionDeviceManager.associate` accepts BLE filters and launches Android's association chooser when required. Automatic approval releases the pending request on `onAssociationCreated`; a launched chooser keeps its request ID until the Activity result arrives. Listen to the returned request's events for pending, created, failure, chooser result and cancellation. Failed or canceled requests deliver their final callback, complete their Dart stream, and release the request's routing state. Association is distinct from Bluetooth bonding. `myAssociations`, `disassociate`, presence observation and public companion bond removal are exposed with their version requirements. Presence events arrive on `CompanionDeviceManager.events` through the process-local background queue.

`BluetoothConnectionService.start(title: ..., text: ...)` explicitly starts a `connectedDevice` foreground service and persistent notification from an attached Activity. Declare its permissions in the app. Start it while the app is allowed to start foreground services. `stop` removes it. It does not create a Flutter engine, restore a killed Dart isolate or override Android background policy. Companion presence services likewise buffer native events without starting Dart. Force-stop, reboot, revoked permissions and OS restrictions can stop delivery; buffered events last only for the lifetime of the Android process.

A companion association request stream completes on success as well as failure/cancellation. On Android 13+, a chooser-based success preserves both `onAssociationCreated` and `onAssociationResult`, in either order. Automatic approval completes with `onAssociationCreated`; older Android completes with `onAssociationResult`. `CompanionDeviceCallback.isComplete` marks the last callback before stream completion. Manager-wide companion presence events continue independently.

## BLE ranging

API 36, `android.permission.RANGING`, compatible hardware and peers are required. This package exposes raw BLE ranging; applications exchange peer parameters using their own BLE protocol. It deliberately does not negotiate Wi-Fi/UWB ranging.

```dart
final manager = RangingManager.shared;
final capabilities = manager.onRangingCapabilities.listen((value) => print(value.technologyAvailability));
await manager.registerCapabilitiesCallback();
final session = await manager.createRangingSession();
final results = session.events.listen((event) => print(event.result?.distance?.measurement));
await session.start(RangingPreference(
  deviceRole: RangingPreference.deviceRoleInitiator,
  devices: [RawRangingDevice(
    uuid: '12345678-1234-5678-1234-567812345678',
    csRangingParams: BleCsRangingParams(peerBluetoothAddress: device.address),
  )],
));
// Later:
await session.close();
await manager.unregisterCapabilitiesCallback();
await results.cancel();
await capabilities.cancel();
```

`onStarted` and `onStopped` report the peer and ranging technology; `onOpenFailed` and `onClosed` report a reason. Closing an unused session or one whose initial open failed finishes its streams after native close. Closing an outstanding start preserves its final `onClosed` or terminal `onOpenFailed`. An initial open failure can be retried before close.

RSSI ranging uses `BleRssiRangingParams`. `session.cancelStart()` cancels the most recent native start CancellationSignal. Initiator/responder roles, security level, location/sight hints, update rate, measurement limit, proximity notifications (centimeters), sensor fusion and interval reconfiguration are exposed. Dynamic peer addition uses Android's required `RawResponderRangingConfig`; support depends on the underlying technology and failures arrive through session callbacks. Android documents raw peer removal as UWB-multicast-only, so `removeDeviceFromRangingSession` returns `unsupported` for this BLE wrapper. Create a new BLE session with the desired peers instead. See [Android's ranging peer requirements](https://developer.android.com/reference/android/ranging/RangingSession#addDeviceToRangingSession(android.ranging.RangingConfig)). Result distance/angle measurements retain confidence, technology and timestamps. Existing BLE connections and any peer-side setup are the application's responsibility.

## Example and validation

From `example`, run `flutter pub get` and `flutter run` on an Android device. The explorer scans, connects, discovers services, reads/subscribes, publishes a simple GATT peripheral and supports L2CAP echo/client operations. Two compatible devices are required to exercise both L2CAP endpoints. Use devices that support the relevant feature for advertising/ranging tests.

See [development and validation](docs/development.md) for the source layout, shared test fixtures, supported toolchains, native regression commands, and minimum-version host. These checks validate transport, identity, parsing, configuration and lifecycle contracts; physical RF interoperability still requires hardware testing.

Failed GATT client/server close remains retryable for cleanup. Once close has started, other native operations reject immediately rather than accepting work whose callbacks can no longer arrive. On modern Dart, byte getters reuse the already-frozen read-only typed view; older Dart continues to return isolated typed copies.

## Wrapping FlutterBluePlus

The [compatibility checklist](docs/flutter_blue_plus_compatibility.md) describes the Dart adapter still required. Connect with `preserveAttributeHandles: true` to retain attribute access after cache refresh and Service Changed until successful rediscovery. The default keeps strict stale-handle invalidation. Late callbacks retain original handles and parent identities for routing, without reactivating stale attributes. Failed discovery includes the cached service graph in compatibility mode.

`AndroidBluetooth.isLocationEnabled` supplies scan preflight without an Activity or permission prompt. `BluetoothCapabilities.hasAdapter` reports adapter presence independently of BLE support. `AndroidBluetooth.onDetachedFromEngine` fires before stream completion and retires old registration streams; subsequent calls can subscribe to a reattached engine. `requestEnable(waitForResult: false)` returns after successful dialog launch and supplies the later decision through `BluetoothAdapter.onEnableResponse`, preserving the separation between launch errors and user cancellation.

## Optional Android components

Declare only the components used by your app inside its manifest’s `<application>`:

```xml
<!-- PendingIntent/background scanning -->
<receiver android:name="com.jamcorder.android_bluetooth.ScanReceiver" android:exported="false" />
<!-- Explicit connected-device foreground service -->
<service android:name="com.jamcorder.android_bluetooth.BluetoothConnectionService"
    android:exported="false" android:foregroundServiceType="connectedDevice" />
<!-- Companion presence (API 31+); choose one companion service -->
<service android:name="com.jamcorder.android_bluetooth.BluetoothCompanionService"
    android:exported="true" android:permission="android.permission.BIND_COMPANION_DEVICE_SERVICE">
    <intent-filter>
        <action android:name="android.companion.CompanionDeviceService" />
    </intent-filter>
</service>
```

For the API 36 presence-event callback, build with SDK 36 and replace the companion service name with `com.jamcorder.android_bluetooth.BluetoothCompanionPresenceService`. It also handles the older callbacks. Foreground/companion/ranging permissions above remain app opt-ins. The example includes explicit declarations for all its features.
