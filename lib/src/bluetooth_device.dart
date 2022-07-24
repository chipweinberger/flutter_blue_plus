// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDevice {
  final DeviceIdentifier id;
  final String name;
  final BluetoothDeviceType type;

  BluetoothDevice.fromProto(protos.BluetoothDevice p)
      : id = DeviceIdentifier(p.remoteId),
        name = p.name,
        type = BluetoothDeviceType.values[p.type.value];

  /// Use on Android when the MAC address is known.
  ///
  /// This constructor enables the Android to connect to a specific device
  /// as soon as it becomes available on the bluetooth "network".
  BluetoothDevice.fromId(String id, {String? name, BluetoothDeviceType? type})
      : id = DeviceIdentifier(id),
        name = name ?? "Unknown name",
        type = type ?? BluetoothDeviceType.unknown;

  final BehaviorSubject<bool> _isDiscoveringServices =
      BehaviorSubject.seeded(false);
  Stream<bool> get isDiscoveringServices => _isDiscoveringServices.stream;

  /// Establishes a connection to the Bluetooth Device.
  Future<void> connect({
    Duration? timeout,
    bool autoConnect = true,
  }) async {
    var request = protos.ConnectRequest.create()
      ..remoteId = id.toString()
      ..androidAutoConnect = autoConnect;

    await FlutterBluePlus.instance._channel
        .invokeMethod('connect', request.writeToBuffer());

    if (timeout == null) {
      await state.firstWhere((s) => s == BluetoothDeviceState.connected);
    } else {
      await state
          .firstWhere((s) => s == BluetoothDeviceState.connected)
          .timeout(
        timeout,
        onTimeout: () {
          disconnect();
          throw TimeoutException('Failed to connect in time.', timeout);
        },
      );
    }
  }

  /// Send a pairing request to the device.
  /// Currently only implemented on Android.
  Future<void> pair() async {
    if (Platform.isAndroid) {
      return FlutterBluePlus.instance._channel
          .invokeMethod('pair', id.toString());
    }
  }

  /// Cancels connection to the Bluetooth Device
  Future disconnect() => FlutterBluePlus.instance._channel
      .invokeMethod('disconnect', id.toString());

  final BehaviorSubject<List<BluetoothService>> _services =
      BehaviorSubject.seeded([]);

  /// Discovers services offered by the remote device as well as their characteristics and descriptors
  Future<List<BluetoothService>> discoverServices() async {
    final s = await state.first;
    if (s != BluetoothDeviceState.connected) {
      return Future.error(Exception(
          'Cannot discoverServices while device is not connected. State == $s'));
    }
    var response = FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "DiscoverServicesResult")
        .map((m) => m.arguments)
        .map((buffer) => protos.DiscoverServicesResult.fromBuffer(buffer))
        .where((p) => p.remoteId == id.toString())
        .map((p) => p.services)
        .map((s) => s.map((p) => BluetoothService.fromProto(p)).toList())
        .first
        .then((list) {
      _services.add(list);
      _isDiscoveringServices.add(false);
      return list;
    });

    await FlutterBluePlus.instance._channel
        .invokeMethod('discoverServices', id.toString());

    _isDiscoveringServices.add(true);

    return response;
  }

  /// Returns a list of Bluetooth GATT services offered by the remote device
  /// This function requires that discoverServices has been completed for this device
  Stream<List<BluetoothService>> get services async* {
    yield await FlutterBluePlus.instance._channel
        .invokeMethod('services', id.toString())
        .then((buffer) =>
            protos.DiscoverServicesResult.fromBuffer(buffer).services)
        .then((i) => i.map((s) => BluetoothService.fromProto(s)).toList());
    yield* _services.stream;
  }

  /// The current connection state of the device
  Stream<BluetoothDeviceState> get state async* {
    yield await FlutterBluePlus.instance._channel
        .invokeMethod('deviceState', id.toString())
        .then((buffer) => protos.DeviceStateResponse.fromBuffer(buffer))
        .then((p) => BluetoothDeviceState.values[p.state.value]);

    yield* FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "DeviceState")
        .map((m) => m.arguments)
        .map((buffer) => protos.DeviceStateResponse.fromBuffer(buffer))
        .where((p) => p.remoteId == id.toString())
        .map((p) => BluetoothDeviceState.values[p.state.value]);
  }

  /// The MTU size in bytes
  Stream<int> get mtu async* {
    yield await FlutterBluePlus.instance._channel
        .invokeMethod('mtu', id.toString())
        .then((buffer) => protos.MtuSizeResponse.fromBuffer(buffer))
        .then((p) => p.mtu);

    yield* FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "MtuSize")
        .map((m) => m.arguments)
        .map((buffer) => protos.MtuSizeResponse.fromBuffer(buffer))
        .where((p) => p.remoteId == id.toString())
        .map((p) => p.mtu);
  }

  /// Request to change the MTU Size
  /// Throws error if request did not complete successfully
  /// Request to change the MTU Size and returns the response back
  /// Throws error if request did not complete successfully
  Future<int> requestMtu(int desiredMtu) async {
    var request = protos.MtuSizeRequest.create()
      ..remoteId = id.toString()
      ..mtu = desiredMtu;

    var response = FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "MtuSize")
        .map((m) => m.arguments)
        .map((buffer) => protos.MtuSizeResponse.fromBuffer(buffer))
        .where((p) => p.remoteId == id.toString())
        .map((p) => p.mtu)
        .first;

    await FlutterBluePlus.instance._channel
        .invokeMethod('requestMtu', request.writeToBuffer());

    return response;
  }

  /// Indicates whether the Bluetooth Device can send a write without response
  Future<bool> get canSendWriteWithoutResponse =>
      Future.error(UnimplementedError());

  /// Read the RSSI for a connected remote device
  Future<int> readRssi() async {
    final remoteId = id.toString();
    await FlutterBluePlus.instance._channel.invokeMethod('readRssi', remoteId);

    return FlutterBluePlus.instance._methodStream
        .where((m) => m.method == "ReadRssiResult")
        .map((m) => m.arguments)
        .map((buffer) => protos.ReadRssiResult.fromBuffer(buffer))
        .where((p) => (p.remoteId == remoteId))
        .first
        .then((c) {
      return (c.rssi);
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BluetoothDevice{id: $id, name: $name, type: $type, isDiscoveringServices: ${_isDiscoveringServices.value}, _services: ${_services.value}';
  }
}

enum BluetoothDeviceType { unknown, classic, le, dual }

enum BluetoothDeviceState { disconnected, connecting, connected, disconnecting }
