/// Native Android APIs for Bluetooth Low Energy communication and device management.
library android_bluetooth;

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/services.dart' show EventChannel, MethodChannel;

part 'src/host.dart';
part 'src/device.dart';
part 'src/scan.dart';
part 'src/gatt.dart';
part 'src/advertising.dart';
part 'src/socket.dart';
part 'src/companion.dart';
part 'src/ranging.dart';
