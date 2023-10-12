/// mockable version of FlutterBluePlus
/// wraps all static FBP calls

import '../flutter_blue_plus.dart';

class FlutterBluePlusMockable {
  /// Start a scan, and return a stream of results
  ///   - [timeout] calls stopScan after a specified duration
  ///   - [removeIfGone] if true, remove devices after they've stopped advertising for X duration
  ///   - [oneByOne] if true, we will stream every advertisement one by one, including duplicates.
  ///    If false, we deduplicate the advertisements, and return a list of devices.
  ///   - [androidUsesFineLocation] request ACCESS_FINE_LOCATION permission at runtime
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

  /// Gets the current state of the Bluetooth module
  Stream<BluetoothAdapterState> get adapterState {
    return FlutterBluePlus.adapterState;
  }

  /// Returns a stream of List<ScanResult> results while a scan is in progress.
  /// - The list contains all the results since the scan started.
  /// - The returned stream is never closed.
  Stream<List<ScanResult>> get scanResults {
    return FlutterBluePlus.scanResults;
  }

  /// are we scanning right now?
  bool get isScanningNow {
    return FlutterBluePlus.isScanningNow;
  }

  /// returns whether we are scanning as a stream
  Stream<bool> get isScanning {
    return FlutterBluePlus.isScanning;
  }

  /// Stops a scan for Bluetooth Low Energy devices
  Future<void> stopScan() {
    return FlutterBluePlus.stopScan();
  }

  /// Sets the internal FlutterBlue log level
  void setLogLevel(LogLevel level, {color = true}) {
    return FlutterBluePlus.setLogLevel(level, color: color);
  }

  LogLevel get logLevel {
    return FlutterBluePlus.logLevel;
  }

  /// Checks whether the hardware supports Bluetooth
  Future<bool> get isSupported {
    return FlutterBluePlus.isSupported;
  }

  /// Return the friendly Bluetooth name of the local Bluetooth adapter
  Future<String> get adapterName {
    return FlutterBluePlus.adapterName;
  }

  /// Turn on Bluetooth (Android only),
  Future<void> turnOn({int timeout = 60}) {
    return FlutterBluePlus.turnOn(timeout: timeout);
  }

  /// Turn off Bluetooth (Android only),
  @Deprecated('Deprecated in Android SDK 33 with no replacement')
  Future<void> turnOff({int timeout = 10}) {
    return FlutterBluePlus.turnOff();
  }

  /// Retrieve a list of connected devices
  /// - The list includes devices connected by other apps
  /// - You must still call device.connect() to connect them to *your app*
  Future<List<BluetoothDevice>> get connectedSystemDevices {
    return FlutterBluePlus.connectedSystemDevices;
  }

  /// Request Bluetooth PHY support
  Future<PhySupport> getPhySupport() {
    return FlutterBluePlus.getPhySupport();
  }

  /// Retrieve a list of bonded devices (Android only)
  Future<List<BluetoothDevice>> get bondedDevices {
    return FlutterBluePlus.bondedDevices;
  }
}
