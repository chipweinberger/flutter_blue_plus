# flutter_blue_plus_android

The Android implementation of [`flutter_blue_plus`][1].

## Usage

This package is [endorsed][2], which means you can simply use `flutter_blue_plus`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this package to use any of its APIs directly, you
should add it to your `pubspec.yaml` as usual.

## AndroidBluetooth access

This backend implements FBP's Android behavior in Dart using `android_bluetooth`. Normal FBP calls, return values and event streams retain their existing contract. The package is Dart-only; AndroidBluetooth owns native registration and the conditional FBP license build hook.

To use additional Android APIs, add `android_bluetooth` as a direct dependency. Its device lookup exposes existing clients created in the current Dart isolate, including FBP's client:

```dart
import 'package:android_bluetooth/android_bluetooth.dart' as android;

final adapter = android.BluetoothAdapter.shared;
final enabled = await adapter.isEnabled;
final device = android.BluetoothDevice(fbpDevice.remoteId.str);
final clients = device.gattClients;
```

A device may have zero or several clients. Client lifetime includes pending connections and disconnected auto-connect registrations. The returned list is a snapshot; it contains the original client objects and does not open another connection. `device.connectGatt()` explicitly opens another client.

For FBP's specific client, this package also exposes a static lookup:

```dart
import 'package:flutter_blue_plus_android/flutter_blue_plus_android.dart';

final gatt = FlutterBluePlusAndroid.getGatt(fbpDevice.remoteId.str);
if (gatt != null) {
  gatt.onPhyRead.listen((result) { /* Android callback */ });
  await gatt.readPhy();
}
```

Callback streams support multiple listeners, so listening directly does not consume FBP's events. Serialize native GATT requests with FBP requests; both use the same Android request queue. Use FBP for its managed connection/discovery/notification lifecycle. Directly closing or changing those resources can invalidate FBP's cached state. L2CAP is device-scoped and can be opened through `device.createL2capChannel(psm)` without another GATT client.

The [compatibility audit](../android_bluetooth/docs/flutter_blue_plus_compatibility.md) describes parity coverage, the approved logging difference, and hardware checks still needed.

[1]: https://pub.dev/packages/flutter_blue_plus
[2]: https://flutter.dev/to/endorsed-federated-plugin
