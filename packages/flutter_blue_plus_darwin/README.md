# flutter_blue_plus_darwin

The iOS and macOS implementation of [`flutter_blue_plus`][1].

## Usage

This package is [endorsed][2], which means you can simply use `flutter_blue_plus`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this package to use any of its APIs directly, you
should add it to your `pubspec.yaml` as usual.

## Native access

Bluetooth operations use the `core_bluetooth` package. Initialize FBP before
accessing native objects, so its startup cleanup has completed:

```dart
import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_darwin/flutter_blue_plus_darwin.dart';

await FlutterBluePlus.isSupported;
final central = FlutterBluePlusDarwin.centralManager;
assert(identical(central, cb.CBCentralManager.shared));

// After connecting through FBP:
final peripheral = FlutterBluePlusDarwin.getPeripheral(device.remoteId.str);
```

These are the same manager and peripheral objects used by FBP. Stream listeners
can coexist. Serialize native GATT requests with FBP requests; native discovery,
notification changes, scanning and disconnection also affect FBP. Do not replace
or dispose the shared manager while FBP uses it. Set FBP options before either
package first creates that manager.

CoreBluetooth can also be used independently. `CBCentralManager.createIsolated()`
creates a separate manager when shared connection ownership is not wanted.

## Native builds

`core_bluetooth` owns the native registration and CoreBluetooth framework linkage.
This backend registers in Dart and supports both CocoaPods and Swift Package
Manager through that dependency. Existing Bluetooth Info.plist descriptions,
background modes and macOS entitlements are still required.

See [compatibility notes](../core_bluetooth/docs/flutter_blue_plus_compatibility.md)
for preserved behavior, validation and limitations.

[1]: https://pub.dev/packages/flutter_blue_plus
[2]: https://flutter.dev/to/endorsed-federated-plugin
