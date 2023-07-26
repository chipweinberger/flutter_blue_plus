// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDevice {
  ////////////////////////////////
  // Internal
  //

  static Map<DeviceIdentifier, List<BluetoothService>> _knownServices = {};

  // used for 'services' public api
  final StreamController<List<BluetoothService>> _services = StreamController();

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
        type = bmToBluetoothDeviceType(p.type);

  /// allows connecting to a known device without scanning
  BluetoothDevice.fromId(String remoteId, {String? localName, BluetoothDeviceType? type})
      : remoteId = DeviceIdentifier(remoteId),
        localName = localName ?? "Unknown",
        type = type ?? BluetoothDeviceType.unknown;

  // stream return whether or not we are currently discovering services
  Stream<bool> get isDiscoveringServices => _isDiscoveringServices.stream;

  /// Stream of bluetooth services offered by the remote device
  Stream<List<BluetoothService>> get servicesStream async* {
    if (_knownServices[remoteId] != null) {
      yield _knownServices[remoteId]!;
    }
    yield* _services.stream;
  }

  /// Establishes a connection to the Bluetooth Device.
  Future<void> connect({
    Duration timeout = const Duration(seconds: 15),
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

    await FlutterBluePlus._invokeMethod('connect', request.toMap());

    // wait for connection
    await futureState.timeout(timeout);

    if (Platform.isAndroid && shouldClearGattCache) {
      clearGattCache();
    }
  }

  /// Cancels connection to the Bluetooth Device
  Future<void> disconnect({int timeout = 15}) async {
    var responseStream = connectionState.where((s) => s == BluetoothConnectionState.disconnected);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothConnectionState> futureState = responseStream.first;

    await FlutterBluePlus._invokeMethod('disconnect', remoteId.str);

    // wait for disconnection
    await futureState.timeout(Duration(seconds: timeout));
  }

  /// Discover services, characteristics, and descriptors of the remote device
  Future<List<BluetoothService>> discoverServices({int timeout = 15}) async {
    final s = await connectionState.first;
    if (s != BluetoothConnectionState.connected) {
      throw FlutterBluePlusException('discoverServices', -1, 'device is not connected');
    }

    // signal that we have started
    _isDiscoveringServices.add(true);

    var responseStream = FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "DiscoverServicesResult")
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

    List<BluetoothService> result = response.services.map((p) => BluetoothService.fromProto(p)).toList();

    // remember known services
    _knownServices[remoteId] = result;

    // update streams
    _isDiscoveringServices.add(false);
    _services.add(result);

    return result;
  }

  /// The current connection state of the device to this application
  Stream<BluetoothConnectionState> get connectionState async* {
    BluetoothConnectionState initialState = await FlutterBluePlus._methods
        .invokeMethod('getConnectionState', remoteId.str)
        .then((buffer) => BmConnectionStateResponse.fromMap(buffer))
        .then((p) => bmToBluetoothConnectionState(p.connectionState));

    yield initialState;

    yield* FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "connectionStateChanged")
        .map((m) => m.arguments)
        .map((buffer) => BmConnectionStateResponse.fromMap(buffer))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => bmToBluetoothConnectionState(p.connectionState));
  }

  /// The current MTU size in bytes
  Stream<int> get mtu async* {
    // wait for connection
    await connectionState.where((v) => v == BluetoothConnectionState.connected).first;

    BmMtuChangedResponse response = await FlutterBluePlus._methods
        .invokeMethod('getMtu', remoteId.str)
        .then((buffer) => BmMtuChangedResponse.fromMap(buffer));

    // failed?
    if (!response.success) {
      throw FlutterBluePlusException("mtu", response.errorCode, response.errorString);
    }

    // initial value
    yield response.mtu;

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

    var mtu = await futureResponse.timeout(Duration(seconds: timeout));

    return mtu;
  }

  /// Read the RSSI of connected remote device
  Future<int> readRssi({int timeout = 15}) async {
    var responseStream = FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "ReadRssiResult")
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

    return response.rssi;
  }

  /// Request connection priority update (Android only)
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

  /// Send a pairing request to the device (Android Only)
  Future<void> pair() async {
    return await FlutterBluePlus._invokeMethod('pair', remoteId.str);
  }

  /// Refresh ble services & characteristics (Android Only)
  Future<void> clearGattCache() async {
    if (Platform.isAndroid) {
      return await FlutterBluePlus._invokeMethod('clearGattCache', remoteId.str);
    }
  }

  /// Remove bond (Android Only)
  Future<bool> removeBond() async {
    if (Platform.isAndroid) {
      return await FlutterBluePlus._methods.invokeMethod('removeBond', remoteId.str).then<bool>((value) => value);
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
        'services: ${_knownServices[remoteId]}'
        '}';
  }

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get id => remoteId;

  @Deprecated('Use localName instead')
  String get name => localName;

  @Deprecated('Use connectionState instead')
  Stream<BluetoothConnectionState> get state => connectionState;

  @Deprecated('Use servicesStream instead')
  Stream<List<BluetoothService>> get services => servicesStream;
}
