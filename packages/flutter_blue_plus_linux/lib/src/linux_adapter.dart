part of '../flutter_blue_plus_linux.dart';

base mixin _AdapterOperations on _LinuxBackend {
  @override
  Future<bool> isSupported(
    BmIsSupportedRequest request,
  ) async {
    await _initFlutterBluePlus();

    return _client.adapters.isNotEmpty;
  }

  @override
  Future<BmBluetoothAdapterName> getAdapterName(
    BmBluetoothAdapterNameRequest request,
  ) async {
    await _initFlutterBluePlus();

    return BmBluetoothAdapterName(
      adapterName: _client.adapters.firstOrNull?.name ?? '',
    );
  }

  @override
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) async {
    await _initFlutterBluePlus();

    return BmBluetoothAdapterState(
      adapterState: switch (_client.adapters.firstOrNull?.powered) {
        true => BmAdapterStateEnum.on,
        false => BmAdapterStateEnum.off,
        _ => BmAdapterStateEnum.unknown,
      },
    );
  }

  @override
  Future<bool> turnOn(
    BmTurnOnRequest request,
  ) async {
    await _initFlutterBluePlus();

    final adapter = _client.adapters.firstOrNull;

    if (adapter == null || adapter.powered == true) {
      return false;
    }

    await adapter.setPowered(true);

    _onTurnOnResponseController.add(
      BmTurnOnResponse(
        userAccepted: true,
      ),
    );

    return true;
  }

  @override
  Future<bool> turnOff(
    BmTurnOffRequest request,
  ) async {
    await _initFlutterBluePlus();

    final adapter = _client.adapters.firstOrNull;

    if (adapter == null || adapter.powered == false) {
      return false;
    }

    await adapter.setPowered(false);

    return true;
  }

  @override
  Future<bool> startScan(
    BmScanSettings request,
  ) async {
    await _initFlutterBluePlus();

    final adapter = _client.adapters.firstOrNull;

    if (adapter == null) {
      return false;
    }

    await adapter.setDiscoveryFilter(
      uuids: request.withServices.map(
        (uuid) {
          return uuid.str128;
        },
      ).toList(),
    );

    await adapter.startDiscovery();

    return true;
  }

  @override
  Future<bool> stopScan(
    BmStopScanRequest request,
  ) async {
    await _initFlutterBluePlus();

    final adapter = _client.adapters.firstOrNull;

    if (adapter == null) {
      return false;
    }

    await adapter.stopDiscovery();

    return true;
  }
}
