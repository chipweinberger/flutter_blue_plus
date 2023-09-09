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
  static final Map<DeviceIdentifier, BmDiscoverServicesResult> _knownServices = {};
  static final Map<DeviceIdentifier, BmBondStateResponse> _bondStates = {};
  static final Map<DeviceIdentifier, BmMtuChangedResponse> _mtuValues = {};
  static final Map<DeviceIdentifier, Map<String, List<int>>> _lastChrs = {};
  static final Map<DeviceIdentifier, Map<String, List<int>>> _lastDescs = {};

  // stream used for the isScanning public api
  static final _isScanning = _StreamController<bool>(initialValue: false);

  // stream used for the scanResults public api
  static final _scanResultsList = _StreamController<List<ScanResult>>(initialValue: []);

  // the subscription to the scan results stream
  static StreamSubscription<BmScanResponse?>? _scanSubscription;

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

  /// Returns a stream of List<ScanResult> results while a scan is in progress.
  /// - The list contains all the results since the scan started.
  /// - The returned stream is never closed.
  static Stream<List<ScanResult>> get scanResults => _scanResultsList.stream;

  /// Turn on Bluetooth (Android only),
  static Future<void> turnOn({int timeout = 10}) async {
    Stream<BluetoothAdapterState> responseStream = adapterState.where((s) => s == BluetoothAdapterState.on);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothAdapterState> futureResponse = responseStream.first;

    await _invokeMethod('turnOn');

    await futureResponse.fbpTimeout(timeout, "turnOn");
  }

  /// Gets the current state of the Bluetooth module
  static Stream<BluetoothAdapterState> get adapterState async* {
    // start listening now so we do not miss any changes
    var buffer = _BufferStream.listen(FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnAdapterStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothAdapterState.fromMap(args))
        .map((s) => _bmToBluetoothAdapterState(s.adapterState)));

    // initial state
    BluetoothAdapterState initialValue = await _invokeMethod('getAdapterState')
        .then((args) => BmBluetoothAdapterState.fromMap(args))
        .then((s) => _bmToBluetoothAdapterState(s.adapterState));

    // make sure the initial value has not become out of date
    // while we were awaiting for the initial state
    if (buffer.hasReceivedValue == false) {
      yield initialValue;
    }

    // stream
    yield* buffer.stream;
  }

  /// Retrieve a list of connected devices
  /// - The list includes devices connected by other apps
  /// - You must call device.connect() before these devices can be used by FlutterBluePlus
  static Future<List<BluetoothDevice>> get connectedSystemDevices {
    return _invokeMethod('getConnectedSystemDevices')
        .then((args) => BmConnectedDevicesResponse.fromMap(args))
        .then((p) => p.devices)
        .then((p) => p.map((d) => BluetoothDevice.fromProto(d)).toList());
  }

  /// Retrieve a list of bonded devices (Android only)
  static Future<List<BluetoothDevice>> get bondedDevices {
    return _invokeMethod('getBondedDevices')
        .then((args) => BmConnectedDevicesResponse.fromMap(args))
        .then((p) => p.devices)
        .then((p) => p.map((d) => BluetoothDevice.fromProto(d)).toList());
  }

  /// Start a scan, and return a stream of results
  ///   - [timeout] calls stopScan after a specified duration
  ///   - [removeIfGone] if true, remove devices after they've stopped advertising for X duration
  ///   - [oneByOne] if true, we will stream every advertistment one by one, including duplicates.
  ///    If false, we deduplicate the advertisements, and return a list of devices.
  ///   - [androidUsesFineLocation] request ACCESS_FINE_LOCATION permission at runtime
  static Future<void> startScan({
    List<Guid> withServices = const [],
    Duration? timeout,
    Duration? removeIfGone,
    bool oneByOne = false,
    bool androidUsesFineLocation = false,
  }) async {
    // stop existing scan
    if (_isScanning.latestValue == true) {
      await stopScan();
    }

    // push to stream
    _isScanning.add(true);

    var settings = BmScanSettings(
        serviceUuids: withServices,
        macAddresses: [],
        allowDuplicates: true,
        androidScanMode: ScanMode.lowLatency.value,
        androidUsesFineLocation: androidUsesFineLocation);

    Stream<BmScanResponse> responseStream = FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnScanResponse")
        .map((m) => m.arguments)
        .map((args) => BmScanResponse.fromMap(args));

    // Start listening now, before invokeMethod, so we do not miss any results
    _BufferStream<BmScanResponse> _scanBuffer = _BufferStream.listen(responseStream);

    // Start timer *after* stream is being listened to, to make sure the
    // timeout does not fire before _buffer is set
    if (timeout != null) {
      _scanTimeout = Timer(timeout, stopScan);
    }

    // invoke platform method
    await _invokeMethod('startScan', settings.toMap());

    // check every 250ms for gone devices?
    late Stream<BmScanResponse?> outputStream;
    if (removeIfGone != null) {
      outputStream = _mergeStreams([_scanBuffer.stream, Stream.periodic(Duration(milliseconds: 250))]);
    } else {
      outputStream = _scanBuffer.stream;
    }

    List<ScanResult> output = [];

    // listen & push to `scanResults` stream
    _scanSubscription = outputStream.listen((BmScanResponse? response) {
      if (response == null) {
        // if null, this is just a periodic update
        // for removing old results
        output.removeWhere((elm) => DateTime.now().difference(elm.timeStamp) > removeIfGone!);

        // push to stream
        _scanResultsList.add(List.from(output));
      } else {
        // failure?
        if (response.failed != null) {
          throw FlutterBluePlusException(
              _nativeError, "scan", response.failed!.errorCode, response.failed!.errorString);
        }

        // convert
        ScanResult sr = ScanResult.fromProto(response.result!);

        // add result to output
        if (oneByOne) {
          output.clear();
          output.add(sr);
        } else {
          output.addOrUpdate(sr);
        }

        // push to stream
        _scanResultsList.add(List.from(output));
      }
    });
  }

  /// Stops a scan for Bluetooth Low Energy devices
  static Future<void> stopScan() async {
    _scanSubscription?.cancel();
    _scanTimeout?.cancel();
    _isScanning.add(false);
    await _invokeMethod('stopScan');
  }

  /// Sets the internal FlutterBlue log level
  static void setLogLevel(LogLevel level, {color = true}) async {
    await _invokeMethod('setLogLevel', level.index);
    _logLevel = level;
    _logColor = color;
  }

  static bool _isDeviceConnected(DeviceIdentifier remoteId) {
    if (_connectionStates[remoteId] == null) {
      return false;
    }
    return _connectionStates[remoteId]!.connectionState == BmConnectionStateEnum.connected;
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

    // keep track of connection states
    if (call.method == "OnConnectionStateChanged") {
      BmConnectionStateResponse r = BmConnectionStateResponse.fromMap(call.arguments);
      _connectionStates[DeviceIdentifier(r.remoteId)] = r;
      if (r.connectionState == BmConnectionStateEnum.disconnected) {
        _knownServices.remove(DeviceIdentifier(r.remoteId));
        _bondStates.remove(DeviceIdentifier(r.remoteId));
        _mtuValues.remove(DeviceIdentifier(r.remoteId));
        _lastChrs.remove(DeviceIdentifier(r.remoteId));
        _lastDescs.remove(DeviceIdentifier(r.remoteId));
      }
    }

    // keep track of bond state
    if (call.method == "OnBondStateChanged") {
      BmBondStateResponse r = BmBondStateResponse.fromMap(call.arguments);
      _bondStates[DeviceIdentifier(r.remoteId)] = r;
    }

    // keep track of services
    if (call.method == "OnDiscoverServicesResult") {
      BmDiscoverServicesResult r = BmDiscoverServicesResult.fromMap(call.arguments);
      if (r.success == true) {
        _knownServices[DeviceIdentifier(r.remoteId)] = r;
      }
    }

    // keep track of mtu values
    if (call.method == "OnMtuChanged") {
      BmMtuChangedResponse r = BmMtuChangedResponse.fromMap(call.arguments);
      if (r.success == true) {
        _mtuValues[DeviceIdentifier(r.remoteId)] = r;
      }
    }

    // keep track of characteristic values
    if (call.method == "OnCharacteristicReceived") {
      BmOnCharacteristicReceived r = BmOnCharacteristicReceived.fromMap(call.arguments);
      if (r.success == true) {
        DeviceIdentifier d = DeviceIdentifier(r.remoteId);
        _lastChrs[d] ??= {};
        _lastChrs[DeviceIdentifier(r.remoteId)]!["${r.serviceUuid}:${r.characteristicUuid}"] = r.value;
      }
    }

    // keep track of descriptor values
    if (call.method == "OnDescriptorRead") {
      BmOnDescriptorRead r = BmOnDescriptorRead.fromMap(call.arguments);
      if (r.success == true) {
        DeviceIdentifier d = DeviceIdentifier(r.remoteId);
        _lastDescs[d] ??= {};
        _lastDescs[d]!["${r.serviceUuid}:${r.characteristicUuid}:${r.descriptorUuid}"] = r.value;
      }
    }

    _methodStream.add(call);
  }

  // invoke a platform method
  static Future<dynamic> _invokeMethod(String method, [dynamic arguments]) async {
    _Mutex mtx = await _MutexFactory.getMutexForKey("invokeMethod");
    await mtx.take();

    // initialize response handler
    if (_initialized == false) {
      _initialized = true; // avoid recursion: must set before setLogLevel
      _methods.setMethodCallHandler(_methodCallHandler);
      setLogLevel(logLevel);
      while ((await _methods.invokeMethod('flutterHotRestart')) != 0) {
        await Future.delayed(Duration(milliseconds: 50));
      }
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

    mtx.give();

    return obj;
  }

  /// Turn off Bluetooth (Android only),
  @Deprecated('Deprecated in Android SDK 33 with no replacement')
  static Future<void> turnOff({int timeout = 10}) async {
    Stream<BluetoothAdapterState> responseStream = adapterState.where((s) => s == BluetoothAdapterState.off);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothAdapterState> futureResponse = responseStream.first;

    await _invokeMethod('turnOff');

    await futureResponse.fbpTimeout(timeout, "turnOff");
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

  @Deprecated('removed. use startScan with the oneByOne option instead')
  static Stream<ScanResult> scan(
          {ScanMode scanMode = ScanMode.lowLatency,
          List<Guid> withServices = const [],
          List<String> macAddresses = const [],
          Duration? timeout,
          bool allowDuplicates = false,
          bool androidUsesFineLocation = false}) =>
      throw Exception;
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

enum ErrorPlatform {
  dart,
  android,
  apple,
}

final ErrorPlatform _nativeError = (() {
  if (Platform.isAndroid) {
    return ErrorPlatform.android;
  } else {
    return ErrorPlatform.apple;
  }
})();

enum FbpErrorCode {
  success,
  timeout,
  androidOnly,
  createBondFailed,
  removeBondFailed,
  deviceIsDisconnected,
}

class FlutterBluePlusException implements Exception {
  final ErrorPlatform platform;
  final String function;
  final int? code;
  final String? description;

  FlutterBluePlusException(this.platform, this.function, this.code, this.description);

  @override
  String toString() {
    return 'FlutterBluePlusException: $function: (code: $code) $description';
  }

  @Deprecated('Use function instead')
  String get errorName => function;

  @Deprecated('Use code instead')
  int? get errorCode => code;

  @Deprecated('Use description instead')
  String? get errorString => description;
}
