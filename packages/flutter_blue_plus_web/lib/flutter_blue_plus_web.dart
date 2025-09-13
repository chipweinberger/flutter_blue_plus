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

  // for instanceIds
  final _charCache = <DeviceIdentifier, Map<Guid, Map<Guid, List<BluetoothRemoteGATTCharacteristic>>>>{};

  final _onCharacteristicReceivedController = StreamController<BmCharacteristicData>.broadcast();
  final _onCharacteristicWrittenController = StreamController<BmCharacteristicData>.broadcast();
  final _onConnectionStateChangedController = StreamController<BmConnectionStateResponse>.broadcast();
  final _onDescriptorReadController = StreamController<BmDescriptorData>.broadcast();
  final _onDescriptorWrittenController = StreamController<BmDescriptorData>.broadcast();
  final _onDevicesChangedController = StreamController<List<BluetoothDevice>>.broadcast();
  final _onDiscoveredServicesController = StreamController<BmDiscoverServicesResult>.broadcast();
  final _onScanResponseController = StreamController<BmScanResponse>.broadcast();

  BluetoothRemoteGATTCharacteristic _findCharacteristicOrThrow({
    required DeviceIdentifier devId,
    required Guid serviceUuid,
    required Guid charUuid,
    required int instanceId,
  }) {
    final list = _charCache[devId]?[serviceUuid]?[charUuid];
    if (list == null || instanceId < 0 || instanceId >= list.length) {
      throw Exception(
        'Characteristic not found in cache: service=$serviceUuid char=$charUuid instanceId=$instanceId',
      );
    }
    return list[instanceId];
  }

  int _instanceId(DeviceIdentifier devId, Guid serviceUuid, BluetoothRemoteGATTCharacteristic target) {
    final list = _charCache[devId]?[serviceUuid]?[Guid(target.uuid)];
    if (list == null) return 0;
    final idx = list.indexWhere((c) => identical(c, target));
    return idx >= 0 ? idx : 0;
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

    // drop cache for this device to avoid stale entries
    _charCache.remove(request.remoteId);

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

      // ensure dev map exists
      final devMap = _charCache.putIfAbsent(device.remoteId, () {
        return <Guid, Map<Guid, List<BluetoothRemoteGATTCharacteristic>>>{};
      });

      // Enumerate services and characteristics; build cache synchronously from discovery results
      final primaryServices = (await gatt.getPrimaryServices().toDart).toDart;
      for (final s in primaryServices) {
        final characteristics = <BmBluetoothCharacteristic>[];

        // reset/ensure service map
        final charsByUuid = devMap.putIfAbsent(Guid(s.uuid), () {
          return <Guid, List<BluetoothRemoteGATTCharacteristic>>{};
        });

        // pull all chars and cache them grouped by char.uuid (order matters and defines instanceId)
        final chars = (await s.getCharacteristics().toDart).toDart;

        // rebuild for this service
        charsByUuid
          ..clear()
          ..addAll(<Guid, List<BluetoothRemoteGATTCharacteristic>>{});
        for (final c in chars) {
          (charsByUuid[Guid(c.uuid)] ??= <BluetoothRemoteGATTCharacteristic>[]).add(c);
        }

        for (final c in chars) {
          final descriptors = <BmBluetoothDescriptor>[];

          try {
            final descs = (await c.getDescriptors().toDart).toDart;
            for (final d in descs) {
              descriptors.add(
                BmBluetoothDescriptor(
                  remoteId: device.remoteId,
                  primaryServiceUuid: null,
                  serviceUuid: Guid(s.uuid),
                  characteristicUuid: Guid(c.uuid),
                  instanceId: _instanceId(device.remoteId, Guid(s.uuid), c),
                  descriptorUuid: Guid(d.uuid),
                ),
              );
            }
          } catch (e) {
            // ignore errors when getting characteristics descriptors
          }

          characteristics.add(
            BmBluetoothCharacteristic(
              remoteId: device.remoteId,
              primaryServiceUuid: null,
              serviceUuid: Guid(s.uuid),
              characteristicUuid: Guid(c.uuid),
              instanceId: _instanceId(device.remoteId, Guid(s.uuid), c),
              descriptors: descriptors,
              properties: BmCharacteristicProperties(
                broadcast: c.properties.broadcast,
                read: c.properties.read,
                writeWithoutResponse: c.properties.writeWithoutResponse,
                write: c.properties.write,
                notify: c.properties.notify,
                indicate: c.properties.indicate,
                authenticatedSignedWrites: c.properties.authenticatedSignedWrites,
                extendedProperties: false,
                notifyEncryptionRequired: false,
                indicateEncryptionRequired: false,
              ),
            ),
          );
        }

        services.add(
          BmBluetoothService(
            remoteId: device.remoteId,
            primaryServiceUuid: null,
            serviceUuid: Guid(s.uuid),
            characteristics: characteristics,
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

      final serviceUuid = request.serviceUuid.str128;
      final charUuid = request.characteristicUuid.str128;

      // Resolve characteristic from cache using instanceId
      final characteristic = _findCharacteristicOrThrow(
        devId: device.remoteId,
        serviceUuid: Guid(serviceUuid),
        charUuid: Guid(charUuid),
        instanceId: request.instanceId,
      );

      final value = (await characteristic.readValue().toDart).toDart;

      _onCharacteristicReceivedController.add(
        BmCharacteristicData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
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

      final serviceUuid = request.serviceUuid.str128;
      final charUuid = request.characteristicUuid.str128;

      // Resolve characteristic by instanceId from cache
      final characteristic = _findCharacteristicOrThrow(
        devId: device.remoteId,
        serviceUuid: Guid(serviceUuid),
        charUuid: Guid(charUuid),
        instanceId: request.instanceId,
      );

      // Then resolve descriptor by UUID on that characteristic
      final descriptor = await characteristic.getDescriptor(request.descriptorUuid.str128.toJS).toDart;

      final value = (await descriptor.readValue().toDart).toDart;

      _onDescriptorReadController.add(
        BmDescriptorData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          descriptorUuid: Guid.fromString(descriptor.uuid),
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

    final serviceUuid = request.serviceUuid.str128;
    final charUuid = request.characteristicUuid.str128;

    // Resolve from cache using instanceId
    final characteristic = _findCharacteristicOrThrow(
      devId: device.remoteId,
      serviceUuid: Guid(serviceUuid),
      charUuid: Guid(charUuid),
      instanceId: request.instanceId,
    );

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

    return true;
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

      if (filters.isNotEmpty) {
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

      final device = await window.navigator.bluetooth.requestDevice(options).toDart;

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

      final serviceUuid = request.serviceUuid.str128;
      final charUuid = request.characteristicUuid.str128;

      // Resolve characteristic from cache using instanceId
      final characteristic = _findCharacteristicOrThrow(
        devId: device.remoteId,
        serviceUuid: Guid(serviceUuid),
        charUuid: Guid(charUuid),
        instanceId: request.instanceId,
      );

      if (request.writeType == BmWriteType.withResponse) {
        await characteristic.writeValueWithResponse(Uint8List.fromList(request.value).toJS).toDart;
      } else {
        await characteristic.writeValueWithoutResponse(Uint8List.fromList(request.value).toJS).toDart;
      }

      _onCharacteristicWrittenController.add(
        BmCharacteristicData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
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

      final serviceUuid = request.serviceUuid.str128;
      final charUuid = request.characteristicUuid.str128;

      // Resolve characteristic by instanceId from cache
      final characteristic = _findCharacteristicOrThrow(
        devId: device.remoteId,
        serviceUuid: Guid(serviceUuid),
        charUuid: Guid(charUuid),
        instanceId: request.instanceId,
      );

      final descriptor = await characteristic.getDescriptor(request.descriptorUuid.str128.toJS).toDart;

      await descriptor.writeValue(Uint8List.fromList(request.value).toJS).toDart;

      _onDescriptorWrittenController.add(
        BmDescriptorData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          descriptorUuid: Guid.fromString(descriptor.uuid),
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

  void _handleCharacteristicValueChanged(
    Event event,
  ) {
    final characteristic = event.target as BluetoothRemoteGATTCharacteristic;

    final devId = characteristic.service.device.remoteId;
    final svcUuid = characteristic.service.uuid;

    _onCharacteristicReceivedController.add(
      BmCharacteristicData(
        remoteId: devId,
        primaryServiceUuid: null,
        serviceUuid: Guid.fromString(svcUuid),
        characteristicUuid: Guid.fromString(characteristic.uuid),
        instanceId: _instanceId(devId, Guid(svcUuid), characteristic),
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
