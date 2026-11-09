## Unreleased
* Wait for included-service discovery as well as characteristic and descriptor callbacks before reporting one final discovery result. Retain included-service errors, query shared included services once, and ignore duplicate subrequest callbacks. Restored services keep cached notification state while actual native discovery completes (approved correction to the former backend's premature/duplicate results).
* Apply continuousDivisor per device in CoreBluetooth before platform-channel delivery, then apply custom scan filters in Dart. Advertisements rejected by Dart now consume sampling slots, so the first matching advertisement may be skipped when the divisor is greater than 1.
* Clear invalid GATT attributes on disconnect so reconnecting requires fresh service discovery; retain peripheral identity and existing disconnect event formats.
* Snapshot every scan-filter list when startScan is called, preserving submitted filters while initialization is pending and after caller lists change.
* Recheck Bluetooth power after peripheral retrieval before submitting a connection.
* Prevent pending writes from crossing reconnections and pending peripheral lookups from starting connections after backend disposal.
* Simplify GATT operations and MTU monitoring; discard obsolete discovery failures, recover initialization failures and fully detach disposed backends.
* Report native errors for failed descriptor reads with missing values instead of the former native crash (approved behavior correction).
* Implement the Darwin backend in Dart through CoreBluetooth, preserving FBP operations and callback formats; expose the shared manager and tracked peripherals.
* Let the main FBP package log standard requests, results and events; continue forwarding native log-level settings.

## 9.0.5
* **[Fix]** allow service discovery to finish when CoreBluetooth restricts access to a UUID, including Matter attributes (#1344)
* **[LICENSE]** add global tier

## 9.0.4
* **[Performance]** only poll for MTU changes while a connection's MTU can still change (#1339)

## 9.0.3
* **[LICENSE]** add `Corporate` tier for 250+ employees

## 9.0.2
* **[LICENSE]** clarify build-time license ping in the FlutterBluePlus License

## 9.0.1
* **[Release]** version bump to publish the updated `flutter_blue_plus_platform_interface: ^9.0.0` dependency

## 9.0.0
* **[Feature]** allow discovering multiple devices at the same time
* **[Feature]** support for services with the same UUID
* **[Improved]** allow `setOptions` arguments to be updated individually without resetting unspecified values
* **[Fix]** discovery would timeout if no services were present
* **[Fix]** included services discovery was broken

## 8.2.2
* **[Release]** version bump for the flutter_blue_plus 2.2.2 release

## 8.2.1
* **[LICENSE]** clarifications to the development exemption

## 8.2.0
* **[LICENSE]** new tiers based on company size & development exemption

## 8.1.1
* **[Fix]** nil-guard rssi in didReadRSSI:error: to prevent crash (#1318)

## 8.1.0
* **[LICENSE]** commercial license is now required for 15 or more employees

## 8.0.1
* Add License symlink

## 8.0.0
* Switch to FBP License

## 4.0.1
* fix unrecognized selector sent to instance (regression from 4.0.0)

## 4.0.0
* Use bytes instead of hex for platform communication (#1130)

## 3.0.0
* Update platform interface version to 3.0.0

## 2.0.1
* Add log color

## 2.0.0
* Combine the packages previously published as flutter_blue_plus_ios and flutter_blue_plus_macos
* Add support for Swift Package Manager
* Replace void return types with bool return types
