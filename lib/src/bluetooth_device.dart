// Copyright 2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDevice {
  ////////////////////////////////
  // Internal
  //

  // used for 'servicesStream' public api
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

  // Get services
  //  - returns null if discoverServices() has not been called
  //  - this is cleared on disconnection. You must call discoverServices() again
  List<BluetoothService>? get servicesList {
    return FlutterBluePlus._knownServices[remoteId]?.services.map((p) => BluetoothService.fromProto(p)).toList();
  }

  /// Establishes a connection to the Bluetooth Device.
  ///   [autoConnect] Android only. reconnect whenever the device is found. This only
  ///   works if the device is in the Bluetooth scan cache or it is has been bonded before.
  ///   The scan cache is cleared whenever bluetooth is turned off.
  Future<void> connect({
    Duration timeout = const Duration(seconds: 35),
    bool autoConnect = false,
  }) async {
    // Only allow a single 'connectOrDisconnect' operation at the same time per device.
    String key = remoteId.str + ":connectOrDisconnect";
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
          .map((args) => BmConnectionStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .where((p) =>
              p.connectionState == BmConnectionStateEnum.disconnected ||
              p.connectionState == BmConnectionStateEnum.connected);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmConnectionStateResponse> futureState = responseStream.first;

      int alreadyConnected = await FlutterBluePlus._invokeMethod('connect', request.toMap());

      if (alreadyConnected == 0) {
        // wait for result
        BmConnectionStateResponse response = await futureState.fbpTimeout(timeout.inSeconds, "connect");

        // failure?
        if (response.connectionState == BmConnectionStateEnum.disconnected) {
          throw FlutterBluePlusException(
              _nativeError, "connect", response.disconnectReasonCode, response.disconnectReasonString);
        }
      }
    } finally {
      opMutex.give();
    }
  }

  /// Cancels connection to the Bluetooth Device
  Future<void> disconnect({int timeout = 35}) async {
    // Only allow a single 'connectOrDisconnect' operation at the same time per device.
    String key = remoteId.str + ":connectOrDisconnect";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnConnectionStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmConnectionStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .where((p) => p.connectionState == BmConnectionStateEnum.disconnected);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmConnectionStateResponse> futureState = responseStream.first;

      int alreadyDisconnected = await FlutterBluePlus._invokeMethod('disconnect', remoteId.str);

      if (alreadyDisconnected == 0) {
        // wait for disconnection
        await futureState.fbpTimeout(timeout, "disconnect");
      }
    } finally {
      opMutex.give();
    }
  }

  /// Discover services, characteristics, and descriptors of the remote device
  Future<List<BluetoothService>> discoverServices({int timeout = 15}) async {
    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "discoverServices",
        FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single 'discoverServices' operation at the same time per device.
    String key = remoteId.str + ":discoverServices";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    List<BluetoothService> result = [];

    try {
      // signal that we have started
      _isDiscoveringServices.add(true);

      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDiscoverServicesResult")
          .map((m) => m.arguments)
          .map((args) => BmDiscoverServicesResult.fromMap(args))
          .where((p) => p.remoteId == remoteId.str);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmDiscoverServicesResult> futureResponse = responseStream.first;

      await FlutterBluePlus._invokeMethod('discoverServices', remoteId.str);

      // wait for response
      BmDiscoverServicesResult response = await futureResponse.fbpTimeout(timeout, "discoverServices");

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException(_nativeError, "discoverServices", response.errorCode, response.errorString);
      }

      result = response.services.map((p) => BluetoothService.fromProto(p)).toList();

      // add to stream
      _services.add(result);
    } finally {
      _isDiscoveringServices.add(false);
      opMutex.give();
    }

    return result;
  }

  // return the most recent disconnection reason
  DisconnectReason? get disconnectReason {
    if (FlutterBluePlus._connectionStates[remoteId] == null) {
      return null;
    }
    int? code = FlutterBluePlus._connectionStates[remoteId]!.disconnectReasonCode;
    String? description = FlutterBluePlus._connectionStates[remoteId]!.disconnectReasonString;
    return DisconnectReason(_nativeError, code, description);
  }

  /// The current connection state of the device to this application
  Stream<BluetoothConnectionState> get connectionState {
    // initial value - Note: we only care about the current connection state of
    // *our* app, which is why we can use our cached value, or assume disconnected
    BluetoothConnectionState initialValue = BluetoothConnectionState.disconnected;
    if (FlutterBluePlus._connectionStates[remoteId] != null) {
      initialValue = _bmToBluetoothConnectionState(FlutterBluePlus._connectionStates[remoteId]!.connectionState);
    }
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnConnectionStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmConnectionStateResponse.fromMap(args))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => _bmToBluetoothConnectionState(p.connectionState))
        .newStreamWithInitialValue(initialValue);
  }

  /// The current MTU size in bytes
  Stream<int> get mtu {
    // get initial value from our cache
    int initialValue = FlutterBluePlus._mtuValues[remoteId]?.mtu ?? 23;
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnMtuChanged")
        .map((m) => m.arguments)
        .map((args) => BmMtuChangedResponse.fromMap(args))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => p.mtu)
        .newStreamWithInitialValue(initialValue);
  }

  /// Read the RSSI of connected remote device
  Future<int> readRssi({int timeout = 15}) async {
    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "readRssi",
        FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single 'readRssi' operation at the same time per device.
    String key = remoteId.str + ":readRssi";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    int rssi = 0;

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnReadRssiResult")
          .map((m) => m.arguments)
          .map((args) => BmReadRssiResult.fromMap(args))
          .where((p) => (p.remoteId == remoteId.str));

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmReadRssiResult> futureResponse = responseStream.first;

      await FlutterBluePlus._invokeMethod('readRssi', remoteId.str);

      // wait for response
      BmReadRssiResult response = await futureResponse.fbpTimeout(timeout, "readRssi");

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException(_nativeError, "readRssi", response.errorCode, response.errorString);
      }
      rssi = response.rssi;
    } finally {
      opMutex.give();
    }

    return rssi;
  }

  /// Request to change MTU (Android Only)
  ///  - returns new MTU
  Future<int> requestMtu(int desiredMtu, {int timeout = 15}) async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "requestMtu", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "requestMtu",
        FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single 'requestMtu' operation at the same time per device.
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
          .map((args) => BmMtuChangedResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .map((p) => p.mtu);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<int> futureResponse = responseStream.first;

      await FlutterBluePlus._invokeMethod('requestMtu', request.toMap());

      mtu = await futureResponse.fbpTimeout(timeout, "requestMtu");
    } finally {
      opMutex.give();
    }

    return mtu;
  }

  /// Request connection priority update (Android only)
  Future<void> requestConnectionPriority({required ConnectionPriority connectionPriorityRequest}) async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "setPreferredPhy", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "requestConnectionPriority",
        FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    var request = BmConnectionPriorityRequest(
      remoteId: remoteId.str,
      connectionPriority: _bmConnectionPriorityEnum(connectionPriorityRequest),
    );

    await FlutterBluePlus._invokeMethod('requestConnectionPriority', request.toMap());
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
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "setPreferredPhy", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "setPreferredPhy",
        FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    var request = BmPreferredPhy(
      remoteId: remoteId.str,
      txPhy: txPhy,
      rxPhy: rxPhy,
      phyOptions: option.index,
    );

    await FlutterBluePlus._invokeMethod('setPreferredPhy', request.toMap());
  }

  /// Force the bonding popup to show now (Android Only) 
  /// Note! calling this is usually not necessary!! The platform does it automatically.
  Future<void> createBond({int timeout = 90}) async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "createBond", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "createBond",
        FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single 'createRemoveBond' operation at the same time per device.
    String key = remoteId.str + ":createRemoveBond";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnBondStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmBondStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .where((p) => p.bondState != BmBondStateEnum.bonding);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmBondStateResponse> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('createBond', remoteId.str);

      // wait for response
      BmBondStateResponse bs = await futureResponse.fbpTimeout(timeout, "createBond");

      // success?
      if (bs.bondState != BmBondStateEnum.bonded) {
        throw FlutterBluePlusException(ErrorPlatform.dart, "createBond", FbpErrorCode.createBondFailed.hashCode,
            "Failed to create bond. ${bs.bondState}");
      }
    } finally {
      opMutex.give();
    }
  }

  /// Remove bond (Android Only)
  Future<void> removeBond({int timeout = 30}) async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "removeBond", FbpErrorCode.androidOnly.index, "android-only");
    }

    // Only allow a single 'createRemoveBond' operation at the same time per device.
    String key = remoteId.str + ":createRemoveBond";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnBondStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmBondStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .where((p) => p.bondState != BmBondStateEnum.bonding);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmBondStateResponse> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('removeBond', remoteId.str);

      // wait for response
      BmBondStateResponse bs = await futureResponse.fbpTimeout(timeout, "removeBond");

      // success?
      if (bs.bondState != BmBondStateEnum.none) {
        throw FlutterBluePlusException(ErrorPlatform.dart, "createBond", FbpErrorCode.removeBondFailed.hashCode,
            "Failed to remove bond. ${bs.bondState}");
      }
    } finally {
      opMutex.give();
    }
  }

  /// Refresh ble services & characteristics (Android Only)
  Future<void> clearGattCache() async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "clearGattCache", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "clearGattCache",
        FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    await FlutterBluePlus._invokeMethod('clearGattCache', remoteId.str);
  }

  // Get the current bondState of the device (Android Only)
  Stream<BluetoothBondState> get bondState async* {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "bondState", FbpErrorCode.androidOnly.index, "android-only");
    }

    // start listening now so we do not miss any changes.
    // in particular, missed chamges that happen due to await getInitialBondState
    var buffer = _BufferStream.listen(FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnBondStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmBondStateResponse.fromMap(args))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => _bmToBluetoothBondState(p)));

    BluetoothBondState initialValue;

    // initial state
    if (FlutterBluePlus._bondStates[remoteId] != null) {
      // we must use the cached bond state (if available) because
      // getInitialBondState is not able to detect bondLost & bondFailed
      initialValue = _bmToBluetoothBondState(FlutterBluePlus._bondStates[remoteId]!);
    } else {
      // must get the initial state from the system.
      initialValue = await FlutterBluePlus._methods
          .invokeMethod('getInitialBondState', remoteId.str)
          .then((args) => BmBondStateResponse.fromMap(args))
          .then((p) => _bmToBluetoothBondState(p));
    }

    // make sure the initial value has not become out of date
    // while we were awaiting for the initial value
    if (buffer.hasReceivedValue == false) {
      yield initialValue;
    }

    // stream
    yield* buffer.stream;
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
        'services: ${FlutterBluePlus._knownServices[remoteId]}'
        '}';
  }

  // stream return whether or not we are currently discovering services
  @Deprecated("planed for removal (Jan 2024). It can be easily implemented yourself") // deprecated on Aug 2023
  Stream<bool> get isDiscoveringServices => _isDiscoveringServices.stream;
  
  /// Stream of bluetooth services offered by the remote device
  ///   - this stream is only updated when you call discoverServices()
  @Deprecated("planed for removal (Jan 2024). It can be easily implemented yourself") // deprecated on Aug 2023
  Stream<List<BluetoothService>> get servicesStream {
    if (FlutterBluePlus._knownServices[remoteId] != null) {
      return _services.stream.newStreamWithInitialValue(servicesList!);
    } else {
      return _services.stream;
    }
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
