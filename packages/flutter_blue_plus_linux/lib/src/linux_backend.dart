part of '../flutter_blue_plus_linux.dart';

abstract base class _LinuxBackend extends FlutterBluePlusPlatform {
  final _client = BlueZClient();
  final _deviceStates = <DeviceIdentifier, _BlueZDeviceState>{};

  BlueZAdapter? _adapter;
  StreamSubscription<List<String>>? _adapterSubscription;

  var _initialized = false;
  var _logLevel = LogLevel.none;

  final _onAdapterStateChangedController = StreamController<BmBluetoothAdapterState>.broadcast();
  final _onBondStateChangedController = StreamController<BmBondStateResponse>.broadcast();
  final _onConnectionStateChangedController = StreamController<BmConnectionStateResponse>.broadcast();
  final _onNameChangedController = StreamController<BmNameChanged>.broadcast();
  final _onServicesResetController = StreamController<BmBluetoothDevice>.broadcast();
  final _onCharacteristicReceivedController = StreamController<BmCharacteristicData>.broadcast();
  final _onCharacteristicWrittenController = StreamController<BmCharacteristicData>.broadcast();
  final _onDescriptorReadController = StreamController<BmDescriptorData>.broadcast();
  final _onDescriptorWrittenController = StreamController<BmDescriptorData>.broadcast();
  final _onDiscoveredServicesController = StreamController<BmDiscoverServicesResult>.broadcast();
  final _onReadRssiController = StreamController<BmReadRssiResult>.broadcast();
  final _onTurnOnResponseController = StreamController<BmTurnOnResponse>.broadcast();

  // Initialization and event handling.

  void _log(String message) {
    FlutterBluePlusPlatform.log('[FBP-Linux] $message');
  }

  // BlueZ currently does not emit errors on these streams.
  // This handler is added as a precaution.
  void _onStreamError(Object error) {
    _log('BlueZ stream error: $error');
  }

  void _discoveryFailed(DeviceIdentifier remoteId, Object error) {
    _onDiscoveredServicesController.add(BmDiscoverServicesResult(
      remoteId: remoteId,
      services: [],
      success: false,
      errorCode: 0,
      errorString: error.toString(),
    ));
  }

  void _onAdapterPropertiesChanged(BlueZAdapter adapter, List<String> changed) {
    if (changed.contains('Powered')) {
      _onAdapterStateChangedController.add(BmBluetoothAdapterState(
        adapterState: adapter.powered ? BmAdapterStateEnum.on : BmAdapterStateEnum.off,
      ));
    }
  }

  void _onAdaptersChanged([BlueZAdapter? _]) {
    final adapter = _client.adapters.firstOrNull;
    if (adapter?.propertiesChanged == _adapter?.propertiesChanged) return;
    unawaited(_adapterSubscription?.cancel());
    _adapter = adapter;
    _adapterSubscription = adapter?.propertiesChanged.listen(
      (changed) => _onAdapterPropertiesChanged(adapter, changed),
      onError: _onStreamError,
    );
  }

  void _onCharacteristicPropertiesChanged(
    _BlueZDeviceState state,
    BlueZGattService service,
    BlueZGattCharacteristic characteristic,
    List<String> changed,
  ) {
    if (_logLevel == LogLevel.verbose) {
      _log(
        'device ${state.remoteId} service ${service.uuid} '
        'characteristic ${characteristic.uuid} properties changed $changed',
      );
    }
    if (changed.contains('Value')) {
      _onCharacteristicReceivedController.add(BmCharacteristicData(
        remoteId: state.remoteId,
        primaryServiceUuid: null,
        serviceUuid: service.guid,
        characteristicUuid: Guid.fromBytes(characteristic.uuid.value),
        instanceId: _instanceId(state.device, service, characteristic),
        value: characteristic.value,
        success: true,
        errorCode: 0,
        errorString: '',
      ));
    }
  }

  void _listenToCharacteristics(_BlueZDeviceState state) {
    for (final subscription in state.characteristicSubscriptions) {
      unawaited(subscription.cancel());
    }
    state.characteristicSubscriptions.clear();
    if (!state.device.connected || !state.device.servicesResolved) return;

    for (final service in state.device.gattServices) {
      for (final characteristic in service.characteristics) {
        state.characteristicSubscriptions.add(characteristic.propertiesChanged.listen(
          (changed) => _onCharacteristicPropertiesChanged(state, service, characteristic, changed),
          onError: _onStreamError,
        ));
      }
    }
  }

  void _publishServicesIfReady(_BlueZDeviceState state) {
    final device = state.device;
    if (!device.connected) {
      _discoveryFailed(state.remoteId, StateError('device disconnected'));
      return;
    }
    if (!_client.devices.any(state.matches)) {
      _discoveryFailed(state.remoteId, StateError('device removed or replaced'));
      return;
    }
    if (!device.servicesResolved) return;

    try {
      _onDiscoveredServicesController.add(_discoveryResult(device));
    } catch (e) {
      _discoveryFailed(state.remoteId, e);
    }
  }

  void _onDevicePropertiesChanged(_BlueZDeviceState state, _BlueZDevicePropertyChanges changed) {
    final device = state.device;
    if (_logLevel == LogLevel.verbose) {
      _log('device ${state.remoteId} properties changed $changed');
    }
    if (changed.contains(_BlueZDeviceProperty.connected)) {
      _onConnectionStateChangedController.add(BmConnectionStateResponse(
        remoteId: state.remoteId,
        connectionState: device.connected ? BmConnectionStateEnum.connected : BmConnectionStateEnum.disconnected,
        disconnectReasonCode: null,
        disconnectReasonString: null,
      ));
    }
    if (changed.contains(_BlueZDeviceProperty.paired)) {
      _onBondStateChangedController.add(BmBondStateResponse(
        remoteId: state.remoteId,
        bondState: device.paired ? BmBondStateEnum.bonded : BmBondStateEnum.none,
        prevState: null,
      ));
    }
    if (changed.contains(_BlueZDeviceProperty.name)) {
      _onNameChangedController.add(BmNameChanged(remoteId: state.remoteId, name: device.name));
    }
    if (changed.contains(_BlueZDeviceProperty.uuids)) {
      _onServicesResetController.add(BmBluetoothDevice(remoteId: state.remoteId, platformName: device.name));
    }
    if (changed.contains(_BlueZDeviceProperty.connected) ||
        changed.contains(_BlueZDeviceProperty.servicesResolved) ||
        changed.contains(_BlueZDeviceProperty.uuids)) {
      _listenToCharacteristics(state);
    }
    if (changed.contains(_BlueZDeviceProperty.servicesResolved)) _publishServicesIfReady(state);
  }

  Future<void> _onDeviceRemoved(BlueZDevice device, [Object? error]) async {
    final state = _deviceStates[device.remoteId];
    if (state == null || !state.matches(device)) return;
    _deviceStates.remove(state.remoteId);
    if (_logLevel == LogLevel.verbose) _log('device ${state.remoteId} removed');
    _discoveryFailed(state.remoteId, error ?? StateError('device removed'));
    await Future.wait([
      state.subscription.cancel(),
      ...state.characteristicSubscriptions.map((subscription) => subscription.cancel()),
    ]);
  }

  void _onDeviceAdded(BlueZDevice device) {
    final previous = _deviceStates[device.remoteId];
    if (previous != null && previous.matches(device)) return;
    if (previous != null) {
      unawaited(_onDeviceRemoved(previous.device, StateError('device replaced')));
    }
    final state = _BlueZDeviceState(device);
    _deviceStates[state.remoteId] = state;
    if (_logLevel == LogLevel.verbose) _log('device ${state.remoteId} added');
    state.subscription = state.propertyChanges.listen(
      (changed) => _onDevicePropertiesChanged(state, changed),
      onError: _onStreamError,
    );
    _listenToCharacteristics(state);
  }

  Future<void> _initFlutterBluePlus() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    await _client.connect();

    _client.deviceAdded.listen(_onDeviceAdded, onError: _onStreamError);
    _client.deviceRemoved.listen(_onDeviceRemoved, onError: _onStreamError);
    for (final device in _client.devices) {
      _onDeviceAdded(device);
    }

    _client.adapterAdded.listen(_onAdaptersChanged, onError: _onStreamError);
    _client.adapterRemoved.listen(_onAdaptersChanged, onError: _onStreamError);
    _onAdaptersChanged();
  }

  // Platform event streams.

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged {
    return _onAdapterStateChangedController.stream;
  }

  @override
  Stream<BmBondStateResponse> get onBondStateChanged {
    return _onBondStateChangedController.stream;
  }

  @override
  Stream<BmCharacteristicData> get onCharacteristicReceived {
    return _onCharacteristicReceivedController.stream;
  }

  @override
  Stream<BmCharacteristicData> get onCharacteristicWritten {
    return _onCharacteristicWrittenController.stream;
  }

  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged {
    return _onConnectionStateChangedController.stream;
  }

  @override
  Stream<BmDescriptorData> get onDescriptorRead {
    return _onDescriptorReadController.stream;
  }

  @override
  Stream<BmDescriptorData> get onDescriptorWritten {
    return _onDescriptorWrittenController.stream;
  }

  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices {
    return _onDiscoveredServicesController.stream;
  }

  @override
  Stream<BmMtuChangedResponse> get onMtuChanged {
    return Stream.empty();
  }

  @override
  Stream<BmNameChanged> get onNameChanged {
    return _onNameChangedController.stream;
  }

  @override
  Stream<BmReadRssiResult> get onReadRssi {
    return _onReadRssiController.stream;
  }

  @override
  Stream<BmBluetoothDevice> get onServicesReset {
    return _onServicesResetController.stream;
  }

  @override
  Stream<BmTurnOnResponse> get onTurnOnResponse {
    return _onTurnOnResponseController.stream;
  }

  @override
  Stream<BmScanResponse> get onScanResponse {
    return _client.deviceAdded.map(
      (device) {
        return BmScanResponse(
          advertisements: [
            BmScanAdvertisement(
              remoteId: device.remoteId,
              platformName: device.name,
              advName: null,
              connectable: true,
              txPowerLevel: device.txPower,
              appearance: device.appearance,
              manufacturerData: device.manufacturerData.map(
                (id, value) {
                  return MapEntry(id.id, value);
                },
              ),
              serviceData: device.serviceData.map(
                (uuid, value) {
                  return MapEntry(Guid.fromBytes(uuid.value), value);
                },
              ),
              serviceUuids: device.uuids.map(
                (uuid) {
                  return Guid.fromBytes(uuid.value);
                },
              ).toList(),
              rssi: device.rssi,
            ),
          ],
          success: true,
          errorCode: 0,
          errorString: '',
        );
      },
    );
  }

  @override
  Future<bool> setLogLevel(
    BmSetLogLevelRequest request,
  ) async {
    await _initFlutterBluePlus();

    _logLevel = request.logLevel;

    return true;
  }
}
