// Copyright 2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDevice {
  ////////////////////////////////
  // Internal
  //

  static Map<DeviceIdentifier, List<BluetoothService>> _knownServices = {};

  // used for 'services' public api
  final StreamController<List<BluetoothService>> _services = StreamController.broadcast();

  // used for 'isDiscoveringServices' public api
  final _StreamController<bool> _isDiscoveringServices = _StreamController(initialValue: false);

  ////////////////////////////////
  // Public
  //

  final DeviceIdentifier remoteId;
  final String localName;
  final BluetoothDeviceType type;

  BluetoothDevice({
    required this.remoteId,
    required this.localName,
    required this.type,
  });

  BluetoothDevice.fromProto(BmBluetoothDevice p)
      : remoteId = DeviceIdentifier(p.remoteId),
        localName = p.localName ?? "",
        type = _bmToBluetoothDeviceType(p.type);

  /// allows connecting to a known device without re-scanning
  /// Note: this device must have been discovered by your app in a previous scan
  BluetoothDevice.fromId(String remoteId, {String? localName, BluetoothDeviceType? type})
      : remoteId = DeviceIdentifier(remoteId),
        localName = localName ?? "Unknown",
        type = type ?? BluetoothDeviceType.unknown;

  // stream return whether or not we are currently discovering services
  Stream<bool> get isDiscoveringServices => _isDiscoveringServices.stream;

  // Get services
  //  - returns null if discoverServices() has not been called
  List<BluetoothService>? get servicesList => _knownServices[remoteId];

  /// Stream of bluetooth services offered by the remote device
  Stream<List<BluetoothService>> get servicesStream async* {
    if (_knownServices[remoteId] != null) {
      yield _knownServices[remoteId]!;
    }
    yield* _services.stream;
  }

  /// Establishes a connection to the Bluetooth Device.
  ///   [autoConnect] Android only. reconnect whenever the device is found. This only
  ///   works if the device is in the Bluetooth scan cache or it is has been bonded before.
  ///   The scan cache is cleared whenever bluetooth is turned off.
  Future<void> connect({
    Duration timeout = const Duration(seconds: 15),
    bool autoConnect = false,
  }) async {
    // Only allow a single 'connectDisconnect' operation to be underway per device.
    String key = remoteId.str + ":connectDisconnect";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    try {
      var request = BmConnectRequest(
        remoteId: remoteId.str,
        autoConnect: autoConnect,
      );

      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnConnectionStateChanged")
          .map((m) => m.arguments)
          .map((buffer) => BmConnectionStateResponse.fromMap(buffer))
          .where((p) => p.remoteId == remoteId.str)
          .where((p) =>
              p.connectionState == BmConnectionStateEnum.disconnected ||
              p.connectionState == BmConnectionStateEnum.connected);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmConnectionStateResponse> futureState = responseStream.first;

      await FlutterBluePlus._invokeMethod('connect', request.toMap());

      // wait for result
      BmConnectionStateResponse response = await futureState.timeout(timeout);

      // failure?
      if (response.connectionState == BmConnectionStateEnum.disconnected) {
        throw FlutterBluePlusException('connect', response.disconnectReasonCode, response.disconnectReasonString);
      }
    } finally {
      opMutex.give();
    }
  }

  /// Cancels connection to the Bluetooth Device
  Future<void> disconnect({int timeout = 15}) async {
    // Only allow a single 'connectDisconnect' operation to be underway per device.
    String key = remoteId.str + ":connectDisconnect";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnConnectionStateChanged")
          .map((m) => m.arguments)
          .map((buffer) => BmConnectionStateResponse.fromMap(buffer))
          .where((p) => p.remoteId == remoteId.str)
          .where((p) => p.connectionState == BmConnectionStateEnum.disconnected);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmConnectionStateResponse> futureState = responseStream.first;

      await FlutterBluePlus._invokeMethod('disconnect', remoteId.str);

      // wait for disconnection
      await futureState.timeout(Duration(seconds: timeout));
    } finally {
      opMutex.give();
    }
  }

  /// Discover services, characteristics, and descriptors of the remote device
  Future<List<BluetoothService>> discoverServices({int timeout = 15}) async {
    // check & wait if bonding
    await _waitIfBonding(remoteId);

    // Only allow a single 'discoverServices' operation to be underway per device.
    String key = remoteId.str + ":discoverServices";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    List<BluetoothService> result = [];

    try {
      if (await connectionState.first != BluetoothConnectionState.connected) {
        throw FlutterBluePlusException('discoverServices', -1, 'device is not connected');
      }

      // signal that we have started
      _isDiscoveringServices.add(true);

      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDiscoverServicesResult")
          .map((m) => m.arguments)
          .map((buffer) => BmDiscoverServicesResult.fromMap(buffer))
          .where((p) => p.remoteId == remoteId.str);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmDiscoverServicesResult> futureResponse = responseStream.first;

      await FlutterBluePlus._invokeMethod('discoverServices', remoteId.str);

      // wait for response
      BmDiscoverServicesResult response = await futureResponse.timeout(Duration(seconds: timeout));

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException("discoverServices", response.errorCode, response.errorString);
      }

      result = response.services.map((p) => BluetoothService.fromProto(p)).toList();

      // remember known services
      _knownServices[remoteId] = result;

      // add to stream
      _services.add(result);
    } finally {
      _isDiscoveringServices.add(false);
      opMutex.give();
    }

    return result;
  }

  /// The current connection state of the device to this application
  Stream<BluetoothConnectionState> get connectionState async* {
    // initial value
    yield _bmToBluetoothConnectionState(
        FlutterBluePlus._connectionStates[remoteId]?.connectionState ?? BmConnectionStateEnum.disconnected);
    // stream
    yield* FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnConnectionStateChanged")
        .map((m) => m.arguments)
        .map((buffer) => BmConnectionStateResponse.fromMap(buffer))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => _bmToBluetoothConnectionState(p.connectionState));
  }

  /// The current MTU size in bytes
  Stream<int> get mtu async* {
    // initial value
    yield FlutterBluePlus._mtuValues[remoteId]?.mtu ?? 23;
    // stream
    yield* FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnMtuChanged")
        .map((m) => m.arguments)
        .map((buffer) => BmMtuChangedResponse.fromMap(buffer))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => p.mtu);
  }

  /// Request to change MTU (Android Only)
  ///  - returns new MTU
  Future<int> requestMtu(int desiredMtu, {int timeout = 15}) async {
    // check & wait if bonding
    await _waitIfBonding(remoteId);

    // Only allow a single 'requestMtu' operation to be underway per device.
    String key = remoteId.str + ":requestMtu";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    var mtu = 0;

    try {
      var request = BmMtuChangeRequest(
        remoteId: remoteId.str,
        mtu: desiredMtu,
      );

      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnMtuChanged")
          .map((m) => m.arguments)
          .map((buffer) => BmMtuChangedResponse.fromMap(buffer))
          .where((p) => p.remoteId == remoteId.str)
          .map((p) => p.mtu);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<int> futureResponse = responseStream.first;

      await FlutterBluePlus._invokeMethod('requestMtu', request.toMap());

      mtu = await futureResponse.timeout(Duration(seconds: timeout));
    } finally {
      opMutex.give();
    }

    return mtu;
  }

  /// Read the RSSI of connected remote device
  Future<int> readRssi({int timeout = 15}) async {
    // check & wait if bonding
    await _waitIfBonding(remoteId);

    // Only allow a single 'readRssi' operation to be underway per device.
    String key = remoteId.str + ":readRssi";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    int rssi = 0;

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnReadRssiResult")
          .map((m) => m.arguments)
          .map((buffer) => BmReadRssiResult.fromMap(buffer))
          .where((p) => (p.remoteId == remoteId.str));

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmReadRssiResult> futureResponse = responseStream.first;

      await FlutterBluePlus._invokeMethod('readRssi', remoteId.str);

      // wait for response
      BmReadRssiResult response = await futureResponse.timeout(Duration(seconds: timeout));

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException("readRssi", response.errorCode, response.errorString);
      }
      rssi = response.rssi;
    } finally {
      opMutex.give();
    }

    return rssi;
  }

  /// Request connection priority update (Android only)
  Future<void> requestConnectionPriority({required ConnectionPriority connectionPriorityRequest}) async {
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException("setPreferredPhy", -1, "android-only");
    }

    var request = BmConnectionPriorityRequest(
      remoteId: remoteId.str,
      connectionPriority: _bmConnectionPriorityEnum(connectionPriorityRequest),
    );

    await FlutterBluePlus._invokeMethod(
      'requestConnectionPriority',
      request.toMap(),
    );
  }

  /// Set the preferred connection (Android Only)
  ///   - [txPhy] bitwise OR of all allowed phys for Tx, e.g. (Phy.le2m.mask | Phy.leCoded.mask)
  ///   - [txPhy] bitwise OR of all allowed phys for Rx, e.g. (Phy.le2m.mask | Phy.leCoded.mask)
  ///   - [option] preferred coding to use when transmitting on Phy.leCoded
  /// Please note that this is just a recommendation given to the system.
  Future<void> setPreferredPhy({
    required int txPhy,
    required int rxPhy,
    required PhyCoding option,
  }) async {
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException("setPreferredPhy", -1, "android-only");
    }

    var request = BmPreferredPhy(
      remoteId: remoteId.str,
      txPhy: txPhy,
      rxPhy: rxPhy,
      phyOptions: option.index,
    );

    await FlutterBluePlus._invokeMethod(
      'setPreferredPhy',
      request.toMap(),
    );
  }

  /// Force pairing dialogue to show. (Android Only)
  /// Typically, the only way to create a pairing request and show the pairing
  /// dialog in Android is to connect and try to use an encrypted characteristic which
  /// is a bit awkward of an API. Calling this function circumvents that step.
  Future<void> createBond({int timeout = 90}) async {
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException("createBond", -1, "android-only");
    }

    // Only allow a single 'createRemoveBond' operation to be underway per device.
    String key = remoteId.str + ":createRemoveBond";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnBondStateChanged")
          .map((m) => m.arguments)
          .map((buffer) => BmBondStateResponse.fromMap(buffer))
          .where((p) => p.remoteId == remoteId.str)
          .where((p) => p.bondState != BmBondStateEnum.bonding);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmBondStateResponse> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('createBond', remoteId.str);

      // wait for response
      BmBondStateResponse bs = await futureResponse.timeout(Duration(seconds: timeout));

      // success?
      if (bs.bondState != BmBondStateEnum.bonded) {
        throw FlutterBluePlusException("createBond", -1, "Failed to establish bond. ${bs.bondState}");
      }
    } finally {
      opMutex.give();
    }
  }

  /// Remove bond (Android Only)
  Future<void> removeBond({int timeout = 30}) async {
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException("removeBond", -1, "android-only");
    }

    // Only allow a single 'createRemoveBond' operation to be underway per device.
    String key = remoteId.str + ":createRemoveBond";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnBondStateChanged")
          .map((m) => m.arguments)
          .map((buffer) => BmBondStateResponse.fromMap(buffer))
          .where((p) => p.remoteId == remoteId.str)
          .where((p) => p.bondState != BmBondStateEnum.bonding);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmBondStateResponse> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('removeBond', remoteId.str);

      // wait for response
      BmBondStateResponse bs = await futureResponse.timeout(Duration(seconds: timeout));

      // success?
      if (bs.bondState != BmBondStateEnum.none && bs.bondState != BmBondStateEnum.lost) {
        throw FlutterBluePlusException("removeBond", -1, "Failed to remove bond. ${bs.bondState}");
      }
    } finally {
      opMutex.give();
    }
  }

  /// Refresh ble services & characteristics (Android Only)
  Future<void> clearGattCache() async {
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException("clearGattCache", -1, "android-only");
    }
    await FlutterBluePlus._invokeMethod('clearGattCache', remoteId.str);
  }

  // for internal use
  // it is unadvisable to do anything else with the device while bonding, otherwise many functions will fail
  // see: https://github.com/weliem/blessed-android
  // see: https://medium.com/@martijn.van.welie/making-android-ble-work-part-2-47a3cdaade07
  static _waitIfBonding(DeviceIdentifier remoteId, {int timeout = 60}) async {
    if (Platform.isAndroid == false) {
      return; // only needed on android
    }
    if (FlutterBluePlus._bondStates[remoteId] == null) {
      return; // bonding not yet started
    }
    if (FlutterBluePlus._bondStates[remoteId]!.bondState != BmBondStateEnum.bonding) {
      return; // already bonded / not yet bonding
    }

    var responseStream = FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnBondStateChanged")
        .map((m) => m.arguments)
        .map((buffer) => BmBondStateResponse.fromMap(buffer))
        .where((p) => p.remoteId == remoteId.str)
        .map((e) => e.bondState);

    await for (BmBondStateEnum bs in responseStream) {
      switch (bs) {
        case BmBondStateEnum.none:
          break;
        case BmBondStateEnum.bonding:
          continue;
        case BmBondStateEnum.bonded:
          break;
        case BmBondStateEnum.failed:
          throw FlutterBluePlusException("bonding", -1, "failed to bond to device.");
        case BmBondStateEnum.lost:
          throw FlutterBluePlusException("bonding", -2, "bond lost. must reconnect");
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BluetoothDevice && runtimeType == other.runtimeType && remoteId == other.remoteId);

  @override
  int get hashCode => remoteId.hashCode;

  @override
  String toString() {
    return 'BluetoothDevice{'
        'remoteId: $remoteId, '
        'localName: $localName, '
        'type: $type, '
        'isDiscoveringServices: ${_isDiscoveringServices.value}, '
        'services: ${_knownServices[remoteId]}'
        '}';
  }

  @Deprecated('Use createBond() instead')
  Future<void> pair() async => await createBond();

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get id => remoteId;

  @Deprecated('Use localName instead')
  String get name => localName;

  @Deprecated('Use connectionState instead')
  Stream<BluetoothConnectionState> get state => connectionState;

  @Deprecated('Use servicesStream instead')
  Stream<List<BluetoothService>> get services => servicesStream;
}
