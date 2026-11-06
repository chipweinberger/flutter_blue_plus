# FlutterBluePlus Android compatibility

Updated 2026-11-06 against `flutter_blue_plus_android` 9.0.5, its platform interface, and the public FlutterBluePlus Dart consumers.

## Implementation

FBP's Android backend now uses AndroidBluetooth. The compatibility policies live in Dart feature files, following the Linux backend's structure:

| File | Responsibility |
| --- | --- |
| `android_backend.dart` | Existing event streams, initialization, permission orchestration, lifecycle and backend diagnostics |
| `android_adapter.dart` | Adapter queries, enable/disable, system/bonded devices, bond state and PHY support |
| `android_scan.dart` | Scan submission, filters, duplicate policy, callback conversion and raw advertisement parsing |
| `android_device.dart` | Connection ownership, cancellation, auto-connect and bonding |
| `android_gatt.dart` | GATT operations, CCCDs, write limits/caches and callback conversion |
| `android_types.dart` | Attribute graphs and FBP identity/handle translation |
| `android_utils.dart` | Existing enum, GATT/HCI/status strings and small translation helpers |

The old Java backend is retained unchanged under [test/reference](../../flutter_blue_plus_android/test/reference/README.md), solely for comparison tests. It is not compiled into applications. FBP's plugin registration is Dart-only. AndroidBluetooth registers the native plugin once and hosts the existing FBP license build hook. The hook runs when the application lockfile contains FBP or its Android backend; standalone AndroidBluetooth builds do not acquire the FBP ping. Manifest ownership, min SDK 21 and Java 11 remain unchanged. No third-party runtime dependencies were introduced.

Feature mixins override the platform interface with typed `Bm*Request` parameters and result types. A shared generic `_run<T>` handles initialization, adapter availability and native error translation. Requests are not routed through method-name switches or unpacked from dynamic maps. GATT lookup uses a typed identity snapshot; maps remain at event serialization boundaries. Each event explicitly supplies its typed controller and decoder; there is no synthetic MethodChannel/MethodCall or string-based event router. Shared subscription cleanup and AndroidBluetooth constants keep lifecycle and protocol values in one place. Focused helpers separate GATT callback handling, request acceptance, write validation, notification selection, scan filter snapshots, advertisement parsing and result filtering. Their ordering retains permission prompts, payload snapshots, duplicate filtering and callback delivery semantics.

Standard verbose request/result/event logging belongs to the main `flutter_blue_plus` package. Its typed `_invokePlatform<T, R>` logs the request and result, and central listeners log each callback once regardless of application listener count. Diagnostic serialization runs only at verbose level and formatting failures do not change operation or event delivery. Android and Darwin no longer duplicate these Dart traces; backend-specific diagnostics and native log-level forwarding remain. WinRT is unchanged as requested, so that external package can still print its own verbose console traces.

Adapter-state events are filtered and processed sequentially with `asyncMap`, awaiting scan/connection cleanup before the next state change. Generation checks suppress stale effects and cleanup errors after engine detach; subscription cancellation discards the old engine's queued events. Cleanup failures are forwarded to the listening zone and later events continue. Permission dialogs retain their separate future queue, while already-granted operations bypass it.

## Contract retained

All 28 platform methods and 15 event streams remain available. Existing public FBP operation queues, timeouts, Android disconnect delay, default MTU request, automatic Service Changed subscription and state caches are unchanged.

| Area | Preserved behavior |
| --- | --- |
| Adapter | Support means adapter presence; denied/null names become empty; absent adapter names become `N/A`; unavailable/denied state becomes unknown. Already-on `turnOn` returns false; already-off `turnOff` returns true. Enable submission and the later Activity result remain separate, including concurrent launch requests. |
| Permissions | Original per-operation permission sets and denial messages, API 21–30 location preflight before prompts, API 31+ bypass, optional fine location and serialized permission dialogs. Already-granted operations proceed while an unrelated dialog is open; queued requests recheck grants before prompting. Queries that previously did not prompt still do not prompt. Bond/PHY reads propagate permission failures rather than treating missing optional metadata as a false state. |
| Scanning | Original scan mode, legacy flag, all-supported PHYs, separate OR filters, absent empty masks, API 33 keyword AD filters and case-sensitive advertised-name checks. Last-payload-per-address dedup emits A/B/A, suppresses A/A regardless of RSSI, and applies the continuous divisor after keyword matching. Batch callbacks remain ignored. |
| Advertisements | Nullable platform/advertised names, TX-power sentinel, appearance, connectability fallback and short UUIDs. Every raw manufacturer payload is concatenated under the first company ID, including later company IDs, matching the original parser. |
| Connections | One FBP client per address; original already-connected/connecting return values; pending cancellation reason `23789258` / `connection canceled`; duplicate/intermediate/stale connection handling; negotiated MTU retained on duplicate connected callbacks. Auto-connect clients survive disconnection until explicitly canceled. Adapter shutdown synthesizes the existing disconnected events. Adapter-on scan cleanup precedes the public state event. |
| Attribute identity | Unique characteristics use FBP ID 0; duplicates in one service use native instance IDs; repeated matching services use ordinal positions across all characteristics. Included services remain flattened with their primary association; properties, descriptors and UUID normalization retain the original shape. |
| GATT | Connected/property checks, original submission results and errors, status/reason strings, MTU/RSSI callbacks, PHY version gate and priority values. Cache refresh returns true when reflection succeeds even if Android returns false. Compatibility handles survive refresh/Service Changed and failed discovery; successful discovery replaces the graph. |
| Writes | Default MTU 23; ordinary/no-response limit `min(MTU - 3, 512)`; long response writes up to 512; descriptors up to `MTU - 3`. Outbound values are cached by a typed FBP identity tuple before submission and removed for the matching write callback. FBP byte values remain mutable copies, isolated from AndroidBluetooth's immutable snapshots. |
| Notifications | Local registration followed by CCCD write; notify preference, forced indication checks, exact enable/disable values and descriptor-written callbacks. Missing CCCD returns false after successful local registration. `1801/2a05` reads/notifications trigger services reset; Android's newer callback does not add another FBP reset event. |
| Bonding | Connected check, already-bonded false, already-bonding true, original remove-bond behavior, synchronous one-shot PIN prearming and current/previous bond-state mapping. |
| Errors/events | Existing method-specific `PlatformException` codes/messages and native `androidException` translation with string stack details; async success/status fields remain separate from submission acceptance. No new FBP name-change events. Engine detach maps to the existing detach stream. `setOptions` remains a successful no-op. |

### Approved diagnostic difference

The user approved not retaining exact internal logs on 2026-11-06 and subsequently requested moving standard logging to the main FBP package. The removed Java backend's internal Logcat messages are no longer emitted. The public `FlutterBluePlusPlatform.logs` API, configured log level/color, and verbose FBP request/result/event logging remain; typed shared formatting replaces raw backend payload formatting. Direct platform-backend calls no longer produce standard FBP traces. Exception stacks naturally refer to the new native/Dart implementation. No intentional BLE operation, result, or callback contract change was approved or introduced.

## Direct AndroidBluetooth access

Applications can import AndroidBluetooth directly:

```dart
import 'package:android_bluetooth/android_bluetooth.dart' as android;

final adapter = android.BluetoothAdapter.shared;
final device = android.BluetoothDevice(fbpDevice.remoteId.str);
final clients = device.gattClients;
```

`gattClients` returns the original open clients for that address in the current Dart isolate, including FBP's client. It is an immutable list snapshot. Clients can be connecting, connected or disconnected for auto-connect; this is not an enumeration of other apps' connections. Closing a client or detaching the engine removes it from lookup. An explicit `connectGatt()` creates another registration.

`FlutterBluePlusAndroid.getGatt(remoteId)` additionally selects FBP's client, or null when none is tracked. No new `.instance` API was added. Typed callback streams accept additional listeners without consuming FBP's callbacks. Serialize GATT requests across both APIs. Use FBP for its managed lifecycle: directly closing clients or changing discovery/notifications can invalidate FBP's cached state. Device-scoped L2CAP and other features do not require another GATT client.

This migration does not change the Darwin backend. CoreBluetooth exposes `CBCentralManager.shared` and peripheral retrieval, but FBP must migrate to that shared manager before direct CoreBluetooth access can share FBP's Apple connection.

## Validation

- Shared logging suite: 8 tests covering typed request/result formatting, callback fan-out, colors/levels, readable discovery/scan data, operation/error preservation and Android/Darwin integration without duplicate Dart traces.
- Backend Dart suite: 49 tests on current Flutter and Flutter 3.10.6/Dart 3.0.6, covering operation/error/event regressions, advertisement parsing boundaries, serialized adapter events and error recovery, concurrency, lifecycle, logging, direct client lookup, write-payload isolation and mutable FBP byte compatibility. AndroidBluetooth separately passes its 62 shared Dart tests on both toolchains, including typed-listener replay/completion, UUID lookup/validation ordering and immutable collection, capability and ranging snapshots.
- Original-Java fixtures: complete service/characteristic/descriptor/property shapes for unique, duplicate and included graphs, plus advertisement conversion. `LegacyContractFixtureTest` generates/checks the committed fixture using the unchanged Java source; Dart tests independently compare their output with it.
- Native suites: 151 passed/1 skipped on the current host (including original-backend comparisons), and 70 passed/1 skipped on the minimum host. AndroidBluetooth Dart/native tests and opt-in native comparisons cover permission/PIN/location primitives, foreground-service validation order and launch payloads, strict/compatibility handle lifetime, partial GATT graph rollback, LE transport on API 21–22, enable launch/results, stale routing, detach/reattach, close/stop failure recovery and engine restart.
- Current-host FBP example APK and a Flutter 3.10.6 / Dart 3.0.6 / SDK 33 integration APK build. The minimum host also runs the backend's shared Dart tests. The current example's pre-existing Gradle 8.11.1 requires `-PskipDependencyChecks=true` with installed Flutter 3.47.5; the check does not require changing consumers' dependency constraints. The local build also uses sufficient heap and disables unnecessary Jetifier.
- Merged manifests retain app-owned declarations. Generated Android registration contains AndroidBluetooth once; FBP has no native registration. The moved license task still runs for FBP apps and is absent from standalone AndroidBluetooth builds.

Run the backend tests from `packages/flutter_blue_plus_android` with `flutter test`. Run the native parity suite from `packages/android_bluetooth/example/android`:

```sh
./gradlew :android_bluetooth:testDebugUnitTest :android_bluetooth:lintDebug \
  --init-script ../../tool/flutter_blue_plus_audit/compare.gradle --console=plain
```

Physical-device parity remains unverified. Before release, compare old/new scans, permissions/revocation, PIN pairing, duplicate/included services, long/no-response writes, notifications during refresh, cancellation races, auto-connect, power cycling and hot restart on at least two Android vendors. Include Android 5/API 21–22 if retained. Mock/Robolectric tests cannot establish OEM radio timing, pairing UI behavior or reconnect reliability.
