// Copyright 2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class FlutterBluePlus {
  ///////////////////
  //  Internal
  //

  static bool _initialized = false;

  // native platform channel
  static final MethodChannel _methods = const MethodChannel('flutter_blue_plus/methods');

  // a broadcast stream version of the MethodChannel
  // ignore: close_sinks
  static final StreamController<MethodCall> _methodStream = StreamController.broadcast();

  // we always keep track of these device variables
  static final Map<DeviceIdentifier, BmConnectionStateResponse> _connectionStates = {};
  static final Map<DeviceIdentifier, BmBondStateResponse> _bondStates = {};
  static final Map<DeviceIdentifier, BmMtuChangedResponse> _mtuValues = {};

  // stream used for the isScanning public api
  static final _StreamController<bool> _isScanning = _StreamController(initialValue: false);

  // stream used for the scanResults public api
  static final _StreamController<List<ScanResult>> _scanResultsList = _StreamController(initialValue: []);

  // ScanResponses are received from the system one-by-one from the method broadcast stream.
  // This variable buffers all the results into a single-subscription stream.
  // We store it at the top level so it can be closed by stopScan
  static _BufferStream<BmScanResponse>? _scanResponseBuffer;

  // timeout for scanning that can be cancelled by stopScan
  static Timer? _scanTimeout;

  /// FlutterBluePlus log level
  static LogLevel _logLevel = LogLevel.debug;
  static bool _logColor = true;

  ////////////////////
  //  Public
  //

  static LogLevel get logLevel => _logLevel;

  /// Checks whether the device allows Bluetooth for your app
  static Future<bool> get isAvailable async => await _invokeMethod('isAvailable');

  /// Return the friendly Bluetooth name of the local Bluetooth adapter
  static Future<String> get adapterName async => await _invokeMethod('getAdapterName');

  // returns whether we are scanning as a stream
  static Stream<bool> get isScanning => _isScanning.stream;

  // are we scanning right now?
  static bool get isScanningNow => _isScanning.latestValue;

  /// Turn on Bluetooth (Android only),
  static Future<void> turnOn({int timeout = 10}) async {
    Stream<BluetoothAdapterState> responseStream = adapterState.where((s) => s == BluetoothAdapterState.on);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothAdapterState> futureResponse = responseStream.first;

    await _invokeMethod('turnOn');

    await futureResponse.timeout(Duration(seconds: timeout));
  }

  /// Returns a stream of List<ScanResult> results while a scan is in progress.
  /// - The list contains all the results since the scan started.
  /// - When a scan is first started, an empty list is emitted.
  /// - The returned stream is never closed.
  static Stream<List<ScanResult>> get scanResults => _scanResultsList.stream;

  /// Gets the current state of the Bluetooth module
  static Stream<BluetoothAdapterState> get adapterState async* {
    BluetoothAdapterState initialState = await _invokeMethod('getAdapterState')
        .then((buffer) => BmBluetoothAdapterState.fromMap(buffer))
        .then((s) => _bmToBluetoothAdapterState(s.adapterState));

    yield initialState;

    Stream<BluetoothAdapterState> responseStream = FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnAdapterStateChanged")
        .map((m) => m.arguments)
        .map((buffer) => BmBluetoothAdapterState.fromMap(buffer))
        .map((s) => _bmToBluetoothAdapterState(s.adapterState));

    yield* responseStream;
  }

  /// Retrieve a list of connected devices
  /// - The list includes devices connected by other apps
  /// - You must call device.connect() before these devices can be used by FlutterBluePlus
  static Future<List<BluetoothDevice>> get connectedSystemDevices {
    return _invokeMethod('getConnectedSystemDevices')
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
  ///    - throws an exception if scanning is already in progress
  ///    - [timeout] calls stopScan after a specified duration
  ///    - [androidUsesFineLocation] requests ACCESS_FINE_LOCATION permission at runtime regardless
  ///    of Android version. On Android 11 and below (Sdk < 31), this permission is required
  ///    and therefore we will always request it. Your AndroidManifest.xml must match.
  static Stream<ScanResult> scan({
    ScanMode scanMode = ScanMode.lowLatency,
    List<Guid> withServices = const [],
    List<String> macAddresses = const [],
    Duration? timeout,
    bool allowDuplicates = false,
    bool androidUsesFineLocation = false,
  }) async* {
    try {
      var settings = BmScanSettings(
          serviceUuids: withServices,
          macAddresses: macAddresses,
          allowDuplicates: allowDuplicates,
          androidScanMode: scanMode.value,
          androidUsesFineLocation: androidUsesFineLocation);

      if (_isScanning.value == true) {
        throw FlutterBluePlusException('scan', -1, 'Another scan is already in progress.');
      }

      // push to isScanning stream
      // we must do this early on to prevent duplicate scans
      _isScanning.add(true);

      // Clear scan results list
      _scanResultsList.add(<ScanResult>[]);

      Stream<BmScanResponse> responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnScanResponse")
          .map((m) => m.arguments)
          .map((buffer) => BmScanResponse.fromMap(buffer))
          .takeWhile((element) => _isScanning.value)
          .doOnDone(stopScan);

      // Start listening now, before invokeMethod, to ensure we don't miss any results
      _scanResponseBuffer = _BufferStream.listen(responseStream);

      // Start timer *after* stream is being listened to, to make sure the
      // timeout does not fire before _scanResponseBuffer is set
      if (timeout != null) {
        _scanTimeout = Timer(timeout, () {
          _scanResponseBuffer?.close();
          _isScanning.add(false);
          _invokeMethod('stopScan');
        });
      }

      await _invokeMethod('startScan', settings.toMap());

      await for (BmScanResponse response in _scanResponseBuffer!.stream) {
        // failure?
        if (response.failed != null) {
          throw FlutterBluePlusException("scan", response.failed!.errorCode, response.failed!.errorString);
        }

        // no result?
        if (response.result == null) {
          continue;
        }

        ScanResult item = ScanResult.fromProto(response.result!);

        // make new list while considering duplicates
        List<ScanResult> list = _addOrUpdate(_scanResultsList.value, item);

        // update list
        _scanResultsList.add(list);

        yield item;
      }
    } finally {
      // cleanup
      _scanResponseBuffer?.close();
      _isScanning.add(false);
    }
  }

  /// Start a scan
  ///  - future completes when the scan is done.
  ///  - To observe the results live, listen to the [scanResults] stream.
  ///  - call [stopScan] to complete the returned future, or set [timeout]
  ///  - see [scan] documentation for more details
  static Future startScan({
    ScanMode scanMode = ScanMode.lowLatency,
    List<Guid> withServices = const [],
    List<String> macAddresses = const [],
    Duration? timeout,
    bool allowDuplicates = false,
    bool androidUsesFineLocation = false,
  }) async {
    await scan(
            scanMode: scanMode,
            withServices: withServices,
            macAddresses: macAddresses,
            timeout: timeout,
            allowDuplicates: allowDuplicates,
            androidUsesFineLocation: androidUsesFineLocation)
        .drain();
    return _scanResultsList.value;
  }

  /// Stops a scan for Bluetooth Low Energy devices
  static Future stopScan() async {
    await _invokeMethod('stopScan');
    _scanResponseBuffer?.close();
    _scanTimeout?.cancel();
    _isScanning.add(false);
  }

  /// Sets the internal FlutterBlue log level
  static void setLogLevel(LogLevel level, {color = true}) async {
    await _invokeMethod('setLogLevel', level.index);
    _logLevel = level;
    _logColor = color;
  }

  static Future<dynamic> _methodCallHandler(MethodCall call) async {
    // log result
    if (logLevel == LogLevel.verbose) {
      String func = '[[ ${call.method} ]]';
      String result = call.arguments.toString();
      func = _logColor ? _black(func) : func;
      result = _logColor ? _brown(result) : result;
      print("[FBP] $func result: $result");
    }

    // keep track of bond state
    if (call.method == "OnBondStateChanged") {
      BmBondStateResponse response = BmBondStateResponse.fromMap(call.arguments);
      _bondStates[DeviceIdentifier(response.remoteId)] = response;
    }

    // keep track of connection states
    if (call.method == "OnConnectionStateChanged") {
      BmConnectionStateResponse response = BmConnectionStateResponse.fromMap(call.arguments);
      _connectionStates[DeviceIdentifier(response.remoteId)] = response;
    }

    // keep track of mtu values
    if (call.method == "OnMtuChanged") {
      BmMtuChangedResponse response = BmMtuChangedResponse.fromMap(call.arguments);
      _mtuValues[DeviceIdentifier(response.remoteId)] = response;
    }

    _methodStream.add(call);
  }

  // invoke a platform method
  static Future<dynamic> _invokeMethod(String method, [dynamic arguments]) async {
    // initialize response handler
    if (_initialized == false) {
      _initialized = true; // avoid recursion: must set before setLogLevel
      _methods.setMethodCallHandler(_methodCallHandler);
      setLogLevel(logLevel);
    }

    // log args
    if (logLevel == LogLevel.verbose) {
      String func = '<$method>';
      String args = arguments.toString();
      func = _logColor ? _black(func) : func;
      args = _logColor ? _magenta(args) : args;
      print("[FBP] $func args: $args");
    }

    // invoke
    dynamic obj = await _methods.invokeMethod(method, arguments);

    // log result
    if (logLevel == LogLevel.verbose) {
      String func = '<$method>';
      String result = obj.toString();
      func = _logColor ? _black(func) : func;
      result = _logColor ? _brown(result) : result;
      print("[FBP] $func result: $result");
    }

    return obj;
  }

  /// Turn off Bluetooth (Android only),
  @Deprecated('Deprecated in Android SDK 33 with no replacement')
  static Future<void> turnOff({int timeout = 10}) async {
    Stream<BluetoothAdapterState> responseStream = adapterState.where((s) => s == BluetoothAdapterState.off);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothAdapterState> futureResponse = responseStream.first;

    await _invokeMethod('turnOff');

    await futureResponse.timeout(Duration(seconds: timeout));
  }

  /// Checks if Bluetooth functionality is turned on
  @Deprecated('Use adapterState.first == BluetoothAdapterState.on instead')
  static Future<bool> get isOn async => await adapterState.first == BluetoothAdapterState.on;

  @Deprecated('Use adapterName instead')
  static Future<String> get name => adapterName;

  @Deprecated('Use adapterState instead')
  static Stream<BluetoothAdapterState> get state => adapterState;

  @Deprecated('No longer needed, remove this from your code')
  static void get instance => null;

  @Deprecated('Use connectedSystemDevices instead')
  static Future<List<BluetoothDevice>> get connectedDevices => connectedSystemDevices;
}

/// Log levels for FlutterBlue
enum LogLevel {
  none, //0
  error, // 1
  warning, // 2
  info, // 3
  debug, // 4
  verbose, //5
}

/// State of the bluetooth adapter.
enum BluetoothAdapterState { unknown, unavailable, unauthorized, turningOn, on, turningOff, off }

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
  final BluetoothDevice device;
  final AdvertisementData advertisementData;
  final int rssi;
  final DateTime timeStamp;

  ScanResult({
    required this.device,
    required this.advertisementData,
    required this.rssi,
    required this.timeStamp,
  });

  ScanResult.fromProto(BmScanResult p)
      : device = BluetoothDevice.fromProto(p.device),
        advertisementData = AdvertisementData.fromProto(p.advertisementData),
        rssi = p.rssi,
        timeStamp = DateTime.now();

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

  AdvertisementData({
    required this.localName,
    required this.txPowerLevel,
    required this.connectable,
    required this.manufacturerData,
    required this.serviceData,
    required this.serviceUuids,
  });

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
