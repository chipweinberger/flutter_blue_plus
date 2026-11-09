part of '../flutter_blue_plus_darwin.dart';

base mixin _AdapterOperations on _DarwinBackend {
  @override
  Future<bool> setLogLevel(BmSetLogLevelRequest request) async {
    _checkNotDisposed();
    _logLevel = request.logLevel;
    return true;
  }

  @override
  Future<bool> setOptions(BmSetOptionsRequest request) async {
    _checkNotDisposed();
    _showPowerAlert = request.showPowerAlert ?? _showPowerAlert;
    _restoreState = request.restoreState ?? _restoreState;
    return true;
  }

  @override
  Future<bool> isSupported(BmIsSupportedRequest request) => _run(() async => true);

  @override
  Future<BmBluetoothAdapterName> getAdapterName(BmBluetoothAdapterNameRequest request) =>
      _run(() async => BmBluetoothAdapterName(adapterName: await cb.CBCentralManager.adapterName));

  @override
  Future<BmBluetoothAdapterState> getAdapterState(BmBluetoothAdapterStateRequest request) =>
      _run(() async => BmBluetoothAdapterState(adapterState: _adapterState(_manager.state)));

  @override
  Future<BmDevicesList> getSystemDevices(BmSystemDevicesRequest request) {
    final services = request.withServices.map((uuid) => cb.CBUUID(uuid.str)).toList();
    return _run(() async => BmDevicesList(devices: [
          for (final peripheral in await _manager.retrieveConnectedPeripherals(services))
            BmBluetoothDevice(remoteId: DeviceIdentifier(_remoteId(peripheral)), platformName: peripheral.name)
        ]));
  }
}
