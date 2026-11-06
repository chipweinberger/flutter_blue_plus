part of '../flutter_blue_plus_android.dart';

base mixin _DeviceOperations on _AndroidBackend {
  Future<void> _closeConnection(_Connection connection) async {
    await connection.subscription?.cancel();
    await connection.gatt?.close();
  }

  @override
  Future<void> _disconnectAll() async {
    final connections = _connections.values.toList();
    _connections.clear();
    _writes.clear();
    // Emit before awaiting native cleanup, in the same order as the adapter event.
    for (final connection in connections) {
      if (connection.connected || connection.autoConnect) {
        _emitConnectionState(connection, BmConnectionStateEnum.disconnected, 0);
      }
    }
    for (final connection in connections) {
      await connection.ready.future;
      await _closeConnection(connection);
    }
  }

  Future<void> _openConnection(_Connection connection) async {
    try {
      final gatt = await ab.BluetoothDevice(connection.remoteId)
          .connectGatt(autoConnect: connection.autoConnect, preserveAttributeHandles: true);
      connection.gatt = gatt;
      connection.subscription = gatt.events.listen((event) => _gattCallback(connection, event));
    } on PlatformException catch (error) {
      if (identical(_connections[connection.remoteId], connection)) _connections.remove(connection.remoteId);
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
      if (old?.connecting == true) return true;
      if (old?.connected == true) return false;
      final connection = _Connection(address, autoConnect);
      _connections[address] = connection;
      await _openConnection(connection);
      if (old != null) await _closeConnection(old);
      return true;
    });
  }

  @override
  Future<bool> disconnect(BmDisconnectRequest request) {
    final address = request.remoteId.str;
    return _run(() async {
      final connection = _connections[address];
      if (connection == null) return false;
      final pending = connection.connecting;
      final connected = connection.connected;
      final closeNow = pending || !connected;
      connection.explicitDisconnect = true;
      if (closeNow) _connections.remove(address);
      await connection.ready.future;
      await connection.gatt?.disconnect();
      if (closeNow) await _closeConnection(connection);
      if (pending) {
        _emitConnectionState(connection, BmConnectionStateEnum.disconnected, bmUserCanceledErrorCode,
            reasonString: 'connection canceled');
      }
      return pending || connected;
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
