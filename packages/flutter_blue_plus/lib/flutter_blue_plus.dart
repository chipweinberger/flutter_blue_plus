// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';

export 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart' show DeviceIdentifier, Guid, LogLevel, PhySupport;

part 'src/bluetooth_characteristic.dart';
part 'src/bluetooth_descriptor.dart';
part 'src/bluetooth_device.dart';
part 'src/bluetooth_events.dart';
part 'src/bluetooth_service.dart';
part 'src/bluetooth_utils.dart';
part 'src/flutter_blue_plus.dart';
part 'src/utils.dart';
