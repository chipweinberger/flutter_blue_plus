// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class FlutterBluePlus {
  ///////////////////
  //  Internal
  //

  static bool _initialized = false;

  // always keep track of these device variables
  static final Map<DeviceIdentifier, BmConnectionStateResponse> _connectionStates = {};
  static final Map<DeviceIdentifier, BmDiscoverServicesResult> _knownServices = {};
  static final Map<DeviceIdentifier, BmBondStateResponse> _bondStates = {};
  static final Map<DeviceIdentifier, BmMtuChangedResponse> _mtuValues = {};
  static final Map<DeviceIdentifier, String> _platformNames = {};
  static final Map<DeviceIdentifier, String> _advNames = {};
  static final Map<DeviceIdentifier, Map<String, List<int>>> _lastChrs = {};
  static final Map<DeviceIdentifier, Map<String, List<int>>> _lastDescs = {};
  static final Map<DeviceIdentifier, List<StreamSubscription>> _deviceSubscriptions = {};
  static final Map<DeviceIdentifier, List<StreamSubscription>> _delayedSubscriptions = {};
  static final Map<DeviceIdentifier, DateTime> _connectTimestamp = {};
  static final List<StreamSubscription> _scanSubscriptions = [];
  static final Set<DeviceIdentifier> _autoConnect = {};

  /// stream used for the isScanning public api
  static final _isScanning = _StreamControllerReEmit<bool>(initialValue: false);

  /// stream used for the scanResults public api
  static final _scanResults = _StreamControllerReEmit<List<ScanResult>>(initialValue: []);

  /// stream used for the scanResults public api
  static final _logsController = StreamController<String>.broadcast();

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

  ////////////////////
  //  Public
  //

  static LogLevel get logLevel => _logLevel;

  /// Checks whether the hardware supports Bluetooth
  static Future<bool> get isSupported async => await _invokeMethod(() => FlutterBluePlusPlatform.instance.isSupported(BmIsSupportedRequest()));

  /// The current adapter state
  static BluetoothAdapterState get adapterStateNow =>
      _adapterStateNow != null ? _bmToAdapterState(_adapterStateNow!) : BluetoothAdapterState.unknown;

  /// Return the friendly Bluetooth name of the local Bluetooth adapter
  static Future<String> get adapterName async => await _invokeMethod(() => FlutterBluePlusPlatform.instance.getAdapterName(BmBluetoothAdapterNameRequest())).then((r) => r.adapterName);

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

  /// Get access to FBP logs
  static Stream<String> get logs => _logsController.stream;

  /// Set configurable options
  ///   - [showPowerAlert] Whether to show the power alert (iOS & MacOS only). i.e. CBCentralManagerOptionShowPowerAlertKey
  ///       To set this option you must call this method before any other method in this package.
  ///       See: https://developer.apple.com/documentation/corebluetooth/cbcentralmanageroptionshowpoweralertkey
  ///       This option has no effect on Android.
  ///   - [restoreState] Whether to opt into state restoration (iOS & MacOS only). i.e. CBCentralManagerOptionRestoreIdentifierKey
  ///       To set this option you must call this method before any other method in this package.
  ///       See Apple Documentation for more details. This option has no effect on Android.
  static Future<void> setOptions({
    bool showPowerAlert = true,
    bool restoreState = false,
  }) async {
    await _invokeMethod(() => FlutterBluePlusPlatform.instance.setOptions(BmSetOptionsRequest(showPowerAlert: showPowerAlert, restoreState: restoreState)));
  }

  /// Turn on Bluetooth (Android only),
  static Future<void> turnOn({int timeout = 60}) async {
    var responseStream = FlutterBluePlusPlatform.instance.onTurnOnResponse;

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BmTurnOnResponse> futureResponse = responseStream.first;

    // invoke
    bool changed = await _invokeMethod(() => FlutterBluePlusPlatform.instance.turnOn(BmTurnOnRequest()));

    // only wait if bluetooth was off
    if (changed) {
      // wait for response
      BmTurnOnResponse response = await futureResponse
          .fbpTimeout(timeout, "turnOn");

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
      var result = await _invokeMethod(() => FlutterBluePlusPlatform.instance.getAdapterState(BmBluetoothAdapterStateRequest()));
      var value = result.adapterState;
      // update _adapterStateNow if it is still null after the await
      if (_adapterStateNow == null) {
        _adapterStateNow = value;
      }
    }

    yield* FlutterBluePlusPlatform.instance.onAdapterStateChanged
        .map((s) => _bmToAdapterState(s.adapterState))
        .newStreamWithInitialValue(_bmToAdapterState(_adapterStateNow!));
  }

  /// Retrieve a list of devices currently connected to your app
  static List<BluetoothDevice> get connectedDevices {
    var copy = Map.from(_connectionStates);
    copy.removeWhere((key, value) => value.connectionState == BmConnectionStateEnum.disconnected);
    return copy.values.map((v) => BluetoothDevice(remoteId: v.remoteId)).toList();
  }

  /// Retrieve a list of devices currently connected to the system
  /// - The list includes devices connected to by *any* app
  /// - You must still call device.connect() to connect them to *your app*
  /// - [withServices] required on iOS (for privacy purposes). ignored on android.
  static Future<List<BluetoothDevice>> systemDevices(List<Guid> withServices) async {
    var r = await _invokeMethod(() => FlutterBluePlusPlatform.instance.getSystemDevices(BmSystemDevicesRequest(withServices: withServices)));
    for (BmBluetoothDevice device in r.devices) {
      if (device.platformName != null) {
        _platformNames[device.remoteId] = device.platformName!;
      }
    }
    return r.devices.map((d) => BluetoothDevice.fromId(d.remoteId.str)).toList();
  }

  /// Retrieve a list of bonded devices (Android only)
  static Future<List<BluetoothDevice>> get bondedDevices async {
    var r = await _invokeMethod(() => FlutterBluePlusPlatform.instance.getBondedDevices(BmBondedDevicesRequest()));
    for (BmBluetoothDevice device in r.devices) {
      if (device.platformName != null) {
        _platformNames[device.remoteId] = device.platformName!;
      }
    }
    return r.devices.map((d) => BluetoothDevice.fromId(d.remoteId.str)).toList();
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
  ///        duplicate advertisements. This takes more power. You typically should not use this option.
  ///   - [continuousDivisor] Useful to help performance. If divisor is 3, then two-thirds of advertisements are
  ///        ignored, and one-third are processed. This reduces main-thread usage caused by the platform channel.
  ///        The scan counting is per-device so you always get the 1st advertisement from each device.
  ///        If divisor is 1, all advertisements are returned. This argument only matters for `continuousUpdates` mode.
  ///   - [oneByOne] if `true`, we will stream every advertistment one by one, possibly including duplicates.
  ///        If `false`, we deduplicate the advertisements, and return a list of devices.
  ///   - [androidLegacy] Android only. If `true`, scan on 1M phy only.
  ///        If `false`, scan on all supported phys. How the radio cycles through all the supported phys is purely
  ///        dependent on the your Bluetooth stack implementation.
  ///   - [androidScanMode] choose the android scan mode to use when scanning
  ///   - [androidUsesFineLocation] request `ACCESS_FINE_LOCATION` permission at runtime
  ///   - [webOptionalServices] the [optional services](https://developer.mozilla.org/en-US/docs/Web/API/Bluetooth/requestDevice#optionalservices)
  ///     for the web target. Required to [access device services](https://webbluetoothcg.github.io/web-bluetooth/#dom-requestdeviceoptions-optionalservices)
  ///     when scanning without [withServices] parameter.
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
    bool androidLegacy = false,
    AndroidScanMode androidScanMode = AndroidScanMode.lowLatency,
    bool androidUsesFineLocation = false,
    List<Guid> webOptionalServices = const [],
  }) async {
    // check args
    assert(removeIfGone == null || continuousUpdates, "removeIfGone requires continuousUpdates");
    assert(removeIfGone == null || !oneByOne, "removeIfGone is not compatible with oneByOne");
    assert(continuousDivisor >= 1, "divisor must be >= 1");

    // check filters
    bool hasOtherFilter = withServices.isNotEmpty ||
        withRemoteIds.isNotEmpty ||
        withNames.isNotEmpty ||
        withMsd.isNotEmpty ||
        withServiceData.isNotEmpty;

    // Note: `withKeywords` is not compatible with other filters on android
    // because it is implemented in custom fbp code, not android code, and the
    // android 'name' filter is only available as of android sdk 33 (August 2022)
    assert(!(!kIsWeb && Platform.isAndroid && withKeywords.isNotEmpty && hasOtherFilter),
        "withKeywords is not compatible with other filters on Android");

    // only allow a single task to call
    // startScan or stopScan at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("scan");
    await mtx.take();
    try {
      // already scanning?
      if (_isScanning.latestValue == true) {
        // stop existing scan
        await _stopScan();
      }

      // push to stream
      _isScanning.add(true);

      var settings = BmScanSettings(
          withServices: withServices,
          withRemoteIds: withRemoteIds,
          withNames: withNames,
          withKeywords: withKeywords,
          withMsd: withMsd.map((d) => d._bm).toList(),
          withServiceData: withServiceData.map((d) => d._bm).toList(),
          continuousUpdates: continuousUpdates,
          continuousDivisor: continuousDivisor,
          androidLegacy: androidLegacy,
          androidScanMode: androidScanMode.value,
          androidUsesFineLocation: androidUsesFineLocation,
          webOptionalServices: webOptionalServices);

      Stream<BmScanResponse> responseStream = FlutterBluePlusPlatform.instance.onScanResponse;

      // Start listening now, before invokeMethod, so we do not miss any results
      _scanBuffer = _BufferStream.listen(responseStream);

      // invoke platform method
      await _invokeMethod(() => FlutterBluePlusPlatform.instance.startScan(settings)).onError((e, s) {
        _stopScan(invokePlatform: false);
        throw e!;
      });

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
            var e = FlutterBluePlusException(_nativeError, "scan", response.errorCode, response.errorString);
            _scanResults.addError(e);
            _stopScan(invokePlatform: false);
          }

          // iterate through advertisements
          for (BmScanAdvertisement bm in response.advertisements) {
            // cache platform name
            if (bm.platformName != null) {
              _platformNames[bm.remoteId] = bm.platformName!;
            }

            // cache advertised name
            if (bm.advName != null) {
              _advNames[bm.remoteId] = bm.advName!;
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
    } finally {
      mtx.give();
    }
  }

  /// Stops a scan for Bluetooth Low Energy devices
  static Future<void> stopScan() async {
    _Mutex mtx = _MutexFactory.getMutexForKey("scan");
    await mtx.take();
    try {
      if (isScanningNow) {
        await _stopScan();
      } else if (_logLevel.index >= LogLevel.info.index) {
        log("[FBP] stopScan: already stopped");
      }
    } finally {
      mtx.give();
    }
  }

  /// for internal use
  static Future<void> _stopScan({bool invokePlatform = true}) async {
    _scanBuffer?.close();
    _scanSubscription?.cancel();
    _scanTimeout?.cancel();
    _isScanning.add(false);
    for (var subscription in _scanSubscriptions) {
      subscription.cancel();
    }
    if (invokePlatform) {
      await _invokeMethod(() => FlutterBluePlusPlatform.instance.stopScan(BmStopScanRequest()));
    }
  }

  /// Register a subscription to be canceled when scanning is complete.
  /// This function simplifies cleanup, so you can prevent creating duplicate stream subscriptions.
  ///   - this is an optional convenience function
  ///   - prevents accidentally creating duplicate subscriptions before each scan
  static void cancelWhenScanComplete(StreamSubscription subscription) {
    FlutterBluePlus._scanSubscriptions.add(subscription);
  }

  /// Sets the internal FlutterBlue log level
  static Future<void> setLogLevel(LogLevel level, {color = true}) async {
    _logLevel = level;
    await _invokeMethod(() => FlutterBluePlusPlatform.instance.setLogLevel(BmSetLogLevelRequest(logLevel: level, logColor: color)));
  }

  /// Request Bluetooth PHY support
  static Future<PhySupport> getPhySupport() async {
    // check android
    if (kIsWeb || !Platform.isAndroid) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "getPhySupport", FbpErrorCode.androidOnly.index, "android-only");
    }

    return await _invokeMethod(() => FlutterBluePlusPlatform.instance.getPhySupport(PhySupportRequest()));
  }

  static Future<void> _initFlutterBluePlus() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    // android only
    if (!kIsWeb && Platform.isAndroid) {
      FlutterBluePlusPlatform.instance.onDetachedFromEngine.listen((r) {
        _stopScan(invokePlatform: false);
      });
    }

    // keep track of adapter states
    try {
      FlutterBluePlusPlatform.instance.onAdapterStateChanged.listen((r) {
        _adapterStateNow = r.adapterState;
        if (isScanningNow && r.adapterState != BmAdapterStateEnum.on) {
          _stopScan(invokePlatform: false);
        }
        if (r.adapterState == BmAdapterStateEnum.on) {
          for (DeviceIdentifier d in _autoConnect) {
            BluetoothDevice(remoteId: d).connect(autoConnect: true, mtu: null).onError((e, s) {
              if (logLevel != LogLevel.none) {
                log("[FBP] [AutoConnect] connection failed: $e");
              }
            });
          }
        }
      });
    } on UnimplementedError {
      // ignored
    }

    // keep track of connection states
    try {
      FlutterBluePlusPlatform.instance.onConnectionStateChanged.listen((r) {
        _connectionStates[r.remoteId] = r;
        if (r.connectionState == BmConnectionStateEnum.disconnected) {
          // clear mtu
          _mtuValues.remove(r.remoteId);

          // clear lastDescs (resets 'isNotifying')
          _lastDescs.remove(r.remoteId);

          // clear lastChrs (api consistency)
          _lastChrs.remove(r.remoteId);

          // cancel & delete subscriptions
          _deviceSubscriptions[r.remoteId]?.forEach((s) => s.cancel());
          _deviceSubscriptions.remove(r.remoteId);

          // Note: to make FBP easier to use, we do not clear `knownServices`,
          // otherwise `servicesList` would be more annoying to use. We also
          // do not clear `bondState`, for faster performance.

          // autoconnect
          if (!kIsWeb && Platform.isAndroid == false) {
            if (_autoConnect.contains(r.remoteId)) {
              if (_adapterStateNow == BmAdapterStateEnum.on) {
                var d = BluetoothDevice(remoteId: r.remoteId);
                d.connect(autoConnect: true, mtu: null).onError((e, s) {
                  if (logLevel != LogLevel.none) {
                    log("[FBP] [AutoConnect] connection failed: $e");
                  }
                });
              }
            }
          }
        }
      });
    } on UnimplementedError {
      // ignored
    }

    // keep track of device name
    try {
      FlutterBluePlusPlatform.instance.onNameChanged.listen((r) {
        _platformNames[r.remoteId] = r.name;
      });
    } on UnimplementedError {
      // ignored
    }

    // keep track of services resets
    try {
      FlutterBluePlusPlatform.instance.onServicesReset.listen((r) {
        _knownServices.remove(r.remoteId);
      });
    } on UnimplementedError {
      // ignored
    }

    // keep track of bond state
    try {
      FlutterBluePlusPlatform.instance.onBondStateChanged.listen((r) {
        _bondStates[r.remoteId] = r;
      });
    } on UnimplementedError {
      // ignored
    }

    // keep track of services
    try {
      FlutterBluePlusPlatform.instance.onDiscoveredServices.listen((r) {
        if (r.success == true) {
          _knownServices[r.remoteId] = r;
        }
      });
    } on UnimplementedError {
      // ignored
    }

    // keep track of mtu values
    try {
      FlutterBluePlusPlatform.instance.onMtuChanged.listen((r) {
        if (r.success == true) {
          _mtuValues[r.remoteId] = r;
        }
      });
    } on UnimplementedError {
      // ignored
    }

    // keep track of characteristic values
    try {
      _mergeStreams([FlutterBluePlusPlatform.instance.onCharacteristicReceived, FlutterBluePlusPlatform.instance.onCharacteristicWritten]).listen((r) {
        if (r.success == true) {
          _lastChrs[r.remoteId] ??= {};
          _lastChrs[r.remoteId]!["${r.serviceUuid}:${r.characteristicUuid}"] = r.value;
        }
      });
    } on UnimplementedError {
      // ignored
    }

    // keep track of descriptor values
    try {
      _mergeStreams([FlutterBluePlusPlatform.instance.onDescriptorRead, FlutterBluePlusPlatform.instance.onDescriptorWritten]).listen((r) {
        if (r.success == true) {
          _lastDescs[r.remoteId] ??= {};
          _lastDescs[r.remoteId]!["${r.serviceUuid}:${r.characteristicUuid}:${r.descriptorUuid}"] = r.value;
        }
      });
    } on UnimplementedError {
      // ignored
    }

    // cancel delayed subscriptions
    try {
      FlutterBluePlusPlatform.instance.onConnectionStateChanged.listen((r) {
        if (_delayedSubscriptions.isNotEmpty) {
          if (r.connectionState == BmConnectionStateEnum.disconnected) {
            var remoteId = r.remoteId;
            // use delayed to update the stream before we cancel it
            Future.delayed(Duration.zero).then((_) {
              _delayedSubscriptions[remoteId]?.forEach((s) => s.cancel()); // cancel
              _delayedSubscriptions.remove(remoteId); // delete
            });
          }
        }
      });
    } on UnimplementedError {
      // ignored
    }
  }

  /// invoke a platform method
  static Future<T> _invokeMethod<T>(Future<T> Function() invoke) async {
    // only allow 1 invocation at a time (guarantees that hot restart finishes)
    _Mutex mtx = _MutexFactory.getMutexForKey("invokeMethod");
    await mtx.take();

    try {
      // initialize
      await _initFlutterBluePlus();

      // invoke
      return await invoke();
    } finally {
      mtx.give();
    }
  }

  /// Turn off Bluetooth (Android only),
  @Deprecated('Deprecated in Android SDK 33 with no replacement')
  static Future<void> turnOff({int timeout = 10}) async {
    var responseStream = FlutterBluePlusPlatform.instance.onAdapterStateChanged
        .where((p) => p.adapterState == BmAdapterStateEnum.off);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BmBluetoothAdapterState> futureResponse = responseStream.first;

    // invoke
    bool changed = await _invokeMethod(() => FlutterBluePlusPlatform.instance.turnOff(BmTurnOffRequest()));

    // only wait if bluetooth was on
    if (changed) {
      await futureResponse
          .fbpTimeout(timeout, "turnOff");
    }
  }

  static void log(String s) {
    _logsController.add(s);
    print(s);
  }

  /// Checks if Bluetooth functionality is turned on
  @Deprecated('Use adapterState.first == BluetoothAdapterState.on instead')
  static Future<bool> get isOn async => await adapterState.first == BluetoothAdapterState.on;

  @Deprecated('Use adapterName instead')
  static Future<String> get name => adapterName;

  @Deprecated('Use adapterState instead')
  static Stream<BluetoothAdapterState> get state => adapterState;

  @Deprecated('Use systemDevices instead')
  static Future<List<BluetoothDevice>> get connectedSystemDevices => systemDevices([Guid("1800")]);

  @Deprecated('No longer needed, remove this from your code')
  static void get instance => null;

  @Deprecated('Use isSupported instead')
  static Future<bool> get isAvailable async => await isSupported;

  @Deprecated('removed. read MIGRATION.md for simple alternatives')
  static Stream<ScanResult> scan() => throw Exception;
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

  /// filter for this data
  List<int> data;

  /// For any bit in the mask, set it the 1 if it needs to match
  /// the one in manufacturer data, otherwise set it to 0.
  /// The 'mask' must have the same length as 'data'.
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
      : device = BluetoothDevice(remoteId: p.remoteId),
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
  final int? appearance; // not supported on iOS / macOS
  final bool connectable;
  final Map<int, List<int>> manufacturerData; // key: manufacturerId
  final Map<Guid, List<int>> serviceData; // key: service guid
  final List<Guid> serviceUuids;

  /// for convenience, raw msd data
  ///   * interprets the first two byte as raw data,
  ///     as opposed to a `manufacturerId`
  List<List<int>> get msd {
    List<List<int>> output = [];
    manufacturerData.forEach((manufacturerId, bytes) {
      int low = manufacturerId & 0xFF;
      int high = (manufacturerId >> 8) & 0xFF;
      output.add([low, high] + bytes);
    });
    return output;
  }

  AdvertisementData({
    required this.advName,
    required this.txPowerLevel,
    required this.appearance,
    required this.connectable,
    required this.manufacturerData,
    required this.serviceData,
    required this.serviceUuids,
  });

  AdvertisementData.fromProto(BmScanAdvertisement p)
      : advName = p.advName ?? "",
        txPowerLevel = p.txPowerLevel,
        appearance = p.appearance,
        connectable = p.connectable,
        manufacturerData = p.manufacturerData,
        serviceData = p.serviceData,
        serviceUuids = p.serviceUuids;

  @override
  String toString() {
    return 'AdvertisementData{'
        'advName: $advName, '
        'txPowerLevel: $txPowerLevel, '
        'appearance: $appearance, '
        'connectable: $connectable, '
        'manufacturerData: $manufacturerData, '
        'serviceData: $serviceData, '
        'serviceUuids: $serviceUuids'
        '}';
  }

  @Deprecated('use advName instead')
  String get localName => advName;
}

enum ErrorPlatform {
  fbp,
  android,
  apple,
  linux,
  web,
}

final ErrorPlatform _nativeError = (() {
  if (kIsWeb) {
    return ErrorPlatform.web;
  } else if (Platform.isAndroid) {
    return ErrorPlatform.android;
  } else if (Platform.isIOS || Platform.isMacOS) {
    return ErrorPlatform.apple;
  } else if (Platform.isLinux) {
    return ErrorPlatform.linux;
  } else {
    return ErrorPlatform.fbp;
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
