import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';

part 'src/darwin_backend.dart';
part 'src/darwin_types.dart';
part 'src/darwin_utils.dart';
part 'src/darwin_adapter.dart';
part 'src/darwin_scan.dart';
part 'src/darwin_device.dart';
part 'src/darwin_gatt.dart';
part 'src/darwin_discovery.dart';
part 'src/darwin_callbacks.dart';
part 'src/darwin_mtu.dart';

final class FlutterBluePlusDarwin extends _DarwinBackend
    with
        _AdapterOperations,
        _ScanOperations,
        _DiscoveryOperations,
        _PeripheralCallbacks,
        _DeviceOperations,
        _GattOperations {
  /// The same CoreBluetooth manager used by FBP. Observe its streams freely;
  /// serialize native GATT operations with FBP operations on the same device.
  /// Options must be configured through FBP before first use.
  static cb.CBCentralManager get centralManager => (FlutterBluePlusPlatform.instance as FlutterBluePlusDarwin)._manager;

  /// The peripheral used by FBP, including pending connections, when tracked.
  static cb.CBPeripheral? getPeripheral(String remoteId) =>
      (FlutterBluePlusPlatform.instance as FlutterBluePlusDarwin)._known[remoteId.toUpperCase()];

  static void registerWith() {
    FlutterBluePlusPlatform.instance = FlutterBluePlusDarwin();
  }
}
