// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class FlutterBluePlus {
  ///////////////////
  //  Internal
  //

  static bool _initialized = false;

  /// native platform channel
  static final MethodChannel _methods = const MethodChannel('flutter_blue_plus/methods');

  /// a broadcast stream version of the MethodChannel
  // ignore: close_sinks
  static final StreamController<MethodCall> _methodStream = StreamController.broadcast();

  // always keep track of these device variables
  static final Map<DeviceIdentifier, BmConnectionStateResponse> _connectionStates = {};
  static final Map<DeviceIdentifier, BmDiscoverServicesResult> _knownServices = {};
  static final Map<DeviceIdentifier, BmBondStateResponse> _bondStates = {};
  static final Map<DeviceIdentifier, BmMtuChangedResponse> _mtuValues = {};
  static final Map<DeviceIdentifier, Map<String, List<int>>> _lastChrs = {};
  static final Map<DeviceIdentifier, Map<String, List<int>>> _lastDescs = {};
  static final Map<DeviceIdentifier, String> _platformNames = {};
  static final Map<DeviceIdentifier, List<StreamSubscription>> _subscriptions = {};

  /// stream used for the isScanning public api
  static final _isScanning = _StreamController<bool>(initialValue: false);

  /// stream used for the scanResults public api
  static final _scanResultsList = _StreamController<List<ScanResult>>(initialValue: []);

  /// the subscription to the scan results stream
  static StreamSubscription<BmScanResponse?>? _scanSubscription;

  /// timeout for scanning that can be cancelled by stopScan
  static Timer? _scanTimeout;

  /// the last known adapter state
  static BmAdapterStateEnum? _adapterStateNow;

  /// FlutterBluePlus log level
  static LogLevel _logLevel = LogLevel.debug;
  static bool _logColor = true;

  ////////////////////
  //  Public
  //

  static LogLevel get logLevel => _logLevel;

  /// Checks whether the hardware supports Bluetooth
  static Future<bool> get isSupported async => await _invokeMethod('isSupported');

  /// Return the friendly Bluetooth name of the local Bluetooth adapter
  static Future<String> get adapterName async => await _invokeMethod('getAdapterName');

  /// returns whether we are scanning as a stream
  static Stream<bool> get isScanning => _isScanning.stream;

  /// are we scanning right now?
  static bool get isScanningNow => _isScanning.latestValue;

  /// Returns a stream of List<ScanResult> results while a scan is in progress.
  /// - The list contains all the results since the scan started.
  /// - The returned stream is never closed.
  static Stream<List<ScanResult>> get scanResults => _scanResultsList.stream;

  /// Turn on Bluetooth (Android only),
  static Future<void> turnOn({int timeout = 60}) async {
    Stream<BluetoothAdapterState> responseStream = adapterState.where((s) => s == BluetoothAdapterState.on);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothAdapterState> futureResponse = responseStream.first;

    // invoke
    await _invokeMethod('turnOn');

    // wait for response
    await futureResponse.fbpTimeout(timeout, "turnOn");
  }

  /// Gets the current state of the Bluetooth module
  static Stream<BluetoothAdapterState> get adapterState async* {
    // already have the initial value?
    if (_adapterStateNow != null) {
      yield* FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnAdapterStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmBluetoothAdapterState.fromMap(args))
          .map((s) => _bmToAdapterState(s.adapterState))
          .newStreamWithInitialValue(_bmToAdapterState(_adapterStateNow!));
    } else {
      // start listening now so we do not miss any
      // changes while we get the initial value
      var buffer = _BufferStream.listen(FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnAdapterStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmBluetoothAdapterState.fromMap(args))
          .map((s) => _bmToAdapterState(s.adapterState)));

      // initial state
      BluetoothAdapterState initialValue = await _invokeMethod('getAdapterState')
          .then((args) => BmBluetoothAdapterState.fromMap(args))
          .then((s) => _bmToAdapterState(s.adapterState));

      // make sure the initial value has not become out of date
      // while we were awaiting for the initial state
      if (buffer.hasReceivedValue == false) {
        yield initialValue;
      }

      // stream
      yield* buffer.stream;
    }
  }

  /// Retrieve a list of devices currently connected to the system
  /// - The list includes devices connected to by *any* app
  /// - You must still call device.connect() to connect them to *your app*
  static Future<List<BluetoothDevice>> get systemDevices async {
    BmDevicesList response = await _invokeMethod('getSystemDevices').then((args) => BmDevicesList.fromMap(args));
    for (BmBluetoothDevice device in response.devices) {
      if (device.platformName != null) {
        _platformNames[DeviceIdentifier(device.remoteId)] = device.platformName!;
      }
    }
    return response.devices.map((d) => BluetoothDevice.fromProto(d)).toList();
  }

  /// Retrieve a list of bonded devices (Android only)
  static Future<List<BluetoothDevice>> get bondedDevices async {
    BmDevicesList response =  await _invokeMethod('getBondedDevices').then((args) => BmDevicesList.fromMap(args));
    for (BmBluetoothDevice device in response.devices) {
      if (device.platformName != null) {
        _platformNames[DeviceIdentifier(device.remoteId)] = device.platformName!;
      }
    }
    return response.devices.map((d) => BluetoothDevice.fromProto(d)).toList();
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

    // invoke platform method
    await _invokeMethod('startScan', settings.toMap());

    // check every 250ms for gone devices?
    late Stream<BmScanResponse?> outputStream = removeIfGone != null
        ? _mergeStreams([_scanBuffer.stream, Stream.periodic(Duration(milliseconds: 250))])
        : _scanBuffer.stream;

    List<ScanResult> output = [];

    // listen & push to `scanResults` stream
    _scanSubscription = outputStream.listen((BmScanResponse? response) {
      if (response == null) {
        // if null, this is just a periodic update to remove old results
        if (output._removeWhere((elm) => DateTime.now().difference(elm.timeStamp) > removeIfGone!)) {
          _scanResultsList.add(List.from(output)); // push to stream
        }
      } else {
        // failure?
        if (response.failed != null) {
          throw FlutterBluePlusException(
              _nativeError, "scan", response.failed!.errorCode, response.failed!.errorString);
        }

        // cache platformName
        BmBluetoothDevice device = response.result!.device;
        if (device.platformName != null) {
          _platformNames[DeviceIdentifier(device.remoteId)] = device.platformName!;
        }

        // convert
        ScanResult sr = ScanResult.fromProto(response.result!);

        // add result to output
        if (oneByOne) {
          output = [sr];
        } else {
          output.addOrUpdate(sr);
        }

        // push to stream
        _scanResultsList.add(List.from(output));
      }
    });

    // Start timer *after* stream is being listened to, to make sure the
    // timeout does not fire before _scanSubscription is set
    if (timeout != null) {
      _scanTimeout = Timer(timeout, stopScan);
    }
  }

  /// Stops a scan for Bluetooth Low Energy devices
  static Future<void> stopScan() async {
    await _stopScan();
  }

  // for internal use
  static Future<void> _stopScan({bool invokePlatform = true}) async {
    _scanSubscription?.cancel();
    _scanTimeout?.cancel();
    _isScanning.add(false);
    try {
      if (invokePlatform) {
        await _invokeMethod('stopScan');
      }
    } finally {
      _scanResultsList.latestValue = [];
    }
  }

  /// Sets the internal FlutterBlue log level
  static void setLogLevel(LogLevel level, {color = true}) async {
    _logLevel = level;
    _logColor = color;
    await _invokeMethod('setLogLevel', level.index);
  }

  /// Request Bluetooth PHY support
  static Future<PhySupport> getPhySupport() async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "getPhySupport", FbpErrorCode.androidOnly.index, "android-only");
    }

    return await _invokeMethod('getPhySupport').then((args) => PhySupport.fromMap(args));
  }

  static bool _isDeviceConnected(DeviceIdentifier remoteId) {
    if (_connectionStates[remoteId] == null) {
      return false;
    }
    return _connectionStates[remoteId]!.connectionState == BmConnectionStateEnum.connected;
  }

  static Future<dynamic> _initFlutterBluePlus() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    // set platform method handler
    _methods.setMethodCallHandler(_methodCallHandler);

    // hot restart
    if ((await _methods.invokeMethod('flutterHotRestart')) != 0) {
      await Future.delayed(Duration(milliseconds: 50));
      while ((await _methods.invokeMethod('connectedCount')) != 0) {
        await Future.delayed(Duration(milliseconds: 50));
      }
    }
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

    // keep track of adapter states
    if (call.method == "OnAdapterStateChanged") {
      BmBluetoothAdapterState r = BmBluetoothAdapterState.fromMap(call.arguments);
      _adapterStateNow = r.adapterState;
      if (isScanningNow && r.adapterState != BmAdapterStateEnum.on) {
        _stopScan(invokePlatform: false);
      }
    }

    // keep track of connection states
    if (call.method == "OnConnectionStateChanged") {
      BmConnectionStateResponse r = BmConnectionStateResponse.fromMap(call.arguments);
      var remoteId = DeviceIdentifier(r.remoteId);
      _connectionStates[remoteId] = r;
      if (r.connectionState == BmConnectionStateEnum.disconnected) {
        _subscriptions[remoteId]?.forEach((s) => s.cancel());
        _knownServices.remove(remoteId);
        _bondStates.remove(remoteId);
        _mtuValues.remove(remoteId);
        _lastChrs.remove(remoteId);
        _lastDescs.remove(remoteId);
        _subscriptions.remove(remoteId);
      }
    }

    // keep track of device name
    if (call.method == "OnNameChanged") {
      BmBluetoothDevice device = BmBluetoothDevice.fromMap(call.arguments);
      if (device.platformName != null) {
        _platformNames[DeviceIdentifier(device.remoteId)] = device.platformName!;
      }
    }

    // keep track of service changes
    if (call.method == "OnServicesChanged") {
      BmBluetoothDevice device = BmBluetoothDevice.fromMap(call.arguments);
      _knownServices.remove(DeviceIdentifier(device.remoteId));
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
    if (call.method == "OnCharacteristicReceived" || call.method == "OnCharacteristicWritten") {
      BmCharacteristicData r = BmCharacteristicData.fromMap(call.arguments);
      if (r.success == true) {
        DeviceIdentifier d = DeviceIdentifier(r.remoteId);
        _lastChrs[d] ??= {};
        _lastChrs[DeviceIdentifier(r.remoteId)]!["${r.serviceUuid}:${r.characteristicUuid}"] = r.value;
      }
    }

    // keep track of descriptor values
    if (call.method == "OnDescriptorRead" || call.method == "OnDescriptorWritten") {
      BmDescriptorData r = BmDescriptorData.fromMap(call.arguments);
      if (r.success == true) {
        DeviceIdentifier d = DeviceIdentifier(r.remoteId);
        _lastDescs[d] ??= {};
        _lastDescs[d]!["${r.serviceUuid}:${r.characteristicUuid}:${r.descriptorUuid}"] = r.value;
      }
    }

    _methodStream.add(call);
  }

  /// invoke a platform method
  static Future<dynamic> _invokeMethod(String method, [dynamic arguments]) async {
    // return value
    dynamic out;

    // only allow 1 invocation at a time (guarentees that hot restart finishes)
    _Mutex mtx = await _MutexFactory.getMutexForKey("invokeMethod");
    await mtx.take();

    try {
      // initialize
      _initFlutterBluePlus();

      // log args
      if (logLevel == LogLevel.verbose) {
        String func = '<$method>';
        String args = arguments.toString();
        func = _logColor ? _black(func) : func;
        args = _logColor ? _magenta(args) : args;
        print("[FBP] $func args: $args");
      }

      // invoke
      out = await _methods.invokeMethod(method, arguments);

      // log result
      if (logLevel == LogLevel.verbose) {
        String func = '<$method>';
        String result = out.toString();
        func = _logColor ? _black(func) : func;
        result = _logColor ? _brown(result) : result;
        print("[FBP] $func result: $result");
      }
    } finally {
      mtx.give();
    }

    return out;
  }

  /// Turn off Bluetooth (Android only),
  @Deprecated('Deprecated in Android SDK 33 with no replacement')
  static Future<void> turnOff({int timeout = 10}) async {
    Stream<BluetoothAdapterState> responseStream = adapterState.where((s) => s == BluetoothAdapterState.off);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothAdapterState> futureResponse = responseStream.first;

    // invoke
    await _invokeMethod('turnOff');

    // wait for response
    await futureResponse.fbpTimeout(timeout, "turnOff");
  }

  /// Checks if Bluetooth functionality is turned on
  @Deprecated('Use adapterState.first == BluetoothAdapterState.on instead')
  static Future<bool> get isOn async => await adapterState.first == BluetoothAdapterState.on;

  @Deprecated('Use adapterName instead')
  static Future<String> get name => adapterName;

  @Deprecated('Use adapterState instead')
  static Stream<BluetoothAdapterState> get state => adapterState;

  @Deprecated('Use systemDevices instead')
  static Future<List<BluetoothDevice>> get connectedSystemDevices => systemDevices;

  @Deprecated('No longer needed, remove this from your code')
  static void get instance => null;

  @Deprecated('Use isSupported instead')
  static Future<bool> get isAvailable async => await isSupported;

  @Deprecated('removed. read MIGRATION.md for simple alternatives')
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

class PhySupport {
  /// High speed (PHY 2M)
  final bool le2M;

  /// Long range (PHY codec)
  final bool leCoded;

  PhySupport({required this.le2M, required this.leCoded});

  factory PhySupport.fromMap(Map<dynamic, dynamic> json) {
    return PhySupport(
      le2M: json['le_2M'],
      leCoded: json['le_coded'],
    );
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
  applePlatformOnly,
  createBondFailed,
  removeBondFailed,
  deviceIsDisconnected,
  serviceNotFound,
  characteristicNotFound,
  adapterIsOff,
}

class FlutterBluePlusException implements Exception {
  /// Which platform did the error occur on?
  final ErrorPlatform platform;

  /// Which function failed?
  final String function;

  /// note: depends on platform
  final int? code;

  /// note: depends on platform
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
