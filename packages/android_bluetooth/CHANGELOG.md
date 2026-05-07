## Unreleased

* Preserve null identity addresses and Android's unknown address type when Bluetooth is disabled or an identity is unavailable, instead of throwing during Dart decoding. BluetoothAddress.address is now nullable; known identity addresses and native permission errors are unchanged.
* Complete advertising-set streams when a pending startup is canceled without native callbacks. Release its routing state and ignore late callbacks; started sets retain their native stopped callback, and failed stop submissions remain retryable.
* Preserve every FIRST_MATCH and MATCH_LOST scan callback regardless of advertisementDivisor or duplicate suppression, including reappearance with unchanged advertising bytes. Presence transitions do not affect advertisement history; ordinary advertisement and batch delivery are unchanged.
* Reject overflowing, fractional and nonfinite Java int arguments with invalid_argument instead of silently narrowing them to different settings. Apply the same checks to connection-state arrays; preserve signed 32-bit values, defaults and 64-bit scan report delays.
* Return empty extras and null optional broadcast fields for PIN-result callbacks instead of throwing when extras are absent; preserve acceptance, error messages and supplied broadcast extras.
* Validate advertising-data mask lengths before constructing scan filters, including masks without data. Reject malformed filters on API 33 before native matching can throw; retain valid masked, unmasked and type-only filters.
* Keep removed included-service handles invalid when parent services are queried or serialized in later add callbacks. Preserve retained native metadata and original identities without restoring active ownership; other registered services remain usable.
* Allow setAlias(null) to clear a device's locally stored alias, forwarding null to Android while preserving native status, permission errors and the API 31 gate.
* Keep failed GATT server additions out of service queries even when Android retains them in its framework list, preventing retired service/characteristic/descriptor objects from being registered again while preserving successful services and retries.
* Preserve the native characteristic value in write callbacks, allowing applications to verify reliable-write response bytes before committing. Copy bytes at callback time and retain null/empty values and native status; FBP continues reporting its submitted write bytes.
* Clarify the SDK 36 companion presence service requirement and verify modern callback metadata, background buffering, live delivery and inherited legacy callbacks.
* Preserve scan records with null manufacturer metadata after Android fails to parse malformed advertising bytes, preventing callback crashes and dropped background batches while retaining raw bytes and subsequent healthy results.
* Report invalid_state when Android returns no component for a connection-service start request, instead of reporting success when the service cannot be found; allow retry after correcting its declaration or enabled state.
* Preserve characteristics, descriptors and nested included services when a GATT service is shared across multiple branches, while continuing to truncate actual recursive cycles and retain stable handles.
* Add optional native ScanDeliveryOptions with a per-device advertisementDivisor and duplicate-payload suppression before serialization/channel delivery; apply software filters in Dart after sampling, preserve raw defaults and allow independent scans to replace delivery options without restarting the radio scan.
* Keep retired GATT callback identities through weak references so invalidated or removed service graphs can be collected while their registration remains open.
* Expose existing per-device GATT clients and all-device action events for integration with BLE wrappers.
* Add strict bond-state and PHY queries that preserve native permission failures.
* Support concurrent split enable-dialog requests and include native stack traces in exception details.
* Host the existing FBP license build hook when FlutterBluePlus is present; standalone builds retain their previous behavior.

## 0.1.0

* Add native Android BLE scanning, advertising, GATT client/server, and LE L2CAP APIs.
* Add device, bonding, ACL and encryption events, adapter capabilities and explicit permissions.
* Add companion association/presence, background scan callbacks and an optional foreground service.
* Add Android 16 raw BLE RSSI/channel-sounding ranging and version-gated connection controls.
* Document the API contract and restricted Android operations; include a runnable BLE explorer.

* Remove arbitrary native/Dart callback-count limits and idle-owner eviction.
* Clean native registrations on Flutter hot restart and reject stale callbacks/results/late accepted sockets.
* Make disposal idempotent and finish callback streams after terminal events.
* Add operation-specific typed callback results and immutable received snapshots.
* Add lifecycle, permission, buffering, shutdown-race, and pending-I/O regressions.
* Migrate the example to AGP 9 built-in Kotlin and document tested tooling/operation requirements.
* Defer startup callback replay until typed listeners installed together can subscribe.
* Retain callback scans after failed stops so cleanup can be retried.
* Correct dynamic ranging peer configuration and explicitly reject UWB-only raw peer removal.
* Release automatically approved companion association requests while retaining chooser-result routing.
* Allow setAlias from API 31 and retain native status/permission errors.
* Use Dart 3.3-compatible development lint dependencies in the package and example.
* Keep late server request snapshots from restoring removed characteristic or descriptor handles.
* Buffer background scan/presence events only in process memory; applications own persistence.
* Log malformed background payloads and report background_error without ending event streams.
* Complete failed/canceled companion request streams and retire their routing entries, including early callbacks.
* Remove the compile-only AndroidX annotation dependency; use SDK lint annotations at native permission-delegation boundaries.
