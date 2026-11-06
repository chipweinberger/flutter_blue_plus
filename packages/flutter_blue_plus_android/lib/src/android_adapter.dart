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
      _run('isSupported', () async => _capabilities.hasAdapter, allowUnavailable: true);

  @override
  Future<bool> setOptions(BmSetOptionsRequest request) =>
      _run('setOptions', () async => true, arguments: request.toMap());

  @override
  Future<bool> setLogLevel(BmSetLogLevelRequest request) {
    _logLevel = request.logLevel;
    _logColor = request.logColor;
    return _run('setLogLevel', () async => true, arguments: request.logLevel.index, allowUnavailable: true);
  }

  @override
  Future<bool> turnOn(BmTurnOnRequest request) => _run('turnOn', () async {
        final adapter = ab.BluetoothAdapter.shared;
        await _requirePermission('turnOn', _adapterPermissions, 'to turn Bluetooth on');
        if (await adapter.isEnabled) return false;
        await adapter.requestEnable(waitForResult: false);
        return true;
      });

  @override
  Future<bool> turnOff(BmTurnOffRequest request) => _run('turnOff', () async {
        final adapter = ab.BluetoothAdapter.shared;
        await _requirePermission('turnOff', _adapterPermissions, 'to turn Bluetooth off');
        if (!await adapter.isEnabled) return true;
        return adapter.disable();
      });

  @override
  Future<BmBluetoothAdapterName> getAdapterName(BmBluetoothAdapterNameRequest request) =>
      _run('getAdapterName', () async {
        final denied = await _permissions(_adapterPermissions);
        if (denied != null) return BmBluetoothAdapterName(adapterName: '');
        if (!_capabilities.hasAdapter) return BmBluetoothAdapterName(adapterName: 'N/A');
        return BmBluetoothAdapterName(adapterName: await ab.BluetoothAdapter.shared.name ?? '');
      }, allowUnavailable: true, logResult: (result) => result.adapterName);

  @override
  Future<BmBluetoothAdapterState> getAdapterState(BmBluetoothAdapterStateRequest request) =>
      _run('getAdapterState', () async => BmBluetoothAdapterState(adapterState: await _readAdapterState()),
          allowUnavailable: true, logResult: (result) => {'adapter_state': result.adapterState.index});

  @override
  Future<PhySupport> getPhySupport(PhySupportRequest request) => _run('getPhySupport', () async {
        _requirePhy('getPhySupport');
        final adapter = ab.BluetoothAdapter.shared;
        return PhySupport(le2M: await adapter.isLe2MPhySupported, leCoded: await adapter.isLeCodedPhySupported);
      }, logResult: (result) => {'le_2M': result.le2M, 'le_coded': result.leCoded});

  @override
  Future<BmDevicesList> getBondedDevices(BmBondedDevicesRequest request) => _run('getBondedDevices',
      () async => BmDevicesList(devices: (await ab.BluetoothAdapter.shared.bondedDevices).map(_deviceInfo).toList()),
      logResult: _devicesMap);

  @override
  Future<BmDevicesList> getSystemDevices(BmSystemDevicesRequest request) => _run('getSystemDevices', () async {
        await _requirePermission('getSystemDevices', _connectPermissions, 'to get system devices');
        return BmDevicesList(
            devices: (await ab.BluetoothManager.shared.getConnectedDevices()).map(_deviceInfo).toList());
      }, logResult: _devicesMap);

  @override
  Future<BmBondStateResponse> getBondState(BmBondStateRequest request) {
    final remoteId = request.remoteId;
    return _run('getBondState', () async {
      final state = await ab.BluetoothDevice(remoteId.str).getBondState();
      return BmBondStateResponse(remoteId: remoteId, bondState: _bondState(state), prevState: null);
    },
        arguments: remoteId.str,
        logResult: (result) => {
              'remote_id': result.remoteId.str,
              'bond_state': result.bondState.index,
              'prev_state': null,
            });
  }
}
