# Mocking guide

How to mock `FlutterBluePlus` for testing.

## Overview

Since version [1.10.0](https://pub.dev/packages/flutter_blue_plus/changelog#1100), `FlutterBluePlus.instance` has been deprecated in favor of static functions, as no platform supports multiple instances. Therefore, in order to mock `FlutterBluePlus` functions for testing, you need to:

1. Wrap `FlutterBluePlus` in a mockable class
2. Create an instance of the mockable class
3. Pass the instance to all classes that call `FlutterBluePlus`
4. Mock the mockable class.

A full example is [here](https://dsavir-h.medium.com/mocking-bluetooth-in-flutter-updated-cb3b9484ae02).

## Mockable class

Create the following class:

```dart
import '../flutter_blue_plus.dart';

///Wrapper for FlutterBluePlus in order to easily mock it
///Wraps all static calls for testing purposes
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

  @Deprecated('Deprecated in Android SDK 33 with no replacement')
  Future<void> turnOff({int timeout = 10}) {
    return FlutterBluePlus.turnOff();
  }


  Future<List<BluetoothDevice>> get connectedSystemDevices {
    return FlutterBluePlus.connectedSystemDevices;
  }

  Future<PhySupport> getPhySupport() {
    return FlutterBluePlus.getPhySupport();
  }

  Future<List<BluetoothDevice>> get bondedDevices {
    return FlutterBluePlus.bondedDevices;
  }
}
```

## Create instance

Create instance of the mockable class where needed, e.g. in `main.dart`:

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

## Use instance instead of FlutterBluePlus

Within your code, replace all calls to `FutterBluePlus` with the mockable instance, e.g.:  
`FlutterBluePlus.isScanning` --> `bluePlusMockable.isScanning`  
`FlutterBluePlus.startScan` --> `bluePlusMockable.startScan`  
`FlutterBluePlus.scanResults` --> `bluePlusMockable.scanResults`  
etc.

## Mock wrapper class

Using e.g. [Mockito](https://pub.dev/packages/mockito), create a mock for the `FlutterBluePlusMockable` class, and build your tests and stubs.

## Example

Detailed example is [here](https://dsavir-h.medium.com/mocking-bluetooth-in-flutter-updated-cb3b9484ae02).
