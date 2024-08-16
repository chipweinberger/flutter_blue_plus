// Copyright 2017-2023, Charles Weinberger & Thomas Clark.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:bluez/bluez.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class FlutterBluePlusLinux {
  static late BlueZClient _client;
  static late Future<dynamic> Function(MethodCall) _methodCallHandler;

  static Map<DeviceIdentifier, BlueZDevice> _devices = {};
  static Map<Guid, StreamSubscription<List<int>>> _notifiers = {};
  static StreamSubscription<BlueZDevice>? _scan;

  static void setMethodCallHandler(
    Future<dynamic> Function(MethodCall) methodCallHandler,
  ) {
    _client = BlueZClient();
    _methodCallHandler = methodCallHandler;
  }

  static Future<dynamic> invokeMethod(
    String method, [
    dynamic arguments,
  ]) async {
    await _client.connect();

    if (method == 'setOptions') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        'setOptions',
        -1,
        'not supported on linux',
      );
    } else if (method == 'flutterRestart') {
      try {
        await Future.wait(
          _devices.values.map(
            (device) {
              return device.disconnect();
            },
          ),
        );

        return _devices.values.where((device) {
          return device.connected;
        }).length;
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'flutterRestart',
          -1,
          e.toString(),
        );
      }
    } else if (method == 'connectedCount') {
      try {
        return _devices.values.where((device) {
          return device.connected;
        }).length;
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'connectedCount',
          -1,
          e.toString(),
        );
      }
    } else if (method == 'setLogLevel') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        'setLogLevel',
        -1,
        'not supported on linux',
      );
    } else if (method == 'isSupported') {
      try {
        return _client.adapters.length > 0;
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'isSupported',
          -1,
          e.toString(),
        );
      }
    } else if (method == 'getAdapterState') {
      try {
        return BmBluetoothAdapterState(
          adapterState: _client.adapters.every((adapter) {
            return adapter.powered;
          })
              ? BmAdapterStateEnum.on
              : BmAdapterStateEnum.off,
        ).toMap();
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'getAdapterState',
          -1,
          e.toString(),
        );
      }
    } else if (method == 'turnOn') {
      try {
        await Future.wait(
          _client.adapters.map(
            (adapter) {
              return adapter.setPowered(true);
            },
          ),
        );
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'turnOn',
          -1,
          e.toString(),
        );
      }

      _methodCallHandler(
        MethodCall(
          'OnTurnOnResponse',
          BmTurnOnResponse(
            userAccepted: true,
          ).toMap(),
        ),
      );

      return true;
    } else if (method == 'turnOff') {
      try {
        await Future.wait(
          _client.adapters.map(
            (adapter) {
              return adapter.setPowered(false);
            },
          ),
        );
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'turnOff',
          -1,
          e.toString(),
        );
      }
    } else if (method == 'startScan') {
      final settings = BmScanSettings.fromMap(arguments);

      await _scan?.cancel();

      _scan = _client.deviceAdded.where(
        (device) {
          bool? isMatch;

          if ((isMatch == null || isMatch == false) &&
              settings.withServices.isNotEmpty) {
            isMatch = settings.withServices.any(
              (uuid) {
                return device.gattServices.any(
                  (service) {
                    return Guid.fromBytes(service.uuid.value) == uuid;
                  },
                );
              },
            );
          }

          if ((isMatch == null || isMatch == false) &&
              settings.withRemoteIds.isNotEmpty) {
            isMatch = settings.withRemoteIds.any(
              (id) {
                return device.address == id;
              },
            );
          }

          if ((isMatch == null || isMatch == false) &&
              settings.withNames.isNotEmpty) {
            isMatch = settings.withNames.any(
              (name) {
                return device.name == name;
              },
            );
          }

          if ((isMatch == null || isMatch == false) &&
              settings.withKeywords.isNotEmpty) {
            isMatch = settings.withKeywords.any(
              (name) {
                return device.name.contains(name);
              },
            );
          }

          if ((isMatch == null || isMatch == false) &&
              settings.withMsd.isNotEmpty) {
            isMatch = settings.withMsd.any(
              (manufacturerData) {
                return device.manufacturerData.keys.any(
                  (key) {
                    return key.id == manufacturerData.manufacturerId;
                  },
                );
              },
            );
          }

          if ((isMatch == null || isMatch == false) &&
              settings.withServiceData.isNotEmpty) {
            isMatch = settings.withServiceData.any(
              (serviceData) {
                return device.serviceData.keys.any(
                  (key) {
                    return Guid.fromBytes(key.value) == serviceData.service;
                  },
                );
              },
            );
          }

          return isMatch == null || isMatch == true;
        },
      ).listen(
        (device) {
          _devices[DeviceIdentifier(device.address)] = device;

          final advertisement = BmScanAdvertisement(
            remoteId: DeviceIdentifier(device.address),
            platformName: device.name,
            advName: device.name,
            connectable: true,
            txPowerLevel: device.txPower,
            appearance: 0,
            manufacturerData: device.manufacturerData.map(
              (key, value) {
                return MapEntry(
                  key.id,
                  value,
                );
              },
            ),
            serviceData: device.serviceData.map(
              (key, value) {
                return MapEntry(
                  Guid.fromBytes(key.value),
                  value,
                );
              },
            ),
            serviceUuids: device.uuids.map(
              (uuid) {
                return Guid.fromBytes(uuid.value);
              },
            ).toList(),
            rssi: device.rssi,
          );

          _methodCallHandler(
            MethodCall(
              'OnScanResult',
              advertisement.toMap(),
            ),
          );
        },
      );

      try {
        await Future.wait(
          _client.adapters.map(
            (adapter) {
              return adapter.startDiscovery();
            },
          ),
        );
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'startScan',
          -1,
          e.toString(),
        );
      }
    } else if (method == 'stopScan') {
      try {
        await Future.wait(
          _client.adapters.map(
            (adapter) {
              return adapter.stopDiscovery();
            },
          ),
        );
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'stopScan',
          -1,
          e.toString(),
        );
      }

      await _scan?.cancel();
    } else if (method == 'getSystemDevices') {
      final devices = <BmBluetoothDevice>[];
      try {
        for (final device in _client.devices) {
          _devices[DeviceIdentifier(device.address)] = device;

          devices.add(
            BmBluetoothDevice(
              remoteId: DeviceIdentifier(device.address),
              platformName: device.name,
            ),
          );
        }
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'getSystemDevices',
          -1,
          e.toString(),
        );
      }

      return BmDevicesList(
        devices: _client.devices.map(
          (device) {
            return BmBluetoothDevice(
              remoteId: DeviceIdentifier(device.address),
              platformName: device.name,
            );
          },
        ).toList(),
      ).toMap();
    } else if (method == 'connect') {
      final request = BmConnectRequest.fromMap(arguments);

      try {
        await _devices[request.remoteId]!.connect();
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'connect',
          -1,
          e.toString(),
        );
      }

      _methodCallHandler(
        MethodCall(
          'OnConnectionStateChanged',
          BmConnectionStateResponse(
            remoteId: request.remoteId,
            connectionState: BmConnectionStateEnum.connected,
            disconnectReasonCode: null,
            disconnectReasonString: null,
          ).toMap(),
        ),
      );

      return true;
    } else if (method == 'disconnect') {
      final remoteId = DeviceIdentifier(arguments as String);

      try {
        await _devices[remoteId]!.disconnect();
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'disconnect',
          -1,
          e.toString(),
        );
      }

      _methodCallHandler(
        MethodCall(
          'OnConnectionStateChanged',
          BmConnectionStateResponse(
            remoteId: remoteId,
            connectionState: BmConnectionStateEnum.disconnected,
            disconnectReasonCode: null,
            disconnectReasonString: null,
          ).toMap(),
        ),
      );

      return true;
    } else if (method == 'discoverServices') {
      final remoteId = DeviceIdentifier(arguments as String);

      List<BmBluetoothService> services;
      try {
        services = _devices[remoteId]!.gattServices.map(
          (service) {
            return BmBluetoothService(
              serviceUuid: Guid.fromBytes(
                service.uuid.value,
              ),
              remoteId: remoteId,
              isPrimary: service.primary,
              characteristics: service.characteristics.map(
                (characteristic) {
                  return BmBluetoothCharacteristic(
                    remoteId: remoteId,
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
                          remoteId: remoteId,
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
        ).toList();
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'discoverServices',
          -1,
          e.toString(),
        );
      }

      _methodCallHandler(
        MethodCall(
          'OnDiscoveredServices',
          BmDiscoverServicesResult(
            remoteId: remoteId,
            services: services,
            success: true,
            errorCode: 0,
            errorString: '',
          ).toMap(),
        ),
      );
    } else if (method == 'readCharacteristic') {
      final request = BmReadCharacteristicRequest.fromMap(arguments);

      List<int> value;
      try {
        value = await _devices[request.remoteId]!
            .gattServices
            .singleWhere(
              (service) {
                return Guid.fromBytes(service.uuid.value) ==
                    request.serviceUuid;
              },
            )
            .characteristics
            .singleWhere(
              (characteristic) {
                return Guid.fromBytes(characteristic.uuid.value) ==
                    request.characteristicUuid;
              },
            )
            .readValue();
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'readCharacteristic',
          -1,
          e.toString(),
        );
      }

      _methodCallHandler(
        MethodCall(
          'OnCharacteristicReceived',
          BmCharacteristicData(
            remoteId: request.remoteId,
            serviceUuid: request.serviceUuid,
            secondaryServiceUuid: request.secondaryServiceUuid,
            characteristicUuid: request.characteristicUuid,
            value: value,
            success: true,
            errorCode: 0,
            errorString: '',
          ).toMap(),
        ),
      );
    } else if (method == 'writeCharacteristic') {
      final request = BmWriteCharacteristicRequest.fromMap(arguments);

      try {
        await _devices[request.remoteId]!
            .gattServices
            .singleWhere(
              (service) {
                return Guid.fromBytes(service.uuid.value) ==
                    request.serviceUuid;
              },
            )
            .characteristics
            .singleWhere(
              (characteristic) {
                return Guid.fromBytes(characteristic.uuid.value) ==
                    request.characteristicUuid;
              },
            )
            .writeValue(
              request.value,
              type: request.writeType == BmWriteType.withResponse
                  ? BlueZGattCharacteristicWriteType.request
                  : BlueZGattCharacteristicWriteType.command,
            );
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'writeCharacteristic',
          -1,
          e.toString(),
        );
      }

      _methodCallHandler(
        MethodCall(
          'OnCharacteristicWritten',
          BmCharacteristicData(
            remoteId: request.remoteId,
            serviceUuid: request.serviceUuid,
            secondaryServiceUuid: request.secondaryServiceUuid,
            characteristicUuid: request.characteristicUuid,
            value: request.value,
            success: true,
            errorCode: 0,
            errorString: '',
          ).toMap(),
        ),
      );
    } else if (method == 'readDescriptor') {
      final request = BmReadDescriptorRequest.fromMap(arguments);

      List<int> value;
      try {
        value = await _devices[request.remoteId]!
            .gattServices
            .singleWhere(
              (service) {
                return Guid.fromBytes(service.uuid.value) ==
                    request.serviceUuid;
              },
            )
            .characteristics
            .singleWhere(
              (characteristic) {
                return Guid.fromBytes(characteristic.uuid.value) ==
                    request.characteristicUuid;
              },
            )
            .descriptors
            .singleWhere(
              (descriptor) {
                return Guid.fromBytes(descriptor.uuid.value) ==
                    request.descriptorUuid;
              },
            )
            .readValue();
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'readDescriptor',
          -1,
          e.toString(),
        );
      }

      _methodCallHandler(
        MethodCall(
          'OnDescriptorRead',
          BmDescriptorData(
            remoteId: request.remoteId,
            serviceUuid: request.serviceUuid,
            secondaryServiceUuid: request.secondaryServiceUuid,
            characteristicUuid: request.characteristicUuid,
            descriptorUuid: request.descriptorUuid,
            value: value,
            success: true,
            errorCode: 0,
            errorString: '',
          ).toMap(),
        ),
      );
    } else if (method == 'writeDescriptor') {
      final request = BmWriteDescriptorRequest.fromMap(arguments);

      try {
        await _devices[request.remoteId]!
            .gattServices
            .singleWhere(
              (service) {
                return Guid.fromBytes(service.uuid.value) ==
                    request.serviceUuid;
              },
            )
            .characteristics
            .singleWhere(
              (characteristic) {
                return Guid.fromBytes(characteristic.uuid.value) ==
                    request.characteristicUuid;
              },
            )
            .descriptors
            .singleWhere(
              (descriptor) {
                return Guid.fromBytes(descriptor.uuid.value) ==
                    request.descriptorUuid;
              },
            )
            .writeValue(request.value);
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'writeDescriptor',
          -1,
          e.toString(),
        );
      }

      _methodCallHandler(
        MethodCall(
          'OnDescriptorWritten',
          BmDescriptorData(
            remoteId: request.remoteId,
            serviceUuid: request.serviceUuid,
            secondaryServiceUuid: request.secondaryServiceUuid,
            characteristicUuid: request.characteristicUuid,
            descriptorUuid: request.descriptorUuid,
            value: request.value,
            success: true,
            errorCode: 0,
            errorString: '',
          ).toMap(),
        ),
      );
    } else if (method == 'setNotifyValue') {
      final request = BmSetNotifyValueRequest.fromMap(arguments);

      try {
        final characteristic = _devices[request.remoteId]!
            .gattServices
            .singleWhere(
              (service) {
                return Guid.fromBytes(service.uuid.value) ==
                    request.serviceUuid;
              },
            )
            .characteristics
            .singleWhere(
              (characteristic) {
                return Guid.fromBytes(characteristic.uuid.value) ==
                    request.characteristicUuid;
              },
            );

        if (request.enable && !characteristic.notifying) {
          _notifiers[request.characteristicUuid] =
              characteristic.propertiesChanged.where(
            (properties) {
              return properties.contains('value');
            },
          ).map(
            (_) {
              return characteristic.value;
            },
          ).listen(
            (value) {
              _methodCallHandler(
                MethodCall(
                  'OnCharacteristicReceived',
                  BmCharacteristicData(
                    remoteId: request.remoteId,
                    serviceUuid: request.serviceUuid,
                    secondaryServiceUuid: request.secondaryServiceUuid,
                    characteristicUuid: request.characteristicUuid,
                    value: value,
                    success: true,
                    errorCode: 0,
                    errorString: '',
                  ).toMap(),
                ),
              );
            },
          );

          await characteristic.startNotify();
        } else if (!request.enable && characteristic.notifying) {
          await characteristic.stopNotify();

          await _notifiers[request.characteristicUuid]?.cancel();
        }
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'setNotifyValue',
          -1,
          e.toString(),
        );
      }

      _methodCallHandler(
        MethodCall(
          'OnDescriptorWritten',
          BmDescriptorData(
            remoteId: request.remoteId,
            serviceUuid: request.serviceUuid,
            secondaryServiceUuid: request.secondaryServiceUuid,
            characteristicUuid: request.characteristicUuid,
            descriptorUuid: cccdUuid,
            value: [],
            success: true,
            errorCode: 0,
            errorString: '',
          ).toMap(),
        ),
      );
    } else if (method == 'requestMtu') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        'requestMtu',
        -1,
        'not supported on linux',
      );
    } else if (method == 'readRssi') {
      final remoteId = DeviceIdentifier(arguments as String);

      int rssi;
      try {
        rssi = _devices[remoteId]!.rssi;
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.linux,
          'readRssi',
          -1,
          e.toString(),
        );
      }

      _methodCallHandler(
        MethodCall(
          'OnReadRssi',
          BmReadRssiResult(
            remoteId: remoteId,
            rssi: rssi,
            success: true,
            errorCode: 0,
            errorString: '',
          ).toMap(),
        ),
      );
    } else if (method == 'requestConnectionPriority') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        'requestConnectionPriority',
        -1,
        'not supported on linux',
      );
    } else if (method == 'getPhySupport') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        'getPhySupport',
        -1,
        'not supported on linux',
      );
    } else if (method == 'setPreferredPhy') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        'setPreferredPhy',
        -1,
        'not supported on linux',
      );
    } else if (method == 'getBondedDevices') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        'getBondedDevices',
        -1,
        'not supported on linux',
      );
    } else if (method == 'createBond') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        'createBond',
        -1,
        'not supported on linux',
      );
    } else if (method == 'removeBond') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        'removeBond',
        -1,
        'not supported on linux',
      );
    } else if (method == 'clearGattCache') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        'clearGattCache',
        -1,
        'not supported on linux',
      );
    } else {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.linux,
        method,
        -1,
        'not supported on linux',
      );
    }
  }
}
