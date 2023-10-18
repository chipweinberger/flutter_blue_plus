// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDevice {
  final DeviceIdentifier remoteId;

  BluetoothDevice({
    required this.remoteId,
  });

  BluetoothDevice.fromProto(BmBluetoothDevice p) : remoteId = DeviceIdentifier(p.remoteId);

  /// allows connecting to a known device without re-scanning
  /// Note: this device must have been discovered by your app in a previous scan
  BluetoothDevice.fromId(String remoteId) : remoteId = DeviceIdentifier(remoteId);

  /// platform name
  /// - iOS: uses GAP name characteristic 0x2A00, otherwise advertised name
  /// - Android: uses advertised name
  String get platformName => FlutterBluePlus._platformNames[remoteId] ?? "";

  /// Get services
  ///  - returns null if discoverServices() has not been called
  ///  - this is cleared on disconnection. You must call discoverServices() again
  List<BluetoothService>? get servicesList {
    return FlutterBluePlus._knownServices[remoteId]?.services.map((p) => BluetoothService.fromProto(p)).toList();
  }

  /// Register a subscription to be canceled when the device is disconnected.
  /// This function simplifies cleanup, to prevent duplicate stream subscriptions.
  ///   - this is an optional convenience function
  ///   - prevents accidentally creating duplicate subscriptions on each reconnection.
  ///   - if already disconnected, the stream will be immediately canceled 
  void cancelWhenDisconnected(StreamSubscription subscription) {
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      subscription.cancel();
    } else {
      FlutterBluePlus._subscriptions[remoteId] ??= [];
      FlutterBluePlus._subscriptions[remoteId]!.add(subscription);
    }
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

      // invoke
      bool changed = await FlutterBluePlus._invokeMethod('connect', request.toMap());

      // only wait for connection if we weren't already connected
      if (changed) {
        BmConnectionStateResponse response =
            await futureState.fbpEnsureAdapterIsOn("connect").fbpTimeout(timeout.inSeconds, "connect");

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

      // invoke
      bool changed = await FlutterBluePlus._invokeMethod('disconnect', remoteId.str);

      // only wait for disconnection if weren't already disconnected
      if (changed) {
        await futureState.fbpEnsureAdapterIsOn("disconnect").fbpTimeout(timeout, "disconnect");
      }
    } finally {
      opMutex.give();
    }
  }

  /// Discover services, characteristics, and descriptors of the remote device
  Future<List<BluetoothService>> discoverServices({int timeout = 15}) async {
    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "discoverServices", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single 'discoverServices' operation at the same time per device.
    String key = remoteId.str + ":discoverServices";
    _Mutex opMutex = await _MutexFactory.getMutexForKey(key);
    await opMutex.take();

    List<BluetoothService> result = [];

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDiscoverServicesResult")
          .map((m) => m.arguments)
          .map((args) => BmDiscoverServicesResult.fromMap(args))
          .where((p) => p.remoteId == remoteId.str);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmDiscoverServicesResult> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('discoverServices', remoteId.str);

      // wait for response
      BmDiscoverServicesResult response = await futureResponse
          .fbpEnsureAdapterIsOn("discoverServices")
          .fbpEnsureDeviceIsConnected(this, "discoverServices")
          .fbpTimeout(timeout, "discoverServices");

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException(_nativeError, "discoverServices", response.errorCode, response.errorString);
      }

      result = response.services.map((p) => BluetoothService.fromProto(p)).toList();
    } finally {
      opMutex.give();
    }

    return result;
  }

  /// The most recent disconnection reason
  DisconnectReason? get disconnectReason {
    if (FlutterBluePlus._connectionStates[remoteId] == null) {
      return null;
    }
    int? code = FlutterBluePlus._connectionStates[remoteId]!.disconnectReasonCode;
    String? description = FlutterBluePlus._connectionStates[remoteId]!.disconnectReasonString;
    return DisconnectReason(_nativeError, code, description);
  }

  /// The current connection state *of our app* to the device
  Stream<BluetoothConnectionState> get connectionState {
    // initial value - Note: we only care about the current connection state of
    // *our* app, which is why we can use our cached value, or assume disconnected
    BluetoothConnectionState initialValue = BluetoothConnectionState.disconnected;
    if (FlutterBluePlus._connectionStates[remoteId] != null) {
      initialValue = _bmToConnectionState(FlutterBluePlus._connectionStates[remoteId]!.connectionState);
    }
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnConnectionStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmConnectionStateResponse.fromMap(args))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => _bmToConnectionState(p.connectionState))
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

  /// Name Changed Stream
  ///  - uses the GAP Device Name characteristic (0x2A00)
  Stream<String> get onNameChanged async* {
    if (Platform.isIOS || Platform.isMacOS) {
      yield* FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnNameChanged")
          .map((m) => m.arguments)
          .map((args) => BmBluetoothDevice.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .map((m) => m.platformName ?? "");
    } else {
      final Guid gattUuid = Guid("00001800-0000-1000-8000-00805F9B34FB");
      final Guid nameUuid = Guid("00002A00-0000-1000-8000-00805F9B34FB");
      BluetoothService? svc = servicesList?._firstWhereOrNull((svc) => svc.uuid == gattUuid);
      if (svc == null) {
        throw FlutterBluePlusException(
            ErrorPlatform.dart, "onNameChanged", FbpErrorCode.serviceNotFound.index, "GATT Service Not Found");
      }
      BluetoothCharacteristic? chr = svc.characteristics._firstWhereOrNull((chr) => chr.uuid == nameUuid);
      if (chr == null) {
        throw FlutterBluePlusException(
            ErrorPlatform.dart, "onNameChanged", FbpErrorCode.characteristicNotFound.index, "GAP Name Not Found");
      }
      if (chr.isNotifying == false) {
        await chr.setNotifyValue(true);
      }
      yield* chr.lastValueStream.map((value) => utf8.decode(value));
    }
  }

  /// Services Changed Stream
  ///  - uses the GAP Services Changed characteristic (0x2A05)
  ///  - you must re-call discoverServices()
  Stream<void> get onServicesChanged async* {
    if (Platform.isIOS || Platform.isMacOS) {
      yield* FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnServicesChanged")
          .map((m) => m.arguments)
          .map((args) => BmBluetoothDevice.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .map((m) => null);
    } else {
      final Guid gattUuid = Guid("00001800-0000-1000-8000-00805F9B34FB");
      final Guid changeUuid = Guid("00002A05-0000-1000-8000-00805F9B34FB");
      BluetoothService? svc = servicesList?._firstWhereOrNull((svc) => svc.uuid == gattUuid);
      if (svc == null) {
        throw FlutterBluePlusException(
            ErrorPlatform.dart, "onServicesChanged", FbpErrorCode.serviceNotFound.index, "GATT Service Not Found");
      }
      BluetoothCharacteristic? chr = svc.characteristics._firstWhereOrNull((chr) => chr.uuid == changeUuid);
      if (chr == null) {
        throw FlutterBluePlusException(
            ErrorPlatform.dart, "onServicesChanged", FbpErrorCode.characteristicNotFound.index, "GAP Name Not Found");
      }
      if (chr.isNotifying == false) {
        await chr.setNotifyValue(true);
      }
      yield* chr.onValueReceived.map((value) => utf8.decode(value));
    }
  }

  /// Read the RSSI of connected remote device
  Future<int> readRssi({int timeout = 15}) async {
    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "readRssi", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
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

      // invoke
      await FlutterBluePlus._invokeMethod('readRssi', remoteId.str);

      // wait for response
      BmReadRssiResult response = await futureResponse
          .fbpEnsureAdapterIsOn("readRssi")
          .fbpEnsureDeviceIsConnected(this, "readRssi")
          .fbpTimeout(timeout, "readRssi");

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
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "requestMtu", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
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

      // invoke
      await FlutterBluePlus._invokeMethod('requestMtu', request.toMap());

      // wait for response
      mtu = await futureResponse
          .fbpEnsureAdapterIsOn("requestMtu")
          .fbpEnsureDeviceIsConnected(this, "requestMtu")
          .fbpTimeout(timeout, "requestMtu");
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
          ErrorPlatform.dart, "requestConnectionPriority", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "requestConnectionPriority",
          FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    var request = BmConnectionPriorityRequest(
      remoteId: remoteId.str,
      connectionPriority: _bmFromConnectionPriority(connectionPriorityRequest),
    );

    // invoke
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
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "setPreferredPhy", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    var request = BmPreferredPhy(
      remoteId: remoteId.str,
      txPhy: txPhy,
      rxPhy: rxPhy,
      phyOptions: option.index,
    );

    // invoke
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
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "createBond", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
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
      bool changed = await FlutterBluePlus._invokeMethod('createBond', remoteId.str);

      // only wait for 'bonded' if we weren't already bonded
      if (changed) {
        BmBondStateResponse bs = await futureResponse
            .fbpEnsureAdapterIsOn("createBond")
            .fbpEnsureDeviceIsConnected(this, "createBond")
            .fbpTimeout(timeout, "createBond");

        // success?
        if (bs.bondState != BmBondStateEnum.bonded) {
          throw FlutterBluePlusException(ErrorPlatform.dart, "createBond", FbpErrorCode.createBondFailed.hashCode,
              "Failed to create bond. ${bs.bondState}");
        }
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
      bool changed = await FlutterBluePlus._invokeMethod('removeBond', remoteId.str);

      // only wait for 'unbonded' state if we weren't already unbonded
      if (changed) {
        BmBondStateResponse bs = await futureResponse
            .fbpEnsureAdapterIsOn("removeBond")
            .fbpEnsureDeviceIsConnected(this, "removeBond")
            .fbpTimeout(timeout, "removeBond");

        // success?
        if (bs.bondState != BmBondStateEnum.none) {
          throw FlutterBluePlusException(ErrorPlatform.dart, "createBond", FbpErrorCode.removeBondFailed.hashCode,
              "Failed to remove bond. ${bs.bondState}");
        }
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
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "clearGattCache", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // invoke
    await FlutterBluePlus._invokeMethod('clearGattCache', remoteId.str);
  }

  /// Get the current bondState of the device (Android Only)
  Stream<BluetoothBondState> get bondState async* {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.dart, "bondState", FbpErrorCode.androidOnly.index, "android-only");
    }

    // do we already have the initial state?
    if (FlutterBluePlus._bondStates[remoteId] != null) {
      // we prefer to use the cached bond state, if available
      BluetoothBondState initialValue = _bmToBondState(FlutterBluePlus._bondStates[remoteId]!.bondState);
      yield* FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnBondStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmBondStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .map((p) => _bmToBondState(p.bondState))
          .newStreamWithInitialValue(initialValue);
    } else {
      // start listening now so we do not miss any changes
      // while we are getting the inital bond state
      var buffer = _BufferStream.listen(FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnBondStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmBondStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .map((p) => _bmToBondState(p.bondState)));

      // must get the initial state from the system.
      BluetoothBondState initialValue = await FlutterBluePlus._methods
          .invokeMethod('getBondState', remoteId.str)
          .then((args) => BmBondStateResponse.fromMap(args))
          .then((p) => _bmToBondState(p.bondState));

      // make sure the initial value has not become out of date
      if (buffer.hasReceivedValue == false) {
        yield initialValue;
      }
      // stream
      yield* buffer.stream;
    }
  }

  /// Get the previous bondState of the device (Android Only)
  BluetoothBondState? get prevBondState {
    var b = FlutterBluePlus._bondStates[remoteId]?.prevState;
    return b != null ? _bmToBondState(b) : null;
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
        'platformName: $platformName, '
        'services: ${FlutterBluePlus._knownServices[remoteId]}'
        '}';
  }

  @Deprecated("removed. no replacement")
  Stream<bool> get isDiscoveringServices async* {
    yield false;
  }

  @Deprecated("removed. no replacement")
  Stream<List<BluetoothService>> get servicesStream async* {
    yield [];
  }

  @Deprecated('Use createBond() instead')
  Future<void> pair() async => await createBond();

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get id => remoteId;

  @Deprecated('Use platformName instead')
  String get localName => platformName;

  @Deprecated('Use platformName instead')
  String get name => platformName;

  @Deprecated('Use connectionState instead')
  Stream<BluetoothConnectionState> get state => connectionState;

  @Deprecated('Use servicesStream instead')
  Stream<List<BluetoothService>> get services => servicesStream;
}
