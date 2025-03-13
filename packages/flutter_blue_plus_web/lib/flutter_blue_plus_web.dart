import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' show Event;

import 'src/html.dart';
import 'src/web_bluetooth.dart';

final class FlutterBluePlusWeb extends FlutterBluePlusPlatform {
  late final _characteristicValueChangedEventListener = _handleCharacteristicValueChanged.toJS;

  final _devices = <DeviceIdentifier, BluetoothDevice>{};

  final _onCharacteristicReceivedController = StreamController<BmCharacteristicData>.broadcast();
  final _onCharacteristicWrittenController = StreamController<BmCharacteristicData>.broadcast();
  final _onConnectionStateChangedController = StreamController<BmConnectionStateResponse>.broadcast();
  final _onDescriptorReadController = StreamController<BmDescriptorData>.broadcast();
  final _onDescriptorWrittenController = StreamController<BmDescriptorData>.broadcast();
  final _onDevicesChangedController = StreamController<List<BluetoothDevice>>.broadcast();
  final _onDiscoveredServicesController = StreamController<BmDiscoverServicesResult>.broadcast();
  final _onScanResponseController = StreamController<BmScanResponse>.broadcast();

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
  Stream<BmScanResponse> get onScanResponse {
    return _onScanResponseController.stream;
  }

  static void registerWith(
    Registrar registrar,
  ) {
    FlutterBluePlusPlatform.instance = FlutterBluePlusWeb();
  }

  @override
  Future<bool> connect(
    BmConnectRequest request,
  ) async {
    final device = _devices[request.remoteId];

    if (device == null) {
      throw Exception(
        'The device "${request.remoteId}" could not be found.',
      );
    }

    final gatt = device.gatt;

    if (gatt == null) {
      throw Exception(
        'The gatt for the device "${request.remoteId}" is null.',
      );
    }

    await gatt.connect().toDart;

    _onConnectionStateChangedController.add(
      BmConnectionStateResponse(
        remoteId: device.remoteId,
        connectionState: BmConnectionStateEnum.connected,
        disconnectReasonCode: null,
        disconnectReasonString: null,
      ),
    );

    return true;
  }

  @override
  Future<bool> disconnect(
    BmDisconnectRequest request,
  ) async {
    final device = _devices[request.remoteId];

    if (device == null) {
      throw Exception(
        'The device "${request.remoteId}" could not be found.',
      );
    }

    final gatt = device.gatt;

    if (gatt == null) {
      throw Exception(
        'The gatt for the device "${request.remoteId}" is null.',
      );
    }

    gatt.disconnect();

    _onConnectionStateChangedController.add(
      BmConnectionStateResponse(
        remoteId: device.remoteId,
        connectionState: BmConnectionStateEnum.disconnected,
        disconnectReasonCode: null,
        disconnectReasonString: null,
      ),
    );

    return true;
  }

  @override
  Future<bool> discoverServices(
    BmDiscoverServicesRequest request,
  ) async {
    try {
      final device = _devices[request.remoteId];

      if (device == null) {
        throw Exception(
          'The device "${request.remoteId}" could not be found.',
        );
      }

      final gatt = device.gatt;

      if (gatt == null) {
        throw Exception(
          'The gatt for the device "${request.remoteId}" is null.',
        );
      }

      final services = <BmBluetoothService>[];

      List<BluetoothRemoteGATTService> primaryServices = (await gatt.getPrimaryServices().toDart).toDart;
      for (final s in primaryServices) {
        final characteristics = <BmBluetoothCharacteristic>[];

        List<BluetoothRemoteGATTCharacteristic> chars = (await s.getCharacteristics().toDart).toDart;
        for (final c in chars) {
          final descriptors = <BmBluetoothDescriptor>[];

          try {
            List<BluetoothRemoteGATTDescriptor> descs = (await c.getDescriptors().toDart).toDart;
            for (final d in descs) {
              descriptors.add(
                BmBluetoothDescriptor(
                  remoteId: device.remoteId,
                  serviceUuid: Guid.fromString(s.uuid),
                  characteristicUuid: Guid.fromString(c.uuid),
                  descriptorUuid: Guid.fromString(d.uuid),
                  primaryServiceUuid: null,
                ),
              );
            }
          } catch(e) {
            // ignore errors when getting characteristics descriptors
          }

          characteristics.add(
            BmBluetoothCharacteristic(
              remoteId: device.remoteId,
              serviceUuid: Guid.fromString(s.uuid),
              characteristicUuid: Guid.fromString(c.uuid),
              primaryServiceUuid: null,
              descriptors: descriptors,
              properties: BmCharacteristicProperties(
                broadcast: c.properties.broadcast,
                read: c.properties.read,
                writeWithoutResponse: c.properties.writeWithoutResponse,
                write: c.properties.write,
                notify: c.properties.notify,
                indicate: c.properties.indicate,
                authenticatedSignedWrites:
                    c.properties.authenticatedSignedWrites,
                extendedProperties: false,
                notifyEncryptionRequired: false,
                indicateEncryptionRequired: false,
              ),
            ),
          );
        }

        services.add(
          BmBluetoothService(
            serviceUuid: Guid.fromString(s.uuid),
            remoteId: device.remoteId,
            characteristics: characteristics,
            primaryServiceUuid: null,
          ),
        );
      }

      _onDiscoveredServicesController.add(
        BmDiscoverServicesResult(
          remoteId: device.remoteId,
          services: services,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onDiscoveredServicesController.add(
        BmDiscoverServicesResult(
          remoteId: request.remoteId,
          services: [],
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }

  @override
  Future<bool> isSupported(
    BmIsSupportedRequest request,
  ) async {
    try {
      return (await window.navigator.bluetooth.getAvailability().toDart).toDart;
    } catch (e) {
      return false; // https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API#browser_compatibility
    }
  }

  @override
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) {
    return isSupported(BmIsSupportedRequest()).then(
      (supported) => BmBluetoothAdapterState(
        adapterState: supported ? BmAdapterStateEnum.on : BmAdapterStateEnum.unknown,
      ),
    );
  }

  @override
  Future<bool> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) async {
    try {
      final device = _devices[request.remoteId];

      if (device == null) {
        throw Exception(
          'The device "${request.remoteId}" could not be found.',
        );
      }

      final gatt = device.gatt;

      if (gatt == null) {
        throw Exception(
          'The gatt for the device "${request.remoteId}" is null.',
        );
      }

      final service =
          await gatt.getPrimaryService(request.serviceUuid.str128.toJS).toDart;

      final characteristic = await service
          .getCharacteristic(request.characteristicUuid.str128.toJS)
          .toDart;

      final value = (await characteristic.readValue().toDart).toDart;

      _onCharacteristicReceivedController.add(
        BmCharacteristicData(
          remoteId: device.remoteId,
          serviceUuid: Guid.fromString(service.uuid),
          characteristicUuid: Guid.fromString(characteristic.uuid),
          primaryServiceUuid: null,
          value: value.buffer.asUint8List(),
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
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          primaryServiceUuid: null,
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
      final device = _devices[request.remoteId];

      if (device == null) {
        throw Exception(
          'The device "${request.remoteId}" could not be found.',
        );
      }

      final gatt = device.gatt;

      if (gatt == null) {
        throw Exception(
          'The gatt for the device "${request.remoteId}" is null.',
        );
      }

      final service =
          await gatt.getPrimaryService(request.serviceUuid.str128.toJS).toDart;

      final characteristic = await service
          .getCharacteristic(request.characteristicUuid.str128.toJS)
          .toDart;

      final descriptor = await characteristic
          .getDescriptor(request.characteristicUuid.str128.toJS)
          .toDart;

      final value = (await descriptor.readValue().toDart).toDart;

      _onDescriptorReadController.add(
        BmDescriptorData(
          remoteId: device.remoteId,
          serviceUuid: Guid.fromString(service.uuid),
          characteristicUuid: Guid.fromString(characteristic.uuid),
          descriptorUuid: Guid.fromString(descriptor.uuid),
          primaryServiceUuid: null,
          value: value.buffer.asUint8List(),
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
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          descriptorUuid: request.descriptorUuid,
          primaryServiceUuid: null,
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
  Future<bool> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) async {
    final device = _devices[request.remoteId];

    if (device == null) {
      throw Exception(
        'The device "${request.remoteId}" could not be found.',
      );
    }

    final gatt = device.gatt;

    if (gatt == null) {
      throw Exception(
        'The gatt for the device "${request.remoteId}" is null.',
      );
    }

    final service =
        await gatt.getPrimaryService(request.serviceUuid.str128.toJS).toDart;

    final characteristic = await service
        .getCharacteristic(request.characteristicUuid.str128.toJS)
        .toDart;

    if (request.enable) {
      characteristic.addEventListener(
        'characteristicvaluechanged',
        _characteristicValueChangedEventListener,
      );

      await characteristic.startNotifications().toDart;
    } else {
      await characteristic.stopNotifications().toDart;

      characteristic.removeEventListener(
        'characteristicvaluechanged',
        _characteristicValueChangedEventListener,
      );
    }

    return false;
  }

  @override
  Future<bool> startScan(
    BmScanSettings request,
  ) async {
    try {
      final filters = <BluetoothLEScanFilterInit>[];

      for (final service in request.withServices) {
        filters.add(
          BluetoothLEScanFilterInit(
            services: [
              service.str128.toJS,
            ].toJS,
          ),
        );
      }

      for (final name in request.withNames) {
        filters.add(
          BluetoothLEScanFilterInit(
            name: name,
          ),
        );
      }

      for (final manufacturerData in request.withMsd) {
        filters.add(
          BluetoothLEScanFilterInit(
            manufacturerData: [
              BluetoothManufacturerDataFilterInit(
                companyIdentifier: manufacturerData.manufacturerId,
              ),
            ].toJS,
          ),
        );
      }

      for (final serviceData in request.withServiceData) {
        filters.add(
          BluetoothLEScanFilterInit(
            serviceData: [
              BluetoothServiceDataFilterInit(
                service: serviceData.service.str128.toJS,
              ),
            ].toJS,
          ),
        );
      }

      final RequestDeviceOptions options;

      if (filters.length > 0) {
        options = RequestDeviceOptions(
          filters: filters.toJS,
          optionalServices: request.webOptionalServices.map((e) => e.str128.toJS).toList().toJS,
        );
      } else {
        // https://developer.mozilla.org/en-US/docs/Web/API/Bluetooth/requestDevice#acceptalldevices
        options = RequestDeviceOptions(
          acceptAllDevices: true,
          optionalServices: request.webOptionalServices.map((e) => e.str128.toJS).toList().toJS,
        );
      }

      final device =
          await window.navigator.bluetooth.requestDevice(options).toDart;

      _devices[device.remoteId] = device;
      _onDevicesChangedController.add([..._devices.values]);

      _onScanResponseController.add(
        BmScanResponse(
          advertisements: [
            BmScanAdvertisement(
              remoteId: device.remoteId,
              platformName: device.name,
              advName: null,
              connectable: true,
              txPowerLevel: null,
              appearance: null,
              manufacturerData: {},
              serviceData: {},
              serviceUuids: [],
              rssi: 0,
            ),
          ],
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onScanResponseController.add(
        BmScanResponse(
          advertisements: [],
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }

  @override
  Future<bool> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) async {
    try {
      final device = _devices[request.remoteId];

      if (device == null) {
        throw Exception(
          'The device "${request.remoteId}" could not be found.',
        );
      }

      final gatt = device.gatt;

      if (gatt == null) {
        throw Exception(
          'The gatt for the device "${request.remoteId}" is null.',
        );
      }

      final service =
          await gatt.getPrimaryService(request.serviceUuid.str128.toJS).toDart;

      final characteristic = await service
          .getCharacteristic(request.characteristicUuid.str128.toJS)
          .toDart;

      if (request.writeType == BmWriteType.withResponse) {
        await characteristic
            .writeValueWithResponse(Uint8List.fromList(request.value).toJS)
            .toDart;
      } else {
        await characteristic
            .writeValueWithoutResponse(Uint8List.fromList(request.value).toJS)
            .toDart;
      }

      _onCharacteristicWrittenController.add(
        BmCharacteristicData(
          remoteId: device.remoteId,
          serviceUuid: Guid.fromString(service.uuid),
          characteristicUuid: Guid.fromString(characteristic.uuid),
          primaryServiceUuid: null,
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
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          primaryServiceUuid: null,
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
      final device = _devices[request.remoteId];

      if (device == null) {
        throw Exception(
          'The device "${request.remoteId}" could not be found.',
        );
      }

      final gatt = device.gatt;

      if (gatt == null) {
        throw Exception(
          'The gatt for the device "${request.remoteId}" is null.',
        );
      }

      final service =
          await gatt.getPrimaryService(request.serviceUuid.str128.toJS).toDart;

      final characteristic = await service
          .getCharacteristic(request.characteristicUuid.str128.toJS)
          .toDart;

      final descriptor = await characteristic
          .getDescriptor(request.characteristicUuid.str128.toJS)
          .toDart;

      await descriptor
          .writeValue(Uint8List.fromList(request.value).toJS)
          .toDart;

      _onDescriptorWrittenController.add(
        BmDescriptorData(
          remoteId: device.remoteId,
          serviceUuid: Guid.fromString(service.uuid),
          characteristicUuid: Guid.fromString(characteristic.uuid),
          descriptorUuid: Guid.fromString(descriptor.uuid),
          primaryServiceUuid: null,
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
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          descriptorUuid: request.descriptorUuid,
          primaryServiceUuid: null,
          value: request.value,
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }

  void _handleCharacteristicValueChanged(
    Event event,
  ) {
    final characteristic = event.target as BluetoothRemoteGATTCharacteristic;

    _onCharacteristicReceivedController.add(
      BmCharacteristicData(
        remoteId: characteristic.service.device.remoteId,
        serviceUuid: Guid.fromString(characteristic.service.uuid),
        characteristicUuid: Guid.fromString(characteristic.uuid),
        primaryServiceUuid: null,
        value: characteristic.value?.toDart.buffer.asUint8List() ?? [],
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
  }
}

extension on BluetoothDevice {
  DeviceIdentifier get remoteId {
    return DeviceIdentifier(id);
  }
}
