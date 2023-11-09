[![pub package](https://img.shields.io/pub/v/flutter_blue_plus.svg)](https://pub.dartlang.org/packages/flutter_blue_plus)
[![Chat](https://img.shields.io/discord/634853295160033301.svg?style=flat-square&colorB=758ED3)](https://discord.gg/Yk5Efra)

<br>
<p align="center">
<img alt="FlutterBlue" src="https://github.com/boskokg/flutter_blue_plus/blob/master/site/flutterblueplus.png?raw=true" />
</p>
<br><br>

**Note: this plugin is continuous work from [FlutterBlue](https://github.com/pauldemarco/flutter_blue).**

Migrating from [FlutterBlue](https://github.com/pauldemarco/flutter_blue)? See [Migration Guides](MIGRATION.md)

## Contents

- [Introduction](#introduction)
- [Usage](#usage)
- [Getting Started](#getting-started)
- [Reference](#reference)
- [Debugging](#debugging)
- [Mocking](#mocking)
- [Common Problems](#common-problems)

## Introduction

FlutterBluePlus is a Bluetooth Low Energy plugin for [Flutter](https://flutter.dev). 

It supports BLE Central Role only (most common). 

If you need BLE Peripheral Role, you should check out [FlutterBlePeripheral](https://pub.dev/packages/flutter_ble_peripheral).

## ❗ Bluetooth Classic is not supported ❗

 i.e. speakers, headphones, mice, keyboards, gamepads, Arduino HC-05 & HC-06, and more are not supported. These all use Bluetooth Classic.

 Also, iBeacons are **_not_** supported on iOS. Apple requires you to use CoreLocation.

## Cross-Platform Bluetooth Low Energy

FlutterBluePlus aims to offer the most from all supported platforms: iOS, macOS, Android.

The code is written to be simple, robust, and incredibly easy to understand.

## No Dependencies

FlutterBluePlus has zero dependencies besides Flutter, Android, and iOS themselves.

This makes FlutterBluePlus very stable, and easy to maintain.

## ⭐ Stars ⭐

Please star this repo & on [pub.dev](https://pub.dev/packages/flutter_blue_plus). We all benefit from having a larger community.

## Example

FlutterBluePlus has a beautiful example app, useful to debug issues.

```
cd ./example
flutter run
```

<p align="center">
<img alt="FlutterBlue" src="https://github.com/boskokg/flutter_blue_plus/blob/master/site/example.png?raw=true" />
</p>

## Usage

### :fire: Error Handling :fire:

Flutter Blue Plus takes error handling very seriously. 

Every error returned by the native platform is checked and thrown as an exception where appropriate. See [Reference](#reference) for a list of throwable functions.

**Streams:** Streams returned by FlutterBluePlus never emit any errors and never close. There's no need to handle `onError` or `onDone` for  `stream.listen(...)`. The one exception is `FlutterBluePlus.scanResults`, which you should handle `onError`.

---

### Set Log Level

```dart
// if your terminal doesn't support color you'll see annoying logs like `\x1B[1;35m`
FlutterBluePlus.setLogLevel(LogLevel.verbose, color:false)
```

Setting `LogLevel.verbose` shows *all* data in and out.

⚫ = function name

🟣 = args to platform

🟡 = data from platform

<img width="600" alt="Screenshot 2023-07-27 at 4 53 08 AM" src="https://github.com/boskokg/flutter_blue_plus/assets/1863934/ee37d702-2752-4402-bf26-fc661728c1c3">


### Enable Bluetooth

**Note:** On iOS, a "*This app would like to use Bluetooth*" system dialogue appears on first call to any FlutterBluePlus method. 
 
```dart
// check if bluetooth is supported by your hardware
// Note: The platform is initialized on the first call to any FlutterBluePlus method.
if (await FlutterBluePlus.isSupported == false) {
    print("Bluetooth not supported by this device");
    return;
}

// handle bluetooth on & off
// note: for iOS the initial state is typically BluetoothAdapterState.unknown
// note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
    print(state);
    if (state == BluetoothAdapterState.on) {
        // usually start scanning, connecting, etc
    } else {
        // show an error to the user, etc
    }
});

// turn on bluetooth ourself if we can
// for iOS, the user controls bluetooth enable/disable
if (Platform.isAndroid) {
    await FlutterBluePlus.turnOn();
}
```

### Scan for devices

If your device is not found, see [Common Problems](#common-problems).

It is recommended to set scan filters to reduce main thread & platform channel usage.

```dart
// Setup Listener for scan results.
var subscription = FlutterBluePlus.scanResults.listen((results) {
        if (results.isNotEmpty) {
            ScanResult r = results.last; // the most recently found device
            print('${r.device.remoteId}: "${r.advertisementData.advName}" found!');
        }
    },
    onError(e) => print(e);
);

// Start scanning
await FlutterBluePlus.startScan();

// Stop scanning
await FlutterBluePlus.stopScan();

// cancel to prevent duplicate listeners
subscription.cancel();
```

### Connect to a device

```dart
// listen for disconnection
device.connectionState.listen((BluetoothConnectionState state) async {
    if (state == BluetoothConnectionState.disconnected) {
        // 1. typically, start a periodic timer that tries to 
        //    reconnect, or just call connect() again right now
        // 2. you must always re-discover services after disconnection!
        print("${device.disconnectReasonCode} ${device.disconnectReasonDescription}");
    }
});

// Connect to the device
await device.connect();

// Disconnect from device
await device.disconnect();
```

### MTU

On Android, we request an mtu of 512 by default during connection (see: `connect` function arguments).

On iOS & macOS, the mtu is negotiated automatically, typically 135 to 255.

```dart
final mtuSubscription = device.onMtu.listen((int mtu) {
    // iOS: initial value is always 23, but iOS will quickly negotiate a higher value
    print("mtu $mtu");
});

// cleanup: cancel subscription when disconnected
device.cancelWhenDisconnected(mtuSubscription);

// You can also manually change the mtu yourself.
if (Platform.isAndroid) {
    await device.requestMtu(512);
}
```

### Discover services

```dart
// Note: You must call discoverServices after every re-connection!
List<BluetoothService> services = await device.discoverServices();
services.forEach((service) {
    // do something with service
});
```

### Read Characteristics

```dart
// Reads all characteristics
var characteristics = service.characteristics;
for(BluetoothCharacteristic c in characteristics) {
    if (c.properties.read) {
        List<int> value = await c.read();
        print(value);
    }
}
```

### Write Characteristic

```dart
// Writes to a characteristic
await c.write([0x12, 0x34]);
```

**allowLongWrite**: To write large characteristics (up to 512 bytes) regardless of mtu, use `allowLongWrite`:

```dart
/// allowLongWrite should be used with caution. 
///   1. it can only be used *with* response to avoid data loss
///   2. the peripheral device must support the 'long write' ble protocol.
///   3. Interrupted transfers can leave the characteristic in a partially written state
///   4. If the mtu is small, it is very very slow.
await c.write(data, allowLongWrite:true);
```

**splitWrite**: To write lots of data (unlimited), you can define the `splitWrite` function. 

```dart
import 'dart:math';
// split write should be used with caution.
//    1. due to splitting, `characteristic.read()` will return partial data.
//    2. it can only be used *with* response to avoid data loss
//    3. The characteristic must be designed to support split data
extension splitWrite on BluetoothCharacteristic {
  Future<void> splitWrite(List<int> value, {int timeout = 15}) async {
    int chunk = device.mtu - 3; // 3 bytes ble overhead
    for (int i = 0; i < value.length; i += chunk) {
      List<int> subvalue = value.sublist(i, min(i + chunk, value.length));
      await write(subvalue, withoutResponse:false, timeout: timeout);
    }
  }
}
```

### Subscribe to a characteristic

// If `onValueReceived` is never called, see [Common Problems](#common-problems) in the README.

```dart
final chrSubscription = characteristic.onValueReceived.listen((value) {
    // onValueReceived is updated:
    //   - anytime read() is called
    //   - anytime a notification arrives (if subscribed)
});

// cleanup: cancel subscription when disconnected
device.cancelWhenDisconnected(chrSubscription);

// subscribe
// Note: If a characteristic supports both **notifications** and **indications**,
// it will default to **notifications**. This matches how CoreBluetooth works on iOS.
await characteristic.setNotifyValue(true);
```

### Last Value Stream

`lastValueStream` is an alternative to `onValueReceived`. It emits a value any time the characteristic changes, **including writes.**

It is very convenient for simple characteristics that support both WRITE and READ (and/or NOTIFY). **e.g.** a "light switch toggle" characteristic. 

```dart
final chrSubscription = characteristic.lastValueStream.listen((value) {
    // lastValueStream` is updated:
    //   - anytime read() is called
    //   - anytime write() is called
    //   - anytime a notification arrives (if subscribed)
    //   - also when first listened to, it re-emits the last value for convenience.
});

// cleanup: cancel subscription when disconnected
device.cancelWhenDisconnected(chrSubscription);

// enable notifications
await characteristic.setNotifyValue(true);
```

### Read and write descriptors

```dart
// Reads all descriptors
var descriptors = characteristic.descriptors;
for(BluetoothDescriptor d in descriptors) {
    List<int> value = await d.read();
    print(value);
}

// Writes to a descriptor
await d.write([0x12, 0x34])
```

### Get Connected Devices

Get devices currently connected to your app.

```dart
List<BluetoothDevice> devs = FlutterBluePlus.connectedDevices;
for (var d in devs) {
    print(d);
}
```

### Get System Devices

Get devices connected to the system by *any* app.

**Note:** you must connect *your app* to them before you can communicate with them.

```dart
List<BluetoothDevice> devs = await FlutterBluePlus.systemDevices;
for (var d in devs) {
    await d.connect(); // Must connect *our* app to the device
    await d.discoverServices();
}
```

### Create Bond (Android Only)

**Note:** calling this is usually not necessary!! The platform will do it automatically. 

However, you can force the popup to show sooner.

```dart
final bsSubscription = device.bondState.listen((value) {
    print("$value prev:{$device.prevBondState}");
});

// cleanup: cancel subscription when disconnected
device.cancelWhenDisconnected(bsSubscription);

// Force the bonding popup to show now (Android Only) 
await device.createBond();

// remove bond
await device.removeBond();
```

### Events API

Access streams from all devices simultaneously.

There are streams for:
* events.onConnectionStateChanged
* events.onMtuChanged
* events.onReadRssi
* events.onServicesReset
* events.onDiscoveredServices
* events.onCharacteristicReceived
* events.onCharacteristicWritten
* events.onDescriptorRead
* events.onDescriptorWritten
* events.onNameChanged (iOS Only)
* events.onBondStateChanged (Android Only)

```dart
// listen to *any device* connection state changes 
FlutterBluePlus.events.connectionState.listen((event)) {
    print('${event.device} ${event.connectionState}');
}
```

## Mocking

To mock `FlutterBluePlus` for development, refer to the [Mocking Guide](MOCKING.md).

## Getting Started

### Change the minSdkVersion for Android

flutter_blue_plus is compatible only from version 21 of Android SDK so you should change this in **android/app/build.gradle**:

```dart
Android {
  defaultConfig {
     minSdkVersion: 21
```

### Add permissions for Android (No Location)

In the **android/app/src/main/AndroidManifest.xml** add:

```xml
<!-- Tell Google Play Store that your app uses Bluetooth LE
     Set android:required="true" if bluetooth is necessary -->
<uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />

<!-- New Bluetooth permissions in Android 12
https://developer.android.com/about/versions/12/features/bluetooth-permissions -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- legacy for Android 11 or lower -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>

<!-- legacy for Android 9 or lower -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
```

### Add permissions for Android (With Fine Location)

If you want to use Bluetooth to determine location.

In the **android/app/src/main/AndroidManifest.xml** add:

```xml
<!-- Tell Google Play Store that your app uses Bluetooth LE
     Set android:required="true" if bluetooth is necessary -->
<uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />

<!-- New Bluetooth permissions in Android 12
https://developer.android.com/about/versions/12/features/bluetooth-permissions -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<!-- legacy for Android 11 or lower -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />

<!-- legacy for Android 9 or lower -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
```

And set androidUsesFineLocation when scanning:
```dart
// Start scanning
flutterBlue.startScan(timeout: Duration(seconds: 4), androidUsesFineLocation: true);
```

### Android Proguard

Add the following line in your `project/android/app/proguard-rules.pro` file:

```
-keep class com.lib.flutter_blue_plus.* { *; }
```

to avoid seeing the following kind errors in your `release` builds:

```
PlatformException(startScan, Field androidScanMode_ for m0.e0 not found. Known fields are
 [private int m0.e0.q, private b3.b0$i m0.e0.r, private boolean m0.e0.s, private static final m0.e0 m0.e0.t,
 private static volatile b3.a1 m0.e0.u], java.lang.RuntimeException: Field androidScanMode_ for m0.e0 not found
```

### Add permissions for iOS

In the **ios/Runner/Info.plist** let’s add:

```dart
	<dict>
	    <key>NSBluetoothAlwaysUsageDescription</key>
	    <string>Need BLE permission</string>
	    <key>NSBluetoothPeripheralUsageDescription</key>
	    <string>Need BLE permission</string>
	    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	    <string>Need Location permission</string>
	    <key>NSLocationAlwaysUsageDescription</key>
	    <string>Need Location permission</string>
	    <key>NSLocationWhenInUseUsageDescription</key>
	    <string>Need Location permission</string>
```

For location permissions on iOS see more at: [https://developer.apple.com/documentation/corelocation/requesting_authorization_for_location_services](https://developer.apple.com/documentation/corelocation/requesting_authorization_for_location_services)

## Reference

🌀 = Stream
⚡ = synchronous

### FlutterBluePlus API

|                        |      Android       |        iOS         | Throws | Description                                                |
| :--------------------- | :----------------: | :----------------: | :----: | :----------------------------------------------------------|
| setLogLevel            | :white_check_mark: | :white_check_mark: |        | Configure plugin log level                                 |
| isSupported            | :white_check_mark: | :white_check_mark: |        | Checks whether the device supports Bluetooth               |
| turnOn                 | :white_check_mark: |                    | :fire: | Turns on the bluetooth adapter                             |
| adapterState        🌀 | :white_check_mark: | :white_check_mark: |        | Stream of on & off states of the bluetooth adapter         |
| startScan              | :white_check_mark: | :white_check_mark: | :fire: | Starts a scan for Ble devices                              |
| stopScan               | :white_check_mark: | :white_check_mark: | :fire: | Stop an existing scan for Ble devices                      |
| scanResults         🌀 | :white_check_mark: | :white_check_mark: |        | Stream of live scan results                                |
| isScanning          🌀 | :white_check_mark: | :white_check_mark: |        | Stream of current scanning state                           |
| isScanningNow       ⚡  | :white_check_mark: | :white_check_mark: |        | Is a scan currently running?                               |
| connectedDevices    ⚡  | :white_check_mark: | :white_check_mark: |        | List of devices connected to *your app*                    |
| systemDevices          | :white_check_mark: | :white_check_mark: | :fire: | List of devices connected to the system, even by other apps|
| getPhySupport          | :white_check_mark: |                    | :fire: | Get supported bluetooth phy codings                        |

### FlutterBluePlus Events API

|                                    |      Android       |        iOS         | Throws | Description                                           |
| :--------------------------------- | :----------------: | :----------------: | :----: | :-----------------------------------------------------|
| events.onConnectionStateChanged 🌀 | :white_check_mark: | :white_check_mark: |        | Stream of connection changes of *all devices*         |
| events.onMtuChanged             🌀 | :white_check_mark: | :white_check_mark: |        | Stream of mtu changes of *all devices*                |
| events.onReadRssi               🌀 | :white_check_mark: | :white_check_mark: |        | Stream of rssi reads of *all devices*                 |
| events.onServicesReset          🌀 | :white_check_mark: | :white_check_mark: |        | Stream of services resets of *all devices*            |
| events.onDiscoveredServices     🌀 | :white_check_mark: | :white_check_mark: |        | Stream of services discovered of *all devices*        |
| events.onCharacteristicReceived 🌀 | :white_check_mark: | :white_check_mark: |        | Stream of characteristic value reads of *all devices* |
| events.onCharacteristicWritten  🌀 | :white_check_mark: | :white_check_mark: |        | Stream of characteristic value writes of *all devices*|
| events.onDescriptorRead         🌀 | :white_check_mark: | :white_check_mark: |        | Stream of descriptor value reads of *all devices*     |
| events.onDescriptorWritten      🌀 | :white_check_mark: | :white_check_mark: |        | Stream of descriptor value writes of *all devices*    |
| events.onBondStateChanged       🌀 | :white_check_mark: |                    |        | Stream of android bond state changes of *all devices* |
| events.onNameChanged            🌀 |                    | :white_check_mark: |        | Stream of iOS name changes of *all devices*           |


### BluetoothDevice API

|                           |      Android       |        iOS         | Throws | Description                                                |
| :------------------------ | :----------------: | :----------------: | :----: | :----------------------------------------------------------|
| platformName            ⚡ | :white_check_mark: | :white_check_mark: |        | The platform preferred name of the device                  |
| advName                 ⚡ | :white_check_mark: | :white_check_mark: |        | The advertised name of the device found during scanning    |
| connect                   | :white_check_mark: | :white_check_mark: | :fire: | Establishes a connection to the device                     |
| disconnect                | :white_check_mark: | :white_check_mark: | :fire: | Cancels an active or pending connection to the device      |
| isConnected             ⚡ | :white_check_mark: | :white_check_mark: |        | Is this device currently connected to *your app*?          |
| connectionState        🌀 | :white_check_mark: | :white_check_mark: |        | Stream of connection changes for the Bluetooth Device      |
| discoverServices          | :white_check_mark: | :white_check_mark: | :fire: | Discover services                                          |
| servicesList            ⚡ | :white_check_mark: | :white_check_mark: |        | The current list of available services                     |
| onServicesReset        🌀 | :white_check_mark: | :white_check_mark: |        | The services changed & must be rediscovered                |
| mtu                    🌀 | :white_check_mark: | :white_check_mark: |        | Stream of current mtu value + changes                      |
| mtuNow                  ⚡ | :white_check_mark: | :white_check_mark: |        | The current mtu value                                      |
| readRssi                  | :white_check_mark: | :white_check_mark: | :fire: | Read RSSI from a connected device                          |
| requestMtu                | :white_check_mark: |                    | :fire: | Request to change the MTU for the device                   |
| requestConnectionPriority | :white_check_mark: |                    | :fire: | Request to update a high priority, low latency connection  |
| bondState              🌀 | :white_check_mark: |                    |        | Stream of device bond state. Can be useful on Android      |
| createBond                | :white_check_mark: |                    | :fire: | Force a system pairing dialogue to show, if needed         |
| removeBond                | :white_check_mark: |                    | :fire: | Remove Bluetooth Bond of device                            |
| setPreferredPhy           | :white_check_mark: |                    | :fire: | Set preferred RX and TX phy for connection and phy options |
| clearGattCache            | :white_check_mark: |                    | :fire: | Clear android cache of service discovery results           |

### BluetoothCharacteristic API

|                    |      Android       |        iOS         | Throws | Description                                                    |
| :----------------- | :----------------: | :----------------: | :----: | :--------------------------------------------------------------|
| uuid             ⚡ | :white_check_mark: | :white_check_mark: |        | The uuid of characeristic                                      |
| read               | :white_check_mark: | :white_check_mark: | :fire: | Retrieves the value of the characteristic                      |
| write              | :white_check_mark: | :white_check_mark: | :fire: | Writes the value of the characteristic                         |
| setNotifyValue     | :white_check_mark: | :white_check_mark: | :fire: | Sets notifications or indications on the characteristic        |
| isNotifying      ⚡ | :white_check_mark: | :white_check_mark: |        | Are notifications or indications currently enabled             |
| onValueReceived 🌀 | :white_check_mark: | :white_check_mark: |        | Stream of characteristic value updates received from the device|
| lastValue        ⚡ | :white_check_mark: | :white_check_mark: |        | The most recent value of the characteristic                    |
| lastValueStream 🌀 | :white_check_mark: | :white_check_mark: |        | Stream of onValueReceived + writes                             |

### BluetoothDescriptor API

|                    |      Android       |        iOS         | Throws | Description                                    |
| :----              | :----------------: | :----------------: | :----: | :----------------------------------------------|
| uuid             ⚡ | :white_check_mark: | :white_check_mark: |        | The uuid of descriptor                         |
| read               | :white_check_mark: | :white_check_mark: | :fire: | Retrieves the value of the descriptor          |
| write              | :white_check_mark: | :white_check_mark: | :fire: | Writes the value of the descriptor             |
| onValueReceived 🌀 | :white_check_mark: | :white_check_mark: |        | Stream of descriptor value reads & writes      |
| lastValue        ⚡ | :white_check_mark: | :white_check_mark: |        | The most recent value of the descriptor        |
| lastValueStream 🌀 | :white_check_mark: | :white_check_mark: |        | Stream of onValueReceived + writes             |

## Debugging

The easiest way to debug issues in FlutterBluePlus is to make your own local copy.

```
cd /user/downloads
git clone https://github.com/boskokg/flutter_blue_plus.git
```

then in `pubspec.yaml` add the repo by path:

```
  flutter_blue_plus:
    path: /user/downloads/flutter_blue_plus
```

Now you can edit the FlutterBluePlus code yourself.

## Common Problems

Many common problems are easily solved.

---

### Scanning does not find my device

**1. your device uses bluetooth classic, not BLE.**

Headphones, speakers, keyboards, mice, gamepads, & printers all use Bluetooth Classic. 

These devices may be found in System Settings, but they cannot be connected to by FlutterBluePlus. FlutterBluePlus only supports Bluetooth Low Energy.

**2. your device stopped advertising.**

- you might need to reboot your device
- you might need put your device in "discovery mode"
- your phone may have already connected automatically
- another app may have already connected to your device
- another phone may have already connected to your device

Try looking through system devices:

```dart
// search system devices. i.e. any device connected to by *any* app
List<BluetoothDevice> system = await FlutterBluePlus.systemDevices;
for (var d in system) {
    print('${r.device.platformName} already connected to! ${r.device.remoteId}');
    if (d.platformName == "myBleDevice") {
         await r.connect(); // must connect our app
    }
}
```

**3. your scan filters are wrong.**

- try removing all scan filters
- for `withServices` to work, your device must actively advertise the serviceUUIDs it supports


**4. try a ble scanner app**

Search the App Store for a BLE scanner apps and install it on your phone, and another phone.

**Question 1:** When the issue is happening, is *your phone* (the phone with your flutter app) able to scan it using the 3rd party scanner?

**Question 2:** When the issue is happening, is *another phone* able to scan it using the 3rd party scanner?

---

### Connection fails

**1. Your ble device may be low battery**

Bluetooth can become erratic when your peripheral device is low battery.

**2. Your ble device may have refused the connection or have a bug**

Connection is a two-way process. Your ble device may be misconfigured.

**3. You may be on the edge of the Bluetooth range.**

The signal is too weak, or there are a lot of devices causing radio interference.

**4. Some phones have an issue connecting while scanning.**

The Huawei P8 Lite is one of the reported phones to have this issue. Try stopping your scanner before connecting.

**5. Try restarting your phone**

Bluetooth is a complicated system service, and can enter a bad state.

---

### The remoteId is different on Android versus iOS & macOS

This is expected. There is no way to avoid it.

For privacy, iOS & macOS use a randomly generated uuid. This uuid will periodically change.

e.g. `6920a902-ba0e-4a13-a35f-6bc91161c517`

Android uses the mac address of the bluetooth device. It never changes.

e.g. `05:A4:22:31:F7:ED`

---

### onValueReceived is never called (or lastValueStream)

**1. you are not calling the right function**

`lastValueStream` is called for `await chr.read()` & `await chr.write()` & `await chr.setNotifyValue(true)` 

`onValueReceived` is only called for `await chr.read()` & `await chr.setNotifyValue(true)` 

**2. your device has nothing to send**

If you are using `await chr.setNotifyValue(true)`, your _device_ chooses when to send data.

Try interacting with your device to get it to send new data.

**3. your device has bugs**

Try rebooting your ble device. 

Some ble devices have buggy software and stop sending data

---

### onValueReceived data is split up (or lastValueStream)

Verify that the mtu is large enough to hold your message.

```dart
device.mtu
```

If it still happens, it is a problem with your peripheral device.

---

### onValueReceived is called with duplicate data (or lastValueStream)

You are probably forgetting to cancel the original `stream.listen` resulting in multiple listens.

The easiest solution is to use `device.cancelWhenDisconnected(subscription)` to cancel device subscriptions.

```dart
final subscription = characteristic.onValueReceived.listen((value) {
    // ...
});

// make sure you have this line!
device.cancelWhenDisconnected(subscription);

await characteristic.setNotifyValue(true);
```

---

### characteristic writes fails

**1. the characeristic is not writeable**

Not all characeristics support `write`.
 
Your device must have configured this characteristic to support `write`.

**2. the data length is too long**

Characteristics only support writes up to a certain size. 

`writeWithoutResponse`: you can only write up to (MTU-3) at a time. This is a BLE limitation.

`write (with response)`: look in the [Usage](#usage) section for functions you can use to solve this issue.

**3. the characeristic does not support writeWithoutResponse**

Not all characeristics support `writeWithoutResponse`. 
 
Your device must have configured this characteristic to support `writeWithoutResponse`.

**4. your bluetooth device turned off, or is out of range**

If your device turns off mid-write, it will cause a failure.

**5. your bluetooth device has bugs**

Maybe your device crashed, or is not sending a response due to software bugs.

**6. there is radio interference**

Bluetooth is wireless and will not always work.

---

### characteristic read fails

**1. the characeristic is not readable**

Not all characeristics support `read`.
 
Your device must have configured this characteristic to support `read`.

**2. your bluetooth device turned off, or is out of range**

If your device turns off mid-read, it will cause a failure.

**3. your bluetooth device has bugs**

Maybe your device crashed, or is not sending a response due to software bugs.

**4. there is radio interference**

Bluetooth is wireless and will not always work.








