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
