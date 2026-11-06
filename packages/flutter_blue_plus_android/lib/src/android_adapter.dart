part of '../flutter_blue_plus_android.dart';

base mixin _AdapterOperations on _AndroidBackend {
  List<String> get _adapterPermissions => _capabilities.apiLevel >= 31 ? [_bluetoothConnect] : [_bluetooth];

  Future<BmAdapterStateEnum> _readAdapterState() async {
    try {
      final state = await ab.BluetoothAdapter.shared.state;
      return _adapterState(state);
    } on PlatformException {
      return BmAdapterStateEnum.unknown;
    }
  }

  @override
  Future<bool> _isAdapterOn() async => await _readAdapterState() == BmAdapterStateEnum.on;

  @override
  Future<bool> isSupported(BmIsSupportedRequest request) =>
      _run(() async => _capabilities.hasAdapter, allowUnavailable: true);

  @override
  Future<bool> setOptions(BmSetOptionsRequest request) => _run(() async => true);

  @override
  Future<bool> setLogLevel(BmSetLogLevelRequest request) {
    _logLevel = request.logLevel;
    return _run(() async => true, allowUnavailable: true);
  }

  @override
  Future<bool> turnOn(BmTurnOnRequest request) => _run(() async {
        final adapter = ab.BluetoothAdapter.shared;
        await _requirePermission('turnOn', _adapterPermissions, 'to turn Bluetooth on');
        if (await adapter.isEnabled) return false;
        await adapter.requestEnable(waitForResult: false);
        return true;
      });

  @override
  Future<bool> turnOff(BmTurnOffRequest request) => _run(() async {
        final adapter = ab.BluetoothAdapter.shared;
        await _requirePermission('turnOff', _adapterPermissions, 'to turn Bluetooth off');
        if (!await adapter.isEnabled) return true;
        return adapter.disable();
      });

  @override
  Future<BmBluetoothAdapterName> getAdapterName(BmBluetoothAdapterNameRequest request) => _run(() async {
        final denied = await _permissions(_adapterPermissions);
        if (denied != null) return BmBluetoothAdapterName(adapterName: '');
        if (!_capabilities.hasAdapter) return BmBluetoothAdapterName(adapterName: 'N/A');
        return BmBluetoothAdapterName(adapterName: await ab.BluetoothAdapter.shared.name ?? '');
      }, allowUnavailable: true);

  @override
  Future<BmBluetoothAdapterState> getAdapterState(BmBluetoothAdapterStateRequest request) =>
      _run(() async => BmBluetoothAdapterState(adapterState: await _readAdapterState()), allowUnavailable: true);

  @override
  Future<PhySupport> getPhySupport(PhySupportRequest request) => _run(() async {
        _requirePhy('getPhySupport');
        final adapter = ab.BluetoothAdapter.shared;
        return PhySupport(le2M: await adapter.isLe2MPhySupported, leCoded: await adapter.isLeCodedPhySupported);
      });

  @override
  Future<BmDevicesList> getBondedDevices(BmBondedDevicesRequest request) => _run(
      () async => BmDevicesList(devices: (await ab.BluetoothAdapter.shared.bondedDevices).map(_deviceInfo).toList()));

  @override
  Future<BmDevicesList> getSystemDevices(BmSystemDevicesRequest request) => _run(() async {
        await _requirePermission('getSystemDevices', _connectPermissions, 'to get system devices');
        return BmDevicesList(
            devices: (await ab.BluetoothManager.shared.getConnectedDevices()).map(_deviceInfo).toList());
      });

  @override
  Future<BmBondStateResponse> getBondState(BmBondStateRequest request) {
    final remoteId = request.remoteId;
    return _run(() async {
      final state = await ab.BluetoothDevice(remoteId.str).getBondState();
      return BmBondStateResponse(remoteId: remoteId, bondState: _bondState(state), prevState: null);
    });
  }
}
