part of '../flutter_blue_plus_darwin.dart';

base mixin _DeviceOperations on _DarwinBackend {
  void _watchMtu(_PeripheralState state) {
    state.mtuMonitor ??= _MtuMonitor(state.peripheral, (mtu) {
      _onMtuChangedController.add(BmMtuChangedResponse(
          remoteId: DeviceIdentifier(_remoteId(state.peripheral)),
          mtu: mtu,
          success: true,
          errorCode: 0,
          errorString: 'success'));
    }, _reportBackgroundError);
  }

  @override
  void _onConnected(cb.CBPeripheral peripheral) {
    final id = _remoteId(peripheral);
    _known[id] = peripheral;
    _watchPeripheral(peripheral);
    _connected[id] = peripheral;
    _connecting.remove(id);
    if (_cleaningPreviousSession) return;
    _watchMtu(_states[id]!);
    _onConnectionStateChangedController.add(BmConnectionStateResponse(
        remoteId: DeviceIdentifier(id),
        connectionState: BmConnectionStateEnum.connected,
        disconnectReasonCode: null,
        disconnectReasonString: null));
  }

  @override
  void _onDisconnected(cb.CBPeripheral peripheral, cb.CBError? error, {bool failed = false}) {
    final id = _remoteId(peripheral);
    _connected.remove(id);
    _connecting.remove(id);
    final state = _states[id];
    if (state != null) state.clearOperations();
    if (_cleaningPreviousSession) {
      _restartDisconnected.add(id);
      _restartPending.remove(id);
      if (_restartPending.isEmpty) _finishRestart();
      // The former Dart channel handler was installed after restart cleanup.
      return;
    }
    _onConnectionStateChangedController.add(BmConnectionStateResponse(
        remoteId: DeviceIdentifier(id),
        connectionState: BmConnectionStateEnum.disconnected,
        disconnectReasonCode: error?.code.rawValue ?? (failed ? null : bmUserCanceledErrorCode),
        disconnectReasonString: error?.localizedDescription ?? (failed ? null : 'connection canceled')));
  }

  @override
  Future<void> _restore(cb.WillRestoreStateResult event) async {
    _onAdapterState(_manager.state);
    for (final peripheral in event.peripherals) {
      _checkNotDisposed();
      _known[_remoteId(peripheral)] = peripheral;
      _watchPeripheral(peripheral);
      if (peripheral.state == cb.CBPeripheralState.connected) {
        _onConnected(peripheral);
        _restoreServices(peripheral);
      } else {
        await _manager.connect(peripheral);
      }
    }
  }

  @override
  Future<bool> disconnect(BmDisconnectRequest request) => _run(() async {
        final id = request.remoteId.str;
        final peripheral = _connecting.remove(id) ?? _connected[id];
        if (peripheral == null) return false;
        await _manager.cancelPeripheralConnection(peripheral);
        return true;
      });

  @override
  Future<bool> readRssi(BmReadRssiRequest request) => _run(() async {
        await _connectedState('readRssi', request.remoteId).peripheral.readRSSI();
        return true;
      });

  @override
  Future<bool> connect(BmConnectRequest request) => _run(() async {
        _requireAdapter('connect');
        final id = request.remoteId.str;
        if (_connecting.containsKey(id)) return true;
        if (_connected.containsKey(id)) return false;
        cb.UUID uuid;
        try {
          uuid = cb.UUID(request.remoteId.str);
        } on FormatException {
          _fail('connect', 'invalid remoteId', request.remoteId.str);
        }
        final peripherals = await _manager.retrievePeripherals([uuid]);
        _checkNotDisposed();
        _requireAdapter('connect');
        final matches = peripherals.where((p) => _remoteId(p) == id);
        if (matches.isEmpty) _fail('connect', 'Peripheral not found', request.remoteId.str);
        final peripheral = matches.first;
        _known[id] = peripheral;
        _watchPeripheral(peripheral);
        _connecting[id] = peripheral;
        try {
          await _manager.connect(peripheral,
              options: cb.ConnectPeripheralOptions(enableAutoReconnect: request.autoConnect));
        } catch (_) {
          _connecting.remove(id);
          rethrow;
        }
        return true;
      });
}
