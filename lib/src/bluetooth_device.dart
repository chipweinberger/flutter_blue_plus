// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDevice {
  final DeviceIdentifier remoteId;
  final String localName;
  final BluetoothDeviceType type;

  final _BehaviorSubject<List<BluetoothService>> _services = _BehaviorSubject([]);

  final _BehaviorSubject<bool> _isDiscoveringServices = _BehaviorSubject(false);

  Stream<bool> get isDiscoveringServices => _isDiscoveringServices.stream;

  BluetoothDevice.fromProto(BmBluetoothDevice p)
      : remoteId = DeviceIdentifier(p.remoteId),
        localName = p.localName ?? "",
        type = bmToBluetoothDeviceType(p.type);

  /// Use on Android when the MAC address is known.
  /// This constructor enables the Android to connect to a specific device
  /// as soon as it becomes available on the bluetooth "network".
  BluetoothDevice.fromId(String remoteId, {String? localName, BluetoothDeviceType? type})
      : remoteId = DeviceIdentifier(remoteId),
        localName = localName ?? "Unknown localName",
        type = type ?? BluetoothDeviceType.unknown;

  /// Establishes a connection to the Bluetooth Device.
  Future<void> connect({
    Duration? timeout,
    bool autoConnect = false,
    bool shouldClearGattCache = true,
  }) async {
    var request = BmConnectRequest(
      remoteId: remoteId.str,
      autoConnect: autoConnect,
    );

    var responseStream = connectionState.where((s) => s == BluetoothConnectionState.connected);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothConnectionState> futureState = responseStream.first;

    await FlutterBluePlus.instance._channel.invokeMethod('connect', request.toMap());

    // wait for connection
    if (timeout != null) {
      await futureState.timeout(timeout, onTimeout: () {
        throw TimeoutException('Failed to connect in time.', timeout);
      });
    } else {
      await futureState;
    }

    if (Platform.isAndroid && shouldClearGattCache) {
      clearGattCache();
    }
  }

  /// Send a pairing request to the device.
  /// Currently only implemented on Android.
  Future<void> pair() async {
    return FlutterBluePlus.instance._channel.invokeMethod('pair', remoteId.str);
  }

  /// Refresh Gatt Device Cache
  /// Emergency method to reload ble services & characteristics
  /// Currently only implemented on Android.
  Future<void> clearGattCache() async {
    if (Platform.isAndroid) {
      return FlutterBluePlus.instance._channel.invokeMethod('clearGattCache', remoteId.str);
    }
  }

  /// Cancels connection to the Bluetooth Device
  Future<void> disconnect() async {
    await FlutterBluePlus.instance._channel.invokeMethod('disconnect', remoteId.str);
  }

  /// Discovers services offered by the remote device
  /// as well as their characteristics and descriptors
  Future<List<BluetoothService>> discoverServices({int timeout = 15}) async {
    final s = await connectionState.first;
    if (s != BluetoothConnectionState.connected) {
      return Future.error(Exception('Cannot discoverServices while'
          'device is not connected. State == $s'));
    }

    // signal that we have started
    _isDiscoveringServices.add(true);

    var responseStream = FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "DiscoverServicesResult")
        .map((m) => m.arguments)
        .map((buffer) => BmDiscoverServicesResult.fromMap(buffer))
        .where((p) => p.remoteId == remoteId.str);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BmDiscoverServicesResult> futureResponse = responseStream.first;

    await FlutterBluePlus.instance._channel.invokeMethod('discoverServices', remoteId.str);

    // wait for response
    BmDiscoverServicesResult response = await futureResponse.timeout(Duration(seconds: timeout));

    // failed?
    if (!response.success) {
      throw FlutterBluePlusException("discoverServicesFail", response.errorCode, response.errorString);
    }

    List<BluetoothService> servicesList = response.services.map((p) => BluetoothService.fromProto(p)).toList();

    _isDiscoveringServices.add(false);
    _services.add(servicesList);

    return servicesList;
  }

  /// Returns a list of Bluetooth GATT services offered by the remote device
  /// This function requires that discoverServices has been completed for this device
  Stream<List<BluetoothService>> get services async* {
    List<BluetoothService> initialServices = await FlutterBluePlus.instance._channel
        .invokeMethod('services', remoteId.str)
        .then((buffer) => BmDiscoverServicesResult.fromMap(buffer).services)
        .then((i) => i.map((s) => BluetoothService.fromProto(s)).toList());

    yield initialServices;

    yield* _services.stream;
  }

  /// The current connection state of the device
  Stream<BluetoothConnectionState> get connectionState async* {
    BluetoothConnectionState initialState = await FlutterBluePlus.instance._channel
        .invokeMethod('getConnectionState', remoteId.str)
        .then((buffer) => BmConnectionStateResponse.fromMap(buffer))
        .then((p) => bmToBluetoothConnectionState(p.connectionState));

    yield initialState;

    yield* FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "connectionStateChanged")
        .map((m) => m.arguments)
        .map((buffer) => BmConnectionStateResponse.fromMap(buffer))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => bmToBluetoothConnectionState(p.connectionState));
  }

  /// The MTU size in bytes
  Stream<int> get mtu async* {
    BmMtuSizeResponse response = await FlutterBluePlus.instance._channel
        .invokeMethod('mtu', remoteId.str)
        .then((buffer) => BmMtuSizeResponse.fromMap(buffer));

    if (!response.success) {
      throw FlutterBluePlusException("mtuFail", response.errorCode, response.errorString);
    }

    // initial value
    yield response.mtu;

    yield* FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "MtuSize")
        .map((m) => m.arguments)
        .map((buffer) => BmMtuSizeResponse.fromMap(buffer))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => p.mtu);
  }

  /// Request to change the MTU Size
  /// Throws error if request did not complete successfully
  /// Request to change the MTU Size and returns the response back
  /// Throws error if request did not complete successfully
  Future<int> requestMtu(int desiredMtu, {int timeout = 15}) async {
    var request = BmMtuSizeRequest(
      remoteId: remoteId.str,
      mtu: desiredMtu,
    );

    var responseStream = FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "MtuSize")
        .map((m) => m.arguments)
        .map((buffer) => BmMtuSizeResponse.fromMap(buffer))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => p.mtu);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<int> futureResponse = responseStream.first;

    await FlutterBluePlus.instance._channel.invokeMethod('requestMtu', request.toMap());

    var mtu = await futureResponse.timeout(Duration(seconds: timeout));

    return mtu;
  }

  /// Indicates whether the Bluetooth Device can
  /// send a write without response
  Future<bool> get canSendWriteWithoutResponse => Future.error(UnimplementedError());

  /// Read the RSSI for a connected remote device
  Future<int> readRssi({int timeout = 15}) async {
    var responseStream = FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "ReadRssiResult")
        .map((m) => m.arguments)
        .map((buffer) => BmReadRssiResult.fromMap(buffer))
        .where((p) => (p.remoteId == remoteId.str));

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BmReadRssiResult> futureResponse = responseStream.first;

    await FlutterBluePlus.instance._channel.invokeMethod('readRssi', remoteId);

    // wait for response
    BmReadRssiResult response = await futureResponse.timeout(Duration(seconds: timeout));

    if (!response.success) {
      throw FlutterBluePlusException("readRssiFail", response.errorCode, response.errorString);
    }

    return response.rssi;
  }

  /// Request a connection parameter update.
  ///
  /// This function will send a connection parameter update request to the
  /// remote device and is only available on Android.
  ///
  /// Request a specific connection priority. Must be one of
  /// ConnectionPriority.balanced, BluetoothGatt#ConnectionPriority.high or
  /// ConnectionPriority.lowPower.
  Future<void> requestConnectionPriority({required ConnectionPriority connectionPriorityRequest}) async {
    int connectionPriority = 0;

    switch (connectionPriorityRequest) {
      case ConnectionPriority.balanced:
        connectionPriority = 0;
        break;
      case ConnectionPriority.high:
        connectionPriority = 1;
        break;
      case ConnectionPriority.lowPower:
        connectionPriority = 2;
        break;
      default:
        break;
    }

    var request = BmConnectionPriorityRequest(
      remoteId: remoteId.str,
      connectionPriority: connectionPriority,
    );

    await FlutterBluePlus.instance._channel.invokeMethod(
      'requestConnectionPriority',
      request.toMap(),
    );
  }

  /// Set the preferred connection [txPhy], [rxPhy] and Phy [option] for this
  /// app. [txPhy] and [rxPhy] are int to be passed a masked value from the
  /// [PhyType] enum, eg `(PhyType.le1m.mask | PhyType.le2m.mask)`.
  ///
  /// Please note that this is just a recommendation, whether the PHY change
  /// will happen depends on other applications preferences, local and remote
  /// controller capabilities. Controller can override these settings.
  Future<void> setPreferredPhy({
    required int txPhy,
    required int rxPhy,
    required PhyOption option,
  }) async {
    var request = BmPreferredPhy(
      remoteId: remoteId.str,
      txPhy: txPhy,
      rxPhy: rxPhy,
      phyOptions: option.index,
    );

    await FlutterBluePlus.instance._channel.invokeMethod(
      'setPreferredPhy',
      request.toMap(),
    );
  }

  /// Only implemented on Android, for now
  Future<bool> removeBond() async {
    if (Platform.isAndroid) {
      return await FlutterBluePlus.instance._channel
          .invokeMethod('removeBond', remoteId.str)
          .then<bool>((value) => value);
    } else {
      return false;
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
        '_services: ${_services.value}'
        '}';
  }

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get id => remoteId;

  @Deprecated('Use localName instead')
  String get name => localName;

  @Deprecated('Use connectionState instead')
  Stream<BluetoothConnectionState> get state => connectionState;
}

enum BluetoothDeviceType { unknown, classic, le, dual }

BluetoothDeviceType bmToBluetoothDeviceType(BmBluetoothSpecEnum value) {
  switch (value) {
    case BmBluetoothSpecEnum.unknown:
      return BluetoothDeviceType.unknown;
    case BmBluetoothSpecEnum.classic:
      return BluetoothDeviceType.classic;
    case BmBluetoothSpecEnum.le:
      return BluetoothDeviceType.le;
    case BmBluetoothSpecEnum.dual:
      return BluetoothDeviceType.dual;
  }
}

enum BluetoothConnectionState { disconnected, connecting, connected, disconnecting }

BluetoothConnectionState bmToBluetoothConnectionState(BmConnectionStateEnum value) {
  switch (value) {
    case BmConnectionStateEnum.disconnected:
      return BluetoothConnectionState.disconnected;
    case BmConnectionStateEnum.connecting:
      return BluetoothConnectionState.connecting;
    case BmConnectionStateEnum.connected:
      return BluetoothConnectionState.connected;
    case BmConnectionStateEnum.disconnecting:
      return BluetoothConnectionState.disconnecting;
  }
}

enum ConnectionPriority { balanced, high, lowPower }

enum PhyType { le1m, le2m, leCoded }

extension PhyTypeExt on PhyType {
  int get mask {
    switch (this) {
      case PhyType.le1m:
        return 1;
      case PhyType.le2m:
        return 2;
      case PhyType.leCoded:
        return 3;
      default:
        return 1;
    }
  }
}

enum PhyOption { noPreferred, s2, s8 }
