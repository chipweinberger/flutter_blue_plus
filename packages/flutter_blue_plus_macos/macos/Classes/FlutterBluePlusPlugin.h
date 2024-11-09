// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#if TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif
#import <CoreBluetooth/CoreBluetooth.h>

#define NAMESPACE @"flutter_blue_plus"

@interface FlutterBluePlusPlugin : NSObject<FlutterPlugin, CBCentralManagerDelegate, CBPeripheralDelegate>
@end

@interface FlutterBluePlusStreamHandler : NSObject<FlutterStreamHandler>
@property FlutterEventSink sink;
@property NSDictionary *cachedBluetoothAdapterState;
@end
