// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_print

part of flutter_blue_plus;

class FlutterBluePlus {
  ///////////////////
  //  Internal
  //

  static bool _initialized = false;

  // native platform channel
  static final MethodChannel _methods = const MethodChannel('flutter_blue_plus/methods');

  // presents the method chanel as a broadcast stream
  // ignore: close_sinks
  static final StreamController<MethodCall> _methodStream = StreamController.broadcast();

  // stream used for the isScanning public api
  static final _StreamController<bool> _isScanning = _StreamController(initialValue: false);

  // stream used for the scanResults public api
  static final _StreamController<List<ScanResult>> _scanResults = _StreamController(initialValue: []);

  // buffer for scan results that can be closed by stopScan
  static _BufferStream<ScanResult>? _scanResultsBuffer;

  // timeout for scanning that can be cancelled by stopScan
  static Timer? _scanTimeout;

  /// Log level of the instance, default is all messages (debug).
  static LogLevel _logLevel = LogLevel.debug;

  ////////////////////
  //  Public
  //

  static LogLevel get logLevel => _logLevel;

  /// Checks whether the device supports Bluetooth
  static Future<bool> get isAvailable async => await _invokeMethod('isAvailable');

  /// Return the friendly Bluetooth name of the local Bluetooth adapter
  static Future<String> get adapterName async => await _invokeMethod('getAdapterName');

  /// Checks if Bluetooth functionality is turned on
  static Future<bool> get isOn async => await _invokeMethod('isOn');

  static Stream<bool> get isScanning => _isScanning.stream;

  static bool get isScanningNow => _isScanning.latestValue;

  /// Tries to turn on Bluetooth (Android only),
  ///
  /// Returns true if bluetooth is being turned on.
  /// You have to listen for a stateChange to ON to ensure bluetooth is already running
  ///
  /// Returns false if an error occured
  ///
  static Future<bool> turnOn() async {
    return await _invokeMethod('turnOn');
  }

  /// Tries to turn off Bluetooth (Android only),
  ///
  /// Returns true if bluetooth is being turned off.
  /// You have to listen for a stateChange to OFF to ensure bluetooth is turned off
  ///
  /// Returns false if an error occured
  ///
  static Future<bool> turnOff() async {
    return await _invokeMethod('turnOff');
  }

  /// Returns a stream that is a list of [ScanResult] results while a scan is in progress.
  ///
  /// The list emitted is all the scanned results as of the last initiated scan. When a scan is
  /// first started, an empty list is emitted. The returned stream is never closed.
  ///
  /// One use for [scanResults] is as the stream in a StreamBuilder to display the
  /// results of a scan in real time while the scan is in progress.
  static Stream<List<ScanResult>> get scanResults => _scanResults.stream;

  /// Gets the current state of the Bluetooth module
  static Stream<BluetoothAdapterState> get adapterState async* {
    BluetoothAdapterState initialState = await _invokeMethod('getAdapterState')
        .then((buffer) => BmBluetoothAdapterState.fromMap(buffer))
        .then((s) => bmToBluetoothAdapterState(s.adapterState));

    yield initialState;

    Stream<BluetoothAdapterState> stream = FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "adapterStateChanged")
        .map((m) => m.arguments)
        .map((buffer) => BmBluetoothAdapterState.fromMap(buffer))
        .map((s) => bmToBluetoothAdapterState(s.adapterState));

    yield* stream;
  }

  /// Retrieve a list of connected devices
  /// The list of connected peripherals can include those that are connected
  /// by other apps and that will need to be connected locally using the
  /// device.connect() method before they can be used.
  static Future<List<BluetoothDevice>> get connectedDevices {
    return _invokeMethod('getConnectedDevices')
        .then((buffer) => BmConnectedDevicesResponse.fromMap(buffer))
        .then((p) => p.devices)
        .then((p) => p.map((d) => BluetoothDevice.fromProto(d)).toList());
  }

  /// Retrieve a list of bonded devices (Android only)
  static Future<List<BluetoothDevice>> get bondedDevices {
    return _invokeMethod('getBondedDevices')
        .then((buffer) => BmConnectedDevicesResponse.fromMap(buffer))
        .then((p) => p.devices)
        .then((p) => p.map((d) => BluetoothDevice.fromProto(d)).toList());
  }

  /// Starts a scan for Bluetooth Low Energy devices and returns a stream
  /// of the [ScanResult] results as they are received.
  ///
  /// timeout calls stopStream after a specified [Duration].
  /// You can also get a list of ongoing results in the [scanResults] stream.
  /// If scanning is already in progress, this will throw an [Exception].
  ///
  /// set [androidUsesFineLocation] to true to request the ACCESS_FINE_LOCATION permission at runtime
  /// on Android Version >=31 (Android 12). You need to add the following permission to your AndroidManifest.xml:
  /// <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  static Stream<ScanResult> scan({
    ScanMode scanMode = ScanMode.lowLatency,
    List<Guid> withServices = const [],
    List<Guid> withDevices = const [],
    List<String> macAddresses = const [],
    Duration? timeout,
    bool allowDuplicates = false,
    bool androidUsesFineLocation = false,
  }) async* {
    var settings = BmScanSettings(
        serviceUuids: withServices,
        macAddresses: macAddresses,
        allowDuplicates: allowDuplicates,
        androidScanMode: scanMode.value,
        androidUsesFineLocation: androidUsesFineLocation);

    if (_isScanning.value == true) {
      throw FlutterBluePlusException('scan', -1, 'Another scan is already in progress.');
    }

    // Clear scan results list
    _scanResults.add(<ScanResult>[]);

    Stream<ScanResult> scanResultsStream = FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "ScanResult")
        .map((m) => m.arguments)
        .map((buffer) => BmScanResult.fromMap(buffer))
        .map((p) => ScanResult.fromProto(p))
        .takeWhile((element) => _isScanning.value)
        .doOnDone(stopScan);

    // Start listening now, before invokeMethod, to ensure we don't miss any results
    _scanResultsBuffer = _BufferStream.listen(scanResultsStream);

    // Start timer *after* stream is being listened to, to make sure the
    // timeout does not fire before _scanResultsBuffer is set
    if (timeout != null) {
      _scanTimeout = Timer(timeout, () {
        _scanResultsBuffer?.close();
        _isScanning.add(false);
        _invokeMethod('stopScan');
      });
    }

    await _invokeMethod('startScan', settings.toMap());

    // push to isScanning stream after invokeMethod('startScan') is called
    _isScanning.add(true);

    await for (ScanResult item in _scanResultsBuffer!.stream) {
      // update list of devices
      List<ScanResult> list = List<ScanResult>.from(_scanResults.value);
      if (list.contains(item)) {
        // the list will have duplicates if allowDuplicates is set.
        // However, we only care to about the most recent advertisment
        // so here we replace old advertisements. 1 per device.
        int index = list.indexOf(item);
        list[index] = item;
      } else {
        list.add(item);
      }

      _scanResults.add(list);

      yield item;
    }
  }

  /// Starts a scan and returns a future that will complete once the scan has finished.
  ///
  /// Once a scan is started, call [stopScan] to stop the scan and complete the returned future.
  ///
  /// timeout automatically stops the scan after a specified [Duration].
  ///
  /// To observe the results while the scan is in progress, listen to the [scanResults] stream,
  /// or call [scan] instead.
  ///
  /// set [androidUsesFineLocation] to true to request the ACCESS_FINE_LOCATION permission at runtime
  /// on Android Version >=31 (Android 12). You need to add the following permission to your AndroidManifest.xml:
  /// <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  static Future startScan({
    ScanMode scanMode = ScanMode.lowLatency,
    List<Guid> withServices = const [],
    List<Guid> withDevices = const [],
    List<String> macAddresses = const [],
    Duration? timeout,
    bool allowDuplicates = false,
    bool androidUsesFineLocation = false,
  }) async {
    await scan(
            scanMode: scanMode,
            withServices: withServices,
            withDevices: withDevices,
            macAddresses: macAddresses,
            timeout: timeout,
            allowDuplicates: allowDuplicates,
            androidUsesFineLocation: androidUsesFineLocation)
        .drain();
    return _scanResults.value;
  }

  /// Stops a scan for Bluetooth Low Energy devices
  static Future stopScan() async {
    await _invokeMethod('stopScan');
    _scanResultsBuffer?.close();
    _scanTimeout?.cancel();
    _isScanning.add(false);
  }

  /// Sets the log level of the FlutterBlue instance
  /// Messages equal or below the log level specified are stored/forwarded,
  /// messages above are dropped.
  static void setLogLevel(LogLevel level) async {
    await _invokeMethod('setLogLevel', level.index);
    _logLevel = level;
  }

  static void _log(LogLevel level, String message) {
    if (level.index <= _logLevel.index) {
      if (kDebugMode) {
        print(message);
      }
    }
  }

  // invoke a platform method
  static Future<dynamic> _invokeMethod(String method, [dynamic arguments]) {
    if (_initialized == false) {
      _methods.setMethodCallHandler((MethodCall call) async {
        _methodStream.add(call);
      });

      setLogLevel(logLevel);

      _initialized = true;
    }

    return _methods.invokeMethod(method, arguments);
  }

  @Deprecated('Use adapterName instead')
  static Future<String> get name => adapterName;

  @Deprecated('Use adapterState instead')
  static Stream<BluetoothAdapterState> get state => adapterState;

  @Deprecated('No longer needed, remove this from your code')
  static void get instance => null;
}

/// Log levels for FlutterBlue
enum LogLevel {
  emergency, // 0
  alert, // 1
  critical, // 2
  error, // 3
  warning, // 4
  notice, // 5
  info, // 6
  debug, // 7
}

/// State of the bluetooth adapter.
enum BluetoothAdapterState { unknown, unavailable, unauthorized, turningOn, on, turningOff, off }

BluetoothAdapterState bmToBluetoothAdapterState(BmAdapterStateEnum value) {
  switch (value) {
    case BmAdapterStateEnum.unknown:
      return BluetoothAdapterState.unknown;
    case BmAdapterStateEnum.unavailable:
      return BluetoothAdapterState.unavailable;
    case BmAdapterStateEnum.unauthorized:
      return BluetoothAdapterState.unauthorized;
    case BmAdapterStateEnum.turningOn:
      return BluetoothAdapterState.turningOn;
    case BmAdapterStateEnum.on:
      return BluetoothAdapterState.on;
    case BmAdapterStateEnum.turningOff:
      return BluetoothAdapterState.turningOff;
    case BmAdapterStateEnum.off:
      return BluetoothAdapterState.off;
  }
}

class ScanMode {
  const ScanMode(this.value);
  static const lowPower = ScanMode(0);
  static const balanced = ScanMode(1);
  static const lowLatency = ScanMode(2);
  static const opportunistic = ScanMode(-1);
  final int value;
}

class DeviceIdentifier {
  final String str;
  const DeviceIdentifier(this.str);

  @Deprecated('Use str instead')
  String get id => str;

  @override
  String toString() => str;

  @override
  int get hashCode => str.hashCode;

  @override
  bool operator ==(other) => other is DeviceIdentifier && _compareAsciiLowerCase(str, other.str) == 0;
}

class ScanResult {
  ScanResult.fromProto(BmScanResult p)
      : device = BluetoothDevice.fromProto(p.device),
        advertisementData = AdvertisementData.fromProto(p.advertisementData),
        rssi = p.rssi,
        timeStamp = DateTime.now();

  final BluetoothDevice device;
  final AdvertisementData advertisementData;
  final int rssi;
  final DateTime timeStamp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ScanResult && runtimeType == other.runtimeType && device == other.device;

  @override
  int get hashCode => device.hashCode;

  @override
  String toString() {
    return 'ScanResult{'
        'device: $device, '
        'advertisementData: $advertisementData, '
        'rssi: $rssi, '
        'timeStamp: $timeStamp'
        '}';
  }
}

class AdvertisementData {
  final String localName;
  final int? txPowerLevel;
  final bool connectable;
  final Map<int, List<int>> manufacturerData;
  final Map<String, List<int>> serviceData;

  // Note: we use strings and not Guids because advertisement UUIDs can
  // be 32-bit UUIDs, 64-bit, etc i.e. "FE56"
  final List<String> serviceUuids;

  AdvertisementData.fromProto(BmAdvertisementData p)
      : localName = p.localName ?? "",
        txPowerLevel = p.txPowerLevel,
        connectable = p.connectable,
        manufacturerData = p.manufacturerData,
        serviceData = p.serviceData,
        serviceUuids = p.serviceUuids;

  @override
  String toString() {
    return 'AdvertisementData{'
        'localName: $localName, '
        'txPowerLevel: $txPowerLevel, '
        'connectable: $connectable, '
        'manufacturerData: $manufacturerData, '
        'serviceData: $serviceData, '
        'serviceUuids: $serviceUuids'
        '}';
  }
}

class FlutterBluePlusException implements Exception {
  final String errorName;
  final int? errorCode;
  final String? errorString;

  FlutterBluePlusException(this.errorName, this.errorCode, this.errorString);

  @override
  String toString() {
    return 'FlutterBluePlusException: name:$errorName errorCode:$errorCode, errorString:$errorString';
  }
}
