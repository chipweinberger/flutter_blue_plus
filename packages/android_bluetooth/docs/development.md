# Development and validation

## Source layout

- `lib/android_bluetooth.dart` is the public library. Its feature parts in `lib/src/` contain both API models and the callback result types used by their streams. `host.dart` owns channel transport and registration event routing.
- `AndroidBluetoothPlugin.java` coordinates engine/activity lifecycle, channels, pending replies and broadcasts. `AdapterBridge`, `DeviceBridge`, and `EnvironmentBridge` handle adapter/device operations, permissions, location state and foreground-service requests. `BluetoothCodec` contains shared wire-value and snapshot helpers.
- `GattBridge` owns registration lookup and dispatch. `GattClient`, `GattServer`, and `GattAttributes` contain central operations, peripheral operations and shared attribute identity/snapshot handling.
- Other native bridges follow their feature names. `android/src/api36/java/` holds optional SDK 36 sources; `android/src/testApi36/java/` holds their tests.
- Dart tests are grouped by feature under `test/`; `test/support/bluetooth_test_host.dart` supplies shared channel mocks and payload fixtures. Native tests share `PluginTestSupport` and `GattTestSupport` in their test package, where they can access package-private implementation types.

## Validation

From the package directory:

```sh
flutter analyze
flutter test
```

From `example/android`, using the current host's JDK:

```sh
./gradlew :android_bluetooth:testDebugUnitTest :android_bluetooth:lintDebug :app:assembleRelease
```

The [minimum-version host](../tool/compatibility/README.md) runs the same Dart feature suites with the older Flutter/Dart SDK, builds its APK and runs the native core suite. Keep its `test/package_test.dart` imports in sync when adding a test file. The [FlutterBluePlus audit](flutter_blue_plus_compatibility.md#validation-and-migration-gate) documents the optional comparison probes against the existing backend.

`EnvironmentBridgeTest` checks service-start acceptance through the full method
handler. A null component returns `invalid_state`, and a later accepted start can
succeed. Both foreground and pre-26 launch branches are exercised; permission
checks, notification arguments and the selected launch method retain their order.

Format Dart with `dart format --line-length 120`. These checks cover transport, parsing, identity and lifecycle behavior; real-device tests cover radio interoperability and OEM behavior.

`AdvertisingStopTest` covers pending cancellation without callbacks, native routing
release, queued/late callbacks, started-set terminal ordering, failed-start delivery,
stop-submission retries and independent registrations. Dart advertising tests verify
completion with listeners installed before or after pending cancellation, concurrent
and repeated stops, failure followed by startup/retry, and stopped callbacks arriving
before the method reply. Pending cancellation does not synthesize native callbacks.

`IntegerArgumentTest` covers Java int boundaries/defaults, rejection of overflow
and non-integer values, and preservation of 64-bit report delays. Real SDK scan
builders reject overflowing modes instead of receiving wrapped opportunistic or
low-latency settings. Full method-handler tests verify invalid scan options and
connection-state arrays return `invalid_argument` without starting a radio scan or
querying native state, leave no scan registration behind, and permit valid retries.

`BluetoothContractTest` verifies advertising-data filters reject short, long and
empty masks of the wrong length, and masks without data, before native builder
submission. Valid masked, unmasked and type-only filters remain supported. This
also covers API 33, whose builder can accept mismatched masks that later throw
during native matching.

`AliasCompatibilityTest` checks setting and clearing aliases on APIs 31, 32, 33
and 36, the API 30 unsupported result, native status values and permission errors.
Dart tests verify the null channel argument, random-address preservation and
unchanged native status/error delivery on both supported toolchains.

`ReliableWriteTest` checks matching and mismatched native write-response bytes,
failure status, null/empty values, and array mutation before main-thread delivery.
Dart tests verify typed callback access and independent byte snapshots on both
toolchains. FBP tests additionally verify that raw native response bytes do not
replace its existing submitted-byte write events, including failed and unmatched
callbacks.

`GattHandleHistoryTest` covers collection of retired framework service graphs
without closing the registration, late callback IDs after unrelated objects are
collected, equal-but-distinct object identities and replacement registrations.
The tests use weak references to detect retention instead of holding every old
attribute in fixture collections.

`BluetoothContractTest` exercises shared included-service graphs built from real
Android GATT objects. Both branches retain characteristics, descriptors and nested
services with stable usable handles, including when a descendant also points back
to a common ancestor; the actual cycle remains finite.

`GattServerAddTest` uses Android's actual pending-service, callback and service-list
implementation, with a mock Binder acknowledging requests. The default Robolectric
server shadow keeps a separate list and cannot reproduce retained failed additions.
The tests verify repeated queries after failure, invalid service/characteristic/
descriptor handles, successful services with duplicate UUIDs, retry, removal and
clearing on both API 33 and API 36.
They also remove a shared included service while Android retains its parent
references, then query repeatedly and add another parent through a surviving
service. Successful and failed add callbacks preserve the retired metadata without
reactivating its handles; active parents and shared descendants remain usable.

`ScanDeliveryTest` drives actual native callbacks and counts event-sink frames and
device snapshot calls. With 1,000 advertisements and divisor 10 it requires 100
frames and 100 snapshots. It also covers per-device/registration isolation,
duplicate suppression before sampling, A/B/A payloads, batch inclusion, default raw
callbacks, history resets and invalid-option recovery. Dart tests verify the
delivery arguments, Dart keyword matching after sampling and that FBP does not
sample a second time after delivery.

`ScanPresenceDeliveryTest` exercises valid FIRST_MATCH/MATCH_LOST scan settings
with Android's real ScanRecord parser and ScanResult objects. Default and
independent scans retain arrival/disappearance/reappearance order and payloads
with duplicate suppression, sampling or both enabled. Policy updates do not
restart the radio scan or drop later transitions; stop and engine restart still
reject late presence callbacks.

`ScanRecordTest` uses Android's real advertisement parser with malformed
manufacturer/name structures. It verifies raw-byte preservation, empty parsed
metadata, continued healthy-result delivery, and both callback and PendingIntent
receiver paths without a spurious background transport error.

`CompanionPresenceTest` exercises the optional SDK 36 presence service with every
API 36 event type, association IDs and optional UUIDs. Events reach both an
already-listening engine and an engine attached after background delivery. The
same service also retains its inherited legacy appeared/disappeared callbacks.
The Dart companion tests verify the public callback fields and global event type.

## Tested toolchains

The example is verified with Flutter 3.47.5 / Dart 3.13.4, Android compile/target SDK 36, AGP 9.0.1, Gradle 9.1.0 and JDK 21. It uses AGP's built-in Kotlin support. The tested Flutter SDK still requires `android.newDsl=false` for its Android extension integration. These are tested build versions, not claims that every older Flutter/Gradle combination works. The [minimum-version host](../tool/compatibility/README.md) uses real Flutter 3.10.6 / Dart 3.0.6, SDK 33, AGP 7.4.2, Gradle 7.6.4 and JDK 17. It runs the shared Dart tests, builds an Android APK and runs native core tests. SDK 36-only tests are isolated in their own source set, while the current host runs core tests on APIs 33 and 36. API 36-only ranging/presence sources are compiled only with SDK 36. Read-only typed-list views were [added in Dart 3.3](https://api.dart.dev/dart-typed_data/Uint8List/asUnmodifiableView.html); on Dart 3.0–3.2 byte getters return isolated copies and shared snapshot bytes remain immutable lists.
