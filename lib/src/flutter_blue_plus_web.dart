// Copyright 2017-2023, Charles Weinberger & Thomas Clark.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:web/web.dart';

class FlutterBluePlusWeb {
  static final _handleCharacteristicValueChanged = (
    Event event,
  ) {
    final target = event.target as BluetoothRemoteGATTCharacteristic;

    final value = target.value?.toDart.buffer.asUint8List();

    _methodCallHandler(
      MethodCall(
        'OnCharacteristicReceived',
        BmCharacteristicData(
          remoteId: DeviceIdentifier(target.service.device.id.toDart),
          serviceUuid: Guid(target.service.uuid.toDart),
          secondaryServiceUuid: null,
          characteristicUuid: Guid(target.uuid.toDart),
          value: value ?? [],
          success: true,
          errorCode: 0,
          errorString: '',
        ).toMap(),
      ),
    );
  }.toJS;

  static late Future<dynamic> Function(MethodCall) _methodCallHandler;

  static Map<DeviceIdentifier, BluetoothDevice> _devices = {};

  static void setMethodCallHandler(
    Future<dynamic> Function(MethodCall) methodCallHandler,
  ) {
    _methodCallHandler = methodCallHandler;
  }

  static Future<dynamic> invokeMethod(
    String method, [
    dynamic arguments,
  ]) async {
    if (method == 'setOptions') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'setOptions',
        -1,
        'not supported on web',
      );
    } else if (method == 'flutterRestart') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'flutterRestart',
        -1,
        'not supported on web',
      );
    } else if (method == 'connectedCount') {
      return _devices.values
          .where((device) => device.gatt?.connected.toDart == true)
          .length;
    } else if (method == 'setLogLevel') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'setLogLevel',
        -1,
        'not supported on web',
      );
    } else if (method == 'isSupported') {
      try {
        return await window.navigator.bluetooth.getAvailability().toDart;
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.web,
          'isSupported',
          -1,
          e.toString(),
        );
      }
    } else if (method == 'getAdapterState') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'getAdapterState',
        -1,
        'not supported on web',
      );
    } else if (method == 'turnOn') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'turnOn',
        -1,
        'not supported on web',
      );
    } else if (method == 'turnOff') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'turnOff',
        -1,
        'not supported on web',
      );
    } else if (method == 'startScan') {
      final settings = BmScanSettings.fromMap(arguments);

      final options = settings.withServices.isNotEmpty ||
              settings.withNames.isNotEmpty ||
              settings.withKeywords.isNotEmpty ||
              settings.withMsd.isNotEmpty ||
              settings.withServiceData.isNotEmpty
          ? RequestDeviceOptions(
              filters: [
                ...settings.withServices.map(
                  (uuid) => BluetoothLEScanFilter(
                    services: [
                      uuid.str128.toJS,
                    ].toJS,
                  ),
                ),
                ...settings.withNames.map(
                  (name) => BluetoothLEScanFilter(
                    name: name.toJS,
                  ),
                ),
                ...settings.withKeywords.map(
                  (keyword) => BluetoothLEScanFilter(
                    namePrefix: keyword.toJS,
                  ),
                ),
                ...settings.withMsd.map(
                  (manufacturerData) => BluetoothLEScanFilter(
                    manufacturerData: [
                      BluetoothManufacturerDataFilter(
                        companyIdentifier: manufacturerData.manufacturerId.toJS,
                        dataPrefix: manufacturerData.data != null
                            ? Uint8List.fromList(manufacturerData.data!)
                                .buffer
                                .toJS
                            : null,
                        mask: manufacturerData.mask != null
                            ? Uint8List.fromList(manufacturerData.mask!)
                                .buffer
                                .toJS
                            : null,
                      ),
                    ].toJS,
                  ),
                ),
                ...settings.withServiceData.map(
                  (serviceData) => BluetoothLEScanFilter(
                    serviceData: [
                      BluetoothServiceDataFilter(
                        service: serviceData.service.str128.toJS,
                        dataPrefix: serviceData.data != null
                            ? Uint8List.fromList(serviceData.data!).buffer.toJS
                            : null,
                        mask: serviceData.mask != null
                            ? Uint8List.fromList(serviceData.mask!).buffer.toJS
                            : null,
                      ),
                    ].toJS,
                  ),
                ),
              ].toJS,
            )
          : RequestDeviceOptions(
              acceptAllDevices: true.toJS,
            );

      final BluetoothDevice device;
      try {
        device = await window.navigator.bluetooth.requestDevice(options).toDart;
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.web,
          'startScan',
          -1,
          e.toString(),
        );
      }

      _devices[DeviceIdentifier(device.id.toDart)] = device;

      final advertisement = BmScanAdvertisement(
        remoteId: DeviceIdentifier(device.id.toDart),
        platformName: device.name?.toDart ?? '',
        advName: device.name?.toDart ?? '',
        connectable: true,
        txPowerLevel: 0,
        appearance: 0,
        manufacturerData: {},
        serviceData: {},
        serviceUuids: [],
        rssi: 0,
      );

      _methodCallHandler(
        MethodCall(
          'OnScanResult',
          advertisement.toMap(),
        ),
      );
    } else if (method == 'stopScan') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'stopScan',
        -1,
        'not supported on web',
      );
    } else if (method == 'getSystemDevices') {
      final JSArray<BluetoothDevice> devices;
      try {
        devices = await window.navigator.bluetooth.getDevices().toDart;
      } catch (e) {
        throw FlutterBluePlusException(
          ErrorPlatform.web,
          'getSystemDevices',
          -1,
          e.toString(),
        );
      }

      return BmDevicesList(
        devices: devices.toDart
            .map(
              (device) => BmBluetoothDevice(
                remoteId: DeviceIdentifier(device.id.toDart),
                platformName: device.name?.toDart,
              ),
            )
            .toList(),
      ).toMap();
    } else if (method == 'connect') {
      final request = BmConnectRequest.fromMap(arguments);

      await _getBluetoothRemoteGATTServer(request.remoteId).connect().toDart;

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
    } else if (method == 'disconnect') {
      final remoteId = DeviceIdentifier(arguments as String);

      _getBluetoothRemoteGATTServer(remoteId).disconnect();

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
    } else if (method == 'discoverServices') {
      final remoteId = DeviceIdentifier(arguments as String);

      final services = await Future.wait<BmBluetoothService>(
        (await _getBluetoothRemoteGATTServer(remoteId)
                .getPrimaryServices()
                .toDart)
            .toDart
            .map(
              (service) async => await _mapBluetoothRemoteGATTService(
                remoteId,
                service,
              ),
            )
            .toList(),
      );

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

      final service = await _getBluetoothRemoteGATTServer(request.remoteId)
          .getPrimaryService(request.serviceUuid.str128.toJS)
          .toDart;

      final characteristic = await service
          .getCharacteristic(request.characteristicUuid.str128.toJS)
          .toDart;

      final value = characteristic.value?.toDart.buffer.asUint8List();

      _methodCallHandler(
        MethodCall(
          'OnCharacteristicReceived',
          BmCharacteristicData(
            remoteId: request.remoteId,
            serviceUuid: request.serviceUuid,
            secondaryServiceUuid: request.secondaryServiceUuid,
            characteristicUuid: request.characteristicUuid,
            value: value ?? [],
            success: true,
            errorCode: 0,
            errorString: '',
          ).toMap(),
        ),
      );
    } else if (method == 'writeCharacteristic') {
      final request = BmWriteCharacteristicRequest.fromMap(arguments);

      final service = await _getBluetoothRemoteGATTServer(request.remoteId)
          .getPrimaryService(request.serviceUuid.str128.toJS)
          .toDart;

      final characteristic = await service
          .getCharacteristic(request.characteristicUuid.str128.toJS)
          .toDart;

      final value = Uint8List.fromList(request.value).buffer.toJS;
      switch (request.writeType) {
        case BmWriteType.withResponse:
          await characteristic.writeValueWithResponse(value).toDart;
          break;
        case BmWriteType.withoutResponse:
          await characteristic.writeValueWithoutResponse(value).toDart;
          break;
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

      final service = await _getBluetoothRemoteGATTServer(request.remoteId)
          .getPrimaryService(request.serviceUuid.str128.toJS)
          .toDart;

      final characteristic = await service
          .getCharacteristic(request.characteristicUuid.str128.toJS)
          .toDart;

      final descriptor = await characteristic
          .getDescriptor(request.descriptorUuid.str128.toJS)
          .toDart;

      final value = descriptor.value?.toDart.buffer.asUint8List();

      _methodCallHandler(
        MethodCall(
          'OnDescriptorRead',
          BmDescriptorData(
            remoteId: request.remoteId,
            serviceUuid: request.serviceUuid,
            secondaryServiceUuid: request.secondaryServiceUuid,
            characteristicUuid: request.characteristicUuid,
            descriptorUuid: request.descriptorUuid,
            value: value ?? [],
            success: true,
            errorCode: 0,
            errorString: '',
          ).toMap(),
        ),
      );
    } else if (method == 'writeDescriptor') {
      final request = BmWriteDescriptorRequest.fromMap(arguments);

      final service = await _getBluetoothRemoteGATTServer(request.remoteId)
          .getPrimaryService(request.serviceUuid.str128.toJS)
          .toDart;

      final characteristic = await service
          .getCharacteristic(request.characteristicUuid.str128.toJS)
          .toDart;

      final descriptor = await characteristic
          .getDescriptor(request.descriptorUuid.str128.toJS)
          .toDart;

      final value = Uint8List.fromList(request.value).buffer.toJS;
      await descriptor.writeValue(value).toDart;

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

      final service = await _getBluetoothRemoteGATTServer(request.remoteId)
          .getPrimaryService(request.serviceUuid.str128.toJS)
          .toDart;

      final characteristic = await service
          .getCharacteristic(request.characteristicUuid.str128.toJS)
          .toDart;

      if (request.enable) {
        characteristic.addEventListener(
          'characteristicvaluechanged',
          _handleCharacteristicValueChanged,
        );

        await characteristic.startNotifications().toDart;
      } else {
        await characteristic.stopNotifications().toDart;

        characteristic.removeEventListener(
          'characteristicvaluechanged',
          _handleCharacteristicValueChanged,
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
        ErrorPlatform.web,
        'requestMtu',
        -1,
        'not supported on web',
      );
    } else if (method == 'readRssi') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'readRssi',
        -1,
        'not supported on web',
      );
    } else if (method == 'requestConnectionPriority') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'requestConnectionPriority',
        -1,
        'not supported on web',
      );
    } else if (method == 'getPhySupport') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'getPhySupport',
        -1,
        'not supported on web',
      );
    } else if (method == 'setPreferredPhy') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'setPreferredPhy',
        -1,
        'not supported on web',
      );
    } else if (method == 'getBondedDevices') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'getBondedDevices',
        -1,
        'not supported on web',
      );
    } else if (method == 'createBond') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'createBond',
        -1,
        'not supported on web',
      );
    } else if (method == 'removeBond') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'removeBond',
        -1,
        'not supported on web',
      );
    } else if (method == 'clearGattCache') {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        'clearGattCache',
        -1,
        'not supported on web',
      );
    } else {
      // unsupported
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        method,
        -1,
        'not supported on web',
      );
    }

    return Future.delayed(Duration.zero);
  }

  static BluetoothRemoteGATTServer _getBluetoothRemoteGATTServer(
    DeviceIdentifier remoteId,
  ) {
    if (_devices[remoteId] case final device?) {
      return device.gatt!;
    } else {
      throw FlutterBluePlusException(
        ErrorPlatform.web,
        '',
        -1,
        'device not found',
      );
    }
  }

  static Future<BmBluetoothService> _mapBluetoothRemoteGATTService(
    DeviceIdentifier remoteId,
    BluetoothRemoteGATTService service,
  ) async {
    final characteristics = <BmBluetoothCharacteristic>[];
    for (final characteristic
        in (await service.getCharacteristics().toDart).toDart) {
      final descriptors = <BmBluetoothDescriptor>[];
      for (final descriptor
          in (await characteristic.getDescriptors().toDart).toDart) {
        descriptors.add(
          BmBluetoothDescriptor(
            remoteId: remoteId,
            serviceUuid: Guid(service.uuid.toDart),
            characteristicUuid: Guid(characteristic.uuid.toDart),
            descriptorUuid: Guid(descriptor.uuid.toDart),
          ),
        );
      }

      characteristics.add(
        BmBluetoothCharacteristic(
          remoteId: remoteId,
          serviceUuid: Guid(service.uuid.toDart),
          secondaryServiceUuid: null,
          characteristicUuid: Guid(characteristic.uuid.toDart),
          descriptors: descriptors,
          properties: BmCharacteristicProperties(
            broadcast: characteristic.properties.broadcast.toDart,
            read: characteristic.properties.read.toDart,
            writeWithoutResponse:
                characteristic.properties.writeWithoutResponse.toDart,
            write: characteristic.properties.write.toDart,
            notify: characteristic.properties.notify.toDart,
            indicate: characteristic.properties.indicate.toDart,
            authenticatedSignedWrites:
                characteristic.properties.authenticatedSignedWrites.toDart,
            extendedProperties: false,
            notifyEncryptionRequired: false,
            indicateEncryptionRequired: false,
          ),
        ),
      );
    }

    final includedServices = <BmBluetoothService>[];
    for (final includedService
        in (await service.getIncludedServices().toDart).toDart) {
      includedServices.add(
        await _mapBluetoothRemoteGATTService(
          remoteId,
          includedService,
        ),
      );
    }

    return BmBluetoothService(
      serviceUuid: Guid(service.uuid.toDart),
      remoteId: remoteId,
      isPrimary: service.isPrimary.toDart,
      characteristics: characteristics,
      includedServices: includedServices,
    );
  }
}

extension on Navigator {
  external Bluetooth get bluetooth;
}

extension type Bluetooth._(JSObject _) implements EventTarget, JSObject {
  external JSPromise<JSBoolean> getAvailability();

  external JSPromise<JSArray<BluetoothDevice>> getDevices();

  external JSPromise<BluetoothDevice> requestDevice([
    RequestDeviceOptions? options,
  ]);

  external EventHandler get onadvertisementreceived;
  external set onadvertisementreceived(EventHandler value);
  external EventHandler get onavailabilitychanged;
  external set onavailabilitychanged(EventHandler value);
  external EventHandler get oncharacteristicvaluechanged;
  external set oncharacteristicvaluechanged(EventHandler value);
  external EventHandler get ongattserverdisconnected;
  external set ongattserverdisconnected(EventHandler value);
  external EventHandler get onserviceadded;
  external set onserviceadded(EventHandler value);
  external EventHandler get onservicechanged;
  external set onservicechanged(EventHandler value);
  external EventHandler get onserviceremoved;
  external set onserviceremoved(EventHandler value);
}

extension type BluetoothCharacteristicProperties._(JSObject _)
    implements JSObject {
  external JSBoolean get broadcast;
  external JSBoolean get read;
  external JSBoolean get writeWithoutResponse;
  external JSBoolean get write;
  external JSBoolean get notify;
  external JSBoolean get indicate;
  external JSBoolean get authenticatedSignedWrites;
  external JSBoolean get reliableWrite;
  external JSBoolean get writableAuxiliaries;
}

extension type BluetoothDataFilter._(JSObject _) implements JSObject {
  external factory BluetoothDataFilter({
    JSString? name,
    JSString? namePrefix,
    JSArray<JSString>? services,
    JSArray<BluetoothManufacturerDataFilter>? manufacturerData,
    JSArray<BluetoothServiceDataFilter>? serviceData,
  });
}

extension type BluetoothDevice._(JSObject _) implements EventTarget, JSObject {
  external JSString get id;
  external JSString? get name;
  external BluetoothRemoteGATTServer? get gatt;
  external JSBoolean get watchingAdvertisements;

  external JSPromise forget();

  external JSPromise watchAdvertisements([
    WatchAdvertisementsOptions? options,
  ]);

  external EventHandler get onadvertisementreceived;
  external set onadvertisementreceived(EventHandler value);
  external EventHandler get oncharacteristicvaluechanged;
  external set oncharacteristicvaluechanged(EventHandler value);
  external EventHandler get ongattserverdisconnected;
  external set ongattserverdisconnected(EventHandler value);
  external EventHandler get onserviceadded;
  external set onserviceadded(EventHandler value);
  external EventHandler get onservicechanged;
  external set onservicechanged(EventHandler value);
  external EventHandler get onserviceremoved;
  external set onserviceremoved(EventHandler value);
}

extension type BluetoothLEScanFilter._(JSObject _) implements JSObject {
  external factory BluetoothLEScanFilter({
    JSString? name,
    JSString? namePrefix,
    JSArray<JSString>? services,
    JSArray<BluetoothManufacturerDataFilter>? manufacturerData,
    JSArray<BluetoothServiceDataFilter>? serviceData,
  });

  external JSString? get name;
  external set name(JSString? value);
  external JSString? get namePrefix;
  external set namePrefix(JSString? value);
  external JSArray<JSString>? get services;
  external set services(JSArray<JSString>? value);
  external JSArray<BluetoothManufacturerDataFilter>? get manufacturerData;
  external set manufacturerData(
      JSArray<BluetoothManufacturerDataFilter>? value);
  external JSArray<BluetoothServiceDataFilter>? get serviceData;
  external set serviceData(JSArray<BluetoothServiceDataFilter>? value);
}

extension type BluetoothManufacturerDataFilter._(JSObject _)
    implements JSObject {
  external factory BluetoothManufacturerDataFilter({
    JSNumber companyIdentifier,
    JSArrayBuffer? dataPrefix,
    JSArrayBuffer? mask,
  });

  external JSNumber get companyIdentifier;
  external set companyIdentifier(JSNumber value);
  external JSArrayBuffer? get dataPrefix;
  external set dataPrefix(JSArrayBuffer? value);
  external JSArrayBuffer? get mask;
  external set mask(JSArrayBuffer? value);
}

extension type BluetoothRemoteGATTCharacteristic._(JSObject _)
    implements EventTarget, JSObject {
  external BluetoothRemoteGATTService get service;
  external JSString get uuid;
  external BluetoothCharacteristicProperties get properties;
  external JSDataView? get value;

  external JSPromise<BluetoothRemoteGATTDescriptor> getDescriptor(
    JSString descriptor,
  );

  external JSPromise<JSArray<BluetoothRemoteGATTDescriptor>> getDescriptors();

  external JSPromise<JSDataView> readValue();

  external JSPromise writeValueWithResponse(
    JSArrayBuffer value,
  );

  external JSPromise writeValueWithoutResponse(
    JSArrayBuffer value,
  );

  external JSPromise<BluetoothRemoteGATTCharacteristic> startNotifications();

  external JSPromise<BluetoothRemoteGATTCharacteristic> stopNotifications();

  external EventHandler get oncharacteristicvaluechanged;
  external set oncharacteristicvaluechanged(EventHandler value);
}

extension type BluetoothRemoteGATTDescriptor._(JSObject _) implements JSObject {
  external BluetoothRemoteGATTCharacteristic get characteristic;
  external JSString get uuid;
  external JSDataView? get value;

  external JSPromise<JSDataView> readValue();

  external JSPromise writeValue(
    JSArrayBuffer value,
  );
}

extension type BluetoothRemoteGATTServer._(JSObject _) implements JSObject {
  external BluetoothDevice get device;
  external JSBoolean get connected;

  external JSPromise<BluetoothRemoteGATTServer> connect();

  external JSVoid disconnect();

  external JSPromise<BluetoothRemoteGATTService> getPrimaryService(
    JSString service,
  );

  external JSPromise<JSArray<BluetoothRemoteGATTService>> getPrimaryServices();
}

extension type BluetoothRemoteGATTService._(JSObject _)
    implements EventTarget, JSObject {
  external BluetoothDevice get device;
  external JSString get uuid;
  external JSBoolean get isPrimary;

  external JSPromise<BluetoothRemoteGATTCharacteristic> getCharacteristic(
    JSString characteristic,
  );

  external JSPromise<JSArray<BluetoothRemoteGATTCharacteristic>>
      getCharacteristics();

  external JSPromise<BluetoothRemoteGATTService> getIncludedService(
    JSString service,
  );

  external JSPromise<JSArray<BluetoothRemoteGATTService>> getIncludedServices();

  external EventHandler get oncharacteristicvaluechanged;
  external set oncharacteristicvaluechanged(EventHandler value);
  external EventHandler get onserviceadded;
  external set onserviceadded(EventHandler value);
  external EventHandler get onservicechanged;
  external set onservicechanged(EventHandler value);
  external EventHandler get onserviceremoved;
  external set onserviceremoved(EventHandler value);
}

extension type BluetoothServiceDataFilter._(JSObject _) implements JSObject {
  external factory BluetoothServiceDataFilter({
    JSString service,
    JSArrayBuffer? dataPrefix,
    JSArrayBuffer? mask,
  });

  external JSString get service;
  external set service(JSString value);
  external JSArrayBuffer? get dataPrefix;
  external set dataPrefix(JSArrayBuffer? value);
  external JSArrayBuffer? get mask;
  external set mask(JSArrayBuffer? value);
}

extension type RequestDeviceOptions._(JSObject _) implements JSObject {
  external factory RequestDeviceOptions({
    JSArray<BluetoothLEScanFilter>? filters,
    JSBoolean? acceptAllDevices,
  });

  external JSArray<BluetoothLEScanFilter>? get filters;
  external set filters(JSArray<BluetoothLEScanFilter>? value);
  external JSBoolean? get acceptAllDevices;
  external set acceptAllDevices(JSBoolean? value);
}

extension type WatchAdvertisementsOptions._(JSObject _) implements JSObject {
  external factory WatchAdvertisementsOptions({
    AbortSignal? signal,
  });

  external AbortSignal? get signal;
  external set signal(AbortSignal? value);
}
