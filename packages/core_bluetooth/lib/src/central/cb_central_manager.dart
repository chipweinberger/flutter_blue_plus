part of '../core_bluetooth.dart';

final class CentralManagerOptions {
  const CentralManagerOptions({
    this.showPowerAlert,
    this.restoreIdentifier,
  });

  final String? restoreIdentifier;
  final bool? showPowerAlert;
}

bool _centralManagerOptionsEqual(CentralManagerOptions? a, CentralManagerOptions? b) {
  return a?.showPowerAlert == b?.showPowerAlert && a?.restoreIdentifier == b?.restoreIdentifier;
}

final class CentralManagerScanOptions {
  const CentralManagerScanOptions({
    this.allowDuplicates,
    this.solicitedServiceUUIDs,
  });

  final bool? allowDuplicates;
  final List<CBUUID>? solicitedServiceUUIDs;
}

final class ConnectPeripheralOptions {
  const ConnectPeripheralOptions({
    this.enableAutoReconnect,
    this.notifyOnConnection,
    this.notifyOnDisconnection,
    this.notifyOnNotification,
    this.enableTransportBridging,
    this.requiresANCS,
    this.startDelay,
  });

  final bool? enableAutoReconnect;
  final bool? enableTransportBridging;
  final bool? notifyOnConnection;
  final bool? notifyOnDisconnection;
  final bool? notifyOnNotification;
  final bool? requiresANCS;
  final double? startDelay;
}

final class ConnectionEventMatchingOptions {
  const ConnectionEventMatchingOptions({
    this.peripheralUUIDs,
    this.serviceUUIDs,
  });

  final List<UUID>? peripheralUUIDs;
  final List<CBUUID>? serviceUUIDs;
}

final class AdvertisementData {
  const AdvertisementData({
    this.localName,
    this.manufacturerData,
    this.serviceData = const {},
    this.serviceUUIDs,
    this.txPowerLevel,
    this.isConnectable,
  });

  final bool? isConnectable;
  final String? localName;
  final Uint8List? manufacturerData;
  final Map<CBUUID, Uint8List> serviceData;
  final List<CBUUID>? serviceUUIDs;
  final int? txPowerLevel;
}

Map<String, Object?>? _centralManagerOptionsToPayload(CentralManagerOptions? options) {
  if (options == null) {
    return null;
  }

  return {
    'showPowerAlert': options.showPowerAlert,
    'restoreIdentifier': options.restoreIdentifier,
  };
}

CentralManagerScanOptions? _centralManagerScanOptionsFromPayload(Map<Object?, Object?> map) {
  return CentralManagerScanOptions(
    allowDuplicates: map['allowDuplicates'] as bool?,
    solicitedServiceUUIDs:
        (map['solicitedServiceUUIDs'] as List<Object?>?)?.map((uuid) => CBUUID(uuid as String)).toList(),
  );
}

Map<String, Object?>? _centralManagerScanOptionsToPayload(CentralManagerScanOptions? options) {
  if (options == null) {
    return null;
  }

  return {
    'allowDuplicates': options.allowDuplicates,
    'solicitedServiceUUIDs': options.solicitedServiceUUIDs?.map((uuid) => uuid.uuidString).toList(),
  };
}

Map<String, Object?>? _connectPeripheralOptionsToPayload(ConnectPeripheralOptions? options) {
  if (options == null) {
    return null;
  }

  return {
    'enableAutoReconnect': options.enableAutoReconnect,
    'notifyOnConnection': options.notifyOnConnection,
    'notifyOnDisconnection': options.notifyOnDisconnection,
    'notifyOnNotification': options.notifyOnNotification,
    'enableTransportBridging': options.enableTransportBridging,
    'requiresANCS': options.requiresANCS,
    'startDelay': options.startDelay,
  };
}

Map<String, Object?>? _connectionEventMatchingOptionsToPayload(ConnectionEventMatchingOptions? options) {
  if (options == null) {
    return null;
  }

  return {
    'peripheralUUIDs': options.peripheralUUIDs?.map((uuid) => uuid.uuidString).toList(),
    'serviceUUIDs': options.serviceUUIDs?.map((uuid) => uuid.uuidString).toList(),
  };
}

AdvertisementData _advertisementDataFromPayload(Map<Object?, Object?> map) {
  final serviceData = <CBUUID, Uint8List>{};
  final rawServiceData = map['serviceData'] as Map?;
  rawServiceData?.forEach((key, value) {
    serviceData[CBUUID(key as String)] = bytesFromObject(value);
  });

  return AdvertisementData(
    isConnectable: map['isConnectable'] as bool?,
    localName: map['localName'] as String?,
    manufacturerData: bytesFromNullable(map['manufacturerData']),
    serviceData: serviceData,
    serviceUUIDs: (map['serviceUUIDs'] as List<Object?>?)?.map((uuid) => CBUUID(uuid as String)).toList(),
    txPowerLevel: (map['txPowerLevel'] as num?)?.toInt(),
  );
}

final class DidDiscoverPeripheralResult {
  const DidDiscoverPeripheralResult({
    required this.peripheral,
    required this.advertisementData,
    required this.rssi,
  });

  final AdvertisementData advertisementData;
  final CBPeripheral peripheral;
  final int? rssi;
}

final class DidFailToConnectPeripheralResult {
  const DidFailToConnectPeripheralResult({
    required this.peripheral,
    required this.error,
  });

  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
}

final class DidDisconnectPeripheralResult {
  const DidDisconnectPeripheralResult({
    required this.peripheral,
    required this.error,
    this.timestamp,
    this.isReconnecting,
  });

  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final bool? isReconnecting;
  final CBPeripheral peripheral;
  final double? timestamp;
}

final class ConnectionEventDidOccurResult {
  const ConnectionEventDidOccurResult({
    required this.event,
    required this.peripheral,
  });

  final CBConnectionEvent event;
  final CBPeripheral peripheral;
}

final class WillRestoreStateResult {
  const WillRestoreStateResult({
    required this.peripherals,
    required this.scanServices,
    required this.scanOptions,
  });

  final List<CBPeripheral> peripherals;
  final CentralManagerScanOptions? scanOptions;
  final List<CBUUID>? scanServices;
}

final class CBCentralManager extends CBManager {
  CBCentralManager._internal({
    this.delegate,
    Object? queue,
    CentralManagerOptions? options,
  })  : _sharedOptions = options,
        super() {
    _ready = _create(options: options);
  }

  static CBCentralManager? _sharedInstance;

  static CBCentralManager get shared => _sharedInstance ??= CBCentralManager._internal();

  static CBCentralManager ensureShared({
    CentralManagerOptions? options,
  }) {
    final existing = _sharedInstance;
    if (existing == null) {
      final manager = CBCentralManager._internal(options: options);
      _sharedInstance = manager;
      return manager;
    }

    if (!_centralManagerOptionsEqual(existing._sharedOptions, options)) {
      throw StateError(
        'CBCentralManager.shared was already created with different options. '
        'Call CBCentralManager.ensureShared(options: ...) before first access to shared.',
      );
    }

    return existing;
  }

  factory CBCentralManager.createIsolated({
    CBCentralManagerDelegate? delegate,
    Object? queue,
    CentralManagerOptions? options,
  }) {
    return CBCentralManager._internal(
      delegate: delegate,
      queue: queue,
      options: options,
    );
  }

  final _host = CoreBluetoothHost.instance;
  final _peripheralsByIdentifier = <String, CBPeripheral>{};
  CBCentralManagerDelegate? delegate;
  final CentralManagerOptions? _sharedOptions;

  late final Future<void> _ready;
  int? _identifier;
  var _isScanning = false;

  StreamSubscription<Map<Object?, Object?>>? _eventsSubscription;

  final _didUpdateStateController = StreamController<CBManagerState>.broadcast();
  final _didDiscoverPeripheralController = StreamController<DidDiscoverPeripheralResult>.broadcast();
  final _didConnectPeripheralController = StreamController<CBPeripheral>.broadcast();
  final _didFailToConnectPeripheralController = StreamController<DidFailToConnectPeripheralResult>.broadcast();
  final _didDisconnectPeripheralController = StreamController<DidDisconnectPeripheralResult>.broadcast();
  final _connectionEventDidOccurController = StreamController<ConnectionEventDidOccurResult>.broadcast();
  final _didUpdateANCSAuthorizationForPeripheralController =
      StreamController<DidUpdateANCSAuthorizationForPeripheralResult>.broadcast();
  final _willRestoreStateController = StreamController<WillRestoreStateResult>.broadcast();
  final _didUpdateNameController = StreamController<DidUpdateNameResult>.broadcast();
  final _didModifyServicesController = StreamController<DidModifyServicesResult>.broadcast();

  bool get isScanning => _isScanning;

  Stream<CBManagerState> get onDidUpdateState => _didUpdateStateController.stream;
  Stream<DidDiscoverPeripheralResult> get onDidDiscoverPeripheral => _didDiscoverPeripheralController.stream;
  Stream<CBPeripheral> get onDidConnectPeripheral => _didConnectPeripheralController.stream;

  Stream<DidFailToConnectPeripheralResult> get onDidFailToConnectPeripheral {
    return _didFailToConnectPeripheralController.stream;
  }

  Stream<DidDisconnectPeripheralResult> get onDidDisconnectPeripheral {
    return _didDisconnectPeripheralController.stream;
  }

  Stream<ConnectionEventDidOccurResult> get onConnectionEventDidOccur {
    return _connectionEventDidOccurController.stream;
  }

  Stream<DidUpdateANCSAuthorizationForPeripheralResult> get onDidUpdateANCSAuthorizationForPeripheral {
    return _didUpdateANCSAuthorizationForPeripheralController.stream;
  }

  Stream<WillRestoreStateResult> get onWillRestoreState => _willRestoreStateController.stream;

  Stream<DidUpdateNameResult> get onDidUpdateName => _didUpdateNameController.stream;
  Stream<DidModifyServicesResult> get onDidModifyServices => _didModifyServicesController.stream;

  static Future<CBManagerAuthorization> get authorization async {
    final rawValue = await CoreBluetoothHost.instance.invokeMethod<int>('centralManager.authorization') ?? 0;
    return cbManagerAuthorizationFromRawValue(rawValue);
  }

  static Future<CBManagerAuthorization> authorizationStatus() async => authorization;

  static Future<bool> supports(CBCentralManagerFeature feature) async {
    return await CoreBluetoothHost.instance.invokeMethod<bool>(
          'centralManager.supports',
          {'feature': feature.rawValue},
        ) ??
        false;
  }

  Future<void> cancelPeripheralConnection(CBPeripheral peripheral) async {
    await _ready;
    await _host.invokeMethod<void>(
      'centralManager.cancelPeripheralConnection',
      {'managerId': _identifier, 'peripheralIdentifier': peripheral.identifier.uuidString},
    );
  }

  Future<void> connect(
    CBPeripheral peripheral, {
    ConnectPeripheralOptions? options,
  }) async {
    await _ready;
    await _host.invokeMethod<void>(
      'centralManager.connect',
      {
        'managerId': _identifier,
        'peripheralIdentifier': peripheral.identifier.uuidString,
        'options': _connectPeripheralOptionsToPayload(options),
      },
    );
  }

  Future<void> dispose() async {
    await _ready;
    await _eventsSubscription?.cancel();
    await _host.invokeMethod<void>('centralManager.dispose', {'managerId': _identifier});
  }

  Future<void> registerForConnectionEvents({
    ConnectionEventMatchingOptions? options,
  }) async {
    await _ready;
    await _host.invokeMethod<void>(
      'centralManager.registerForConnectionEvents',
      {
        'managerId': _identifier,
        'options': _connectionEventMatchingOptionsToPayload(options),
      },
    );
  }

  Future<List<CBPeripheral>> retrieveConnectedPeripherals(List<CBUUID> serviceUUIDs) async {
    await _ready;

    final response = await _host.invokeMethod<List<Object?>>(
      'centralManager.retrieveConnectedPeripherals',
      {
        'managerId': _identifier,
        'serviceUUIDs': serviceUUIDs.map((uuid) => uuid.uuidString).toList(),
      },
    );

    return _decodePeripherals(response);
  }

  Future<List<CBPeripheral>> retrievePeripherals(List<UUID> identifiers) async {
    await _ready;

    final response = await _host.invokeMethod<List<Object?>>(
      'centralManager.retrievePeripherals',
      {
        'managerId': _identifier,
        'identifiers': identifiers.map((identifier) => identifier.uuidString).toList(),
      },
    );

    return _decodePeripherals(response);
  }

  Future<void> scanForPeripherals({
    List<CBUUID>? withServices,
    CentralManagerScanOptions? options,
  }) async {
    await _ready;
    await _host.invokeMethod<void>(
      'centralManager.scanForPeripherals',
      {
        'managerId': _identifier,
        'serviceUUIDs': withServices?.map((uuid) => uuid.uuidString).toList(),
        'options': _centralManagerScanOptionsToPayload(options),
      },
    );
  }

  Future<void> stopScan() async {
    await _ready;
    await _host.invokeMethod<void>('centralManager.stopScan', {'managerId': _identifier});
  }

  Future<void> _create({
    CentralManagerOptions? options,
  }) async {
    final pendingEvents = <Map<Object?, Object?>>[];
    _eventsSubscription = _host.events.listen((event) {
      if (_identifier == null) {
        pendingEvents.add(event);
        return;
      }
      _handleEvent(event);
    });

    final result = Map<Object?, Object?>.from(
      await _host.invokeMethod<Map<Object?, Object?>>(
            'centralManager.create',
            {
              'options': _centralManagerOptionsToPayload(options),
            },
          ) ??
          const <Object?, Object?>{},
    );

    _identifier = (result['managerId'] as num?)?.toInt();
    _applyManagerSnapshot(result);
    for (final event in pendingEvents) {
      _handleEvent(event);
    }
  }

  void _applyManagerSnapshot(Map<Object?, Object?> map) {
    _updateState(cbManagerStateFromRawValue((map['state'] as num?)?.toInt() ?? 0));
    _isScanning = map['isScanning'] as bool? ?? false;
  }

  List<CBPeripheral> _decodePeripherals(List<Object?>? rawList) {
    return (rawList ?? const <Object?>[]).map((raw) {
      return _upsertPeripheral(Map<Object?, Object?>.from(raw as Map));
    }).toList();
  }

  void _handleEvent(Map<Object?, Object?> event) {
    if ((event['managerId'] as num?)?.toInt() != _identifier) {
      return;
    }

    final kind = event['kind'] as String? ?? '';
    final payload = Map<Object?, Object?>.from(event['payload'] as Map? ?? const {});

    switch (kind) {
      case 'didUpdateState':
        _applyManagerSnapshot(payload);
        _didUpdateStateController.add(state);
        delegate?.centralManagerDidUpdateState(this);
      case 'didDiscoverPeripheral':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final advertisementData = _advertisementDataFromPayload(
          Map<Object?, Object?>.from(payload['advertisementData'] as Map? ?? const {}),
        );
        final rssi = (payload['rssi'] as num?)?.toInt();
        _didDiscoverPeripheralController.add(
          DidDiscoverPeripheralResult(
            peripheral: peripheral,
            advertisementData: advertisementData,
            rssi: rssi,
          ),
        );
        delegate?.centralManagerDidDiscover(this, peripheral, advertisementData, rssi);
      case 'didConnectPeripheral':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        peripheral._state = CBPeripheralState.connected;
        _didConnectPeripheralController.add(peripheral);
        delegate?.centralManagerDidConnect(this, peripheral);
      case 'didFailToConnectPeripheral':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        peripheral._state = CBPeripheralState.disconnected;
        final error = cbErrorFromPayload(payload);
        _didFailToConnectPeripheralController.add(
          DidFailToConnectPeripheralResult(
            peripheral: peripheral,
            error: error,
          ),
        );
        delegate?.centralManagerDidFailToConnect(this, peripheral, error);
      case 'didDisconnectPeripheral':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        peripheral._state = CBPeripheralState.disconnected;
        final error = cbErrorFromPayload(payload);
        final timestamp = (payload['timestamp'] as num?)?.toDouble();
        final isReconnecting = payload['isReconnecting'] as bool?;
        _didDisconnectPeripheralController.add(
          DidDisconnectPeripheralResult(
            peripheral: peripheral,
            error: error,
            timestamp: timestamp,
            isReconnecting: isReconnecting,
          ),
        );
        delegate?.centralManagerDidDisconnectPeripheral(
          this,
          peripheral,
          error,
          timestamp: timestamp,
          isReconnecting: isReconnecting,
        );
      case 'connectionEventDidOccur':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final connectionEvent = cbConnectionEventFromRawValue((payload['event'] as num?)?.toInt() ?? 0);
        _connectionEventDidOccurController.add(
          ConnectionEventDidOccurResult(
            event: connectionEvent,
            peripheral: peripheral,
          ),
        );
        delegate?.centralManagerConnectionEventDidOccur(this, connectionEvent, peripheral);
      case 'didUpdateANCSAuthorizationForPeripheral':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final result = DidUpdateANCSAuthorizationForPeripheralResult(peripheral: peripheral);
        _didUpdateANCSAuthorizationForPeripheralController.add(result);
        peripheral._didUpdateANCSAuthorizationController.add(result);
        delegate?.centralManagerDidUpdateANCSAuthorizationFor(this, peripheral);
      case 'willRestoreState':
        final peripherals = _decodePeripherals((payload['peripherals'] as List<Object?>?) ?? const <Object?>[]);
        final scanServices =
            (payload['scanServices'] as List<Object?>?)?.map((uuid) => CBUUID(uuid as String)).toList();
        final scanOptionsMap = payload['scanOptions'] as Map?;
        final state = WillRestoreStateResult(
          peripherals: peripherals,
          scanServices: scanServices,
          scanOptions: scanOptionsMap == null
              ? null
              : _centralManagerScanOptionsFromPayload(Map<Object?, Object?>.from(scanOptionsMap)),
        );
        _willRestoreStateController.add(state);
        delegate?.centralManagerWillRestoreState(this, state);
      case 'peripheralIsReadyToSendWriteWithoutResponse':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        peripheral._canSendWriteWithoutResponse = true;
        peripheral._isReadyToSendWriteWithoutResponseController.add(
          IsReadyToSendWriteWithoutResponseResult(
            peripheral: peripheral,
          ),
        );
        peripheral.delegate?.peripheralIsReadyToSendWriteWithoutResponse(peripheral);
      case 'peripheralDidUpdateName':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        _didUpdateNameController.add(DidUpdateNameResult(peripheral: peripheral));
        peripheral.delegate?.peripheralDidUpdateName(peripheral);
      case 'peripheralDidModifyServices':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final invalidatedServices = (payload['invalidatedServices'] as List<Object?>? ?? const [])
            .map(
              (raw) => CBService.fromMap(
                peripheral: peripheral,
                map: Map<Object?, Object?>.from(raw as Map),
              ),
            )
            .toList();
        _didModifyServicesController.add(
          DidModifyServicesResult(
            peripheral: peripheral,
            invalidatedServices: invalidatedServices,
          ),
        );
        peripheral.delegate?.peripheralDidModifyServices(peripheral, invalidatedServices);
      case 'peripheralDidDiscoverServices':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        peripheral._services = (payload['services'] as List<Object?>? ?? const [])
            .map(
              (raw) => CBService.fromMap(
                peripheral: peripheral,
                map: Map<Object?, Object?>.from(raw as Map),
              ),
            )
            .toList();
        peripheral._didDiscoverServicesController.add(
          DidDiscoverServicesResult(
            peripheral: peripheral,
            error: cbErrorFromPayload(payload),
            services: peripheral.services,
          ),
        );
        peripheral.delegate?.peripheralDidDiscoverServices(
          peripheral,
          peripheral.services,
          cbErrorFromPayload(payload),
        );
      case 'peripheralDidDiscoverIncludedServicesForService':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final service = peripheral._findServiceByHandle(payload['serviceHandle'] as String?);
        if (service == null) {
          return;
        }
        service.updateIncludedServices((payload['includedServices'] as List<Object?>? ?? const [])
            .map(
              (raw) => CBService.fromMap(
                peripheral: peripheral,
                map: Map<Object?, Object?>.from(raw as Map),
              ),
            )
            .toList());
        peripheral._didDiscoverIncludedServicesForServiceController.add(
          DidDiscoverIncludedServicesForServiceResult(
            peripheral: peripheral,
            service: service,
            includedServices: service.includedServices,
            error: cbErrorFromPayload(payload),
          ),
        );
        peripheral.delegate?.peripheralDidDiscoverIncludedServicesForService(
          peripheral,
          service,
          service.includedServices,
          cbErrorFromPayload(payload),
        );
      case 'peripheralDidDiscoverCharacteristicsForService':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final service = peripheral._findServiceByHandle(payload['serviceHandle'] as String?);
        if (service == null) {
          return;
        }
        service.updateCharacteristics((payload['characteristics'] as List<Object?>? ?? const [])
            .map(
              (raw) => CBCharacteristic.fromMap(
                service: service,
                map: Map<Object?, Object?>.from(raw as Map),
              ),
            )
            .toList());
        peripheral._didDiscoverCharacteristicsForServiceController.add(
          DidDiscoverCharacteristicsForServiceResult(
            peripheral: peripheral,
            service: service,
            characteristics: service.characteristics,
            error: cbErrorFromPayload(payload),
          ),
        );
        peripheral.delegate?.peripheralDidDiscoverCharacteristicsForService(
          peripheral,
          service,
          service.characteristics,
          cbErrorFromPayload(payload),
        );
      case 'peripheralDidDiscoverDescriptorsForCharacteristic':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final characteristic = peripheral._findCharacteristicByHandle(payload['characteristicHandle'] as String?);
        if (characteristic == null) {
          return;
        }
        characteristic.updateDescriptors((payload['descriptors'] as List<Object?>? ?? const [])
            .map(
              (raw) => CBDescriptor.fromMap(
                characteristic: characteristic,
                map: Map<Object?, Object?>.from(raw as Map),
              ),
            )
            .toList());
        peripheral._didDiscoverDescriptorsForCharacteristicController.add(
          DidDiscoverDescriptorsForCharacteristicResult(
            peripheral: peripheral,
            characteristic: characteristic,
            descriptors: characteristic.descriptors,
            error: cbErrorFromPayload(payload),
          ),
        );
        peripheral.delegate?.peripheralDidDiscoverDescriptorsForCharacteristic(
          peripheral,
          characteristic,
          characteristic.descriptors,
          cbErrorFromPayload(payload),
        );
      case 'peripheralDidUpdateValueForCharacteristic':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final characteristic = peripheral._findCharacteristicByHandle(payload['characteristicHandle'] as String?);
        if (characteristic == null) {
          return;
        }
        characteristic.updateValue(bytesFromObject(payload['value']));
        peripheral._didUpdateValueForCharacteristicController.add(
          DidUpdateValueForCharacteristicResult(
            peripheral: peripheral,
            characteristic: characteristic,
            error: cbErrorFromPayload(payload),
          ),
        );
        peripheral.delegate?.peripheralDidUpdateValueForCharacteristic(
          peripheral,
          characteristic,
          cbErrorFromPayload(payload),
        );
      case 'peripheralDidWriteValueForCharacteristic':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final characteristic = peripheral._findCharacteristicByHandle(payload['characteristicHandle'] as String?);
        if (characteristic == null) {
          return;
        }
        peripheral._didWriteValueForCharacteristicController.add(
          DidWriteValueForCharacteristicResult(
            peripheral: peripheral,
            characteristic: characteristic,
            error: cbErrorFromPayload(payload),
          ),
        );
        peripheral.delegate?.peripheralDidWriteValueForCharacteristic(
          peripheral,
          characteristic,
          cbErrorFromPayload(payload),
        );
      case 'peripheralDidUpdateNotificationStateForCharacteristic':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final characteristic = peripheral._findCharacteristicByHandle(payload['characteristicHandle'] as String?);
        if (characteristic == null) {
          return;
        }
        characteristic.updateIsNotifying(payload['isNotifying'] as bool? ?? characteristic.isNotifying);
        peripheral._didUpdateNotificationStateForCharacteristicController.add(
          DidUpdateNotificationStateForCharacteristicResult(
            peripheral: peripheral,
            characteristic: characteristic,
            error: cbErrorFromPayload(payload),
          ),
        );
        peripheral.delegate?.peripheralDidUpdateNotificationStateForCharacteristic(
          peripheral,
          characteristic,
          cbErrorFromPayload(payload),
        );
      case 'peripheralDidReadRSSI':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        peripheral._didReadRSSIController.add(
          DidReadRssiResult(
            peripheral: peripheral,
            rssi: (payload['rssi'] as num?)?.toInt(),
            error: cbErrorFromPayload(payload),
          ),
        );
        peripheral.delegate?.peripheralDidReadRSSI(
          peripheral,
          (payload['rssi'] as num?)?.toInt(),
          cbErrorFromPayload(payload),
        );
      case 'peripheralDidOpenL2CAPChannel':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final channelMap = payload['channel'] as Map?;
        final channel = channelMap == null
            ? null
            : CBL2CAPChannel.fromMap(
                manager: this,
                map: Map<Object?, Object?>.from(channelMap),
              );
        final error = cbErrorFromPayload(payload);
        peripheral._didOpenL2CAPChannelController.add(
          DidOpenL2CAPChannelResult(
            peripheral: peripheral,
            channel: channel,
            error: error,
          ),
        );
        peripheral.delegate?.peripheralDidOpen(peripheral, channel, error);
      case 'peripheralDidUpdateValueForDescriptor':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final descriptor = peripheral._findDescriptorByHandle(payload['descriptorHandle'] as String?);
        if (descriptor == null) {
          return;
        }
        descriptor.updateValue(payload['value']);
        peripheral._didUpdateValueForDescriptorController.add(
          DidUpdateValueForDescriptorResult(
            peripheral: peripheral,
            descriptor: descriptor,
            error: cbErrorFromPayload(payload),
          ),
        );
        peripheral.delegate?.peripheralDidUpdateValueForDescriptor(
          peripheral,
          descriptor,
          cbErrorFromPayload(payload),
        );
      case 'peripheralDidWriteValueForDescriptor':
        final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
        final descriptor = peripheral._findDescriptorByHandle(payload['descriptorHandle'] as String?);
        if (descriptor == null) {
          return;
        }
        peripheral._didWriteValueForDescriptorController.add(
          DidWriteValueForDescriptorResult(
            peripheral: peripheral,
            descriptor: descriptor,
            error: cbErrorFromPayload(payload),
          ),
        );
        peripheral.delegate?.peripheralDidWriteValueForDescriptor(
          peripheral,
          descriptor,
          cbErrorFromPayload(payload),
        );
    }
  }

  CBPeripheral _upsertPeripheral(Map<Object?, Object?> map) {
    final identifier = UUID(map['identifier'] as String? ?? '00000000-0000-0000-0000-000000000000');
    final peripheral = _peripheralsByIdentifier.putIfAbsent(
      identifier.uuidString,
      () => CBPeripheral._(manager: this, identifier: identifier),
    );

    peripheral._name = map['name'] as String?;
    peripheral._ancsAuthorized = map['ancsAuthorized'] as bool? ?? false;
    peripheral._canSendWriteWithoutResponse = map['canSendWriteWithoutResponse'] as bool? ?? true;
    peripheral._state = cbPeripheralStateFromRawValue((map['state'] as num?)?.toInt() ?? 0);
    return peripheral;
  }
}
