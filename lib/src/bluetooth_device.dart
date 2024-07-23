// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDevice {
  final DeviceIdentifier remoteId;

  BluetoothDevice({
    required this.remoteId,
  });

  BluetoothDevice.fromProto(BmBluetoothDevice p) : remoteId = p.remoteId;

  /// Create a device from an id
  ///   - to connect, this device must have been discovered by your app in a previous scan
  ///   - iOS uses 128-bit uuids the remoteId, e.g. e006b3a7-ef7b-4980-a668-1f8005f84383
  ///   - Android uses 48-bit mac addresses as the remoteId, e.g. 06:E5:28:3B:FD:E0
  BluetoothDevice.fromId(String remoteId) : remoteId = DeviceIdentifier(remoteId);

  /// platform name
  /// - this name is kept track of by the platform
  /// - this name usually persist between app restarts
  /// - iOS: after you connect, iOS uses the GAP name characteristic (0x2A00)
  ///        if it exists. Otherwise iOS use the advertised name.
  /// - Android: always uses the advertised name
  String get platformName => FlutterBluePlus._platformNames[remoteId] ?? "";

  /// Advertised Named
  ///  - this is the name advertised by the device during scanning
  ///  - it is only available after you scan with FlutterBluePlus
  ///  - it is cleared when the app restarts.
  ///  - not all devices advertise a name
  String get advName => FlutterBluePlus._advNames[remoteId] ?? "";

  /// Get services
  ///  - returns empty if discoverServices() has not been called
  ///    or if your device does not have any services (rare)
  List<BluetoothService> get servicesList {
    BmDiscoverServicesResult? result = FlutterBluePlus._knownServices[remoteId];
    if (result == null) {
      return [];
    } else {
      return result.services.map((p) => BluetoothService.fromProto(p)).toList();
    }
  }

  /// Register a subscription to be canceled when the device is disconnected.
  /// This function simplifies cleanup, so you can prevent creating duplicate stream subscriptions.
  ///   - this is an optional convenience function
  ///   - prevents accidentally creating duplicate subscriptions on each reconnection.
  ///   - [next] if true, the the stream will be canceled only on the *next* disconnection.
  ///     This is useful if you setup your subscriptions before you connect.
  ///   - [delayed] Note: This option is only meant for `connectionState` subscriptions.  
  ///     When `true`, we cancel after a small delay. This ensures the `connectionState` 
  ///     listener receives the `disconnected` event.
  void cancelWhenDisconnected(StreamSubscription subscription, {bool next = false, bool delayed = false}) {
    if (isConnected == false && next == false) {
      subscription.cancel(); // cancel immediately if already disconnected.
    } else if (delayed) {
      FlutterBluePlus._delayedSubscriptions[remoteId] ??= [];
      FlutterBluePlus._delayedSubscriptions[remoteId]!.add(subscription);
    } else {
      FlutterBluePlus._deviceSubscriptions[remoteId] ??= [];
      FlutterBluePlus._deviceSubscriptions[remoteId]!.add(subscription);      
    }
  }

  /// Returns true if autoConnect is currently enabled for this device
  bool get isAutoConnectEnabled {
    return FlutterBluePlus._autoConnect.contains(remoteId);
  }

  /// Returns true if this device is currently connected to your app
  bool get isConnected {
    if (FlutterBluePlus._connectionStates[remoteId] == null) {
      return false;
    } else {
      var state = FlutterBluePlus._connectionStates[remoteId]!.connectionState;
      return state == BmConnectionStateEnum.connected;
    }
  }

  /// Returns true if this device is currently disconnected from your app
  bool get isDisconnected => isConnected == false;

  /// Establishes a connection to the Bluetooth Device.
  ///   [timeout] if timeout occurs, cancel the connection request and throw exception
  ///   [mtu] Android only. Request a larger mtu right after connection, if set.
  ///   [autoConnect] reconnect whenever the device is found
  ///      - if true, this function always returns immediately.
  ///      - you must listen to `connectionState` to know when connection occurs.
  ///      - auto connect is turned off by calling `disconnect`
  ///      - auto connect results in a slower connection process compared to a direct connection
  ///        because it relies on the internal scheduling of background scans.
  Future<void> connect({
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool autoConnect = false,
  }) async {
    // If you hit this assert, you must set `mtu:null`, i.e `device.connect(mtu:null, autoConnect:true)`
    // and you'll have to call `requestMtu` yourself. `autoConnect` is not compatibile with `mtu`.
    assert((mtu == null) || !autoConnect, "mtu and auto connect are incompatible");

    // make sure no one else is calling disconnect
    _Mutex dmtx = _MutexFactory.getMutexForKey("disconnect");
    bool dtook = await dmtx.take();

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    try {
      // remember auto connect value
      if (autoConnect) {
        FlutterBluePlus._autoConnect.add(remoteId);
      }

      var request = BmConnectRequest(
        remoteId: remoteId,
        autoConnect: autoConnect,
      );

      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnConnectionStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmConnectionStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmConnectionStateResponse> futureState = responseStream.first;

      // record connection time
      if (Platform.isAndroid) {
        FlutterBluePlus._connectTimestamp[remoteId] = DateTime.now();
      }

      // invoke
      bool changed = await FlutterBluePlus._invokeMethod('connect', request.toMap());

      // we return the disconnect mutex now so that this
      // connection attempt can be canceled by calling disconnect
      dtook = dmtx.give();

      // only wait for connection if we weren't already connected
      if (changed && !autoConnect) {
        BmConnectionStateResponse response = await futureState
            .fbpEnsureAdapterIsOn("connect")
            .fbpTimeout(timeout.inSeconds, "connect")
            .catchError((e) async {
          if (e is FlutterBluePlusException && e.code == FbpErrorCode.timeout.index) {
            await FlutterBluePlus._invokeMethod('disconnect', remoteId.str); // cancel connection attempt
          }
          throw e;
        });

        // failure?
        if (response.connectionState == BmConnectionStateEnum.disconnected) {
          if (response.disconnectReasonCode == bmUserCanceledErrorCode) {
            throw FlutterBluePlusException(
                ErrorPlatform.fbp, "connect", FbpErrorCode.connectionCanceled.index, "connection canceled");
          } else {
            throw FlutterBluePlusException(
                _nativeError, "connect", response.disconnectReasonCode, response.disconnectReasonString);
          }
        }
      }
    } finally {
      if (dtook) {
        dmtx.give();
      }
      mtx.give();
    }

    // request larger mtu
    if (Platform.isAndroid && isConnected && mtu != null) {
      await requestMtu(mtu);
    }
  }

  /// Cancels connection to the Bluetooth Device
  ///   - [queue] If true, this disconnect request will be executed after all other operations complete.
  ///     If false, this disconnect request will be executed right now, i.e. skipping to the front
  ///     of the fbp operation queue, which is useful to cancel an in-progress connection attempt.
  ///   - [androidDelay] Android only. Minimum gap in milliseconds between connect and disconnect to
  ///     workaround a race condition that leaves connection stranded. A stranded connection in this case
  ///     refers to a connection that FBP and Android Bluetooth stack are not aware of and thus cannot be
  ///     disconnected because there is no gatt handle.
  ///     https://issuetracker.google.com/issues/37121040
  ///     From testing, 2 second delay appears to be enough.
  Future<void> disconnect({
    int timeout = 35,
    bool queue = true,
    int androidDelay = 2000,
  }) async {
    // Only allow a single disconnect operation at a time
    _Mutex dtx = _MutexFactory.getMutexForKey("disconnect");
    await dtx.take();

    // Only allow a single ble operation to be underway at a time?
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    if (queue) {
      await mtx.take();
    }

    try {
      // remove from auto connect list if there
      FlutterBluePlus._autoConnect.remove(remoteId);

      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnConnectionStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmConnectionStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId)
          .where((p) => p.connectionState == BmConnectionStateEnum.disconnected);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmConnectionStateResponse> futureState = responseStream.first;

      // Workaround Android race condition
      await _ensureAndroidDisconnectionDelay(androidDelay);

      // invoke
      bool changed = await FlutterBluePlus._invokeMethod('disconnect', remoteId.str);

      // only wait for disconnection if weren't already disconnected
      if (changed) {
        await futureState.fbpEnsureAdapterIsOn("disconnect").fbpTimeout(timeout, "disconnect");
      }

      if (Platform.isAndroid) {
        // Disconnected, remove connect timestamp
        FlutterBluePlus._connectTimestamp.remove(remoteId);
      }
    } finally {
      dtx.give();
      if (queue) {
        mtx.give();
      }
    }
  }

  /// Discover services, characteristics, and descriptors of the remote device
  ///   - [subscribeToServicesChanged] Android Only: If true, after discovering services we will subscribe
  ///     to the Services Changed Characteristic (0x2A05) used for the `device.onServicesReset` stream.
  ///     Note: this behavior happens automatically on iOS and cannot be disabled
  Future<List<BluetoothService>> discoverServices({bool subscribeToServicesChanged = true, int timeout = 15}) async {
    // check connected
    if (isDisconnected) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "discoverServices", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    List<BluetoothService> result = [];

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDiscoveredServices")
          .map((m) => m.arguments)
          .map((args) => BmDiscoverServicesResult.fromMap(args))
          .where((p) => p.remoteId == remoteId);

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
      mtx.give();
    }

    // in order to match iOS behavior on all platforms,
    // we always listen to the Services Changed characteristic if it exists.
    if (subscribeToServicesChanged) {
      if (Platform.isIOS == false && Platform.isMacOS == false) {
        BluetoothCharacteristic? c = _servicesChangedCharacteristic;
        if (c != null && (c.properties.notify || c.properties.indicate) && c.isNotifying == false) {
          await c.setNotifyValue(true);
        }
      }
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
        .where((p) => p.remoteId == remoteId)
        .map((p) => _bmToConnectionState(p.connectionState))
        .newStreamWithInitialValue(initialValue);
  }

  /// The current MTU size in bytes
  int get mtuNow {
    // get initial value from our cache
    return FlutterBluePlus._mtuValues[remoteId]?.mtu ?? 23;
  }

  /// Stream emits a value:
  ///   - immediately when first listened to
  ///   - whenever the mtu changes
  Stream<int> get mtu {
    // get initial value from our cache
    int initialValue = FlutterBluePlus._mtuValues[remoteId]?.mtu ?? 23;
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnMtuChanged")
        .map((m) => m.arguments)
        .map((args) => BmMtuChangedResponse.fromMap(args))
        .where((p) => p.remoteId == remoteId)
        .map((p) => p.mtu)
        .newStreamWithInitialValue(initialValue);
  }


  /// Services Reset Stream
  ///  - uses the GAP Services Changed characteristic (0x2A05)
  ///  - you must re-call discoverServices() when services are reset
  Stream<void> get onServicesReset {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnServicesReset")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothDevice.fromMap(args))
        .where((p) => p.remoteId == remoteId)
        .map((m) => null);
  }

  /// Open a L2CAP channel to the Bluetooth Device.
  Future<void> openL2CapChannel({
    required final int psm,
    bool secure = true,
  }) async {
    var request = OpenL2CapChannelRequest(
      remoteId: remoteId.toString(),
      psm: psm,
      secure: secure,
    );

    await FlutterBluePlus._invokeMethod(
        methodConnectToL2CapChannel, request.toMap());
  }

  /// Close a L2CAP channel to the Bluetooth Device.
  Future<void> closeL2CapChannel({required final int psm}) async {
    var request = CloseL2CapChannelRequest(
      remoteId: remoteId.toString(),
      psm: psm,
    );

    await FlutterBluePlus._invokeMethod(
        methodCloseL2CapChannel, request.toMap());
  }

  /// Read from a L2CAP channel
  Future<List<int>> readL2CapChannel({
    required final int psm,
  }) async {
    final request = ReadL2CapChannelRequest(
      remoteId: remoteId.toString(),
      psm: psm,
    );

    return await FlutterBluePlus._invokeMethod(
            methodReadL2CapChannel, request.toMap())
        .then((buffer) => ReadL2CapChannelResponse.fromMap(buffer))
        .then((readChannelResponse) {
      return readChannelResponse.value
          .sublist(0, readChannelResponse.bytesRead);
    });
  }

  /// Write some [bytesToSend] using the L2CAP channel with the PSM: [psm]
  Future<void> writeL2CapChannel(
      {required final int psm, required final List<int> bytesToSend}) async {
    var request = WriteL2CapChannelRequest(
      remoteId: remoteId.toString(),
      psm: psm,
      value: bytesToSend,
    );

    return await FlutterBluePlus._invokeMethod(
        methodWriteL2CapChannel, request.toMap());
  }

  /// Read the RSSI of connected remote device
  Future<int> readRssi({int timeout = 15}) async {
    // check connected
    if (isDisconnected) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "readRssi", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    int rssi = 0;

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnReadRssi")
          .map((m) => m.arguments)
          .map((args) => BmReadRssiResult.fromMap(args))
          .where((p) => (p.remoteId == remoteId));

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
      mtx.give();
    }

    return rssi;
  }

  /// Request to change MTU (Android Only)
  ///  - returns new MTU
  ///  - [predelay] adds delay to avoid race conditions on some devices. see comments below.
  Future<int> requestMtu(int desiredMtu, {double predelay = 0.35, int timeout = 15}) async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.fbp, "requestMtu", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (isDisconnected) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "requestMtu", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    // predelay
    if (predelay > 0) {
      // hack: By adding delay before we call `requestMtu`, we can avoid
      // a race condition that can cause `discoverServices` to timeout or fail.
      //
      // Note: This hack is only needed for devices that automatically send an
      // MTU update right after connection. If your device does not do that, 
      // you can set this delay to zero. Other people may need to increase it!
      //
      // The race condition goes like this:
      //  1. you call `requestMtu` right after connection
      //  2. some devices automatically send a new MTU right after connection, without being asked
      //  3. your call to `requestMtu` confuses the results from step 1 and step 2, and returns to early
      //  4. the user then calls `discoverServices`, thinking that `requestMtu` has finished
      //  5. in reality, `requestMtu` is still happening, and the call to `discoverServices` will fail/timeout
      //
      // Adding delay before we call `requestMtu` helps ensure 
      // that the automatic mtu update has already happened.
      await Future.delayed(Duration(milliseconds: (predelay * 1000).toInt()));
    }

    var mtu = 0;

    try {
      var request = BmMtuChangeRequest(
        remoteId: remoteId,
        mtu: desiredMtu,
      );

      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnMtuChanged")
          .map((m) => m.arguments)
          .map((args) => BmMtuChangedResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId)
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
      mtx.give();
    }

    return mtu;
  }

  /// Request connection priority update (Android only)
  Future<void> requestConnectionPriority({required ConnectionPriority connectionPriorityRequest}) async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "requestConnectionPriority", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (isDisconnected) {
      throw FlutterBluePlusException(ErrorPlatform.fbp, "requestConnectionPriority",
          FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    var request = BmConnectionPriorityRequest(
      remoteId: remoteId,
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
          ErrorPlatform.fbp, "setPreferredPhy", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (isDisconnected) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "setPreferredPhy", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    var request = BmPreferredPhy(
      remoteId: remoteId,
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
      throw FlutterBluePlusException(ErrorPlatform.fbp, "createBond", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (isDisconnected) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "createBond", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnBondStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmBondStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId)
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
          throw FlutterBluePlusException(ErrorPlatform.fbp, "createBond", FbpErrorCode.createBondFailed.hashCode,
              "Failed to create bond. ${bs.bondState}");
        }
      }
    } finally {
      mtx.give();
    }
  }

  /// Remove bond (Android Only)
  Future<void> removeBond({int timeout = 30}) async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.fbp, "removeBond", FbpErrorCode.androidOnly.index, "android-only");
    }

    // Only allow a single ble operation to be underway at a time
    _Mutex mtx = _MutexFactory.getMutexForKey("global");
    await mtx.take();

    try {
      var responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnBondStateChanged")
          .map((m) => m.arguments)
          .map((args) => BmBondStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId)
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
          throw FlutterBluePlusException(ErrorPlatform.fbp, "createBond", FbpErrorCode.removeBondFailed.hashCode,
              "Failed to remove bond. ${bs.bondState}");
        }
      }
    } finally {
      mtx.give();
    }
  }

  /// Refresh ble services & characteristics (Android Only)
  Future<void> clearGattCache() async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "clearGattCache", FbpErrorCode.androidOnly.index, "android-only");
    }

    // check connected
    if (isDisconnected) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "clearGattCache", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // invoke
    await FlutterBluePlus._invokeMethod('clearGattCache', remoteId.str);
  }

  /// Get the current bondState of the device (Android Only)
  Stream<BluetoothBondState> get bondState async* {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.fbp, "bondState", FbpErrorCode.androidOnly.index, "android-only");
    }

    // get current state if needed
    if (FlutterBluePlus._bondStates[remoteId] == null) {
      var val = await FlutterBluePlus._methodChannel
          .invokeMethod('getBondState', remoteId.str)
          .then((args) => BmBondStateResponse.fromMap(args));
      // update _bondStates if it is still null after the await
      if (FlutterBluePlus._bondStates[remoteId] == null) {
        FlutterBluePlus._bondStates[remoteId] = val;
      }
    }

    yield* FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnBondStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmBondStateResponse.fromMap(args))
        .where((p) => p.remoteId == remoteId)
        .map((p) => _bmToBondState(p.bondState))
        .newStreamWithInitialValue(_bmToBondState(FlutterBluePlus._bondStates[remoteId]!.bondState));
  }

  /// Get the previous bondState of the device (Android Only)
  BluetoothBondState? get prevBondState {
    var b = FlutterBluePlus._bondStates[remoteId]?.prevState;
    return b != null ? _bmToBondState(b) : null;
  }

  /// Get the Services Changed characteristic (0x2A05)
  BluetoothCharacteristic? get _servicesChangedCharacteristic {
    final Guid gattUuid = Guid("1801");
    final Guid servicesChangedUuid = Guid("2A05");
    BluetoothService? gatt = servicesList._firstWhereOrNull((svc) => svc.uuid == gattUuid);
    return gatt?.characteristics._firstWhereOrNull((chr) => chr.uuid == servicesChangedUuid);
  }

  /// Workaround race condition between connect and disconnect.
  /// The bug: If you call disconnect right as android is establishing a connection 
  /// android may still connect to the device. Worse, "onConnectionStateChange" will not be called
  /// so FBP will have no idea this connection is active. Adding a delay fixes this issue.
  /// https://issuetracker.google.com/issues/37121040
  Future<void> _ensureAndroidDisconnectionDelay(int androidDelay) async {
    if (Platform.isAndroid) {
      if (FlutterBluePlus._connectTimestamp.containsKey(remoteId)) {
        Duration minGap = Duration(milliseconds: androidDelay);
        Duration elapsed = DateTime.now().difference(FlutterBluePlus._connectTimestamp[remoteId]!);
        if (elapsed.compareTo(minGap) < 0) {
          Duration timeLeft = minGap - elapsed;
          print("[FBP] disconnect: enforcing ${minGap.inMilliseconds}ms disconnect gap, delaying "
              "${timeLeft.inMilliseconds}ms");
          await Future<void>.delayed(timeLeft);
        }
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
        'platformName: $platformName, '
        'services: ${FlutterBluePlus._knownServices[remoteId]}'
        '}';
  }

  @Deprecated("removed. no replacement")
  Stream<bool> get isDiscoveringServices async* {
    yield false;
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

  @Deprecated("removed. no replacement")
  Stream<List<BluetoothService>> get servicesStream async* {
    yield [];
  }

  @Deprecated("removed. no replacement")
  Stream<List<BluetoothService>> get services async* {
    yield [];
  }
}
