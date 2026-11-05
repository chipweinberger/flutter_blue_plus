import 'dart:async';

import 'package:bluez/bluez.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';

extension on BlueZDevice {
  DeviceIdentifier get remoteId {
    return DeviceIdentifier(address);
  }
}

extension on BlueZGattCharacteristic {
  int localInstanceId(BlueZGattService service) {
    final target = Guid.fromBytes(uuid.value);
    var idx = 0;
    for (final c in service.characteristics) {
      if (Guid.fromBytes(c.uuid.value) == target) {
        // BlueZ recreates wrappers; streams for the same cached object compare equal.
        if (c.propertiesChanged == propertiesChanged) return idx;
        idx++;
      }
    }
    return 0;
  }
}

extension on BlueZGattService {
  Guid get guid {
    return Guid.fromBytes(uuid.value);
  }
}

final class _LinuxFoundCharacteristic {
  final BlueZGattService service;
  final BlueZGattCharacteristic characteristic;

  const _LinuxFoundCharacteristic({
    required this.service,
    required this.characteristic,
  });
}

// https://github.com/bluez/bluez/blob/master/doc/org.bluez.Device.rst#properties
enum _BlueZDeviceProperty {
  adapter('Adapter'),
  address('Address'),
  addressType('AddressType'),
  advertisingData('AdvertisingData'),
  advertisingFlags('AdvertisingFlags'),
  alias('Alias'),
  appearance('Appearance'),
  blocked('Blocked'),
  bonded('Bonded'),
  cablePairing('CablePairing'),
  connectable('Connectable'),
  connected('Connected'),
  deviceClass('Class'),
  encryptionType('EncryptionType'),
  icon('Icon'),
  legacyPairing('LegacyPairing'),
  manufacturerData('ManufacturerData'),
  modalias('Modalias'),
  name('Name'),
  paired('Paired'),
  preferredBearer('PreferredBearer'),
  rssi('RSSI'),
  securityLevel('SecurityLevel'),
  serviceData('ServiceData'),
  servicesResolved('ServicesResolved'),
  sets('Sets'),
  trusted('Trusted'),
  txPower('TxPower'),
  uuids('UUIDs'),
  wakeAllowed('WakeAllowed');

  final String dbusName;
  const _BlueZDeviceProperty(this.dbusName);
}

final class _BlueZDevicePropertyChanges {
  final List<String> _names;
  final Set<_BlueZDeviceProperty> _properties;

  _BlueZDevicePropertyChanges(this._names)
      : _properties = _BlueZDeviceProperty.values.where((property) => _names.contains(property.dbusName)).toSet();

  bool contains(_BlueZDeviceProperty property) => _properties.contains(property);

  @override
  String toString() => _names.toString();
}

final class _LinuxDeviceState {
  final BlueZDevice device;
  final DeviceIdentifier remoteId;
  final Stream<_BlueZDevicePropertyChanges> propertyChanges;
  final characteristicSubscriptions = <StreamSubscription<List<String>>>[];
  late final StreamSubscription<_BlueZDevicePropertyChanges> subscription;

  _LinuxDeviceState(this.device)
      : remoteId = device.remoteId,
        propertyChanges = device.propertiesChanged.map(_BlueZDevicePropertyChanges.new);

  // BlueZ recreates device wrappers.
  // Their property-change streams compare equal for the same cached object.
  bool matches(BlueZDevice other) => device.propertiesChanged == other.propertiesChanged;
}

final class FlutterBluePlusLinux extends FlutterBluePlusPlatform {
  final _client = BlueZClient();
  final _deviceStates = <DeviceIdentifier, _LinuxDeviceState>{};

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

  void _log(String message) {
    FlutterBluePlusPlatform.log('[FBP-Linux] $message');
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

  List<BlueZGattService> _matchingServices(BlueZDevice device, Guid serviceUuid) {
    return device.gattServices.where((service) => service.guid == serviceUuid).toList();
  }

  int _instanceId(BlueZDevice device, BlueZGattService service, BlueZGattCharacteristic target) {
    final services = _matchingServices(device, service.guid);
    if (services.length <= 1) {
      return target.localInstanceId(service);
    }

    var idx = 0;
    for (final candidateService in services) {
      for (final characteristic in candidateService.characteristics) {
        if (characteristic.propertiesChanged == target.propertiesChanged) {
          return idx;
        }
        idx++;
      }
    }

    return 0;
  }

  _LinuxFoundCharacteristic _findCharacteristic(
    BlueZDevice device,
    Guid serviceUuid,
    Guid characteristicUuid,
    int instanceId,
  ) {
    final services = _matchingServices(device, serviceUuid);
    if (services.isEmpty) {
      throw StateError('service not found: $serviceUuid');
    }

    if (services.length <= 1) {
      final service = services.single;
      final characteristic = service.characteristics.singleWhere((characteristic) {
        final uuid = Guid.fromBytes(characteristic.uuid.value);
        return uuid == characteristicUuid && characteristic.localInstanceId(service) == instanceId;
      });
      return _LinuxFoundCharacteristic(service: service, characteristic: characteristic);
    }

    var idx = 0;
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        final uuid = Guid.fromBytes(characteristic.uuid.value);
        if (idx == instanceId && uuid == characteristicUuid) {
          return _LinuxFoundCharacteristic(service: service, characteristic: characteristic);
        }
        idx++;
      }
    }

    throw StateError('characteristic not found: $characteristicUuid/$instanceId');
  }

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
  Stream<BmBluetoothDevice> get onServicesReset {
    return _onServicesResetController.stream;
  }

  @override
  Stream<BmTurnOnResponse> get onTurnOnResponse {
    return _onTurnOnResponseController.stream;
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

  // BlueZ currently does not emit errors on these streams.
  // This handler is added as a precaution.
  void _onStreamError(Object error) {
    _log('BlueZ stream error: $error');
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
    _LinuxDeviceState state,
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

  void _listenToCharacteristics(_LinuxDeviceState state) {
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

  void _onDevicePropertiesChanged(_LinuxDeviceState state, _BlueZDevicePropertyChanges changed) {
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
    final state = _LinuxDeviceState(device);
    _deviceStates[state.remoteId] = state;
    if (_logLevel == LogLevel.verbose) _log('device ${state.remoteId} added');
    state.subscription = state.propertyChanges.listen(
      (changed) => _onDevicePropertiesChanged(state, changed),
      onError: _onStreamError,
    );
    _listenToCharacteristics(state);
  }

  BmDiscoverServicesResult _discoveryResult(BlueZDevice device) {
    return BmDiscoverServicesResult(
      remoteId: device.remoteId,
      services: device.gattServices.map(
        (service) {
          return BmBluetoothService(
            primaryServiceUuid: null,
            serviceUuid: Guid.fromBytes(service.uuid.value),
            remoteId: device.remoteId,
            characteristics: service.characteristics.map(
              (characteristic) {
                return BmBluetoothCharacteristic(
                  remoteId: device.remoteId,
                  primaryServiceUuid: null,
                  serviceUuid: Guid.fromBytes(service.uuid.value),
                  characteristicUuid: Guid.fromBytes(characteristic.uuid.value),
                  instanceId: _instanceId(device, service, characteristic),
                  descriptors: characteristic.descriptors.map(
                    (descriptor) {
                      return BmBluetoothDescriptor(
                        remoteId: device.remoteId,
                        primaryServiceUuid: null,
                        serviceUuid: Guid.fromBytes(service.uuid.value),
                        characteristicUuid: Guid.fromBytes(characteristic.uuid.value),
                        instanceId: _instanceId(device, service, characteristic),
                        descriptorUuid: Guid.fromBytes(descriptor.uuid.value),
                      );
                    },
                  ).toList(),
                  properties: BmCharacteristicProperties(
                    broadcast: characteristic.flags.contains(BlueZGattCharacteristicFlag.broadcast),
                    read: characteristic.flags.contains(BlueZGattCharacteristicFlag.read),
                    writeWithoutResponse:
                        characteristic.flags.contains(BlueZGattCharacteristicFlag.writeWithoutResponse),
                    write: characteristic.flags.contains(BlueZGattCharacteristicFlag.write),
                    notify: characteristic.flags.contains(BlueZGattCharacteristicFlag.notify),
                    indicate: characteristic.flags.contains(BlueZGattCharacteristicFlag.indicate),
                    authenticatedSignedWrites:
                        characteristic.flags.contains(BlueZGattCharacteristicFlag.authenticatedSignedWrites),
                    extendedProperties: characteristic.flags.contains(BlueZGattCharacteristicFlag.extendedProperties),
                    notifyEncryptionRequired: false,
                    indicateEncryptionRequired: false,
                  ),
                );
              },
            ).toList(),
          );
        },
      ).toList(),
      success: true,
      errorCode: 0,
      errorString: '',
    );
  }

  void _publishServicesIfReady(_LinuxDeviceState state) {
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
  Future<bool> isSupported(
    BmIsSupportedRequest request,
  ) async {
    await _initFlutterBluePlus();

    return _client.adapters.isNotEmpty;
  }

  @override
  Future<bool> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final found = _findCharacteristic(
        device,
        request.serviceUuid,
        request.characteristicUuid,
        request.instanceId,
      );
      final service = found.service;
      final characteristic = found.characteristic;

      final value = await characteristic.readValue();

      _onCharacteristicReceivedController.add(
        BmCharacteristicData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          instanceId: _instanceId(device, service, characteristic),
          value: value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onCharacteristicReceivedController.add(
        BmCharacteristicData(
          remoteId: request.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          value: [],
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }

  @override
  Future<bool> readDescriptor(
    BmReadDescriptorRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final found = _findCharacteristic(
        device,
        request.serviceUuid,
        request.characteristicUuid,
        request.instanceId,
      );
      final service = found.service;
      final characteristic = found.characteristic;

      final descriptor = characteristic.descriptors.singleWhere(
        (descriptor) {
          final uuid = Guid.fromBytes(
            descriptor.uuid.value,
          );

          return uuid == request.descriptorUuid;
        },
      );

      final value = await descriptor.readValue();

      _onDescriptorReadController.add(
        BmDescriptorData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          instanceId: _instanceId(device, service, characteristic),
          descriptorUuid: Guid.fromBytes(
            descriptor.uuid.value,
          ),
          value: value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onDescriptorReadController.add(
        BmDescriptorData(
          remoteId: request.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          descriptorUuid: request.descriptorUuid,
          value: [],
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
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

  @override
  Future<bool> setLogLevel(
    BmSetLogLevelRequest request,
  ) async {
    await _initFlutterBluePlus();

    _logLevel = request.logLevel;

    return true;
  }

  @override
  Future<bool> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) async {
    await _initFlutterBluePlus();

    final device = _client.devices.singleWhere(
      (device) {
        return device.remoteId == request.remoteId;
      },
    );

    final found = _findCharacteristic(
      device,
      request.serviceUuid,
      request.characteristicUuid,
      request.instanceId,
    );
    final characteristic = found.characteristic;

    if (request.enable) {
      await characteristic.startNotify();
    } else {
      await characteristic.stopNotify();
    }

    // No CCCD write on Linux; no separate response event expected
    return false;
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
  Future<bool> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final found = _findCharacteristic(
        device,
        request.serviceUuid,
        request.characteristicUuid,
        request.instanceId,
      );
      final service = found.service;
      final characteristic = found.characteristic;

      await characteristic.writeValue(
        request.value,
        type: request.writeType == BmWriteType.withResponse
            ? BlueZGattCharacteristicWriteType.request
            : BlueZGattCharacteristicWriteType.command,
      );

      _onCharacteristicWrittenController.add(
        BmCharacteristicData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          instanceId: _instanceId(device, service, characteristic),
          value: request.value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onCharacteristicWrittenController.add(
        BmCharacteristicData(
          remoteId: request.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          value: request.value,
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }

  @override
  Future<bool> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final found = _findCharacteristic(
        device,
        request.serviceUuid,
        request.characteristicUuid,
        request.instanceId,
      );
      final service = found.service;
      final characteristic = found.characteristic;

      final descriptor = characteristic.descriptors.singleWhere(
        (descriptor) {
          final uuid = Guid.fromBytes(
            descriptor.uuid.value,
          );

          return uuid == request.descriptorUuid;
        },
      );

      await descriptor.writeValue(request.value);

      _onDescriptorWrittenController.add(
        BmDescriptorData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          instanceId: _instanceId(device, service, characteristic),
          descriptorUuid: Guid.fromBytes(
            descriptor.uuid.value,
          ),
          value: request.value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onDescriptorWrittenController.add(
        BmDescriptorData(
          remoteId: request.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          descriptorUuid: request.descriptorUuid,
          value: request.value,
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }

  static void registerWith() {
    FlutterBluePlusPlatform.instance = FlutterBluePlusLinux();
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
}
