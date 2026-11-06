part of '../flutter_blue_plus_android.dart';

abstract base class _AndroidBackend extends FlutterBluePlusPlatform {
  final _connections = <String, _Connection>{};
  final _writes = <_WriteKey, Uint8List>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  Future<void>? _initialization;
  Future<void> _permissionTail = Future.value();
  int _generation = 0;
  late ab.BluetoothCapabilities _capabilities;
  ab.BluetoothScan? _scan;
  StreamSubscription<ab.ScanCallback>? _scanSubscription;
  BmScanSettings? _scanSettings;
  final _advertisements = <String, List<int>>{};
  final _scanCounts = <String, int>{};

  Future<void> _disconnectAll();
  Future<void> _stopScan();
  Future<bool> _isAdapterOn();
  void _gattCallback(_Connection connection, ab.BluetoothGattCallback event);

  void _requirePhy(String method) {
    if (_capabilities.apiLevel < 26) {
      _fail(method, 'Only supported on devices >= API 26. This device == ${_capabilities.apiLevel}');
    }
  }

  _Connection _connected(String method, String remoteId) {
    final connection = _connections[remoteId];
    if (connection == null || !connection.connected) _fail(method, 'device is disconnected');
    return connection;
  }

  void _cancelSubscriptions() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  PlatformException _translateError(PlatformException error) {
    const nativeErrors = {
      'android_error',
      'permission_denied',
      'invalid_argument',
      'invalid_state',
      'unsupported',
      'io_error',
      'restricted_api',
      'activity_detached',
    };
    if (!nativeErrors.contains(error.code)) return error;
    final details = error.details;
    return PlatformException(
        code: 'androidException', message: error.message, details: details is Map ? details['stackTrace'] : details);
  }

  void _emit<T>(
      String name, StreamController<T> controller, Map<String, Object?> data, T Function(Map<String, Object?>) decode) {
    // Malformed callbacks were rejected at the former native channel boundary.
    try {
      controller.add(decode(data));
    } catch (error) {
      if (_logLevel.index >= LogLevel.error.index) {
        FlutterBluePlusPlatform.log('[FBP] <$name> event decoding failed: $error');
      }
    }
  }

  void _emitConnectionState(_Connection connection, BmConnectionStateEnum state, int reasonCode,
      {String? reasonString}) {
    _emit(
        'OnConnectionStateChanged',
        _onConnectionStateChangedController,
        {
          'remote_id': connection.remoteId,
          'connection_state': state.index,
          'disconnect_reason_code': reasonCode,
          'disconnect_reason_string': reasonString ?? _hciStatus(reasonCode),
        },
        BmConnectionStateResponse.fromMap);
  }

  Future<List<String>> _missingPermissions(List<String> permissions) async {
    final granted = await ab.AndroidBluetooth.checkPermissions(permissions);
    return permissions.where((permission) => granted[permission] != true).toList();
  }

  Future<String?> _requestMissingPermissions(List<String> permissions) async {
    // A preceding dialog may have granted permissions while this caller waited.
    final needed = await _missingPermissions(permissions);
    if (needed.isEmpty) return null;
    final result = await ab.AndroidBluetooth.requestPermissions(needed);
    for (final permission in needed) {
      if (result[permission] != true) return permission;
    }
    return null;
  }

  Future<String?> _permissions(List<String> permissions) async {
    // Match the original backend: only operations that need a dialog must wait.
    if (permissions.isEmpty || (await _missingPermissions(permissions)).isEmpty) return null;
    final previous = _permissionTail;
    final done = Completer<void>();
    _permissionTail = done.future;
    await previous;
    try {
      return await _requestMissingPermissions(permissions);
    } finally {
      done.complete();
    }
  }

  Future<void> _requirePermission(String method, List<String> permissions, String reason) async {
    final denied = await _permissions(permissions);
    if (denied != null) _fail(method, 'Permission $denied required $reason');
  }

  List<String> get _connectPermissions => _capabilities.apiLevel >= 31 ? [_bluetoothConnect] : [];

  Future<void> _adapterEvent(ab.BluetoothAdapterEvent event, int generation) async {
    if (generation != _generation) return;
    if (event.state == ab.BluetoothAdapter.stateOn) await _stopScan();
    if (generation != _generation) return;
    _emit('OnAdapterStateChanged', _onAdapterStateChangedController,
        {'adapter_state': _adapterState(event.state).index}, BmBluetoothAdapterState.fromMap);
    if (event.state == ab.BluetoothAdapter.stateOff || event.state == ab.BluetoothAdapter.stateTurningOff) {
      await _disconnectAll();
    }
  }

  Future<void> _initialize() {
    final generation = _generation;
    return _initialization ??= _initializeOnce(generation).catchError((Object error, StackTrace stack) {
      if (generation == _generation) {
        _cancelSubscriptions();
        _initialization = null;
      }
      Error.throwWithStackTrace(error, stack);
    });
  }

  void _enableResponse(ab.BluetoothEnableResponse event) {
    // Legacy FBP reports an Activity result, not Activity-detach cleanup.
    if (event.errorCode != null) return;
    _emit('OnTurnOnResponse', _onTurnOnResponseController, {'user_accepted': event.userAccepted},
        BmTurnOnResponse.fromMap);
  }

  void _bondStateChanged(ab.BluetoothDeviceEvent event) {
    if (event.type != ab.BluetoothDevice.actionBondStateChanged || event.device == null) return;
    _emit(
        'OnBondStateChanged',
        _onBondStateChangedController,
        {
          'remote_id': event.device!.address,
          'bond_state': _bondState(event.bondState).index,
          'prev_state': _bondState(event.previousBondState).index,
        },
        BmBondStateResponse.fromMap);
  }

  void _engineDetached(ab.BluetoothEngineEvent event) {
    _generation++;
    _connections.clear();
    _writes.clear();
    _scan = null;
    _emit('OnDetachedFromEngine', _onDetachedFromEngineController, {}, (_) => BmDetachedFromEngineResponse());
    _cancelSubscriptions();
    _initialization = null;
  }

  Future<void> _initializeOnce(int generation) async {
    final adapterEvents = ab.BluetoothAdapter.shared.events
        .where((event) => event.type == 'android.bluetooth.adapter.action.STATE_CHANGED')
        .asyncMap((event) => _adapterEvent(event, generation));
    _subscriptions.add(adapterEvents.listen(null, onError: (Object error, StackTrace stack) {
      if (generation == _generation) Zone.current.handleUncaughtError(error, stack);
    }));
    _subscriptions.add(ab.BluetoothAdapter.shared.onEnableResponse.listen(_enableResponse));
    _subscriptions.add(ab.BluetoothDevice.allEvents.listen(_bondStateChanged));
    _subscriptions.add(ab.AndroidBluetooth.onDetachedFromEngine.listen(_engineDetached));
    _capabilities = await ab.AndroidBluetooth.capabilities;
  }

  var _logLevel = LogLevel.none;

  final _onAdapterStateChangedController = StreamController<BmBluetoothAdapterState>.broadcast();
  final _onBondStateChangedController = StreamController<BmBondStateResponse>.broadcast();
  final _onCharacteristicReceivedController = StreamController<BmCharacteristicData>.broadcast();
  final _onCharacteristicWrittenController = StreamController<BmCharacteristicData>.broadcast();
  final _onConnectionStateChangedController = StreamController<BmConnectionStateResponse>.broadcast();
  final _onDescriptorReadController = StreamController<BmDescriptorData>.broadcast();
  final _onDescriptorWrittenController = StreamController<BmDescriptorData>.broadcast();
  final _onDetachedFromEngineController = StreamController<BmDetachedFromEngineResponse>.broadcast();
  final _onDiscoveredServicesController = StreamController<BmDiscoverServicesResult>.broadcast();
  final _onMtuChangedController = StreamController<BmMtuChangedResponse>.broadcast();
  final _onNameChangedController = StreamController<BmNameChanged>.broadcast();
  final _onReadRssiController = StreamController<BmReadRssiResult>.broadcast();
  final _onScanResponseController = StreamController<BmScanResponse>.broadcast();
  final _onServicesResetController = StreamController<BmBluetoothDevice>.broadcast();
  final _onTurnOnResponseController = StreamController<BmTurnOnResponse>.broadcast();

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged => _onAdapterStateChangedController.stream;

  @override
  Stream<BmBondStateResponse> get onBondStateChanged => _onBondStateChangedController.stream;

  @override
  Stream<BmCharacteristicData> get onCharacteristicReceived => _onCharacteristicReceivedController.stream;

  @override
  Stream<BmCharacteristicData> get onCharacteristicWritten => _onCharacteristicWrittenController.stream;

  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged => _onConnectionStateChangedController.stream;

  @override
  Stream<BmDescriptorData> get onDescriptorRead => _onDescriptorReadController.stream;

  @override
  Stream<BmDescriptorData> get onDescriptorWritten => _onDescriptorWrittenController.stream;

  @override
  Stream<BmDetachedFromEngineResponse> get onDetachedFromEngine => _onDetachedFromEngineController.stream;

  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices => _onDiscoveredServicesController.stream;

  @override
  Stream<BmMtuChangedResponse> get onMtuChanged => _onMtuChangedController.stream;

  @override
  Stream<BmNameChanged> get onNameChanged => _onNameChangedController.stream;

  @override
  Stream<BmReadRssiResult> get onReadRssi => _onReadRssiController.stream;

  @override
  Stream<BmScanResponse> get onScanResponse => _onScanResponseController.stream;

  @override
  Stream<BmBluetoothDevice> get onServicesReset => _onServicesResetController.stream;

  @override
  Stream<BmTurnOnResponse> get onTurnOnResponse => _onTurnOnResponseController.stream;

  Future<T> _run<T>(Future<T> Function() operation, {bool allowUnavailable = false}) async {
    await _initialize();
    if (!_capabilities.hasAdapter && !allowUnavailable) {
      _fail('bluetoothUnavailable', 'the device does not support bluetooth');
    }
    try {
      return await operation();
    } on PlatformException catch (error) {
      final translated = _translateError(error);
      if (identical(translated, error)) rethrow;
      throw translated;
    }
  }
}
