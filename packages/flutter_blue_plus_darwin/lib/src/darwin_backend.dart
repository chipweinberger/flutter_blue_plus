part of '../flutter_blue_plus_darwin.dart';

abstract base class _DarwinBackend extends FlutterBluePlusPlatform {
  cb.CBCentralManager? _centralManager;
  Future<void>? _initialization;
  bool _showPowerAlert = true;
  bool _restoreState = false;
  final _known = <String, cb.CBPeripheral>{};
  final _states = <String, _PeripheralState>{};
  final _connected = <String, cb.CBPeripheral>{};
  final _connecting = <String, cb.CBPeripheral>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  BmScanSettings? _scanSettings;
  bool _disposed = false;
  Future<void>? _disposal;
  LogLevel _logLevel = LogLevel.none;
  bool _initializing = false;
  final _restartDisconnected = <String>{};
  final _restartPending = <String>{};
  Completer<void>? _restartDone;

  final _onAdapterStateChangedController = StreamController<BmBluetoothAdapterState>.broadcast();
  final _onCharacteristicReceivedController = StreamController<BmCharacteristicData>.broadcast();
  final _onCharacteristicWrittenController = StreamController<BmCharacteristicData>.broadcast();
  final _onConnectionStateChangedController = StreamController<BmConnectionStateResponse>.broadcast();
  final _onDescriptorReadController = StreamController<BmDescriptorData>.broadcast();
  final _onDescriptorWrittenController = StreamController<BmDescriptorData>.broadcast();
  final _onDiscoveredServicesController = StreamController<BmDiscoverServicesResult>.broadcast();
  final _onMtuChangedController = StreamController<BmMtuChangedResponse>.broadcast();
  final _onNameChangedController = StreamController<BmNameChanged>.broadcast();
  final _onReadRssiController = StreamController<BmReadRssiResult>.broadcast();
  final _onScanResponseController = StreamController<BmScanResponse>.broadcast();
  final _onServicesResetController = StreamController<BmBluetoothDevice>.broadcast();

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged => _onAdapterStateChangedController.stream;

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

  cb.CBCentralManager get _manager => _centralManager ??= cb.CBCentralManager.ensureShared(
        options: _restoreState || _showPowerAlert
            ? cb.CentralManagerOptions(
                // The old backend omitted the option when false, retaining the OS default.
                showPowerAlert: _showPowerAlert ? true : null,
                restoreIdentifier: _restoreState ? 'flutterBluePlusRestoreIdentifier' : null,
              )
            : null,
      );

  bool get _cleaningPreviousSession => _initializing && _manager.wasReattached;

  void _checkNotDisposed() {
    if (_disposed) throw StateError('FlutterBluePlusDarwin has been disposed');
  }

  void _reportBackgroundError(Object error, StackTrace stack) {
    if (!_disposed && _logLevel.index >= LogLevel.error.index) {
      FlutterBluePlusPlatform.log('[FBP-Darwin] $error');
    }
  }

  void _background(Future<void> action) => unawaited(action.catchError(_reportBackgroundError));

  void _listen<T>(Stream<T> stream, void Function(T) listener) {
    _subscriptions.add(stream.listen((event) {
      if (!_disposed) listener(event);
    }, onError: _reportBackgroundError));
  }

  void _requireAdapter(String method) {
    if (_manager.state != cb.CBManagerState.poweredOn) {
      _fail(method, 'bluetooth must be turned on. (${_stateName(_manager.state)})');
    }
  }

  _PeripheralState _connectedState(String method, DeviceIdentifier remoteId, {Object? connectionToken}) {
    _checkNotDisposed();
    final state = _states[remoteId.str];
    if (!_connected.containsKey(remoteId.str) ||
        state == null ||
        (connectionToken != null && !identical(state.connectionToken, connectionToken))) {
      _fail(method, 'device is disconnected', remoteId.str);
    }
    return state;
  }

  void _finishRestart() {
    _restartPending.clear();
    final done = _restartDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> _cancelManagerListeners() async {
    final subscriptions = _subscriptions.toList();
    _subscriptions.clear();
    await Future.wait(subscriptions.map((subscription) => subscription.cancel()));
  }

  Future<void> _clearDevices() async {
    final subscriptions = <StreamSubscription<Object?>>[];
    for (final state in _states.values) {
      state.clearOperations();
      subscriptions.addAll(state.subscriptions);
      state.subscriptions.clear();
    }
    _states.clear();
    _known.clear();
    _connected.clear();
    _connecting.clear();
    await Future.wait(subscriptions.map((subscription) => subscription.cancel()));
  }

  Future<void> _ensureInitialized() => _initialization ??= _initialize().catchError((Object error, StackTrace stack) {
        _initialization = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<T> _run<T>(Future<T> Function() operation) async {
    _checkNotDisposed();
    await _ensureInitialized();
    _checkNotDisposed();
    try {
      final result = await operation();
      _checkNotDisposed();
      return result;
    } on PlatformException catch (error) {
      if (error.code != 'invalid_args') rethrow;
      throw PlatformException(code: 'iosException', message: error.message, details: error.details);
    }
  }

  void _watchPeripheral(cb.CBPeripheral peripheral);
  void _onConnected(cb.CBPeripheral peripheral);
  void _onDisconnected(cb.CBPeripheral peripheral, cb.CBError? error, {bool failed = false});
  void _onDiscovered(cb.DidDiscoverPeripheralResult event);
  Future<void> _restore(cb.WillRestoreStateResult event);
  void _restoreServices(cb.CBPeripheral peripheral);

  void _onNameChanged(cb.DidUpdateNameResult event) {
    if (event.name != null && _connected.containsKey(_remoteId(event.peripheral))) {
      _onNameChangedController
          .add(BmNameChanged(remoteId: DeviceIdentifier(_remoteId(event.peripheral)), name: event.name!));
    }
  }

  void _onServicesReset(cb.DidModifyServicesResult event) {
    if (_connected.containsKey(_remoteId(event.peripheral))) {
      _onServicesResetController
          .add(BmBluetoothDevice(remoteId: DeviceIdentifier(_remoteId(event.peripheral)), platformName: event.name));
    }
  }

  void _onAdapterState(cb.CBManagerState state) {
    _onAdapterStateChangedController.add(BmBluetoothAdapterState(adapterState: _adapterState(state)));
    if (state == cb.CBManagerState.poweredOn) return;
    _background(_manager.stopScan());
    if (!_cleaningPreviousSession) {
      for (final peripheral in _connected.values.toList()) {
        _onConnectionStateChangedController.add(BmConnectionStateResponse(
            remoteId: DeviceIdentifier(_remoteId(peripheral)),
            connectionState: BmConnectionStateEnum.disconnected,
            disconnectReasonCode: 1573878,
            disconnectReasonString: 'Bluetooth turned off'));
      }
    }
    _connected.clear();
    _connecting.clear();
    for (final state in _states.values) {
      state.clearOperations();
    }
    if (_cleaningPreviousSession) _finishRestart();
  }

  void _listenToManager(cb.CBCentralManager manager) {
    _listen(manager.onDidUpdateState, _onAdapterState);
    _listen(manager.onDidDiscoverPeripheral, _onDiscovered);
    _listen(manager.onDidConnectPeripheral, _onConnected);
    _listen(manager.onDidDisconnectPeripheral, (event) => _onDisconnected(event.peripheral, event.error));
    _listen(
        manager.onDidFailToConnectPeripheral, (event) => _onDisconnected(event.peripheral, event.error, failed: true));
    _listen(manager.onWillRestoreState, (event) => _background(_restore(event)));
    _listen(manager.onDidUpdateName, _onNameChanged);
    _listen(manager.onDidModifyServices, _onServicesReset);
  }

  Future<void> _disconnectPreviousSession(cb.CBCentralManager manager) async {
    final pending = await manager.disconnectAllPeripherals();
    _checkNotDisposed();
    _restartPending.addAll(pending.map(_remoteId).where((id) => !_restartDisconnected.contains(id)));
    if (_restartPending.isEmpty || manager.state != cb.CBManagerState.poweredOn) return;
    _restartDone = Completer<void>();
    await _restartDone!.future;
    _checkNotDisposed();
  }

  Future<void> _initialize() async {
    _initializing = true;
    try {
      final manager = _manager;
      final existingDartManager = manager.isInitialized;
      _listenToManager(manager);
      await manager.ready;
      _checkNotDisposed();
      if (manager.wasReattached) {
        await _disconnectPreviousSession(manager);
      } else {
        // Preserve fresh OS restoration, and adopt direct connections made in
        // this Dart session before FBP started using the shared manager.
        _initializing = false;
        if (existingDartManager) {
          for (final peripheral in manager.connectedPeripherals) {
            if (!_connected.containsKey(_remoteId(peripheral))) _onConnected(peripheral);
          }
        }
      }
    } catch (_) {
      await _cancelManagerListeners();
      await _clearDevices();
      rethrow;
    } finally {
      _initializing = false;
      _finishRestart();
      _restartDisconnected.clear();
      _restartDone = null;
    }
  }

  /// Detaches this backend without disposing the shared native manager.
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _finishRestart();
    await _cancelManagerListeners();
    await _clearDevices();
    _scanSettings = null;
  }
}
