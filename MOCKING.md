# Mocking guide

How to mock `FlutterBluePlus` for testing.

## Overview

Since version [1.10.0](https://pub.dev/packages/flutter_blue_plus/changelog#1100), `FlutterBluePlus.instance` has been deprecated in favor of static functions. 

Therefore, to mock FlutterBluePlus you must:

1. Wrap `FlutterBluePlus` in a mockable non-static class
2. Add your mocked functions to the mockable class.
2. Use the mockable class in your code

A full example is [here](https://dsavir-h.medium.com/mocking-bluetooth-in-flutter-updated-cb3b9484ae02).

## Mockable class

Create the following class:

```dart
import '../flutter_blue_plus.dart';

/// Wrapper for FlutterBluePlus in order to easily mock it
/// Wraps all static calls for testing purposes
class FlutterBluePlusMockable {
  Future<void> startScan({
    List<Guid> withServices = const [],
    Duration? timeout,
    Duration? removeIfGone,
    bool oneByOne = false,
    bool androidUsesFineLocation = false,
  }) {
    return FlutterBluePlus.startScan(
        withServices: withServices,
        timeout: timeout,
        removeIfGone: removeIfGone,
        oneByOne: oneByOne,
        androidUsesFineLocation: androidUsesFineLocation);
  }

  Stream<BluetoothAdapterState> get adapterState {
    return FlutterBluePlus.adapterState;
  }

  Stream<List<ScanResult>> get scanResults {
    return FlutterBluePlus.scanResults;
  }

  bool get isScanningNow {
    return FlutterBluePlus.isScanningNow;
  }

  Stream<bool> get isScanning {
    return FlutterBluePlus.isScanning;
  }

  Future<void> stopScan() {
    return FlutterBluePlus.stopScan();
  }

  void setLogLevel(LogLevel level, {color = true}) {
    return FlutterBluePlus.setLogLevel(level, color: color);
  }

  LogLevel get logLevel {
    return FlutterBluePlus.logLevel;
  }

  Future<bool> get isSupported {
    return FlutterBluePlus.isSupported;
  }

  Future<String> get adapterName {
    return FlutterBluePlus.adapterName;
  }

  Future<void> turnOn({int timeout = 60}) {
    return FlutterBluePlus.turnOn(timeout: timeout);
  }

  List<BluetoothDevice> get connectedDevices {
    return FlutterBluePlus.connectedDevices;
  }

  Future<List<BluetoothDevice>> get systemDevices {
    return FlutterBluePlus.systemDevices;
  }

  Future<PhySupport> getPhySupport() {
    return FlutterBluePlus.getPhySupport();
  }

  Future<List<BluetoothDevice>> get bondedDevices {
    return FlutterBluePlus.bondedDevices;
  }
}
```

## Mock the wrapper class

Using e.g. [Mockito](https://pub.dev/packages/mockito), create a mock for the `FlutterBluePlusMockable` class, and build your tests and stubs.

## Create instance

Use the mockable class where needed, e.g. in `main.dart`:

```dart
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);
  //instance of FlutterBluePlus that will be passed
  //throughout the app as necessary
  FlutterBluePlusMockable bluePlusMockable = FlutterBluePlusMockable();//<--

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

## Use mock instead of FlutterBluePlus

Within your code, replace all calls to `FutterBluePlus` with the mockable instance, e.g.:  
`FlutterBluePlus.isScanning` --> `bluePlusMockable.isScanning`  
`FlutterBluePlus.startScan` --> `bluePlusMockable.startScan`  
`FlutterBluePlus.scanResults` --> `bluePlusMockable.scanResults`  
etc.

## Example

Detailed example is [here](https://dsavir-h.medium.com/mocking-bluetooth-in-flutter-updated-cb3b9484ae02).
