## Unreleased
* Keep pending and disconnected auto-connect clients tracked when native disconnect submission fails, allowing retry with the existing error. Pause callbacks during cancellation and resume them on failure; successful cancellation still emits its existing single canceled event. Restore the former Java behavior for pending clients and correct the same tracking bug already present in its disconnected auto-connect path.
* Retain the original auto-connect client and its callbacks when replacement registration fails, matching the former Java backend. Canceling or shutting down a pending replacement cleans up both clients without restoring a retired registration; native connection errors remain unchanged.
* Attempt every GATT client's cleanup during adapter shutdown even if an earlier close fails. Preserve cleanup order, disconnect events and the first failure's error/stack, reporting it after all cleanup attempts finish (approved correction to the former Java backend).
* Handle failures from automatic GATT cleanup after disconnect, logging at error level without an unhandled async exception or changing disconnect events. Suppress diagnostics after engine detach; explicit close and awaited disconnect failures still propagate.
* Clear a device's pending write payloads before its disconnect event, including auto-connect link loss. Reconnecting native writes no longer inherit bytes from the previous connection; other devices' pending writes remain intact (approved correction to the former Java backend).
* Discard cached characteristic, descriptor and notification payloads when native write submission is rejected or throws, preserving any earlier accepted write awaiting its callback. Later native writes no longer inherit rejected FBP bytes (approved correction to the former Java backend).
* Snapshot scan name and remote-ID filters before initialization and permission requests, preserving the original submitted values and filter order when callers modify their lists.
* Apply duplicate suppression and per-device continuousDivisor sampling in AndroidBluetooth before platform-channel delivery, then apply keyword filtering in Dart. Advertisements rejected by Dart now consume sampling slots. Preserve ignored batches and repeated-start history resets.
* Move standard request/result/event logging to the main FBP package; retain backend initialization, availability checks and error translation.
* Let already-granted operations proceed during unrelated permission dialogs, matching the original Android backend.
* Implement the Android backend in Dart through AndroidBluetooth, retaining FBP operation, error and event semantics.
* Add direct access to the existing GATT client through `FlutterBluePlusAndroid.getGatt` and AndroidBluetooth's `BluetoothDevice.gattClients`.
* Move the conditional FBP license build hook to AndroidBluetooth and remove the native FBP plugin.
* Preserve public logging controls; internal Java-only Logcat messages are no longer emitted.

## 9.0.5
* **[LICENSE]** add global tier

## 9.0.4
* **[Fix]** Android: duplicate connected callbacks could disconnect the device and leave Dart reporting it as connected (#1121)
* **[Fix]** Android: callbacks from previous connection attempts could overwrite or clear the current connection state (#1121)
* **[Fix]** Android: avoid crashes when reading adapter or device names without `BLUETOOTH_CONNECT` permission (#1340)

## 9.0.3
* **[Android]** rename `com.lib.flutter_blue_plus` to `com.jmx.flutter_blue_plus`
* **[LICENSE]** add `Corporate` tier for 250+ employees

## 9.0.2
* **[LICENSE]** clarify build-time license ping in the FlutterBluePlus License

## 9.0.1
* **[LICENSE]** add license ping during build w/ package name & app name

## 9.0.0
* **[Fix]** Android: improve characteristic `instanceId` resolution when multiple services share the same UUID

## 8.2.2
* **[Release]** version bump for the flutter_blue_plus 2.2.2 release

## 8.2.1
* **[LICENSE]** clarifications to the development exemption

## 8.2.0
* **[LICENSE]** new tiers based on company size & development exemption

## 8.1.0
* **[LICENSE]** commercial license is now required for 15 or more employees

## 8.0.1
* Add License symlink

## 8.0.0
* Switch to FBP License

## 4.0.5
* Fixes to check for location services when plugin is called from a service

## 4.0.3
* Added option to disable Location Services check

## 4.0.2
* Fix compile error

## 4.0.1
* Fix compile error

## 4.0.0
* Use bytes instead of hex for platform communication (#1130)
* Check if Android location services are enabled when doing scan (#1167)

## 3.0.0
* Add option to provide pairing PIN to `createBond` (#1119)

## 2.0.1
* Add log color

## 2.0.0
* Replace void return types with bool return types

## 1.35.0
* Split from `flutter_blue_plus` as a federated implementation
