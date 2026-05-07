# FlutterBluePlus Darwin compatibility

The Darwin backend now implements FBP operations in Dart using `core_bluetooth`.
CoreBluetooth owns native registration, CBCentralManager/CBPeripheral delegates,
object registries and framework linkage. The federated backend registers only in
Dart. Neither native package introduces third-party runtime dependencies.

The reference is the Dart Darwin backend and Objective-C implementation at
commit `8208c93a`. The original native implementation is retained verbatim under
`packages/flutter_blue_plus_darwin/test/reference` as a review reference; it is
not compiled into the plugin.

## Preserved behavior

| Area | Contract retained |
| --- | --- |
| Errors | Current `FlutterBluePlusException` and backend `PlatformException` behavior. No new shared error model. Native callback codes and messages, including unknown codes, remain intact. |
| Initialization | Lazy manager creation; setOptions/setLogLevel do not create a manager. Established native connections from the previous Dart session are canceled before accepting operations after hot restart. Fresh managers preserve OS-restored connections; connections already made through CoreBluetooth in the current Dart session are adopted. Cleanup disconnect callbacks are not forwarded as new FBP events. |
| Manager options | Same default power alert and restoration identifier (`flutterBluePlusRestoreIdentifier`). As in the reference, false showPowerAlert omits the native option. Changes after manager creation do not reconfigure that manager. |
| Adapter | Same state mapping, device name on iOS and `Mac Bluetooth Adapter` on macOS. `isSupported` reports manager availability, including while the adapter is off or unauthorized. |
| Scan | Snapshot submitted filters before initialization, matching the former method-channel copy. Radio service filtering only without custom filters; additive service, ID, exact name, keyword, manufacturer and service-data matching. Native per-device sampling counts all Apple discoveries, beginning at zero, before serialization/channel delivery; custom filters then run in Dart. Native duplicate scanning remains controlled by continuousUpdates. |
| Data masks | Explicit bit masks and the reference backend's default mask byte of 1 are preserved. Short advertisement data is rejected safely. |
| Scan data | Uppercase peripheral identifiers, optional names/power/connectability, manufacturer ID in little endian with its first two bytes removed, service UUIDs/data and RSSI. |
| Connections | Pending connect returns true, already connected returns false, already disconnected returns false. Native autoConnect option remains version-gated. Error-free disconnects use FBP's existing canceled reason; failed connects without an error retain null reasons. |
| Identifier matching | Native FBP identifiers remain uppercase. Historical case-sensitive operation lookup is retained; the new native-access getPeripheral helper also accepts lowercase identifiers. |
| Adapter off | Stop native scanning, clear connection/operation state and synthesize `1573878 / Bluetooth turned off` disconnects. |
| Discovery | Wait for included-service, characteristic and descriptor callbacks before reporting one final result (approved correction to the reference's premature/duplicate completion). Empty discovery completes. The first discovery error wins; CBErrorDomain/UUIDNotAllowed remains nonfatal. Published service results retain the reference's top-level service layout. |
| Attribute identity | Within one matching service, instance IDs count characteristics with the same UUID. Across duplicate matching services, they count all characteristics in service order. Included-service lookup retains primary-service context. |
| Writes | Original property checks and error strings, 512-byte cap, long-write selection and native maximum payload limits. Callback values echo copied submitted bytes. Writes without response complete on native readiness callbacks; current native readiness is checked before submission. |
| Notifications | Same native selection, with forceIndications ignored on Darwin. Notification-state callbacks synthesize the reference four-byte little-endian CCCD value, including notify-bit precedence when both properties exist. |
| Descriptors | NSData bytes, UTF-8 strings and four-byte little-endian integer values. Descriptor writes retain the MTU payload limit and submitted-value echo. |
| Missing characteristic values | The reference Dart decoder rejected null values rather than publishing an empty read. These callbacks remain rejected; changing this to report the native error immediately is deferred to an explicit behavior change. |
| MTU | Maximum write-without-response payload capped at 512 plus 3 bytes. Poll every 100ms after connection, reset the settling window on a change, stop after 20 stable ticks and rearm after another connection. |
| Restoration | Restore manager state, reconnect disconnected peripherals, adopt connected peripherals, rehydrate cached GATT objects and notification callbacks, and continue discovery. |
| Other callbacks | Names, service resets and RSSI retain the same FBP event types. Peripheral callbacks from unrelated native devices do not become FBP connection events. |
| Unsupported operations | Methods not overridden by the original Dart backend keep the platform interface's default return values. The unused error branches in the former Objective-C channel do not define those Dart methods' behavior. |

Standard request/result/event logging remains in the main FBP package. The old
Objective-C-only debug messages are removed; exact diagnostic text was explicitly
accepted as nonessential. WinRT is unchanged.

## Approved descriptor read correction

In the reference native implementation, a descriptor callback with a missing
value passes nil into an Objective-C dictionary literal, which can raise an
uncaught exception. The migrated backend can instead deliver the original native
error through the existing `FlutterBluePlusException` when the callback reports
failure. The user explicitly approved reporting the native error for this case. The public
FBP integration test covers that correction; it does not introduce a new exception
type or the deferred error API redesign.

## Lifecycle and implementation structure

FBP maps `continuousDivisor` directly to `scanForPeripherals(advertisementDivisor:)`.
This is the sole custom scan-delivery argument in CoreBluetooth. The package
retains Apple's service filters and radio options and exposes no software filter
predicates. Native code counts all Apple discoveries per device and serializes
only sampled discoveries. FBP then applies its additive filters in Dart, retaining
the legacy default mask byte of 1. No second sampling step runs in Dart.
`continuousUpdates` still controls native `allowDuplicates`; when disabled, the
divisor stays at 1. Each scan submission resets its counters. Direct CoreBluetooth
scans default to divisor 1. Listeners on FBP's shared manager see its sampled
stream; an isolated manager supports independently configured scans.

The user explicitly approved native sampling before Dart filtering, replacing the
reference backend's filter-then-divisor order. An advertisement rejected by Dart
still consumes a sampling slot. With a divisor greater than 1, the first matching
advertisement may be skipped. Filters themselves retain their existing matching
semantics and are not sent to CoreBluetooth.

The Dart backend separates adapter operations, scanning, connections, discovery,
peripheral callbacks and GATT requests. Typed identity objects construct FBP
responses directly; the backend does not build maps merely to decode them again.

Each connection owns a small MTU subscription. It samples every 100ms, serializes
its native queries through asyncMap, emits changes and stops after 20 unchanged
samples. Disconnect and disposal cancel delivery even while a query is pending.
A failed query is handled as a backend diagnostic and stops that monitor.

Discovery submissions belong to a discovery object. Replacing it or clearing the
connection invalidates late submission failures. Completion waits separately for
included-service, characteristic and descriptor callbacks. A service shared by
multiple parents is queried once per discovery. Subrequest callbacks without a
matching pending operation do not restart discovery or emit another result after
completion/failure. Included-service errors are recorded before the final result;
the first error wins, and restricted UUID errors remain nonfatal. Restoration
keeps cached services and notification state immediately available while real
native discovery callbacks complete the refreshed graph. These changes correct
premature and duplicate results also present in the former Objective-C backend,
and were explicitly approved during review. Channel tests cover both callback
orders, empty characteristics, nested/shared services, errors, submission failure
and retry, duplicate callbacks and restoration. A public FBP integration test
verifies that discoverServices remains pending and then throws the existing native
exception for included-service failure.

Partial included-service, characteristic and
descriptor snapshots also prune obsolete handles from the Dart cache and native
registries. Service invalidation releases the obsolete native graph after
capturing the callback snapshot. Pruning preserves reachable included services,
local GATT and other managers' objects, and tolerates included-service cycles.
Late discovery callbacks cannot retain invalidated or orphaned attributes again.

Both native disconnect callback forms remove the disconnected peripheral's remote
attribute handles before forwarding the event. Dart clears that peripheral's GATT
caches and notification flags before delivering the disconnect callback. Peripheral
identity, disconnect errors, timestamps and reconnect metadata remain intact;
other native peripheral instances and local GATT stay registered. After reconnect,
FBP requires fresh discovery, matching the original native attribute invalidation.
This correction was explicitly requested during review. No extra FBP notification
or services-reset events are synthesized.

Adapter transitions away from powered-on perform the same remote GATT cleanup
even when CoreBluetooth does not send individual disconnect callbacks. Cached
peripherals become disconnected and scanning stops before the state callback;
native peripheral objects are retired below powered-off and must be retrieved or
discovered again after recovery. FBP still emits its existing single adapter-off
disconnect with reason `1573878 / Bluetooth turned off`, and requires fresh GATT
discovery after reconnecting. Direct peripheral servers retire local publications
on power-off/reset, clear subscriptions and release pending ATT requests when
leaving powered-on. Services require explicit re-publication after recovery;
late add callbacks cannot revive the cleared database. These corrections were
explicitly approved during review, and cleanup remains scoped to each manager.

Initialization failures roll back subscriptions and device state and can be
retried. Disposal detaches listeners, cancels per-connection work and prevents
subsequent backend operations, without disposing the shared native manager.

CoreBluetooth's buffered startup event replay reports callback exceptions through
the current Dart zone, matching ordinary stream delivery. A user delegate exception
does not turn successful native creation into a retry or discard its native manager
ID. Explicit disposal, including disposal initiated by the throwing callback,
continues to release that manager exactly once.

Direct CoreBluetooth discovery exposes optional `overflowServiceUUIDs` and
`solicitedServiceUUIDs` in `AdvertisementData`. Native serialization and Dart
decoding retain these lists separately from `serviceUUIDs`, including absence,
empty lists and full UUIDs. FBP continues to filter and report its original
`serviceUUIDs` list; these native-access fields do not change FBP scan behavior.

Writes capture a connection token before querying the payload limit or write
readiness. Disconnecting, powering the adapter off or disposing the backend
invalidates that token. A query from a previous connection cannot submit a write
on a replacement connection; it reports the existing operation-specific
`device is disconnected` error. Connect also rechecks disposal and adapter power
after peripheral retrieval, before tracking the peripheral or submitting the
native connection. If Bluetooth turned off during lookup, it reports the existing
operation-specific powered-off error and does not submit a connection.
These lifecycle race corrections were explicitly requested during review.

Isolation remains an optional CoreBluetooth capability for components that need
independent scan configuration and manager lifetime. FBP itself uses only the
shared manager. Native peripheral registries belong to their manager; requests
validate attribute ownership, callbacks route by native object identity and
retired managers do not receive or repopulate callback state.

Direct `CBPeripheral` operations check their central manager's disposal state
before submitting native requests. Write-limit and write-readiness queries also
check after the native reply; disposed queries fail with `StateError` and cannot
update cached readiness. Local service removals capture the registrations present
at submission and clear only those registrations on success. Newer adds survive
older removal replies, including reuse of the same mutable service object;
failed submissions cannot restore a registration already removed. These corrections
were explicitly requested during review and retain live-operation method arguments
and native callback delivery.

Central-manager operations recheck disposal after initialization and before
applying delayed scan or retrieval results. Disposing during creation releases
the eventual native manager without forwarding buffered startup callbacks or
submitting queued work. Disposed managers retain neither scanning state nor
cached connections. Native attribute cleanup removes descriptors and
characteristics before services, while their weak parent links still resolve;
disposal and discovery pruning share that cleanup implementation. Local GATT and
other managers' native objects remain available.

Peripheral/server mode tracks local service roots by manager and preserves
included services still reachable through another root. Removing services,
clearing a manager or disposing it releases only its own obsolete GATT objects
and client-reference metadata. Failed adds are also released after capturing
their callback snapshot. Restoration retains identity metadata for services
that remain present. Late callbacks do not revive removed services.

Local characteristic snapshots include their native permission bits, including
encryption requirements and explicit zero permissions. Add callbacks and
restoration therefore preserve permissions on retained Dart objects, and
republishing a removed service submits the same access permissions. Mutable
descriptor construction converts `FlutterStandardTypedData` to native `Data`,
preventing the native type exception for valid byte-valued Presentation Format
descriptors; string descriptors keep their existing representation. These
server-mode corrections were explicitly requested during review.

Before constructing a new local service graph, descriptor validation requires a
string for User Description (`0x2901`) and native/typed byte data for Presentation
Format (`0x2904`) and custom 128-bit descriptors. Valid Range (`0x2906`) requires
byte data with an even length. Missing, incorrectly typed or invalid-length values return `invalid_args`
instead of reaching native assertions. Validation covers included services and
runs before allocating any service/attribute objects or registering identity
metadata. Reused native service definitions remain unchanged. The rejected
service can be corrected and submitted again. This error correction was explicitly
requested during review and does not affect FBP central-mode operations.

Native publication reuses included services from the submitting manager's graph,
using handles or client references. This preserves native and Dart handles when
publishing parents of an existing service or sharing new services across branches.
Foreign live handles are rejected before allocating or publishing the graph;
retired graphs can still be rebuilt as new native objects. Final-root cleanup and
failed-parent cleanup preserve included services that remain owned elsewhere in
the same manager.

Server connection-latency requests resolve manager-owned centrals observed through
ATT requests, subscription/unsubscription callbacks, restored subscribers and
L2CAP peers. They no longer require a notification subscription. Answered ATT
requests are still released; observed centrals are tracked separately and cleared
when the manager leaves the powered-on state or is disposed. Unknown and foreign
centrals remain rejected. These corrections were explicitly requested during review
and do not change FBP's central-mode behavior.

Dart restoration shares local service objects by native handle throughout the
restored graph. Roots that include the same service share its characteristics,
descriptors and subscription state, retaining existing Dart objects for handles
that survive another restoration. This reconciliation is scoped to one manager
and keeps no separate long-lived graph cache.

Notification targeting preserves `onSubscribedCentrals: null` as native `nil`
(all subscribed centrals) and forwards explicit empty or unmatched selections as
empty native lists. Previously an empty selection became `nil` and could broadcast
to unintended subscribers. These server-mode corrections were explicitly requested
during review; FBP's central-mode operations do not use these server methods.

Dart server callbacks resolve characteristic handles throughout the included
service graph, preserving the tracked object identity for ATT reads, writes,
subscriptions and unsubscriptions. Traversal uses service identity to tolerate
shared or cyclic included-service references; unknown handles remain ignored.
These included-service and disposal corrections were requested during review.

ATT requests carry their receiving manager's ID and an opaque request handle.
Service removal, value updates, connection-latency lookup and ATT responses
validate manager ownership. A foreign or retired handle reports the existing
`invalid_args` error before reaching CoreBluetooth. Read responses release their
individual request. Each write callback is one atomic batch: one response to a
member releases all members, for either success or failure. Further responses to
that batch report `invalid_args`; unrelated reads and write batches remain
pending. Disposing a manager releases all its unanswered read and write requests.
These requested fixes affect direct CoreBluetooth peripheral/server use.

The Dart peripheral manager exposes `ready` and `isInitialized`, retries failed
native creation on the next operation, and cancels the failed attempt's listener.
Disposal joins concurrent cleanup calls, clears services and advertising state,
releases the shared instance and rejects new or queued operations with
`StateError`. Disposal during creation still releases the eventual native manager
without allowing the queued operation to run. These lifecycle and write-batch
corrections were requested during review.

L2CAP channels retain their owning manager IDs and stream-close state. Closing
both streams releases the native channel; closing one leaves the other usable.
Central and peripheral-manager disposal closes and releases their channels once
no other manager owns them. Repeated snapshots preserve the close state.
Handles identify a channel lifetime independently of its native memory address.
Subsequent operations on a released handle report the existing `invalid_args`
platform error, even if a later allocation reuses that address. This requested
resource cleanup affects direct CoreBluetooth L2CAP use; the FBP GATT path and
Dart stream API signatures remain unchanged.

L2CAP input and output each use a background run loop, following
[Apple's stream scheduling guidance](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Streams/Articles/ReadingInputStreams.html).
Stream preparation, readiness checks, I/O and close run on that stream's thread.
Requests are processed in submission order; input and output progress independently.
Flutter results return on the main thread. Reads with a positive maximum length
return empty bytes only at clean EOF. Negative native reads report
`PlatformException(code: 'stream_error')` with the native message and NSError
domain/code details when available. Write results retain the native byte count,
including partial writes and -1 on write failure.

Opening and unpublishing L2CAP channels validate PSM arguments using exact
unsigned 16-bit conversion. Negative, oversized, fractional and nonfinite inputs
return `invalid_args` before any native channel operation. Representable values
are forwarded unchanged. Reads use `FlutterStandardTypedData` to encode byte
buffers compactly instead of serializing individual integers. Dart retains its
existing buffer copy, zero byte offset, legacy list decoding, EOF and error
semantics. These direct CoreBluetooth corrections were requested during review;
FBP's GATT operations do not use these L2CAP methods.

Native L2CAP reads allocate at most 64 KiB of scratch space per operation instead
of allocating the entire requested maximum. The Dart argument remains an upper
bound, with no new public size limit: larger requests can return partial chunks.
Native regressions exercise the full method handler with Int.max and small/boundary
sizes, preserve every byte across successive partial reads, leave unread bytes
available and retain clean EOF. The Dart transport regression preserves large
64-bit upper bounds and partial replies without padding or extra native reads.

Close cancels queued I/O waiting for readiness with `stream_closed`. Stream-close
and final-owner manager-disposal futures complete after native stream cleanup.
Closing channels retain their existing handle until cleanup finishes, so a late
snapshot cannot register a new lifetime for the same closing stream pair. Closing
one direction preserves the other. These asynchronous I/O and read-error
corrections were explicitly requested during review; they affect direct
CoreBluetooth L2CAP use.
Releasing the owning plugin also closes its stream workers and cancels queued
I/O, so worker threads do not keep abandoned channels alive.

## Native access and ownership

After FBP initialization, `FlutterBluePlusDarwin.centralManager` is identical to
`CBCentralManager.shared`. `FlutterBluePlusDarwin.getPeripheral(remoteId)` returns
the tracked CoreBluetooth object, including pending and previously known devices.
GATT objects retain identity across snapshots using native handles, including
included services; separate stream subscribers can observe the same objects.

Initialize FBP before issuing native operations on that shared manager, so startup
cleanup does not cancel native work. Configure options before first access to the
manager. Serialize GATT requests on the same peripheral across both APIs. Native
scan, discovery, notification and connection mutations affect FBP. Avoid disposing
the shared manager while the backend uses it. Independent CoreBluetooth use can
instead choose `CBCentralManager.createIsolated()`.

## Packaging and verification

Dart/Flutter dependency constraints remain Dart 3.0 / Flutter 3.7. CoreBluetooth's
Dart constraint was lowered after verifying its source on Dart 3.0. Native
package deployment targets remain iOS 12.0 and macOS 10.14. CoreBluetooth retains
its existing Swift 5.9 build configuration and both CocoaPods and SPM metadata.

Run backend callback/behavior tests with `flutter test` in
`packages/flutter_blue_plus_darwin`. Run shared logging/integration tests with
`flutter test` in `packages/flutter_blue_plus`. Native registry tests can be run
on macOS without Bluetooth hardware or third-party test dependencies:

```sh
zsh packages/core_bluetooth/tool/test_native.zsh /path/to/flutter
```

The native harness uses Objective-C selector doubles for framework objects. It
checks same-UUID manager isolation, callback routing, handle ownership, disposal,
suppression of late callbacks, full and partial GATT replacement, repeated
invalidation, actual object release, and preservation of local and shared graphs.
L2CAP tests cover both close orders, use of the remaining stream, object release,
stale handles, both manager roles, shared ownership, repeated snapshots and native
address reuse.
L2CAP I/O tests use real Foundation streams and local pipes to verify main-thread
responsiveness, FIFO delivery, native error details versus EOF, bounded write
counts, cancellation under input/output backpressure, both manager roles, empty
operations and snapshots during concurrent close.
Owner-release coverage verifies that pending reads do not retain the plugin and
receive cancellation when the plugin is released.
Peripheral-manager tests cover independent services with matching UUIDs, scoped
remove/clear/dispose, client-reference cleanup, foreign-handle rejection, request
value preservation, actual read/write request deallocation, failed and pending
adds, shared included services, restoration and late callbacks.
Write-batch tests exercise success and failure replies through either member,
sibling deallocation, duplicate rejection and preservation of unrelated requests.
Central lifecycle tests cover startup disposal, delayed scan and retrieval
responses, readiness callbacks and rejection of disposed operations. Included
service tests cover nested ATT requests, subscriptions, tracked object identity
and cyclic references. Peripheral-manager state tests verify that late add callbacks
remain observable without restoring removed services, failed submissions release
pending adds, and successful advertising stops clear cached state while preserving
newer starts, failed-stop state and disposal. Native disposal tests verify actual object deallocation
after cached graphs disappear and preservation until the final manager releases
a shared native peripheral.
Additional lifecycle tests cover every peripheral request during and after central
disposal, stale query replies, overlapping service removals and adds, failed re-adds,
handle aliases and replacement restoration snapshots.
Shared-restoration tests cover object and parent identity, subscription consistency
after removing one root, ATT callback identity, repeated restoration values,
caller-owned objects and isolation across managers. Native notification tests
cover absent/null, empty, selected, duplicate, unmatched and invalid recipients,
including characteristics without subscribers.
Publication tests cover stable included-service and attribute handles, pending
client references, shared new graphs, foreign-handle rejection without leaked
metadata, retired-graph re-publication and final-root release. Central tracking
tests cover all observation sources, answered ATT requests, manager isolation for
matching UUIDs, actual object release on power-off and disposal, and late callbacks.

Scan snapshot tests mutate name, remote-ID and keyword lists immediately after
submission with both initialized and pending managers, then mutate them again
after startup. They also verify that adding a custom filter after submission
cannot change the native service filter selected for that scan.

Native scan-delivery tests count actual event-sink frames and peripheral snapshots:
1,000 advertisements with divisor 10 require 100 frames and 100 snapshots.
They cover every discovery advancing its counter regardless of name or service
data, interleaved devices, separate managers, scan restarts, raw defaults and
invalid-option recovery. Dart tests verify native scan options plus the divisor,
filter snapshots and that delivered callbacks are filtered but not sampled a
second time. Filtering, including names, empty keywords and byte masks, stays in
Dart.

Native central-option tests submit zero, fractional and positive connection start
delays, and round-trip empty/nonempty solicited-service UUID lists through scan
submission and restoration callbacks. Both options are available throughout the
package's supported iOS/macOS range and are forwarded without newer-version
guards. Extended scan/connect capability queries call CoreBluetooth on iOS 13+;
older iOS and macOS retain the unsupported result. Swift type checks cover the
iOS 12/macOS 10.14 deployment targets; these checks do not execute older OS runtimes.

Local metadata tests cover native descriptor construction with typed bytes and
strings, permission snapshots for add/restoration, encryption and zero permission
bits, retained Dart object identity and byte/permission round trips through
removal and republication.

Descriptor validation tests cover missing/null values, wrong types, odd-length
Valid Range values, custom 128-bit descriptors, full and short UUIDs, valid binary
values in both native and channel representations, root and nested services, unchanged native registries on rejection,
reuse of existing native definitions and successful retry after correction.

Disconnect tests cover both native callback signatures, rejection of retired
handles before rediscovery, peripheral identity, notification flag reset,
same-handle wrapper replacement, other managers and local GATT. Startup tests cover
central and peripheral delegate exceptions, buffered event continuation and
disposal from a throwing callback. Advertisement tests cover native and Dart UUID
lists, stream/delegate delivery and FBP filtering and payload parity.

L2CAP range tests verify native calls for boundary values, rejection without side
effects for invalid PSMs, Dart error propagation and valid retries. Typed-buffer
tests cover binary envelope size, successive reads, EOF, native errors, existing
stream lifetime/cancellation checks, legacy list replies and independent zero-offset
Dart buffers.

UUID validation rejects signed hexadecimal pairs, whitespace and other non-hex
characters in Dart before native calls. Valid 16-bit, 32-bit and 128-bit Bluetooth
UUIDs retain normalization, byte conversion and equality. Full Foundation UUIDs
retain their existing representation and conversion to Bluetooth UUIDs. Regression
tests cover the malformed strings that otherwise cause a native CoreBluetooth
exception; this correction was explicitly approved during review.

`CBUUID.data` returns an independent typed byte copy. Editing either that list
or a view of its buffer cannot change the UUID's stored bytes, string, equality,
hash or map-key lookup. Constructor inputs remain copied. Three regressions cover
16-, 32- and 128-bit UUIDs through every constructor and alias, including byte
round trips. The exposed mutable storage was present in the original package
commit `32fc2770`; this correction was explicitly approved during review.

Scan submission returns actual native scanning activity to the CoreBluetooth
cache. Refused scans remain inactive; older scan/stop replies cannot overwrite a
newer operation or an adapter transition. FBP keeps its existing scan submission
return values, native arguments and adapter-off errors. UUID byte construction
rejects out-of-range values with `RangeError`, without shifting or truncating the
address; boundary tests cover every byte position and valid round trips. These
corrections were explicitly approved during review.

Failed service re-add callbacks preserve an already published registration,
its native handles, client references and pending ATT requests. This includes
OS-restored services. Dart keeps the retained publication revision so a later
submission failure cannot leave an unremovable entry in `services`. Failed first
adds still release their graph. Removal, power-off/reset, replacement restoration
and disposal retire publication metadata; late callbacks cannot revive an old
service or remove a newer publication. Tests cover these lifetimes and isolation
across managers. This correction was explicitly approved during review.

GATT handles are opaque UUID strings, stable for the lifetime of each native
object. A weak, pointer-identity lookup supplies the same IDs to snapshots,
registries and local ownership graphs without extending object lifetimes.
Replacement objects receive new IDs even when the allocator reuses their memory
addresses. This internal handle-format correction was explicitly approved during
review; FBP identifiers, GATT instance IDs and callbacks remain unchanged.

Native lifetime tests release 6,000 actual CoreBluetooth service, characteristic
and descriptor objects across 2,000 publication/removal cycles, asserting handle
uniqueness, stable live IDs, deallocation, stale-operation rejection and usable
replacement objects. Address reuse is observed and checked when it occurs, without
making test success depend on a particular allocator. Another 500 remote discovery
and disconnect cycles use weak-parent doubles that actually deallocate, verifying
that stale characteristic/descriptor reads never reach replacement attributes.
Separate identity tests cover equal-but-distinct objects and weak lookup ownership.

Characteristic snapshots forward native `isBroadcasted` state separately from
the broadcast capability flag. Discovery refreshes cached remote characteristics;
local add and restoration snapshots update retained mutable characteristics.
The property is deprecated by Apple and is not used by FBP. This correction was
explicitly approved during review. Regression tests cover inactive/active state
with unchanged capability bits, native snapshot serialization and retained Dart
object identity.

Native GATT collections preserve `nil` as Dart `null` through snapshots,
discovery callbacks and restoration; empty native arrays remain empty. An explicit
null clears the cached collection and retires unreachable attribute wrappers,
whereas omitted snapshot fields preserve existing values. Local GATT snapshots
also retain this distinction. This correction to the native wrapper was explicitly
approved during review. FBP continues treating unavailable discovery collections
as empty while retaining the native error and one aggregate completion event.
Tests cover null/empty collections with successful and failed native callbacks,
platform-codec round trips, cached snapshot updates and every FBP discovery-error
stage.

The standalone peripheral role now reattaches `CBPeripheralManager.shared` to
its existing native registration after Flutter hot restart. Its initialization
snapshot restores published services and pending additions separately, preserving
attribute handles, subscribed centrals and shared graph identities before buffered
requests are replayed. It does not manufacture an OS restoration event. Stop and
dispose target the original advertiser; disposing shared permits a fresh native
registration and leaves isolated managers untouched. Native manager options remain
those chosen at initial creation. Generated local references include a random
Dart-session prefix to avoid collisions with old references recovered on restart.
This lifecycle correction was explicitly approved during review and does not
change FBP's central-role manager. Native tests simulate restart subscription
replacement and repeated attachment without radio access; Dart tests cover shared
selection, recovered state, buffered ATT requests and pending-add success/failure.

Validation covers 86 backend tests and 128 CoreBluetooth Dart tests on
current and Dart 3.0/Flutter 3.10 hosts, 9 shared logging/integration tests,
native Swift type checks at the minimum deployment targets, macOS example builds
with SPM and CocoaPods, and an unsigned
iOS example build with CocoaPods. Tests exercise mock native channel events,
submitted native calls and FBP results. The original source
is the behavioral reference; mocked tests do not prove radio timing, background
restoration or actual peripheral interoperability. Those require iOS/macOS BLE
hardware testing before release.
