library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

// ─────────────────────────────────────────────────────────────
// Linux imports
// ─────────────────────────────────────────────────────────────

import 'package:bluez/bluez.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────
// Web imports
// ─────────────────────────────────────────────────────────────

import 'dart:js_interop';
import 'package:web/web.dart' show Event;
import 'src/platform/web/web_bluetooth.dart' as wb;
import 'src/platform/web/html.dart';

// ─────────────────────────────────────────────────────────────
// Platform interface
// ─────────────────────────────────────────────────────────────

part 'src/platform_interface/flutter_blue_plus_platform_interface.dart';
part 'src/platform_interface/log_level.dart';
part 'src/platform_interface/guid.dart';
part 'src/platform_interface/device_identifier.dart';
part 'src/platform_interface/bluetooth_msgs.dart';

// ─────────────────────────────────────────────────────────────
// Platform
// ─────────────────────────────────────────────────────────────

part 'src/platform/android/flutter_blue_plus_android.dart';
part 'src/platform/darwin/flutter_blue_plus_darwin.dart';
part 'src/platform/linux/flutter_blue_plus_linux.dart';
part 'src/platform/web/flutter_blue_plus_web.dart';

// ─────────────────────────────────────────────────────────────
// Core
// ─────────────────────────────────────────────────────────────

part 'src/core/bluetooth_characteristic.dart';
part 'src/core/bluetooth_descriptor.dart';
part 'src/core/bluetooth_device.dart';
part 'src/core/bluetooth_events.dart';
part 'src/core/bluetooth_service.dart';
part 'src/core/bluetooth_utils.dart';
part 'src/core/flutter_blue_plus.dart';
part 'src/core/utils.dart';
