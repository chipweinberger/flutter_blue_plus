[![pub package](https://img.shields.io/pub/v/flutter_blue_plus.svg)](https://pub.dartlang.org/packages/flutter_blue_plus)

<br>
<p align="center">
<img alt="FlutterBlue" src="https://github.com/boskokg/flutter_blue_plus/blob/master/site/flutterblue.png?raw=true" />
</p>
<br><br>

**Note: this plugin is continuous work from FlutterBlue since maintenance stopped.**

## Introduction

FlutterBluePlus is a bluetooth plugin for [Flutter](https://flutter.dev), a new app SDK to help developers build modern multi-platform apps.

## Cross-Platform Bluetooth LE

FlutterBluePlus aims to offer the most from all supported platforms: iOS, macOS, Android.

The code is written to be simple, robust, and incredibly easy to understand.

## No Dependencies

FlutterBluePlus has zero dependencies besides Flutter, Android, and iOS themselves.

This makes FlutterBluePlus very stable.

## Usage

### Error Handling :fire:

Flutter Blue Plus takes error handling very seriously. 

Every error returned by the native platform is checked and thrown as an exception where appropriate.

**Streams:** At the time of writing, streams returned by Flutter Blue Plus never emit any errors and never close. There's no need to handle `onError` or `onDone` for  `stream.listen(...)`.

**See the Reference section below for a complete list of throwing function.**

---

### Enable Bluetooth

```dart
// check availability
if (await FlutterBluePlus.isAvailable() == false) {
    print("Bluetooth not supported by this device");
    return;
}

// turn on bluetooth ourself if we can
if (Platform.isAndroid) {
    await FlutterBluePlus.turnOn();
}

// wait bluetooth to be on
await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first;
```

### Scan for devices

```dart
// Setup Listener for scan results
var subscription = FlutterBluePlus.scanResults.listen((results) {
    // do something with scan results
    for (ScanResult r in results) {
        print('${r.device.localName} found! rssi: ${r.rssi}');
    }
});

// Start scanning
FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

// Stop scanning
FlutterBluePlus.stopScan();
```

### Connect to a device

```dart
// Connect to the device
await device.connect();

// Disconnect from device
device.disconnect();
```

### Discover services

```dart
List<BluetoothService> services = await device.discoverServices();
services.forEach((service) {
    // do something with service
});
```

### Read and write characteristics

```dart
// Reads all characteristics
var characteristics = service.characteristics;
for(BluetoothCharacteristic c in characteristics) {
    List<int> value = await c.read();
    print(value);
}

// Writes to a characteristic
await c.write([0x12, 0x34])
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

### Set notifications and listen to changes

```dart
// Setup Listener for characteristic reads
characteristic.onValueReceived.listen((value) {
    // do something with new value
});

// enable notifications
await characteristic.setNotifyValue(true);
```

### Read the MTU and request larger size

```dart
final mtu = await device.mtu.first;
await device.requestMtu(512);
```

Note that iOS will not allow requests of MTU size, and will always try to negotiate the highest possible MTU (iOS supports up to MTU size 185)

## Getting Started

### Change the minSdkVersion for Android

flutter_blue_plus is compatible only from version 19 of Android SDK so you should change this in **android/app/build.gradle**:

```dart
Android {
  defaultConfig {
     minSdkVersion: 19
```

### Add permissions for Bluetooth

We need to add the permission to use Bluetooth and access location:

#### **Android**

In the **android/app/src/main/AndroidManifest.xml** let’s add:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

As of Android 12, ACCESS_FINE_LOCATION is no longer required. However, if you need to determine the physical
location of the device via Bluetooth, you must add this permission to your **android/app/src/main/AndroidManifest.xml**:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

and set the androidUsesFineLocation flag to true when scanning:

```dart
// Start scanning
flutterBlue.startScan(timeout: Duration(seconds: 4), androidUsesFineLocation: true);

// Stop scanning
flutterBlue.stopScan();
```

#### **IOS**

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

### FlutterBlue API

|                 |      Android       |        iOS         | Throws | Description                                          |
| :----------     | :----------------: | :----------------: | :----: | :----------------------------------------------------|
| adapterState    | :white_check_mark: | :white_check_mark: |        | Stream of state changes for the bluetooth adapter    |
| isAvailable     | :white_check_mark: | :white_check_mark: |        | Checks whether the device supports Bluetooth         |
| isOn            | :white_check_mark: | :white_check_mark: |        | Checks if Bluetooth adapter is turned on             |
| turnOn          | :white_check_mark: |                    | :fire: | Turns on the bluetooth adapter                       |
| turnOff         | :white_check_mark: |                    | :fire: | Turns off the bluetooth adapter                      |
| scan            | :white_check_mark: | :white_check_mark: | :fire: | Starts a scan for Ble devices and return a stream    |
| startScan       | :white_check_mark: | :white_check_mark: | :fire: | Starts a scan for Ble devices with no return value   |
| stopScan        | :white_check_mark: | :white_check_mark: | :fire: | Stop an existing scan for Ble devices                |
| scanResults     | :white_check_mark: | :white_check_mark: |        | Streams live scan results                            |
| isScanning      | :white_check_mark: | :white_check_mark: |        | Returns stream of current scanning state             |
| isScanningNow   | :white_check_mark: | :white_check_mark: |        | Is a scan currently running?                         |
| connectedDevices| :white_check_mark: | :white_check_mark: |        | List of already connected devices, even by other apps|
| setLogLevel     | :white_check_mark: | :white_check_mark: |        | Configure plugin log level                           |

### BluetoothDevice API

|                           |      Android       |        iOS         | Throws | Description                                                |
| :------------------------ | :----------------: | :----------------: | :----: | :----------------------------------------------------------|
| localName                 | :white_check_mark: | :white_check_mark: |        | Get the cached localName of the device                     |
| connect                   | :white_check_mark: | :white_check_mark: | :fire: | Establishes a connection to the device                     |
| disconnect                | :white_check_mark: | :white_check_mark: | :fire: | Cancels an active or pending connection to the device      |
| discoverServices          | :white_check_mark: | :white_check_mark: | :fire: | Discover services, characteristics, and descriptors        |
| isDiscoveryingServices    | :white_check_mark: | :white_check_mark: |        | Stream of whether service discovery is in progress         |
| services                  | :white_check_mark: | :white_check_mark: | :fire: | Get result of previous call to discoverServices()          |
| connectionState           | :white_check_mark: | :white_check_mark: |        | Stream of connection changes for the Bluetooth Device      |
| mtu                       | :white_check_mark: | :white_check_mark: | :fire: | Stream of mtu size changes                                 |
| readRssi                  | :white_check_mark: | :white_check_mark: | :fire: | Read RSSI from a connected device                          |
| requestMtu                | :white_check_mark: |                    | :fire: | Request to change the MTU for the device                   |
| requestConnectionPriority | :white_check_mark: |                    | :fire: | Request to update a high priority, low latency connection  |
| pair                      | :white_check_mark: |                    | :fire: | Calls createBond on a device                               |
| removeBond                | :white_check_mark: |                    | :fire: | Remove Bluetooth Bond of device                            |
| setPreferredPhy           | :white_check_mark: |                    |        | Set preferred RX and TX phy for connection and phy options |
| clearGattCache            | :white_check_mark: |                    | :fire: | Clear android cache of service discovery results           |

### BluetoothCharacteristic API

|                 |      Android       |        iOS         | Throws | Description                                                    |
| :-------------  | :----------------: | :----------------: | :----: | :--------------------------------------------------------------|
| uuid            | :white_check_mark: | :white_check_mark: |        | return the uuid of characeristic                               |
| read            | :white_check_mark: | :white_check_mark: | :fire: | Retrieves the value of the characteristic                      |
| write           | :white_check_mark: | :white_check_mark: | :fire: | Writes the value of the characteristic                         |
| setNotifyValue  | :white_check_mark: | :white_check_mark: | :fire: | Sets notifications or indications on the characteristic        |
| isNotifying     | :white_check_mark: | :white_check_mark: |        | Are notifications or indications currently enabled             |
| onValueReceived | :white_check_mark: | :white_check_mark: |        | Stream of characteristic value updates received from the device|
| lastValue       | :white_check_mark: | :white_check_mark: |        | Returns the most recent value of the characteristic            |
| lastValueStream | :white_check_mark: | :white_check_mark: |        | Stream of lastValue + onValueReceived                          |

### BluetoothDescriptor API

|                   |      Android       |        iOS         | Throws | Description                                    |
| :----             | :----------------: | :----------------: | :----: | :----------------------------------------------|
| uuid              | :white_check_mark: | :white_check_mark: |        | return the uuid of descriptor                  |
| read              | :white_check_mark: | :white_check_mark: | :fire: | Retrieves the value of the descriptor          |
| write             | :white_check_mark: | :white_check_mark: | :fire: | Writes the value of the descriptor             |
| onValueReceived   | :white_check_mark: | :white_check_mark: |        | Stream of descriptor value reads & writes      |
| lastValue         | :white_check_mark: | :white_check_mark: |        | Returns the most recent value of the descriptor|
| lastValueStream   | :white_check_mark: | :white_check_mark: |        | Stream of lastValue + onValueReceived          |


## Troubleshooting

The easiest way to debug issues in FlutterBluePlus is to first make local copy.

```
cd /user/downloads
git clone https://github.com/boskokg/flutter_blue_plus.git
```

then in `pubspec.yaml` add the repo by path:

```
  flutter_blue_plus:
    path: /user/downloads/flutter_blue_plus
```

Now you can edit FlutterBluePlus code and debug issues yourself. 

### When I scan using a service UUID filter, it doesn't find any devices.

Make sure the device is advertising which service UUID's it supports. This is found in the advertisement
packet as **UUID 16 bit complete list** or **UUID 128 bit complete list**.


