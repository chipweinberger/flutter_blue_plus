part of '../flutter_blue_plus_android.dart';

base mixin _DeviceOperations on _AndroidBackend {
  void _pauseConnectionCallbacks(_Connection connection, bool pause) {
    final subscription = connection.subscription;
    if (pause) {
      subscription?.pause();
    } else {
      subscription?.resume();
    }
    final previous = connection.previous;
    if (previous != null) _pauseConnectionCallbacks(previous, pause);
  }

  Iterable<_Connection> _retireConnection(_Connection connection) sync* {
    final previous = connection.previous;
    connection.previous = null;
    if (previous != null) yield* _retireConnection(previous);
    yield connection;
  }

  Future<void> _closeConnection(_Connection connection) => _closeConnections([connection]);

  Future<void> _closeConnections(Iterable<_Connection> connections) async {
    final retired = connections.expand(_retireConnection).toList();
    Object? firstError;
    StackTrace? firstStack;
    for (final connection in retired) {
      try {
        await connection.ready.future;
        await connection.subscription?.cancel();
        await connection.gatt?.close();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    // Preserve cleanup order and report the first failure after every client is attempted.
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  @override
  Future<void> _disconnectAll() async {
    final connections = _connections.values.toList();
    _connections.clear();
    _writes.clear();
    // Emit before awaiting native cleanup, including retained auto-connect clients.
    for (final connection in connections) {
      if (connection.connected || connection.autoConnect || connection.previous != null) {
        _emitConnectionState(connection, BmConnectionStateEnum.disconnected, 0);
      }
    }
    await _closeConnections(connections);
  }

  Future<void> _openConnection(_Connection connection) async {
    try {
      final gatt = await ab.BluetoothDevice(connection.remoteId)
          .connectGatt(autoConnect: connection.autoConnect, preserveAttributeHandles: true);
      connection.gatt = gatt;
      connection.subscription = gatt.events.listen((event) => _gattCallback(connection, event));
      if (connection.canceling) connection.subscription!.pause();
    } on PlatformException catch (error) {
      if (!connection.canceling && identical(_connections[connection.remoteId], connection)) {
        final previous = connection.previous;
        connection.previous = null;
        if (previous == null) {
          _connections.remove(connection.remoteId);
        } else {
          _connections[connection.remoteId] = previous;
        }
      }
      if (error.code == 'invalid_state' && (error.message ?? '').contains('register GATT')) {
        _fail('connect', 'device.connectGatt returned null');
      }
      rethrow;
    } finally {
      connection.ready.complete();
    }
  }

  @override
  Future<bool> connect(BmConnectRequest request) {
    final address = request.remoteId.str;
    final autoConnect = request.autoConnect;
    return _run(() async {
      await _requirePermission('connect', _connectPermissions, 'for new connection');
      if (!await _isAdapterOn()) _fail('connect', 'Bluetooth must be turned on');
      final old = _connections[address];
      if (old?.connecting == true || old?.canceling == true) return true;
      if (old?.connected == true) return false;
      final connection = _Connection(address, autoConnect, previous: old);
      _connections[address] = connection;
      await _openConnection(connection);
      // A pending disconnect owns cleanup of both registrations.
      if (!connection.explicitDisconnect) {
        final previous = connection.previous;
        connection.previous = null;
        if (previous != null) await _closeConnection(previous);
      }
      return true;
    });
  }

  @override
  Future<bool> disconnect(BmDisconnectRequest request) {
    final address = request.remoteId.str;
    return _run(() async {
      final connection = _connections[address];
      if (connection == null) return false;
      if (connection.canceling) return false;
      final pending = connection.connecting;
      final connected = connection.connected;
      final closeNow = pending || !connected;
      connection.explicitDisconnect = true;
      if (closeNow) {
        connection.canceling = true;
        _pauseConnectionCallbacks(connection, true);
      }
      try {
        await connection.ready.future;
        await connection.gatt?.disconnect();
        if (closeNow) {
          if (identical(_connections[address], connection)) _connections.remove(address);
          await _closeConnection(connection);
        }
        if (pending) {
          _emitConnectionState(connection, BmConnectionStateEnum.disconnected, bmUserCanceledErrorCode,
              reasonString: 'connection canceled');
        }
        return pending || connected;
      } finally {
        if (closeNow) {
          connection.canceling = false;
          // Failed submission leaves the tracked client and its queued callbacks usable.
          _pauseConnectionCallbacks(connection, false);
        }
      }
    });
  }

  @override
  Future<bool> removeBond(BmRemoveBondRequest request) {
    final address = request.remoteId.str;
    return _run(() async {
      final device = ab.BluetoothDevice(address);
      if (await device.getBondState() == ab.BluetoothDevice.bondNone) return false;
      if (!await device.removeBond()) _fail('removeBond', 'device.removeBond() returned false');
      return true;
    });
  }

  @override
  Future<bool> createBond(BmCreateBondRequest request) {
    final address = request.remoteId.str;
    final pin = request.pin == null ? null : Uint8List.fromList(request.pin!);
    return _run(() async {
      final device = ab.BluetoothDevice(address);
      // Legacy prearms the PIN even when the operation later finds no connection.
      if (pin != null) await device.setPinForNextPairing(pin);
      _connected('createBond', address);
      final state = await device.getBondState();
      if (state == ab.BluetoothDevice.bondBonded) return false;
      if (state == ab.BluetoothDevice.bondBonding) return true;
      if (!await device.createBond(pin: pin)) _fail('createBond', 'device.createBond() returned false');
      return true;
    });
  }
}
