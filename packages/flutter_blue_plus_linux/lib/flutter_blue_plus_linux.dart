import 'dart:async';

import 'package:bluez/bluez.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';

part 'src/bluez_types.dart';
part 'src/bluez_utils.dart';
part 'src/linux_backend.dart';
part 'src/linux_adapter.dart';
part 'src/linux_device.dart';
part 'src/linux_gatt.dart';

final class FlutterBluePlusLinux extends _LinuxBackend with _AdapterOperations, _DeviceOperations, _GattOperations {
  static void registerWith() {
    FlutterBluePlusPlatform.instance = FlutterBluePlusLinux();
  }
}
