part of '../flutter_blue_plus_linux.dart';

base mixin _DeviceOperations on _LinuxBackend {
  @override
  Future<BmDevicesList> getSystemDevices(
    BmSystemDevicesRequest request,
  ) async {
    await _initFlutterBluePlus();

    return BmDevicesList(
      devices: _client.devices.map(
        (device) {
          return BmBluetoothDevice(
            remoteId: device.remoteId,
            platformName: device.name,
          );
        },
      ).toList(),
    );
  }

  @override
  Future<BmDevicesList> getBondedDevices(
    BmBondedDevicesRequest request,
  ) async {
    await _initFlutterBluePlus();

    return BmDevicesList(
      devices: _client.devices.where(
        (device) {
          return device.paired;
        },
      ).map(
        (device) {
          return BmBluetoothDevice(
            remoteId: device.remoteId,
            platformName: device.name,
          );
        },
      ).toList(),
    );
  }

  @override
  Future<BmBondStateResponse> getBondState(
    BmBondStateRequest request,
  ) async {
    await _initFlutterBluePlus();

    final device = _client.devices.singleWhere(
      (device) {
        return device.remoteId == request.remoteId;
      },
    );

    return BmBondStateResponse(
      remoteId: device.remoteId,
      bondState: device.paired ? BmBondStateEnum.bonded : BmBondStateEnum.none,
      prevState: null,
    );
  }

  @override
  Future<bool> connect(
    BmConnectRequest request,
  ) async {
    await _initFlutterBluePlus();

    final device = _client.devices.singleWhere(
      (device) {
        return device.remoteId == request.remoteId;
      },
    );

    await device.connect();

    return true;
  }

  @override
  Future<bool> disconnect(
    BmDisconnectRequest request,
  ) async {
    await _initFlutterBluePlus();

    final device = _client.devices.singleWhere(
      (device) {
        return device.remoteId == request.remoteId;
      },
    );

    await device.disconnect();

    return true;
  }

  @override
  Future<bool> createBond(
    BmCreateBondRequest request,
  ) async {
    await _initFlutterBluePlus();

    final device = _client.devices.singleWhere(
      (device) {
        return device.remoteId == request.remoteId;
      },
    );

    await device.pair();

    return true;
  }

  @override
  Future<bool> discoverServices(BmDiscoverServicesRequest request) async {
    try {
      await _initFlutterBluePlus();
    } catch (e) {
      _discoveryFailed(request.remoteId, e);
      return false;
    }
    final state = _deviceStates[request.remoteId];
    if (state == null) {
      _discoveryFailed(request.remoteId, StateError('device is not available'));
      return false;
    }
    _publishServicesIfReady(state);
    return true;
  }

  @override
  Future<bool> readRssi(
    BmReadRssiRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      _onReadRssiController.add(
        BmReadRssiResult(
          remoteId: device.remoteId,
          rssi: device.rssi,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onReadRssiController.add(
        BmReadRssiResult(
          remoteId: request.remoteId,
          rssi: 0,
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }
}
