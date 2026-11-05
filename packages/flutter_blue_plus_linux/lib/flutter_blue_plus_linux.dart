import 'dart:async';

import 'package:bluez/bluez.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'src/stream_utils.dart';

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
  StreamSubscription<_BlueZDevicePropertyChanges>? subscription;

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

  var _initialized = false;
  var _logLevel = LogLevel.none;

  final _onCharacteristicReadController = StreamController<BmCharacteristicData>.broadcast();
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
    return _client.adaptersChanged.where(
      (adapters) {
        return adapters.isNotEmpty;
      },
    ).switchMap(
      (adapters) {
        return adapters.first.propertiesChanged.where(
          (properties) {
            return properties.contains('Powered');
          },
        ).map(
          (properties) {
            return BmBluetoothAdapterState(
              adapterState: adapters.first.powered ? BmAdapterStateEnum.on : BmAdapterStateEnum.off,
            );
          },
        );
      },
    );
  }

  @override
  Stream<BmBondStateResponse> get onBondStateChanged {
    return _client.devicesChanged.switchMap(
      (devices) {
        return mergeStreams(
          devices.map(
            (device) {
              return device.propertiesChanged.where(
                (properties) {
                  return properties.contains('Paired');
                },
              ).map(
                (properties) {
                  return BmBondStateResponse(
                    remoteId: device.remoteId,
                    bondState: device.paired ? BmBondStateEnum.bonded : BmBondStateEnum.none,
                    prevState: null,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Stream<BmCharacteristicData> get onCharacteristicReceived {
    return _onCharacteristicReadController.stream.mergeWith([
      _client.devicesChanged.switchMap(
        (devices) {
          final streams = <Stream<BmCharacteristicData>>[];

          for (final device in devices) {
            for (final service in device.gattServices) {
              for (final characteristic in service.characteristics) {
                streams.add(
                  characteristic.propertiesChanged.where(
                    (properties) {
                      return properties.contains('Value');
                    },
                  ).map(
                    (properties) {
                      return BmCharacteristicData(
                        remoteId: device.remoteId,
                        primaryServiceUuid: null,
                        serviceUuid: Guid.fromBytes(
                          service.uuid.value,
                        ),
                        characteristicUuid: Guid.fromBytes(
                          characteristic.uuid.value,
                        ),
                        instanceId: _instanceId(device, service, characteristic),
                        value: characteristic.value,
                        success: true,
                        errorCode: 0,
                        errorString: '',
                      );
                    },
                  ),
                );
              }
            }
          }

          return mergeStreams(streams);
        },
      ),
    ]);
  }

  @override
  Stream<BmCharacteristicData> get onCharacteristicWritten {
    return _onCharacteristicWrittenController.stream;
  }

  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged {
    return _client.devicesChanged.switchMap(
      (devices) {
        return mergeStreams(
          devices.map(
            (device) {
              return device.propertiesChanged.where(
                (properties) {
                  return properties.contains('Connected');
                },
              ).map(
                (properties) {
                  return BmConnectionStateResponse(
                    remoteId: device.remoteId,
                    connectionState:
                        device.connected ? BmConnectionStateEnum.connected : BmConnectionStateEnum.disconnected,
                    disconnectReasonCode: null,
                    disconnectReasonString: null,
                  );
                },
              );
            },
          ),
        );
      },
    );
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
    return _client.devicesChanged.switchMap(
      (devices) {
        return mergeStreams(
          devices.map(
            (device) {
              return device.propertiesChanged.where(
                (properties) {
                  return properties.contains('Name');
                },
              ).map(
                (properties) {
                  return BmNameChanged(
                    remoteId: device.remoteId,
                    name: device.name,
                  );
                },
              );
            },
          ),
        );
      },
    );
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
    return _client.devicesChanged.switchMap(
      (devices) {
        return mergeStreams(
          devices.map(
            (device) {
              return device.propertiesChanged.where(
                (properties) {
                  return properties.contains('UUIDs');
                },
              ).map(
                (properties) {
                  return BmBluetoothDevice(
                    remoteId: device.remoteId,
                    platformName: device.name,
                  );
                },
              );
            },
          ),
        );
      },
    );
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
  void _onBlueZError(Object error) {
    _log('BlueZ stream error: $error');
  }

  void _onBlueZDevicePropertiesChanged(_LinuxDeviceState state, _BlueZDevicePropertyChanges changed) {
    if (_logLevel == LogLevel.verbose) {
      _log('device ${state.remoteId} properties changed $changed');
    }
    if (changed.contains(_BlueZDeviceProperty.servicesResolved)) _publishServicesIfReady(state);
  }

  Future<void> _onBlueZDeviceRemoved(BlueZDevice device, [Object? error]) async {
    final state = _deviceStates[device.remoteId];
    if (state == null || !state.matches(device)) return;
    _deviceStates.remove(state.remoteId);
    _discoveryFailed(state.remoteId, error ?? StateError('device removed'));
    await state.subscription?.cancel();
  }

  void _onBlueZDeviceAdded(BlueZDevice device) {
    final previous = _deviceStates[device.remoteId];
    if (previous != null && previous.matches(device)) return;
    if (previous != null) {
      unawaited(_onBlueZDeviceRemoved(previous.device, StateError('device replaced')));
    }
    final state = _LinuxDeviceState(device);
    _deviceStates[state.remoteId] = state;
    state.subscription = state.propertyChanges.listen(
      (changed) => _onBlueZDevicePropertiesChanged(state, changed),
      onError: _onBlueZError,
    );
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

      _onCharacteristicReadController.add(
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
      _onCharacteristicReadController.add(
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

    _client.deviceAdded.listen(_onBlueZDeviceAdded, onError: _onBlueZError);
    _client.deviceRemoved.listen(_onBlueZDeviceRemoved, onError: _onBlueZError);
    for (final device in _client.devices) {
      _onBlueZDeviceAdded(device);
    }

    _client.devicesChanged.switchMap(
      (devices) {
        if (_logLevel == LogLevel.verbose) {
          _log('devices changed ${devices.map((device) => device.remoteId).toList()}');
        }

        return mergeStreams(
          devices.map(
            (device) {
              return device.propertiesChanged.switchMap(
                (_) {
                  final streams = <Stream<void>>[];

                  for (final service in device.gattServices) {
                    for (final characteristic in service.characteristics) {
                      streams.add(
                        characteristic.propertiesChanged.map(
                          (properties) {
                            if (_logLevel == LogLevel.verbose) {
                              _log(
                                'device ${device.remoteId} service ${service.uuid} characteristic ${characteristic.uuid} properties changed $properties',
                              );
                            }
                          },
                        ),
                      );
                    }
                  }

                  return mergeStreams(streams);
                },
              );
            },
          ),
        );
      },
    ).listen(null);
  }
}

extension on BlueZClient {
  Stream<List<BlueZAdapter>> get adaptersChanged {
    return mergeStreams([
      adapterAdded,
      adapterRemoved,
    ]).map(
      (adapter) {
        return adapters;
      },
    ).startWith(adapters);
  }

  Stream<List<BlueZDevice>> get devicesChanged {
    return mergeStreams([
      deviceAdded,
      deviceRemoved,
    ]).map(
      (device) {
        return devices;
      },
    ).startWith(devices);
  }
}
