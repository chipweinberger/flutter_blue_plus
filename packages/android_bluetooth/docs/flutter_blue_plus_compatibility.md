# FlutterBluePlus compatibility audit

Audited and updated 2026-11-06 against the sibling `flutter_blue_plus_android` 9.0.5 implementation, the checked-in platform interface, and FlutterBluePlus's public Dart implementation.

## Verdict

**The identified native and packaging gaps are fixed.** AndroidBluetooth now supplies the primitives needed for a behavior-preserving FlutterBluePlus adapter, while retaining stricter default GATT handling for other consumers. No third-party production dependencies were added.

The FlutterBluePlus backend has not been migrated. Connection management, scan processing, CCCD policy, synthetic characteristic identity and FlutterBluePlus errors still need a Dart compatibility adapter behind the existing platform interface. Full behavior parity must be checked on that adapter and on physical devices before switching.

## Resolved native and packaging gaps

### 1. Prearmed pairing PINs

`BluetoothDevice.createBond(pin: ...)` arms a copied one-shot PIN atomically before native bonding submission. `setPinForNextPairing(pin)` also supports prearming separately; null cancels it. Android's receiver applies the PIN synchronously before returning from the pairing broadcast. It is cleared on use, failed submission, disconnect, terminal bond state, explicit rejection/removal, adapter shutdown and engine reset. `onPairingPinSet` reports acceptance without exposing the PIN. No pairing broadcast suppression was added.

The Dart adapter must retain FlutterBluePlus's connected-device and already-bonded/bonding checks. Supplying a PIN does not bypass Android's permission or pairing policies.

### 2. Location-services preflight

`AndroidBluetooth.isLocationEnabled` reports the actual system setting using LocationManager on API 28+ and Settings.Secure on earlier Android, without requesting permission or requiring an Activity. Comparison tests cover enabled/disabled location on API 23, 28 and 30 against the existing backend.

The adapter must call it before scan permission requests when `androidCheckLocationServices` is true on API 21–30, and preserve the existing error. As before, FlutterBluePlus bypasses this preflight on API 31+.

### 3. Cache refresh, Service Changed and callback identity

`connectGatt(preserveAttributeHandles: true)` retains usable handles after successful refresh and Service Changed, matching the old backend's lifetime policy without adding rediscovery radio operations. It also reports the cached graph on discovery failure. Successful rediscovery still retires the previous handles. The default remains strict: refresh and Service Changed invalidate active handles.

Invalidation now retains original routing handles and parent characteristic/service metadata for late callbacks. Those identities do not reactivate stale attributes, and are freed when the registration closes. The adapter must retain its identity mapping for late events and rebuild active mappings on successful discovery.

Comparison tests verify the old and new native reads still succeed after refresh in compatibility mode, Service Changed does not trigger extra discovery, and late descriptor callbacks retain their identity while native stale-handle operations remain rejected.

### 4. Engine-detach event

`AndroidBluetooth.onDetachedFromEngine` and the global event stream expose a native lifecycle event before cleanup and EventChannel completion. Dart registration streams finish and reject further operations. A subsequent call can reopen the event channel after native reattachment. Reusing the same native plugin instance also recreates its I/O executor.

The adapter must map this event to the existing platform detach stream so FlutterBluePlus stops scan bookkeeping without another native call. Native and Dart detach/reattach tests cover delivery, cleanup and relistening; hot-restart cleanup remains separately tested.

Outstanding native method calls receive a terminal engine-detached/restarted error instead of having their replies silently discarded. Late worker replies cannot complete a call twice. Enable, permission and association UI requests have distinct per-attempt codes, including across hot restart and engine replacement. Companion success retires the Dart session after preserving the expected success callback sequence.

### 5. LE transport on API 21–22

The connection path now mirrors the old best-effort hidden `connectGatt(..., TRANSPORT_LE)` invocation on API 21–22, with fallback to the default overload if reflection fails. API 23+ continues to select LE explicitly. Tests cover LE overload selection and fallback; actual Android 5 radio behavior still requires device validation.

### 6. Manifest and host toolchain

The library manifest is empty: permissions, BLE feature flags and optional services/receiver declarations belong to the app. The example explicitly declares its own components. A central-only FlutterBluePlus adapter therefore does not acquire unrelated advertising, companion, background or ranging declarations transitively.

Dart/Flutter constraints now match the existing backend (`^3.0.0` / `>=3.7.0`); Java 11 and min SDK 21 are retained. Native compile SDK follows Flutter when its plugin extension is available; older Flutter hosts fall back to SDK 33, with an optional `androidBluetoothCompileSdk` property override. SDK 33 builds include the existing FlutterBluePlus surface. API 36-only ranging and the newer companion presence service are optional source files included only with SDK 36. Newer socket/device/companion methods use guarded reflection so they remain callable on suitable devices even with the SDK 33 core build. Missing optional ranging code reports unsupported rather than breaking plugin registration.

Dart 3.0–3.2 byte getters return isolated typed copies; immutable raw snapshots prevent mutations from affecting other consumers. Dart 3.3+ retains read-only typed views. The committed minimum-version host uses real Flutter 3.10.6 / Dart 3.0.6 and SDK 33 to run the shared Dart suite, assemble an APK and run native core tests. It does not substitute a Flutter services stub or copied production sources. Additional host versions and physical-device behavior remain separate validation.

Keep FlutterBluePlus's Dart registration and existing build/licensing hooks when migrating. AndroidBluetooth should register once through the dependency, and the old native backend should then stop registering.

### Additional submission/query primitives

`BluetoothCapabilities.hasAdapter` exposes the old backend's support predicate independently of BLE capability and permissions. `requestEnable(waitForResult: false)` returns after successful dialog launch and emits the later user decision on `onEnableResponse`. This avoids treating native launch failures as user cancellation when adapting the old split submission/result contract. The default still waits for the activity result.

## Complete platform-method mapping

All 28 platform methods were checked. “Adapter” means the primitives exist, with the listed behavior implemented in FlutterBluePlus's Dart backend. It does not mean an adapter has already been implemented or tested end to end.

| FlutterBluePlus method | AndroidBluetooth primitive | Work required |
| --- | --- | --- |
| `isSupported` | capabilities / adapter query | Adapter: use `capabilities.hasAdapter` for the old predicate; `isSupported` additionally requires the BLE feature. |
| `getAdapterName` | adapter `name` | Adapter: preserve permission requests, empty string on denial/null, and `N/A` when no adapter exists. |
| `getAdapterState` | adapter `state`, adapter events | Adapter: translate native enum values and unavailable/error cases to the existing unknown state. |
| `turnOn` | adapter `requestEnable` | Adapter: use `requestEnable(waitForResult: false)` and map `onEnableResponse`; keep the already-on false result and permission policy. |
| `turnOff` | adapter `disable` | Adapter: preserve already-off behavior and native submission result. |
| `getSystemDevices` | manager `getConnectedDevices(profile: gatt)` | Adapter: keep system-wide connected devices distinct from this plugin's registrations; preserve CONNECT permission handling. |
| `getBondedDevices` | adapter `bondedDevices` | Adapter: translate device/name snapshots and native errors. |
| `getBondState` | device `refresh`, bond-state snapshot/events | Adapter: fetch fresh state rather than a previously cached device snapshot; map current/previous enums. |
| `getPhySupport` | capabilities | Adapter: preserve API <26 error instead of treating absent capability fields as false; handle permission-limited capability snapshots. |
| `startScan` | scanner filters/settings and scan callbacks | Adapter using the location-services query: preserve defaults, permission order, OR filters, keyword checks, deduplication, divisor, and advertisement conversion. |
| `stopScan` | scan/session `stop` | Adapter: preserve harmless repeated stops and retire per-scan callback routing. |
| `connect` | device `connectGatt(autoConnect:)` | Adapter (native LE transport branches now match): keep one current registration per remote ID, native auto-connect lifetime, and old changed/submitted return semantics. |
| `disconnect` | GATT `disconnect`, `close` | Adapter: distinguish pending, connected, and idle auto-connect registrations; synthesize pending-connect cancellation and close at the correct time. |
| `discoverServices` | GATT `discoverServices`, service graph callback | Adapter: flatten included services and rebuild FlutterBluePlus identities/handle maps. Enable `preserveAttributeHandles` so failed discovery includes the cached graph, as the old backend does. |
| `readCharacteristic` | GATT `readCharacteristic` | Adapter: connected/property checks, identity lookup, submission errors, and callback translation. Use retained callback handles and parent metadata for late events. |
| `writeCharacteristic` | GATT `writeCharacteristic` | Adapter: write type, MTU/512-byte policy, status normalization, and outbound-value cache for write callbacks. |
| `readDescriptor` | GATT `readDescriptor` | Adapter: parent characteristic identity and submission/callback errors. Use retained callback handles and parent metadata for late events. |
| `writeDescriptor` | GATT `writeDescriptor` | Adapter: MTU limit, outbound-value cache, status/error conversion. |
| `setNotifyValue` | local `setCharacteristicNotification` plus CCCD write | Adapter: preserve notify/indicate preference, forced indications, missing-CCCD behavior, and descriptor-written event. |
| `requestMtu` | GATT `requestMtu`, MTU callback | Adapter: cache negotiated MTU for native-equivalent write validation; keep callback result/error separate from submission. |
| `readRssi` | GATT `readRemoteRssi`, RSSI callback | Adapter: map acceptance/result/errors. |
| `requestConnectionPriority` | GATT `requestConnectionPriority` | Adapter: connected check, false-result error, same priority values. |
| `setPreferredPhy` | GATT `setPreferredPhy` | Adapter: preserve API gate, connected check, and old `true` return on successful submission. |
| `createBond` | device `createBond`, bond events | Adapter using atomic `createBond(pin:)` or the one-shot PIN facility: connected check, already-bonded/bonding semantics, false-result error. |
| `removeBond` | device `removeBond` | Adapter: already-unbonded result and hidden-API errors. |
| `clearGattCache` | GATT `refresh` | Use `preserveAttributeHandles`; old backend returns true after reflection succeeds even if the reflected method returns false. |
| `setLogLevel` | FlutterBluePlus adapter logging | Adapter: keep public logging behavior; AndroidBluetooth does not implement the old native debug log stream. Exact old internal log text would require additional instrumentation if treated as contractual. |
| `setOptions` | no native operation needed | Adapter: current Android backend is a successful no-op. |

## Observable behavior the Dart adapter must preserve

### Connection ownership and event ordering

- Track connecting, connected, and auto-connect registrations by remote ID and AndroidBluetooth registration ID. An obsolete registration must not disconnect or update a newer connection to the same device.
- Return false for already-connected `connect`, true for already-connecting `connect`, and the existing distinct disconnect return values. These booleans control whether public Dart code waits for callbacks.
- Cancelling a pending connection must emit disconnected with reason `23789258` (`connection canceled`). Calling native disconnect/close alone is insufficient.
- Keep auto-connect GATT registrations alive across disconnections; close ordinary registrations after disconnect. Ignore intermediate and duplicate connection events as the old backend does, including retaining negotiated MTU on duplicate connected events.
- Synthesize disconnect events and clear appropriate state when the adapter turns off; Android callbacks are not the only source of these events in the old backend. Stop scan state and preserve the existing adapter-on auto-connect interaction.
- Install event routing before operations can produce callbacks. AndroidBluetooth can buffer early session events, but the wrapper must associate them with the correct connection/scan generation and avoid replaying retired events.
- Keep the existing public Dart mutexes, cancellation, timeouts, Android disconnect delay, and default post-connect MTU request. Moving the backend should not rewrite these policies.

### Scanning

- Explicitly request low-latency mode, `legacy: false`, and all supported PHYs on API 26+, matching FlutterBluePlus defaults. AndroidBluetooth's own defaults differ.
- Request SCAN and CONNECT on API 31+, optionally fine location when requested; use fine location on older Android. Normalize empty filter masks to absent masks.
- Build separate native filters per service/address/name/MSD/service-data entry: the old list is OR, not one combined AND filter. Preserve API 33+ name AD-type filters for keywords and the case-sensitive advertised-name substring test.
- When `continuousUpdates` is false, compare each address's raw advertisement bytes with its last received payload: A/B/A should emit all three, while repeated A/A is suppressed even if RSSI changed. This is not a scan-wide set of previously seen payloads. In continuous mode, preserve per-device counting/divisor and its order relative to keyword checks. Reset these caches per scan.
- Convert raw advertisement bytes with the old semantics, including appearance, TX-power sentinel, connectability fallback before API 26, nullable platform name, shortest-form UUIDs, and repeated manufacturer fields. The old parser concatenates every manufacturer AD payload, including subsequent company IDs, and stores the result under the first company ID. Copying AndroidBluetooth's parsed manufacturer map would change existing data.
- Emit the existing scan failure code/string and stop public scan bookkeeping. Avoid adding new batch-result behavior accidentally; the old backend does not process batch callbacks.

### Service and attribute identity

- Do not expose AndroidBluetooth handles or raw Android instance IDs as FlutterBluePlus `instanceId`s. A unique characteristic in one matching service has ID 0 today, regardless of its native instance ID. Duplicate characteristics within that service use native IDs. With multiple matching services, IDs are ordinal positions across all their characteristics, including other UUIDs.
- Preserve primary/included-service association, flattened secondary services, descriptor UUID lookup, graph order, and UUID normalization. Map the resulting FlutterBluePlus identity tuple to opaque AndroidBluetooth handles and back for callbacks.
- Preserve Service Changed characteristic (`1801` / `2A05`) handling and FlutterBluePlus's automatic subscription during discovery. Do not silently add extra public reset events just because AndroidBluetooth exposes a newer native callback.

### Writes and notifications

- Track negotiated MTU, defaulting to 23. Normal and no-response writes are limited to `min(MTU - 3, 512)`; allowed long writes with response are limited to 512. Descriptor writes use `MTU - 3`. Preserve property checks and immediate failure behavior.
- `allowLongWrite` currently lets Android perform the long write; it does not start a reliable-write transaction. Do not substitute one.
- Cache outbound characteristic/descriptor bytes before dispatch. AndroidBluetooth's write callbacks contain status and attribute metadata, while FlutterBluePlus's written events include the submitted value.
- Local notification registration alone is insufficient. Write CCCD values `01 00`, `02 00`, or `00 00`, prefer notifications when both properties exist unless forced, and preserve indication-property errors. If the CCCD is missing, return false after successful local registration so public Dart does not wait for a nonexistent descriptor-write callback.

### Permissions, errors, and streams

- AndroidBluetooth intentionally leaves permission orchestration to callers. The adapter must perform the old per-operation checks/requests, serialize concurrent permission requests as necessary, and preserve denial results. Do not start requesting permissions on methods that did not request them before.
- Translate raw native states/statuses to the existing `Bm*` models and their success/error fields. Immediate booleans, API 33+ write status integers, and asynchronous GATT/HCI result codes are different contracts.
- Preserve method-specific PlatformException codes, public error descriptions, disconnection reason strings, and unsupported-version errors. Directly forwarding AndroidBluetooth's `permission_denied`, `invalid_state`, or `unsupported` exceptions changes what callers observe.
- The 15 platform event streams are accounted for: adapter state, bond state, characteristic received/written, connection state, descriptor read/written, detach, discovery, MTU, name, RSSI, scan, services reset, and turn-on response. All now have native primitives or Dart synthesis paths, including detach and late attribute identity. The current old backend declares `onNameChanged` but does not emit it; adding name broadcasts would be a deliberate expansion.

## Validation and migration gate

Completed after the gap fixes:

- Read all 28 platform method implementations, all 15 event contracts, and the public Dart consumers of submission booleans, ordering, identity and timeouts.
- Dart tests: 52 passed on both current and minimum hosts; analyzers clean. Regressions cover snapshot isolation, compatibility arguments, parent identities, detach/relisten and owner callback retention with global observers and ranging close/stop contracts.
- Current-host native tests including old/new comparisons: 137 passed, 1 skipped, covering APIs 33 and 36 plus older targeted cases. Regressions cover copied one-shot PINs and cleanup, strict/compatibility GATT behavior, late routing identities, successful/failed enable launch, LE selection/fallback, detach ordering and reattachment.
- Comparisons against the actual old backend verify refresh/PIN/location behavior and preserve the documented synthetic-ID and repeated-MSD translations the Dart adapter must retain.
- Android lint and the SDK 36 release APK build pass. The minimum host uses Flutter 3.10.6, Dart 3.0.6, AGP 7.4.2, Gradle 7.6.4, SDK 33 and JDK 17; see its committed compatibility runner for the shared Dart suite, Android APK and native core checks.

The opt-in harness is [tool/flutter_blue_plus_audit/compare.gradle](../tool/flutter_blue_plus_audit/compare.gradle), with [comparison probes](../tool/flutter_blue_plus_audit/java/com/jamcorder/android_bluetooth/FlutterBluePlusParityProbe.java). It adds the sibling Java implementation to test sources only and does not apply its Gradle build hooks or add production dependencies. Run from `packages/android_bluetooth/example/android` with a suitable Java installation:

```sh
./gradlew :android_bluetooth:testDebugUnitTest \
  --tests com.jamcorder.android_bluetooth.FlutterBluePlusParityProbe \
  --init-script ../../tool/flutter_blue_plus_audit/compare.gradle --console=plain
```

Before replacing the backend:

1. Implement the Dart compatibility adapter behind the existing platform interface, selecting the compatibility primitives above.
2. Compare old/new `Bm*` results and event traces for scans, filters, repeated AD fields, duplicate/included services, reads/writes, CCCDs, submission failures, and error mapping. The resolved native-gap probes now assert the matching behavior; extend them to the actual Dart adapter.
3. Exercise pending-connect cancellation/reconnect races, auto-connect, adapter power cycling, timeout/disconnect cleanup, permission denial/revocation, hot restart, and detach/reattach. Include a PIN-paired device and notifications arriving during discovery/cache refresh/service changes.
4. Verify merged manifests and supported host Flutter/Android toolchain versions. Cover API 21–22 if retained, 23–30 location behavior, 31–32 Bluetooth permissions, and 33+ write callbacks/statuses.
5. Validate on physical devices, including a dual-mode peripheral and at least two Android vendors. Mock/Robolectric tests cannot establish radio timing, pairing UI behavior, OEM GATT quirks, or actual reconnect reliability.

L2CAP, GATT server, advertising, companions, ranging, ACL/encryption events, and other additional AndroidBluetooth features are not blockers for this migration: the existing FlutterBluePlus platform contract does not require them. The adapter can leave them unused without changing FlutterBluePlus's public API.

## Source references

- [Existing Android Dart backend](../../flutter_blue_plus_android/lib/flutter_blue_plus_android.dart)
- [Existing Android native backend](../../flutter_blue_plus_android/android/src/main/java/com/jmx/flutter_blue_plus/FlutterBluePlusPlugin.java)
- [Platform interface](../../flutter_blue_plus_platform_interface/lib/flutter_blue_plus_platform_interface.dart)
- [Public scan/lifecycle consumers](../../flutter_blue_plus/lib/src/flutter_blue_plus.dart)
- [Public connection/bonding consumers](../../flutter_blue_plus/lib/src/bluetooth_device.dart)
- [Public notification/write consumers](../../flutter_blue_plus/lib/src/bluetooth_characteristic.dart)
- [AndroidBluetooth native lifecycle/permissions](../android/src/main/java/com/jamcorder/android_bluetooth/AndroidBluetoothPlugin.java)
- [AndroidBluetooth native GATT](../android/src/main/java/com/jamcorder/android_bluetooth/GattBridge.java)
- [AndroidBluetooth native scanning](../android/src/main/java/com/jamcorder/android_bluetooth/ScanBridge.java)
