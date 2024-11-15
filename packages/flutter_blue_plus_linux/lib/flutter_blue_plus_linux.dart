import 'dart:async';

import 'package:bluez/bluez.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:rxdart/rxdart.dart';

class FlutterBluePlusLinux extends FlutterBluePlusPlatform {
  final _client = BlueZClient();

  var _initialized = false;
  var _logLevel = LogLevel.none;

  final _onCharacteristicReadController = StreamController<BmCharacteristicData>.broadcast();
  final _onCharacteristicWrittenController = StreamController<BmCharacteristicData>.broadcast();
  final _onDescriptorReadController = StreamController<BmDescriptorData>.broadcast();
  final _onDescriptorWrittenController = StreamController<BmDescriptorData>.broadcast();
  final _onDiscoveredServicesController = StreamController<BmDiscoverServicesResult>.broadcast();
  final _onReadRssiController = StreamController<BmReadRssiResult>.broadcast();

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged {
    return _client.adaptersChanged.where(
      (adapters) {
        return adapters.length > 0;
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
              adapterState: adapters.first.powered
                  ? BmAdapterStateEnum.on
                  : BmAdapterStateEnum.off,
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
        return MergeStream(
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
                    bondState: device.paired
                        ? BmBondStateEnum.bonded
                        : BmBondStateEnum.none,
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
                        serviceUuid: Guid.fromBytes(
                          service.uuid.value,
                        ),
                        secondaryServiceUuid: null,
                        characteristicUuid: Guid.fromBytes(
                          characteristic.uuid.value,
                        ),
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

          return MergeStream(streams);
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
        return MergeStream(
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
                    connectionState: device.connected
                        ? BmConnectionStateEnum.connected
                        : BmConnectionStateEnum.disconnected,
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
        return MergeStream(
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
        return MergeStream(
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
  Future<void> connect(
    BmConnectRequest request,
  ) async {
    await _initFlutterBluePlus();

    final device = _client.devices.singleWhere(
      (device) {
        return device.remoteId == request.remoteId;
      },
    );

    await device.connect();
  }

  @override
  Future<void> createBond(
    BmCreateBondRequest request,
  ) async {
    await _initFlutterBluePlus();

    final device = _client.devices.singleWhere(
      (device) {
        return device.remoteId == request.remoteId;
      },
    );

    await device.pair();
  }

  @override
  Future<void> disconnect(
    BmDisconnectRequest request,
  ) async {
    await _initFlutterBluePlus();

    final device = _client.devices.singleWhere(
      (device) {
        return device.remoteId == request.remoteId;
      },
    );

    await device.disconnect();
  }

  @override
  Future<void> discoverServices(
    BmDiscoverServicesRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      _onDiscoveredServicesController.add(
        BmDiscoverServicesResult(
          remoteId: device.remoteId,
          services: device.gattServices.map(
            (service) {
              return BmBluetoothService(
                serviceUuid: Guid.fromBytes(
                  service.uuid.value,
                ),
                remoteId: device.remoteId,
                isPrimary: service.primary,
                characteristics: service.characteristics.map(
                  (characteristic) {
                    return BmBluetoothCharacteristic(
                      remoteId: device.remoteId,
                      serviceUuid: Guid.fromBytes(
                        service.uuid.value,
                      ),
                      secondaryServiceUuid: null,
                      characteristicUuid: Guid.fromBytes(
                        characteristic.uuid.value,
                      ),
                      descriptors: characteristic.descriptors.map(
                        (descriptor) {
                          return BmBluetoothDescriptor(
                            remoteId: device.remoteId,
                            serviceUuid: Guid.fromBytes(
                              service.uuid.value,
                            ),
                            characteristicUuid: Guid.fromBytes(
                              characteristic.uuid.value,
                            ),
                            descriptorUuid: Guid.fromBytes(
                              descriptor.uuid.value,
                            ),
                          );
                        },
                      ).toList(),
                      properties: BmCharacteristicProperties(
                        broadcast: characteristic.flags.contains(
                          BlueZGattCharacteristicFlag.broadcast,
                        ),
                        read: characteristic.flags.contains(
                          BlueZGattCharacteristicFlag.read,
                        ),
                        writeWithoutResponse: characteristic.flags.contains(
                          BlueZGattCharacteristicFlag.writeWithoutResponse,
                        ),
                        write: characteristic.flags.contains(
                          BlueZGattCharacteristicFlag.write,
                        ),
                        notify: characteristic.flags.contains(
                          BlueZGattCharacteristicFlag.notify,
                        ),
                        indicate: characteristic.flags.contains(
                          BlueZGattCharacteristicFlag.indicate,
                        ),
                        authenticatedSignedWrites: characteristic.flags.contains(
                          BlueZGattCharacteristicFlag.authenticatedSignedWrites,
                        ),
                        extendedProperties: characteristic.flags.contains(
                          BlueZGattCharacteristicFlag.extendedProperties,
                        ),
                        notifyEncryptionRequired: false,
                        indicateEncryptionRequired: false,
                      ),
                    );
                  },
                ).toList(),
                includedServices: [],
              );
            },
          ).toList(),
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );
    } catch (e) {
      _onDiscoveredServicesController.add(
        BmDiscoverServicesResult(
          remoteId: request.remoteId,
          services: [],
          success: false,
          errorCode: 0,
          errorString: '',
        ),
      );
    }
  }

  @override
  Future<BmBluetoothAdapterName> getAdapterName(
    BmBluetoothAdapterNameRequest request,
  ) async {
    await _initFlutterBluePlus();

    return BmBluetoothAdapterName(
      adapterName: _client.adapters.first.name,
    );
  }

  @override
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) async {
    await _initFlutterBluePlus();

    return BmBluetoothAdapterState(
      adapterState: _client.adapters.first.powered
          ? BmAdapterStateEnum.on
          : BmAdapterStateEnum.off,
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

    return _client.adapters.length > 0;
  }

  @override
  Future<void> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final service = device.gattServices.singleWhere(
        (service) {
          final uuid = Guid.fromBytes(
            service.uuid.value,
          );

          return uuid == request.serviceUuid;
        },
      );

      final characteristic = service.characteristics.singleWhere(
        (characteristic) {
          final uuid = Guid.fromBytes(
            characteristic.uuid.value,
          );

          return uuid == request.characteristicUuid;
        },
      );

      final value = await characteristic.readValue();

      _onCharacteristicReadController.add(
        BmCharacteristicData(
          remoteId: device.remoteId,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          secondaryServiceUuid: null,
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          value: value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );
    }  catch (e) {
      _onCharacteristicReadController.add(
        BmCharacteristicData(
          remoteId: request.remoteId,
          serviceUuid: request.serviceUuid,
          secondaryServiceUuid: null,
          characteristicUuid: request.characteristicUuid,
          value: [],
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> readDescriptor(
    BmReadDescriptorRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final service = device.gattServices.singleWhere(
        (service) {
          final uuid = Guid.fromBytes(
            service.uuid.value,
          );

          return uuid == request.serviceUuid;
        },
      );

      final characteristic = service.characteristics.singleWhere(
        (characteristic) {
          final uuid = Guid.fromBytes(
            characteristic.uuid.value,
          );

          return uuid == request.characteristicUuid;
        },
      );

      final descriptor = characteristic.descriptors.singleWhere(
        (descriptor) {
          final uuid = Guid.fromBytes(
            descriptor.uuid.value,
          );

          return uuid == request.descriptorUuid;
        },
      );

      final value = await characteristic.readValue();

      _onDescriptorReadController.add(
        BmDescriptorData(
          remoteId: device.remoteId,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          secondaryServiceUuid: null,
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          descriptorUuid: Guid.fromBytes(
            descriptor.uuid.value,
          ),
          value: value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );
    } catch (e) {
      _onDescriptorReadController.add(
        BmDescriptorData(
          remoteId: request.remoteId,
          serviceUuid: request.serviceUuid,
          secondaryServiceUuid: null,
          characteristicUuid: request.characteristicUuid,
          descriptorUuid: request.descriptorUuid,
          value: [],
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> readRssi(
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
    }
  }

  @override
  Future<void> setLogLevel(
    BmSetLogLevelRequest request,
  ) async {
    await _initFlutterBluePlus();

    _logLevel = request.logLevel;
  }

  @override
  Future<void> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) async {
    await _initFlutterBluePlus();

    final device = _client.devices.singleWhere(
      (device) {
        return device.remoteId == request.remoteId;
      },
    );

    final service = device.gattServices.singleWhere(
      (service) {
        final uuid = Guid.fromBytes(
          service.uuid.value,
        );

        return uuid == request.serviceUuid;
      },
    );

    final characteristic = service.characteristics.singleWhere(
      (characteristic) {
        final uuid = Guid.fromBytes(
          characteristic.uuid.value,
        );

        return uuid == request.characteristicUuid;
      },
    );

    if (request.enable) {
      await characteristic.startNotify();
    } else {
      await characteristic.stopNotify();
    }
  }

  @override
  Future<void> setOptions(
    BmSetOptionsRequest request,
  ) {
    return Future.value();
  }

  @override
  Future<void> startScan(
    BmScanSettings request,
  ) async {
    await _initFlutterBluePlus();

    await _client.adapters.first.setDiscoveryFilter(
      uuids: request.withServices.map(
        (uuid) {
          return uuid.str128;
        },
      ).toList(),
    );

    await _client.adapters.first.startDiscovery();
  }

  @override
  Future<void> stopScan(
    BmStopScanRequest request,
  ) async {
    await _initFlutterBluePlus();

    await _client.adapters.first.stopDiscovery();
  }

  @override
  Future<void> turnOff(
    BmTurnOffRequest request,
  ) async {
    await _initFlutterBluePlus();

    await _client.adapters.first.setPowered(false);
  }

  @override
  Future<void> turnOn(
    BmTurnOnRequest request,
  ) async {
    await _initFlutterBluePlus();

    await _client.adapters.first.setPowered(true);
  }

  @override
  Future<void> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final service = device.gattServices.singleWhere(
        (service) {
          final uuid = Guid.fromBytes(
            service.uuid.value,
          );

          return uuid == request.serviceUuid;
        },
      );

      final characteristic = service.characteristics.singleWhere(
        (characteristic) {
          final uuid = Guid.fromBytes(
            characteristic.uuid.value,
          );

          return uuid == request.characteristicUuid;
        },
      );

      await characteristic.writeValue(
        request.value,
        type: request.writeType == BmWriteType.withResponse
            ? BlueZGattCharacteristicWriteType.request
            : BlueZGattCharacteristicWriteType.command,
      );

      _onCharacteristicWrittenController.add(
        BmCharacteristicData(
          remoteId: device.remoteId,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          secondaryServiceUuid: null,
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          value: request.value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );
    } catch (e) {
      _onCharacteristicWrittenController.add(
        BmCharacteristicData(
          remoteId: request.remoteId,
          serviceUuid: request.serviceUuid,
          secondaryServiceUuid: null,
          characteristicUuid: request.characteristicUuid,
          value: request.value,
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final service = device.gattServices.singleWhere(
        (service) {
          final uuid = Guid.fromBytes(
            service.uuid.value,
          );

          return uuid == request.serviceUuid;
        },
      );

      final characteristic = service.characteristics.singleWhere(
        (characteristic) {
          final uuid = Guid.fromBytes(
            characteristic.uuid.value,
          );

          return uuid == request.characteristicUuid;
        },
      );

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
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          secondaryServiceUuid: null,
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          descriptorUuid: Guid.fromBytes(
            descriptor.uuid.value,
          ),
          value: request.value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );
    } catch (e) {
      _onDescriptorWrittenController.add(
        BmDescriptorData(
          remoteId: request.remoteId,
          serviceUuid: request.serviceUuid,
          secondaryServiceUuid: null,
          characteristicUuid: request.characteristicUuid,
          descriptorUuid: request.descriptorUuid,
          value: request.value,
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );
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

    _client.devicesChanged.switchMap(
      (devices) {
        if (_logLevel == LogLevel.verbose) {
          print(
            '[FBP-Linux] devices changed ${devices.map((device) => device.remoteId).toList()}',
          );
        }

        return MergeStream(
          devices.map(
            (device) {
              return device.propertiesChanged.switchMap(
                (properties) {
                  if (_logLevel == LogLevel.verbose) {
                    print(
                      '[FBP-Linux] device ${device.remoteId} properties changed $properties',
                    );
                  }

                  final streams = <Stream<void>>[];

                  for (final service in device.gattServices) {
                    for (final characteristic in service.characteristics) {
                      streams.add(
                        characteristic.propertiesChanged.map(
                          (properties) {
                            if (_logLevel == LogLevel.verbose) {
                              print(
                                '[FBP-Linux] device ${device.remoteId} service ${service.uuid} characteristic ${characteristic.uuid} properties changed $properties',
                              );
                            }
                          },
                        ),
                      );
                    }
                  }

                  return MergeStream(streams);
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
    return MergeStream([
      adapterAdded,
      adapterRemoved,
    ]).map(
      (adapter) {
        return adapters;
      },
    ).startWith(adapters);
  }

  Stream<List<BlueZDevice>> get devicesChanged {
    return MergeStream([
      deviceAdded,
      deviceRemoved,
    ]).map(
      (device) {
        return devices;
      },
    ).startWith(devices);
  }
}

extension on BlueZDevice {
  DeviceIdentifier get remoteId {
    return DeviceIdentifier(address);
  }
}