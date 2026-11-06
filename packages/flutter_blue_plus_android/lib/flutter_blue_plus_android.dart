import 'dart:async';
import 'dart:math' as math;

import 'package:android_bluetooth/android_bluetooth.dart' as ab;
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';

part 'src/android_backend.dart';
part 'src/android_types.dart';
part 'src/android_utils.dart';
part 'src/android_adapter.dart';
part 'src/android_scan.dart';
part 'src/android_device.dart';
part 'src/android_gatt.dart';

final class FlutterBluePlusAndroid extends _AndroidBackend
    with _AdapterOperations, _ScanOperations, _DeviceOperations, _GattOperations {
  /// The AndroidBluetooth client used by FBP, or null when no client is tracked.
  ///
  /// This is the same registration, not a second connection. Subscribe to its
  /// callback streams freely. Serialize GATT requests with FBP requests; changing
  /// discovery, notifications or connection lifetime also changes FBP's device.
  static ab.BluetoothGatt? getGatt(String remoteId) =>
      (FlutterBluePlusPlatform.instance as FlutterBluePlusAndroid)._connections[remoteId.toUpperCase()]?.gatt;

  static void registerWith() {
    FlutterBluePlusPlatform.instance = FlutterBluePlusAndroid();
  }
}
