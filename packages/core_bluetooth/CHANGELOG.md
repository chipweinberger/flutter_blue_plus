## Unreleased
* Bound native L2CAP input buffers to 64 KiB so oversized maxLength requests cannot crash the app during allocation. Keep maxLength as an upper bound and return partial chunks without padding, preserving byte order, EOF, cancellation and native read errors.
* Return an independent byte copy from CBUUID.data so callers cannot change the UUID's stored bytes while its string, equality and hash remain unchanged. Preserve constructor input copying and 16-, 32- and 128-bit representations; this fixes behavior present in the original Dart package.
* Reattach CBPeripheralManager.shared to its existing native manager after hot restart, recovering advertising state, published services and pending additions with stable handles. Stop/dispose now controls the original registration; isolated managers remain independent. Give generated local object references a Dart-session prefix so new definitions cannot collide with recovered ones.
* Preserve native null versus empty GATT discovery collections in snapshots, callbacks and restoration. Explicit null clears cached services, included services, characteristics and descriptors; omitted snapshot fields preserve cached values. FBP retains its existing discovery results and native errors.
* Forward native isBroadcasted state instead of inferring activity from the broadcast capability flag, including discovery, local add and restoration snapshots.
* Query extended scan/connect support on iOS 13–16, and preserve solicited-service scan options, restored scan options and connection start delays on all supported iOS/macOS versions.
* Add advertisementDivisor to scanForPeripherals for per-device native sampling before serialization/channel delivery and Dart filtering, while retaining CoreBluetooth's native service filters and scan options.
* Reject non-byte values for custom 128-bit descriptors and missing, incorrectly typed or odd-length Valid Range descriptor values with invalid_args before native construction, preventing uncaught native exceptions.
* Query legacy peripheral authorization on older supported systems instead of always reporting allowed access.
* Use stable opaque GATT handles backed by weak native object identity, preventing stale service, characteristic and descriptor handles from reaching replacement objects after allocator address reuse.
* Preserve previously published services and native attribute handles when a re-add callback fails, including restored services; keep Dart publication revisions consistent through later submission failures and removals.
* Report actual native scanning activity after scan submission and prevent delayed scan/stop replies from overwriting newer operations or adapter transitions.
* Reject UUID byte values outside 0–255 with RangeError instead of shifting or truncating the resulting address.
* Reject non-hexadecimal UUID strings in Dart before native calls, including signed pairs and whitespace that could otherwise trigger an uncaught CoreBluetooth exception.
* Invalidate remote connection/GATT state before adapter-state callbacks even without individual disconnects; retire local publications on power-off/reset and release subscriptions and pending ATT requests when the server leaves powered-on.
* Reject out-of-range L2CAP PSM arguments instead of truncating them, and transfer L2CAP read results as compact typed bytes while preserving Dart buffer layout, EOF and errors.
* Clear remote GATT caches, notification flags and native attribute handles on disconnect while retaining peripheral identity.
* Preserve native manager ownership when buffered startup callbacks throw, reporting callback errors through Dart zones.
* Expose overflow and solicited service UUIDs as separate optional AdvertisementData lists.
* Reject missing or incorrectly typed User Description and Presentation Format descriptor values with invalid_args before allocating a new service graph, preventing uncaught native exceptions and partial registrations.
* Convert typed descriptor bytes to native Data before construction, and preserve local characteristic permissions in add/restoration snapshots so republishing retains the configured access permissions.
* Reuse manager-owned included services when publishing parents, preserving handles and shared attributes; allow connection-latency requests for centrals observed through ATT, subscriptions, restoration or L2CAP without requiring a notification subscription.
* Preserve empty notification recipient lists instead of broadcasting, and retain one Dart object per shared restored local service and its attributes across roots and restoration updates.
* Preserve newer service adds when older removals complete, including re-adds and failed submissions; reject peripheral operations and delayed query results once their central manager begins disposal.
* Keep removed local services out of the Dart cache when late add callbacks arrive; clear advertising state after a successful stop without overwriting newer starts.
* Run L2CAP I/O on background stream loops; report native read errors separately from EOF and cancel queued operations when streams close or their final manager is disposed.
* Deliver callbacks for characteristics in included services, guard central-manager disposal races and release remote attributes before their weak parent links disappear.
* Recover peripheral-manager creation failures, guard disposal and reset disposed shared instances; release entire ATT write batches after their single response.
* Scope local GATT services and ATT requests to their peripheral manager; preserve other managers during cleanup, reject foreign handles and release unanswered requests on disposal.
* Release native L2CAP channels after both streams close or their final owning manager is disposed; preserve the remaining stream and other managers' channels.
* Release obsolete native GATT objects after service invalidation and discovery updates while preserving reachable included services, local GATT and other managers' objects.
* Scope peripheral ownership by manager, validate remote attribute handles, prune partial GATT cache updates and allow native manager creation to recover after failure.
* Support the FBP Darwin backend: retain shared native managers across hot restart, expose startup cleanup and native write readiness, restore complete GATT snapshots, preserve unknown error codes and stable attribute identity, and retain callback value snapshots. Verify Dart 3.0 and native iOS 12/macOS 10.14 compatibility.

## 3.0.0
* `CBPeripheralManager.shared`
* `CBPeripheralManager.ensureShared(options: ...)`
* `CBPeripheralManager.createIsolated(options: ...)`

## 2.0.1
* **[Feature]** Readme: add l2cap usage

## 2.0.0
* `CBCentralManager.shared`
* `CBCentralManager.ensureShared(options: ...)`
* `CBCentralManager.createIsolated(options: ...)`

## 1.0.2
* **[Feature]** Readme: peripheral mode example usage

## 1.0.1
* **[Feature]** Readme: central mode example usage

## 1.0.0
* **[Feature]** Support `CBManager`, `CBPeer`, `CBUUID`, `CBError`, `CBATTRequest`, `CBL2CAPChannel`, and `CBL2CAPPSM`
* **[Feature]** Support `CBCentralManager`, `CBCentralManagerDelegate`, `CBCentral`, and `CBConnectionEvent`
* **[Feature]** Support `CBPeripheral`, `CBPeripheralDelegate`, `CBPeripheralManager`, and `CBPeripheralManagerDelegate`
* **[Feature]** Support `CBAttribute`, `CBService`, `CBMutableService`, `CBCharacteristic`, `CBMutableCharacteristic`, `CBDescriptor`, and `CBMutableDescriptor`
* **[Feature]** Support CoreBluetooth enums, option sets, and constants

## 0.1.0

- Initial scaffold for a standalone CoreBluetooth package.
- Add Darwin plugin wiring for iOS and macOS.
