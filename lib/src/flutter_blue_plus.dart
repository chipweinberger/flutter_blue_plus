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
  static final Map<DeviceIdentifier, String> _platformNames = {};
  static final Map<DeviceIdentifier, String> _advNames = {};
  static final Map<DeviceIdentifier, Map<String, List<int>>> _lastChrs = {};
  static final Map<DeviceIdentifier, Map<String, List<int>>> _lastDescs = {};
  static final Map<DeviceIdentifier, List<StreamSubscription>> _subscriptions = {};
  static final Set<DeviceIdentifier> _autoConnect = {};

  /// stream used for the isScanning public api
  static final _isScanning = _StreamControllerReEmit<bool>(initialValue: false);

  /// stream used for the scanResults public api
  static final _scanResults = _StreamControllerReEmit<List<ScanResult>>(initialValue: []);

  /// buffers the scan results
  static _BufferStream<BmScanResponse>? _scanBuffer;

  /// the subscription to the merged scan results stream
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

  /// The current adapter state
  static BluetoothAdapterState get adapterStateNow =>
      _adapterStateNow != null ? _bmToAdapterState(_adapterStateNow!) : BluetoothAdapterState.unknown;

  /// Return the friendly Bluetooth name of the local Bluetooth adapter
  static Future<String> get adapterName async => await _invokeMethod('getAdapterName');

  /// returns whether we are scanning as a stream
  static Stream<bool> get isScanning => _isScanning.stream;

  /// are we scanning right now?
  static bool get isScanningNow => _isScanning.latestValue;

  /// the most recent scan results
  static List<ScanResult> get lastScanResults => _scanResults.latestValue;

  /// a stream of scan results
  /// - if you re-listen to the stream it re-emits the previous results
  /// - the list contains all the results since the scan started
  /// - the returned stream is never closed.
  static Stream<List<ScanResult>> get scanResults => _scanResults.stream;

  /// This is the same as scanResults, except:
  /// - it *does not* re-emit previous results after scanning stops.
  static Stream<List<ScanResult>> get onScanResults {
    if (isScanningNow) {
      return _scanResults.stream;
    } else {
      // skip previous results & push empty list
      return _scanResults.stream.skip(1).newStreamWithInitialValue([]);
    }
  }

  /// Get access to all device event streams
  static final BluetoothEvents events = BluetoothEvents();

  /// Turn on Bluetooth (Android only),
  static Future<void> turnOn({int timeout = 60}) async {
    var responseStream = FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnTurnOnResponse")
        .map((m) => m.arguments)
        .map((args) => BmTurnOnResponse.fromMap(args));

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BmTurnOnResponse> futureResponse = responseStream.first;

    // invoke
    bool changed = await _invokeMethod('turnOn');

    // only wait if bluetooth was off
    if (changed) {
      // wait for response
      BmTurnOnResponse response = await futureResponse.fbpTimeout(timeout, "turnOn");

      // check response
      if (response.userAccepted == false) {
        throw FlutterBluePlusException(ErrorPlatform.fbp, "turnOn", FbpErrorCode.userRejected.index, "user rejected");
      }

      // wait for adapter to turn on
      await adapterState.where((s) => s == BluetoothAdapterState.on).first.fbpTimeout(timeout, "turnOn");
    }
  }

  /// Gets the current state of the Bluetooth module
  static Stream<BluetoothAdapterState> get adapterState async* {
    // get current state if needed
    if (_adapterStateNow == null) {
      BmAdapterStateEnum val =
          await _invokeMethod('getAdapterState').then((args) => BmBluetoothAdapterState.fromMap(args).adapterState);
      // update _adapterStateNow if it is still null after the await
      if (_adapterStateNow == null) {
        _adapterStateNow = val;
      }
    }

    yield* FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnAdapterStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothAdapterState.fromMap(args))
        .map((s) => _bmToAdapterState(s.adapterState))
        .newStreamWithInitialValue(_bmToAdapterState(_adapterStateNow!));
  }

  /// Retrieve a list of devices currently connected to your app
  static List<BluetoothDevice> get connectedDevices {
    var copy = Map<DeviceIdentifier, BmConnectionStateResponse>.from(_connectionStates);
    copy.removeWhere((key, value) => value.connectionState == BmConnectionStateEnum.disconnected);
    return copy.values.map((v) => BluetoothDevice(remoteId: DeviceIdentifier(v.remoteId))).toList();
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
    BmDevicesList response = await _invokeMethod('getBondedDevices').then((args) => BmDevicesList.fromMap(args));
    for (BmBluetoothDevice device in response.devices) {
      if (device.platformName != null) {
        _platformNames[DeviceIdentifier(device.remoteId)] = device.platformName!;
      }
    }
    return response.devices.map((d) => BluetoothDevice.fromProto(d)).toList();
  }

  /// Start a scan, and return a stream of results
  /// Note: scan filters use an "or" behavior. i.e. if you set `withServices` & `withNames` we 
  /// return all the advertisments that match any of the specified services *or* any of the specified names.
  ///   - [withServices] filter by advertised services
  ///   - [withRemoteIds] filter for known remoteIds (iOS: 128-bit guid, android: 48-bit mac address)
  ///   - [withNames] filter by advertised names (exact match)
  ///   - [withKeywords] filter by advertised names (matches any substring)
  ///   - [withMsd] filter by manfacture specific data
  ///   - [withServiceData] filter by service data
  ///   - [timeout] calls stopScan after a specified duration
  ///   - [removeIfGone] if true, remove devices after they've stopped advertising for X duration
  ///   - [continuousUpdates] If `true`, we continually update 'lastSeen' & 'rssi' by processing
  ///        duplicate advertisements. This takes more power.
  ///   - [continuousDivisor] Useful to help performance. If divisor is 3, then two-thirds of advertisements are
  ///        ignored, and one-third are processed. This reduces main-thread usage caused by the platform channel.
  ///        The scan counting is per-device so you always get the 1st advertisement from each device.
  ///        If divisor is 1, all advertisements are returned. This argument only matters for `continuousUpdates` mode.
  ///   - [oneByOne] if `true`, we will stream every advertistment one by one, possibly including duplicates.
  ///        If `false`, we deduplicate the advertisements, and return a list of devices.
  ///   - [androidScanMode] choose the android scan mode to use when scanning
  ///   - [androidUsesFineLocation] request `ACCESS_FINE_LOCATION` permission at runtime
  static Future<void> startScan({
    List<Guid> withServices = const [],
    List<String> withRemoteIds = const [],
    List<String> withNames = const [],
    List<String> withKeywords = const [],
    List<MsdFilter> withMsd = const [],
    List<ServiceDataFilter> withServiceData = const [],
    Duration? timeout,
    Duration? removeIfGone,
    bool continuousUpdates = false,
    int continuousDivisor = 1,
    bool oneByOne = false,
    AndroidScanMode androidScanMode = AndroidScanMode.lowLatency,
    bool androidUsesFineLocation = false,
  }) async {
    // check args
    assert(removeIfGone == null || continuousUpdates, "removeIfGone requires continuousUpdates");
    assert(removeIfGone == null || !oneByOne, "removeIfGone is not compatible with oneByOne");
    assert(continuousDivisor >= 1, "divisor must be >= 1");

    // Note: `withKeywords` is not yet compatible with other filters on android.
    // Why? `withKeywords` is implemented in custom fbp code. If fbp wanted to support
    // `withKeywords` & other filters at the same time, fbp would need to re-implement all
    // filtering in custom code and skip android OS filtering entirely, hurting perf.
    bool other = withServices.isNotEmpty ||
        withRemoteIds.isNotEmpty ||
        withNames.isNotEmpty ||
        withMsd.isNotEmpty ||
        withServiceData.isNotEmpty;
    assert(!(Platform.isAndroid && withKeywords.isNotEmpty && other),
        "withKeywords is not compatible with other filters on Android");

    // already scanning?
    if (_isScanning.latestValue == true) {
      // stop existing scan
      await _stopScan(pushToStream: false);
    } else {
      // push to stream
      _isScanning.add(true);
    }

    var settings = BmScanSettings(
        withServices: withServices,
        withRemoteIds: withRemoteIds,
        withNames: withNames,
        withKeywords: withKeywords,
        withMsd: withMsd.map((d) => d._bm).toList(),
        withServiceData: withServiceData.map((d) => d._bm).toList(),
        continuousUpdates: continuousUpdates,
        continuousDivisor: continuousDivisor,
        androidScanMode: androidScanMode.value,
        androidUsesFineLocation: androidUsesFineLocation);

    Stream<BmScanResponse> responseStream = FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnScanResponse")
        .map((m) => m.arguments)
        .map((args) => BmScanResponse.fromMap(args));

    // Start listening now, before invokeMethod, so we do not miss any results
    _scanBuffer = _BufferStream.listen(responseStream);

    // invoke platform method
    await _invokeMethod('startScan', settings.toMap());

    // check every 250ms for gone devices?
    late Stream<BmScanResponse?> outputStream = removeIfGone != null
        ? _mergeStreams([_scanBuffer!.stream, Stream.periodic(Duration(milliseconds: 250))])
        : _scanBuffer!.stream;

    // start by pushing an empty array
    _scanResults.add([]);

    List<ScanResult> output = [];

    // listen & push to `scanResults` stream
    _scanSubscription = outputStream.listen((BmScanResponse? response) {
      if (response == null) {
        // if null, this is just a periodic update to remove old results
        if (output._removeWhere((elm) => DateTime.now().difference(elm.timeStamp) > removeIfGone!)) {
          _scanResults.add(List.from(output)); // push to stream
        }
      } else {
        // failure?
        if (response.success == false) {
          _scanResults
              .addError(FlutterBluePlusException(_nativeError, "scan", response.errorCode, response.errorString));
        }

        // iterate through advertisements
        for (BmScanAdvertisement bm in response.advertisements) {
          // cache platform name
          if (bm.platformName != null) {
            _platformNames[DeviceIdentifier(bm.remoteId)] = bm.platformName!;
          }

          // cache advertised name
          if (bm.advName != null) {
            _advNames[DeviceIdentifier(bm.remoteId)] = bm.advName!;
          }

          // convert
          ScanResult sr = ScanResult.fromProto(bm);

          if (oneByOne) {
            // push single item
            _scanResults.add([sr]);
          } else {
            // add result to output
            output.addOrUpdate(sr);
          }
        }

        // push entire list
        if (!oneByOne) {
          _scanResults.add(List.from(output));
        }
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

  /// for internal use
  static Future<void> _stopScan({bool invokePlatform = true, bool pushToStream = true}) async {
    _scanBuffer?.close();
    _scanSubscription?.cancel();
    _scanTimeout?.cancel();
    if (pushToStream) {
      _isScanning.add(false);
    }
    if (invokePlatform) {
      await _invokeMethod('stopScan');
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
          ErrorPlatform.fbp, "getPhySupport", FbpErrorCode.androidOnly.index, "android-only");
    }

    return await _invokeMethod('getPhySupport').then((args) => PhySupport.fromMap(args));
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

    // android only
    if (call.method == "OnDetachedFromEngine") {
      _stopScan(invokePlatform: false);
    }

    // keep track of adapter states
    if (call.method == "OnAdapterStateChanged") {
      BmBluetoothAdapterState r = BmBluetoothAdapterState.fromMap(call.arguments);
      _adapterStateNow = r.adapterState;
      if (isScanningNow && r.adapterState != BmAdapterStateEnum.on) {
        _stopScan(invokePlatform: false);
      }
      if (r.adapterState == BmAdapterStateEnum.on) {
        for (DeviceIdentifier d in _autoConnect) {
          BluetoothDevice(remoteId: d).connect(autoConnect: true);
        }
      }
    }

    // keep track of connection states
    if (call.method == "OnConnectionStateChanged") {
      BmConnectionStateResponse r = BmConnectionStateResponse.fromMap(call.arguments);
      var remoteId = DeviceIdentifier(r.remoteId);
      _connectionStates[remoteId] = r;
      if (r.connectionState == BmConnectionStateEnum.disconnected) {
        // to make FBP easier to use, we purposely do not clear knownServices,
        // otherwise `servicesList` would be annoying to use.
        // We also don't clear the `bondState` cache for faster performance.

        _subscriptions[remoteId]?.forEach((s) => s.cancel()); // cancel subscriptions
        _subscriptions.remove(remoteId); // delete subscriptions
        _mtuValues.remove(remoteId); // reset known mtu
        _lastDescs.remove(remoteId); // clear lastDescs so that 'isNotifying' is reset
        _lastChrs.remove(remoteId); // for api consistency, clear characteristic values

        // On apple, autoconnect is just a long running connection attempt
        // so the connection request must be restored after disconnection
        for (DeviceIdentifier d in _autoConnect) {
          if (Platform.isIOS || Platform.isMacOS) {
            if (_adapterStateNow == BmAdapterStateEnum.on) {
              BluetoothDevice(remoteId: d).connect(autoConnect: true);
            }
          }
        }
      }
    }

    // keep track of device name
    if (call.method == "OnNameChanged") {
      BmNameChanged device = BmNameChanged.fromMap(call.arguments);
      if (Platform.isMacOS || Platform.isIOS) {
        // iOS & macOS internally use the name changed callback for the platform name
        _platformNames[DeviceIdentifier(device.remoteId)] = device.name;
      }
    }

    // keep track of services resets
    if (call.method == "OnServicesReset") {
      BmBluetoothDevice device = BmBluetoothDevice.fromMap(call.arguments);
      _knownServices.remove(DeviceIdentifier(device.remoteId));
    }

    // keep track of bond state
    if (call.method == "OnBondStateChanged") {
      BmBondStateResponse r = BmBondStateResponse.fromMap(call.arguments);
      _bondStates[DeviceIdentifier(r.remoteId)] = r;
    }

    // keep track of services
    if (call.method == "OnDiscoveredServices") {
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
    _Mutex mtx = _MutexFactory.getMutexForKey("invokeMethod");
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
  static Stream<ScanResult> scan() => throw Exception;
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

class AndroidScanMode {
  const AndroidScanMode(this.value);
  static const lowPower = AndroidScanMode(0);
  static const balanced = AndroidScanMode(1);
  static const lowLatency = AndroidScanMode(2);
  static const opportunistic = AndroidScanMode(-1);
  final int value;
}

class MsdFilter {
  int manufacturerId;

  // filter for this data
  List<int> data;

  // For any bit in the mask, set it the 1 if it needs to match
  // the one in manufacturer data, otherwise set it to 0.
  // The 'mask' must have the same length as 'data'.
  List<int> mask;

  MsdFilter(this.manufacturerId, {this.data = const [], this.mask = const []});

  // convert to bmMsg
  BmMsdFilter get _bm {
    assert(mask.isEmpty || (data.length == mask.length), "mask & data must be same length");
    return BmMsdFilter(manufacturerId, data, mask);
  }
}

class ServiceDataFilter {
  Guid service;

  // filter for this data
  List<int> data;

  // For any bit in the mask, set it the 1 if it needs to match
  // the one in service data, otherwise set it to 0.
  // The 'mask' must have the same length as 'data'.
  List<int> mask;

  ServiceDataFilter(this.service, {this.data = const [], this.mask = const []});

  // convert to bmMsg
  BmServiceDataFilter get _bm {
    assert(mask.isEmpty || (data.length == mask.length), "mask & data must be same length");
    return BmServiceDataFilter(service, data, mask);
  }
}

class DeviceIdentifier {
  final String str;
  const DeviceIdentifier(this.str);

  @override
  String toString() => str;

  @override
  int get hashCode => str.hashCode;

  @override
  bool operator ==(other) => other is DeviceIdentifier && _compareAsciiLowerCase(str, other.str) == 0;

  @Deprecated('Use str instead')
  String get id => str;
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

  ScanResult.fromProto(BmScanAdvertisement p)
      : device = BluetoothDevice.fromId(p.remoteId),
        advertisementData = AdvertisementData.fromProto(p),
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
  final String advName;
  final int? txPowerLevel;
  final bool connectable;
  final Map<int, List<int>> manufacturerData; // key: manufacturerId
  final Map<Guid, List<int>> serviceData; // key: service guid
  final List<Guid> serviceUuids;

  AdvertisementData({
    required this.advName,
    required this.txPowerLevel,
    required this.connectable,
    required this.manufacturerData,
    required this.serviceData,
    required this.serviceUuids,
  });

  AdvertisementData.fromProto(BmScanAdvertisement p)
      : advName = p.advName ?? "",
        txPowerLevel = p.txPowerLevel,
        connectable = p.connectable,
        manufacturerData = p.manufacturerData,
        serviceData = p.serviceData,
        serviceUuids = p.serviceUuids;

  @override
  String toString() {
    return 'AdvertisementData{'
        'advName: $advName, '
        'txPowerLevel: $txPowerLevel, '
        'connectable: $connectable, '
        'manufacturerData: $manufacturerData, '
        'serviceData: $serviceData, '
        'serviceUuids: $serviceUuids'
        '}';
  }

  @Deprecated('use advName instead')
  String get localName => advName;
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
  fbp,
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
  connectionCanceled,
  userRejected
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
    String sPlatform = platform.toString().split('.').last;
    return 'FlutterBluePlusException | $function | $sPlatform-code: $code | $description';
  }

  @Deprecated('Use function instead')
  String get errorName => function;

  @Deprecated('Use code instead')
  int? get errorCode => code;

  @Deprecated('Use description instead')
  String? get errorString => description;
}
