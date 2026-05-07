# FlutterBluePlus Android compatibility

Updated 2026-11-06 against `flutter_blue_plus_android` 9.0.5, its platform interface, and the public FlutterBluePlus Dart consumers.

## Implementation

FBP's Android backend now uses AndroidBluetooth. The compatibility policies live in Dart feature files, following the Linux backend's structure:

| File | Responsibility |
| --- | --- |
| `android_backend.dart` | Existing event streams, initialization, permission orchestration, lifecycle and backend diagnostics |
| `android_adapter.dart` | Adapter queries, enable/disable, system/bonded devices, bond state and PHY support |
| `android_scan.dart` | Scan submission, hardware filters, native delivery configuration, callback conversion and raw advertisement parsing |
| `android_device.dart` | Connection ownership, cancellation, auto-connect and bonding |
| `android_gatt.dart` | GATT operations, CCCDs, write limits/caches and callback conversion |
| `android_types.dart` | Attribute graphs and FBP identity/handle translation |
| `android_utils.dart` | Existing enum, GATT/HCI/status strings and small translation helpers |

The old Java backend is retained unchanged under [test/reference](../../flutter_blue_plus_android/test/reference/README.md), solely for comparison tests. It is not compiled into applications. FBP's plugin registration is Dart-only. AndroidBluetooth registers the native plugin once and hosts the existing FBP license build hook. The hook runs when the application lockfile contains FBP or its Android backend; standalone AndroidBluetooth builds do not acquire the FBP ping. Manifest ownership, min SDK 21 and Java 11 remain unchanged. No third-party runtime dependencies were introduced.

Feature mixins override the platform interface with typed `Bm*Request` parameters and result types. A shared generic `_run<T>` handles initialization, adapter availability and native error translation. Requests are not routed through method-name switches or unpacked from dynamic maps. GATT lookup uses a typed identity snapshot; maps remain at event serialization boundaries. Each event explicitly supplies its typed controller and decoder; there is no synthetic MethodChannel/MethodCall or string-based event router. Shared subscription cleanup and AndroidBluetooth constants keep lifecycle and protocol values in one place. Focused helpers separate GATT callback handling, request acceptance, write validation, notification selection, scan filter snapshots, native delivery configuration and advertisement parsing. Their ordering retains permission prompts, payload snapshots, duplicate filtering and callback delivery semantics.

Standard verbose request/result/event logging belongs to the main `flutter_blue_plus` package. Its typed `_invokePlatform<T, R>` logs the request and result, and central listeners log each callback once regardless of application listener count. Diagnostic serialization runs only at verbose level and formatting failures do not change operation or event delivery. Android and Darwin no longer duplicate these Dart traces; backend-specific diagnostics and native log-level forwarding remain. WinRT is unchanged as requested, so that external package can still print its own verbose console traces.

Adapter-state events are filtered and processed sequentially with `asyncMap`, awaiting scan/connection cleanup before the next state change. Generation checks suppress stale effects and cleanup errors after engine detach; subscription cancellation discards the old engine's queued events. Cleanup failures are forwarded to the listening zone and later events continue. Permission dialogs retain their separate future queue, while already-granted operations bypass it.

The FBP backend copies scan-filter lists and payload bytes when `startScan` is
called, before initialization or permission requests. This includes name and
remote-ID lists: clearing or editing the caller's lists while either step is
pending cannot change the submitted native filters. Filter order remains services,
remote IDs, names, API 33 keyword AD filters, manufacturer data and service data,
matching the former method-channel copy. Regression tests cover both waits,
replacement and clearing, original list order and independent payload bytes.

## Contract retained

All 28 platform methods and 15 event streams remain available. Existing public FBP operation queues, timeouts, Android disconnect delay, default MTU request, automatic Service Changed subscription and state caches are unchanged.

| Area | Preserved behavior |
| --- | --- |
| Adapter | Support means adapter presence; denied/null names become empty; absent adapter names become `N/A`; unavailable/denied state becomes unknown. Already-on `turnOn` returns false; already-off `turnOff` returns true. Enable submission and the later Activity result remain separate, including concurrent launch requests. |
| Permissions | Original per-operation permission sets and denial messages, API 21–30 location preflight before prompts, API 31+ bypass, optional fine location and serialized permission dialogs. Already-granted operations proceed while an unrelated dialog is open; queued requests recheck grants before prompting. Queries that previously did not prompt still do not prompt. Bond/PHY reads propagate permission failures rather than treating missing optional metadata as a false state. |
| Scanning | Original scan mode, legacy flag, all-supported PHYs, separate OR filters, absent empty masks, API 33 keyword AD filters and case-sensitive advertised-name checks. Native delivery emits A/B/A, suppresses A/A regardless of RSSI when continuousUpdates is false, and applies the per-device continuous divisor before Dart keyword matching. Repeated starts reset software history without replacing the active radio scan. Batch callbacks remain ignored. |
| Advertisements | Nullable platform/advertised names, TX-power sentinel, appearance, connectability fallback and short UUIDs. Every raw manufacturer payload is concatenated under the first company ID, including later company IDs, matching the original parser. |
| Connections | One FBP client per address; original already-connected/connecting return values; pending cancellation reason `23789258` / `connection canceled`; duplicate/intermediate/stale connection handling; negotiated MTU retained on duplicate connected callbacks. Auto-connect clients survive disconnection until explicitly canceled. Adapter shutdown synthesizes the existing disconnected events. Adapter-on scan cleanup precedes the public state event. |
| Attribute identity | Unique characteristics use FBP ID 0; duplicates in one service use native instance IDs; repeated matching services use ordinal positions across all characteristics. Included services remain flattened with their primary association; properties, descriptors and UUID normalization retain the original shape. |
| GATT | Connected/property checks, original submission results and errors, status/reason strings, MTU/RSSI callbacks, PHY version gate and priority values. Cache refresh returns true when reflection succeeds even if Android returns false. Compatibility handles survive refresh/Service Changed and failed discovery; successful discovery replaces the graph. |
| Writes | Default MTU 23; ordinary/no-response limit `min(MTU - 3, 512)`; long response writes up to 512; descriptors up to `MTU - 3`. Outbound values are cached by a typed FBP identity tuple before submission and removed for the matching write callback. Rejected submissions roll back their cached value, and disconnect discards that device's pending values (approved corrections). FBP byte values remain mutable copies, isolated from AndroidBluetooth's immutable snapshots. |
| Notifications | Local registration followed by CCCD write; notify preference, forced indication checks, exact enable/disable values and descriptor-written callbacks. Missing CCCD returns false after successful local registration. `1801/2a05` reads/notifications trigger services reset; Android's newer callback does not add another FBP reset event. |
| Bonding | Connected check, already-bonded false, already-bonding true, original remove-bond behavior, synchronous one-shot PIN prearming and current/previous bond-state mapping. |
| Errors/events | Existing method-specific `PlatformException` codes/messages and native `androidException` translation with string stack details; async success/status fields remain separate from submission acceptance. No new FBP name-change events. Engine detach maps to the existing detach stream. `setOptions` remains a successful no-op. |

### Approved diagnostic difference

The user approved not retaining exact internal logs on 2026-11-06 and subsequently requested moving standard logging to the main FBP package. The removed Java backend's internal Logcat messages are no longer emitted. The public `FlutterBluePlusPlatform.logs` API, configured log level/color, and verbose FBP request/result/event logging remain; typed shared formatting replaces raw backend payload formatting. Direct platform-backend calls no longer produce standard FBP traces. Exception stacks naturally refer to the new native/Dart implementation. No intentional BLE operation, result, or callback contract change was approved or introduced.

### Approved automatic cleanup correction

After a terminal disconnect, FBP cancels its GATT subscription and closes the
native client without delaying the existing disconnect event. Failures in this
automatic cleanup are caught and logged when the configured level includes errors;
they no longer escape as unhandled asynchronous exceptions. An engine-generation
check suppresses diagnostics from a detached session. Explicit AndroidBluetooth
`close()` errors still propagate and can be retried; FBP operations that await
cleanup, including pending-connect cancellation, retain their existing exception
translation. Failed native closes remain retryable through the retained native
client. This correction was explicitly approved during review. Six regressions
cover normal and auto-connect disconnection, enabled/disabled diagnostics,
unchanged event reasons, explicit errors/retry and engine detach.

Adapter-shutdown cleanup now attempts every captured client in its original
order even when an earlier close fails, then forwards the first error with its
original stack through the existing adapter-event error path. Disconnect events
still precede cleanup, and subsequent adapter events wait for every cleanup
attempt to finish. Three multi-device regressions cover an early failure,
multiple failures and a delayed later close. The original Java
`disconnectAllDevices()` loop also stopped on the first exception; correcting
that behavior was explicitly approved during review.

### Failed connection replacement

A disconnected auto-connect client remains retained while a replacement GATT
registration is being opened. If registration fails, FBP restores that original
client, including connection-state changes received during the pending attempt.
Its reconnect callbacks, direct lookup and explicit disconnect remain usable.
The existing registration and permission errors are preserved. This restores the
former Java backend's failure behavior rather than leaving an open native client
unmanaged.

Successful replacement retires the old client and ignores its subsequent
callbacks. Cancellation or adapter shutdown retires both registrations, including
when the pending open fails; rollback cannot restore a canceled client. Cleanup
attempts every retained client even if an earlier close fails, then reports the
first cleanup error. Nine regressions cover registration/permission failures,
reconnection during replacement, successful replacement, pending cancellation and
shutdown with successful/failed opens, and cleanup failure with explicit retry.

### Disconnect submission failures

Pending and disconnected auto-connect clients remain tracked until native
`disconnect()` accepts the request. Their callback subscriptions are paused during
cancellation, including subscriptions created by a pending registration. A failed
submission resumes queued callbacks and retains the client for retry, preserving
the existing native error translation without emitting a synthetic cancellation.
Successful cancellation retires the client and discards queued callbacks before
emitting its existing single canceled event. Shutdown or engine detach can still
retire that registration while submission is pending; a later failure cannot
restore it. Overlapping cancellation does not submit another disconnect.

The former Java backend removed pending connections only after native disconnect
returned, so losing those clients on submission failure was a migration regression.
Its disconnected auto-connect branch removed tracking before submission and already
had the same bug. Correcting that branch was explicitly approved during review.
Eight regressions cover pending normal/auto-connect and disconnected auto-connect
retries, queued callback delivery on failure, unchanged successful cancellation,
shutdown/detach during submission, and overlapping requests.

### Approved scan sampling order

Native sampling deliberately runs before Dart keyword filtering. Every result
admitted by Android's real scan filters advances its per-device counter when
continuous updates are enabled, even if Dart later rejects its name. The first
native result is sent, but the first matching result may be skipped with a divisor
greater than 1. This ordering change from the reference backend was explicitly
approved to keep software filter APIs out of the native packages. Duplicate
suppression remains native when continuous updates are disabled; the divisor then
stays at 1. Batch callbacks remain ignored without advancing the counter.

## Direct AndroidBluetooth access

Applications can import AndroidBluetooth directly:

```dart
import 'package:android_bluetooth/android_bluetooth.dart' as android;

final adapter = android.BluetoothAdapter.shared;
final device = android.BluetoothDevice(fbpDevice.remoteId.str);
final clients = device.gattClients;
```

`onCharacteristicWrite.value` exposes the native characteristic-value snapshot for reliable-write verification, including null/empty values and failure status. FBP continues to report the bytes it submitted; native response bytes do not replace FBP's cached write payload. Tests cover both views of the same callback.

Rejected characteristic and descriptor submissions, including notification CCCD
writes, discard their provisional payload instead of leaving it for a later native
write callback. Both nonzero native statuses and thrown exceptions roll back the
cache, retaining an earlier accepted write still awaiting its callback. Cleanup
only changes the entry if that submission still owns it. Accepted writes retain
their bytes even when the eventual GATT callback reports failure; unmatched native
write callbacks retain FBP's empty payload. Existing method-specific rejection
messages and native exception translation remain unchanged. This corrects a bug
also present in the former Java backend and was explicitly approved during review.
Regression tests cover API 33 statuses, pre-33 boolean normalization, permission
errors, later serialized native writes, accepted retries, failed completion
callbacks, pending accepted writes and CCCD submissions.

Disconnect also discards that device's pending characteristic and descriptor write
payloads before emitting its connection-state event. Android may never complete an
accepted write when the link drops; its bytes must not appear in a later native
write's callback after reconnect. This applies both to replacement GATT clients
and auto-connect clients that retain their registration. Other devices' pending
writes remain intact, and accepted FBP writes after reconnect still report their
own payloads. Six regression tests cover these cases. This is another explicitly
approved correction to a cache-lifetime bug in the former Java backend.

`gattClients` returns the original open clients for that address in the current Dart isolate, including FBP's client. It is an immutable list snapshot. Clients can be connecting, connected or disconnected for auto-connect; this is not an enumeration of other apps' connections. Closing a client or detaching the engine removes it from lookup. An explicit `connectGatt()` creates another registration.

`FlutterBluePlusAndroid.getGatt(remoteId)` additionally selects FBP's client, or null when none is tracked. No new `.instance` API was added. Typed callback streams accept additional listeners without consuming FBP's callbacks. Serialize GATT requests across both APIs. Use FBP for its managed lifecycle: directly closing clients or changing discovery/notifications can invalidate FBP's cached state. Device-scoped L2CAP and other features do not require another GATT client.

This migration does not change the Darwin backend. CoreBluetooth exposes `CBCentralManager.shared` and peripheral retrieval, but FBP must migrate to that shared manager before direct CoreBluetooth access can share FBP's Apple connection.

## Validation

- Shared logging suite: 8 tests covering typed request/result formatting, callback fan-out, colors/levels, readable discovery/scan data, operation/error preservation and Android/Darwin integration without duplicate Dart traces.
- Backend Dart suite: 94 tests on current Flutter and Flutter 3.10.6/Dart 3.0.6, covering operation/error/event regressions, advertisement parsing boundaries, serialized adapter events and error recovery, concurrency, lifecycle, logging, direct client lookup, write-payload isolation, rejected-submission rollback and disconnect cleanup across normal/auto-connect reconnects, handled automatic-close failures with explicit error/retry preservation, complete multi-device shutdown cleanup after failures, failed connection replacement with retained callbacks and cancellation/shutdown cleanup, retryable failed disconnect submissions with queued callbacks and shutdown/detach protection, scan-filter snapshots across initialization/permission waits, native scan-delivery options and mutable FBP byte compatibility. AndroidBluetooth separately passes its 78 shared Dart tests on both toolchains, including delivery transport/validation, typed-listener replay/completion, UUID lookup/validation ordering, nullable alias clearing, safe optional fields on PIN-result events, nullable unknown identity addresses, unchanged public/random identities and permission errors, supplied broadcast extras and immutable collection, capability and ranging snapshots.
- Original-Java fixtures: complete service/characteristic/descriptor/property shapes for unique, duplicate and included graphs, plus advertisement conversion. `LegacyContractFixtureTest` generates/checks the committed fixture using the unchanged Java source; Dart tests independently compare their output with it.
- Native package suites: 217 passed/1 skipped on the current host and 106 passed/1 skipped on the minimum host. Integer argument tests cover signed 32-bit boundaries/defaults, rejected narrowing of oversized scan modes and connection-state arrays, invalid_argument propagation before native side effects, valid retries and preserved 64-bit report delays. Advertising-stop tests additionally cover pending cancellation without callbacks, queued/late callback rejection, normal terminal-event ordering, startup failures, stop-submission retries and independent sets. Dart advertising tests verify stream completion with early/late listeners, concurrent/repeated stops and terminal callbacks arriving before the native reply. An API 36 regression bypasses Robolectric's synthesized identity to exercise the real SDK fallback with Bluetooth disabled, preserving a null identity address and ADDRESS_TYPE_UNKNOWN through the native bridge. The original-backend comparison probes remain separately opt-in. AndroidBluetooth Dart/native tests and those comparison probes cover permission/PIN/location primitives, foreground-service validation order and launch payloads, alias setting/clearing, strict/compatibility handle lifetime, partial GATT graph rollback, LE transport on API 21–22, enable launch/results, stale routing, detach/reattach, close/stop failure recovery and engine restart. Retired-handle tests additionally verify collection of obsolete framework GATT graphs while registrations remain open, stable late-callback parent IDs and weak identity behavior for equal-but-distinct objects. GATT server tests also preserve removed included-service metadata without reactivating handles during repeated queries or later successful/failed add callbacks, while retaining active shared descendants. Scan-delivery tests require 100 channel frames and snapshots for 1,000 advertisements with divisor 10, plus raw-advertisement counting before Dart keywords, duplicate suppression, per-device/registration isolation, restart/update resets, batch behavior, raw defaults and invalid-option recovery. Presence-delivery regressions preserve FIRST_MATCH/MATCH_LOST arrival, disappearance and reappearance callbacks under every delivery policy for default and independent scans, retain later transitions after policy updates without restarting the radio scan, and reject late transitions after stop or engine restart. FBP uses ALL_MATCHES, whose existing sampling behavior is unchanged.
- Current-host FBP example APK and a Flutter 3.10.6 / Dart 3.0.6 / SDK 33 integration APK build. The minimum host also runs the backend's shared Dart tests. The current example's pre-existing Gradle 8.11.1 requires `-PskipDependencyChecks=true` with installed Flutter 3.47.5; the check does not require changing consumers' dependency constraints. The local build also uses sufficient heap and disables unnecessary Jetifier.
- Merged manifests retain app-owned declarations. Generated Android registration contains AndroidBluetooth once; FBP has no native registration. The moved license task still runs for FBP apps and is absent from standalone AndroidBluetooth builds.

Run the backend tests from `packages/flutter_blue_plus_android` with `flutter test`. Run the native parity suite from `packages/android_bluetooth/example/android`:

```sh
./gradlew :android_bluetooth:testDebugUnitTest :android_bluetooth:lintDebug \
  --init-script ../../tool/flutter_blue_plus_audit/compare.gradle --console=plain
```

Physical-device parity remains unverified. Before release, compare old/new scans, permissions/revocation, PIN pairing, duplicate/included services, long/no-response writes, notifications during refresh, cancellation races, auto-connect, power cycling and hot restart on at least two Android vendors. Include Android 5/API 21–22 if retained. Mock/Robolectric tests cannot establish OEM radio timing, pairing UI behavior or reconnect reliability.
