# Mocking guide

How to mock `VXFlutterBlue` for testing.

## Overview

Since version [1.10.0](https://pub.dev/packages/vx_flutter_blue/changelog#1100), `VXFlutterBlue.instance` has been deprecated in favor of static functions.

Therefore, to mock VXFlutterBlue you must:

1. Wrap `VXFlutterBlue` in a mockable non-static class
2. Add your mocked functions to the mockable class.
2. Use the mockable class in your code

A full example is [here](https://dsavir-h.medium.com/mocking-bluetooth-in-flutter-updated-cb3b9484ae02).

## Mockable class

Create the following class:

```dart
import '../vx_flutter_blue.dart';

/// Wrapper for VXFlutterBlue in order to easily mock it
/// Wraps all static calls for testing purposes
class VXFlutterBlueMockable {
  Future<void> startScan({
    List<Guid> withServices = const [],
    Duration? timeout,
    Duration? removeIfGone,
    bool oneByOne = false,
    bool androidUsesFineLocation = false,
  }) {
    return VXFlutterBlue.startScan(
        withServices: withServices,
        timeout: timeout,
        removeIfGone: removeIfGone,
        oneByOne: oneByOne,
        androidUsesFineLocation: androidUsesFineLocation);
  }

  Stream<BluetoothAdapterState> get adapterState {
    return VXFlutterBlue.adapterState;
  }

  Stream<List<ScanResult>> get scanResults {
    return VXFlutterBlue.scanResults;
  }

  bool get isScanningNow {
    return VXFlutterBlue.isScanningNow;
  }

  Stream<bool> get isScanning {
    return VXFlutterBlue.isScanning;
  }

  Future<void> stopScan() {
    return VXFlutterBlue.stopScan();
  }

  void setLogLevel(LogLevel level, {color = true}) {
    return VXFlutterBlue.setLogLevel(level, color: color);
  }

  LogLevel get logLevel {
    return VXFlutterBlue.logLevel;
  }

  Future<bool> get isSupported {
    return VXFlutterBlue.isSupported;
  }

  Future<String> get adapterName {
    return VXFlutterBlue.adapterName;
  }

  Future<void> turnOn({int timeout = 60}) {
    return VXFlutterBlue.turnOn(timeout: timeout);
  }

  List<BluetoothDevice> get connectedDevices {
    return VXFlutterBlue.connectedDevices;
  }

  Future<List<BluetoothDevice>> get systemDevices {
    return VXFlutterBlue.systemDevices;
  }

  Future<PhySupport> getPhySupport() {
    return VXFlutterBlue.getPhySupport();
  }

  Future<List<BluetoothDevice>> get bondedDevices {
    return VXFlutterBlue.bondedDevices;
  }
}
```

## Mock the wrapper class

Using e.g. [Mockito](https://pub.dev/packages/mockito), create a mock for the `VXFlutterBlueMockable` class, and build your tests and stubs.

## Create instance

Use the mockable class where needed, e.g. in `main.dart`:

```dart
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);
  //instance of VXFlutterBlue that will be passed
  //throughout the app as necessary
  VXFlutterBlueMockable bluePlusMockable = VXFlutterBlueMockable();//<--

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My app',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
      ),
      home:  FindDevicesScreen(
        bluePlusMockable: bluePlusMockable,
      );
    );
  }
}
```

## Use mock instead of VXFlutterBlue

Within your code, replace all calls to `VXFlutterBlue` with the mockable instance, e.g.:  
`VXFlutterBlue.isScanning` --> `bluePlusMockable.isScanning`  
`VXFlutterBlue.startScan` --> `bluePlusMockable.startScan`  
`VXFlutterBlue.scanResults` --> `bluePlusMockable.scanResults`  
etc.

## Example

Detailed example is [here](https://dsavir-h.medium.com/mocking-bluetooth-in-flutter-updated-cb3b9484ae02).
