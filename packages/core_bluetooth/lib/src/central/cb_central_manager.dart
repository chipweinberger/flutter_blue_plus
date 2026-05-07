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
  return (a?.showPowerAlert ?? true) == (b?.showPowerAlert ?? true) && a?.restoreIdentifier == b?.restoreIdentifier;
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
    this.overflowServiceUUIDs,
    this.solicitedServiceUUIDs,
    this.txPowerLevel,
    this.isConnectable,
  });

  final bool? isConnectable;
  final String? localName;
  final Uint8List? manufacturerData;
  final Map<CBUUID, Uint8List> serviceData;
  final List<CBUUID>? serviceUUIDs;

  /// Service UUIDs reported in the advertisement's overflow area.
  final List<CBUUID>? overflowServiceUUIDs;

  /// Service UUIDs solicited by the advertiser.
  final List<CBUUID>? solicitedServiceUUIDs;
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
    overflowServiceUUIDs:
        (map['overflowServiceUUIDs'] as List<Object?>?)?.map((uuid) => CBUUID(uuid as String)).toList(),
    solicitedServiceUUIDs:
        (map['solicitedServiceUUIDs'] as List<Object?>?)?.map((uuid) => CBUUID(uuid as String)).toList(),
    txPowerLevel: (map['txPowerLevel'] as num?)?.toInt(),
  );
}

final class DidDiscoverPeripheralResult {
  const DidDiscoverPeripheralResult({
    required this.peripheral,
    this.peripheralName,
    required this.advertisementData,
    required this.rssi,
  });

  final AdvertisementData advertisementData;
  final String? peripheralName;
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
    bool shared = false,
  })  : _sharedOptions = options,
        _shared = shared,
        super() {
    // Start eagerly while exposing failures through ready and allowing retries.
    unawaited(ready.catchError((Object error) {}));
  }

  static CBCentralManager? _sharedInstance;

  static CBCentralManager get shared => _sharedInstance ??= CBCentralManager._internal(shared: true);

  static CBCentralManager ensureShared({
    CentralManagerOptions? options,
  }) {
    final existing = _sharedInstance;
    if (existing == null) {
      final manager = CBCentralManager._internal(options: options, shared: true);
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

  final bool _shared;
  bool _disposed = false;
  Future<void>? _creation;
  Future<void>? _disposal;
  int? _identifier;
  var _isScanning = false;
  int _scanRevision = 0;
  var _wasReattached = false;

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

  /// Completes after the native manager and its initial state are available.
  Future<void> get ready {
    if (_disposed) return Future.error(StateError('CBCentralManager has been disposed'));
    return _creation ??= _create(options: _sharedOptions, shared: _shared);
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('CBCentralManager has been disposed');
  }

  Future<void> _ensureReady() async {
    _checkNotDisposed();
    await ready;
    _checkNotDisposed();
  }

  /// Whether the native manager has been created and its initial snapshot applied.
  bool get isInitialized => !_disposed && _identifier != null;

  /// Whether this Dart object reattached to a shared native manager after restart.
  bool get wasReattached => _wasReattached;

  /// Connections last observed through this manager's snapshots and callbacks.
  List<CBPeripheral> get connectedPeripherals => _peripheralsByIdentifier.values
      .where((peripheral) => peripheral.state == CBPeripheralState.connected)
      .toList(growable: false);

  /// Local adapter name, matching the system device name on iOS.
  static Future<String> get adapterName async =>
      await CoreBluetoothHost.instance.invokeMethod<String>('centralManager.adapterName') ?? '';

  /// Stops scanning and cancels this manager's established connections.
  /// Returns the peripherals whose disconnection callbacks are still pending.
  Future<List<CBPeripheral>> disconnectAllPeripherals() async {
    await _ensureReady();
    final peripherals =
        await _host.invokeMethod<List<Object?>>('centralManager.disconnectAllPeripherals', {'managerId': _identifier});
    _checkNotDisposed();
    _isScanning = false;
    return _decodePeripherals(peripherals);
  }

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
    await _ensureReady();
    await _host.invokeMethod<void>(
      'centralManager.cancelPeripheralConnection',
      {'managerId': _identifier, 'peripheralIdentifier': peripheral.identifier.uuidString},
    );
  }

  Future<void> connect(
    CBPeripheral peripheral, {
    ConnectPeripheralOptions? options,
  }) async {
    await _ensureReady();
    await _host.invokeMethod<void>(
      'centralManager.connect',
      {
        'managerId': _identifier,
        'peripheralIdentifier': peripheral.identifier.uuidString,
        'options': _connectPeripheralOptionsToPayload(options),
      },
    );
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    try {
      try {
        await _creation;
      } catch (_) {
        // Failed creation has no native manager to release.
      }
      await _eventsSubscription?.cancel();
      if (_identifier != null) {
        await _host.invokeMethod<void>('centralManager.dispose', {'managerId': _identifier});
      }
    } finally {
      _eventsSubscription = null;
      _identifier = null;
      _isScanning = false;
      _peripheralsByIdentifier.clear();
      if (identical(_sharedInstance, this)) _sharedInstance = null;
    }
  }

  Future<void> registerForConnectionEvents({
    ConnectionEventMatchingOptions? options,
  }) async {
    await _ensureReady();
    await _host.invokeMethod<void>(
      'centralManager.registerForConnectionEvents',
      {
        'managerId': _identifier,
        'options': _connectionEventMatchingOptionsToPayload(options),
      },
    );
  }

  Future<List<CBPeripheral>> retrieveConnectedPeripherals(List<CBUUID> serviceUUIDs) async {
    await _ensureReady();

    final response = await _host.invokeMethod<List<Object?>>(
      'centralManager.retrieveConnectedPeripherals',
      {
        'managerId': _identifier,
        'serviceUUIDs': serviceUUIDs.map((uuid) => uuid.uuidString).toList(),
      },
    );

    _checkNotDisposed();
    return _decodePeripherals(response);
  }

  Future<List<CBPeripheral>> retrievePeripherals(List<UUID> identifiers) async {
    await _ensureReady();

    final response = await _host.invokeMethod<List<Object?>>(
      'centralManager.retrievePeripherals',
      {
        'managerId': _identifier,
        'identifiers': identifiers.map((identifier) => identifier.uuidString).toList(),
      },
    );

    _checkNotDisposed();
    return _decodePeripherals(response);
  }

  /// Scans using CoreBluetooth's service filters and radio options.
  ///
  /// [advertisementDivisor] is a package extension: native code delivers the first
  /// discovery per device, then every Nth discovery, before channel serialization.
  /// All native discoveries count, including those later rejected by Dart filters.
  /// Defaults to 1; valid values are 1–2147483647. Each scan resets its counters.
  Future<void> scanForPeripherals({
    List<CBUUID>? withServices,
    CentralManagerScanOptions? options,
    int advertisementDivisor = 1,
  }) async {
    RangeError.checkValueInInterval(advertisementDivisor, 1, 2147483647, 'advertisementDivisor');
    await _ensureReady();
    final revision = ++_scanRevision;
    final scanning = await _host.invokeMethod<bool>(
      'centralManager.scanForPeripherals',
      {
        'managerId': _identifier,
        'serviceUUIDs': withServices?.map((uuid) => uuid.uuidString).toList(),
        'options': _centralManagerScanOptionsToPayload(options),
        'advertisementDivisor': advertisementDivisor,
      },
    );
    _checkNotDisposed();
    if (revision == _scanRevision) {
      _isScanning = state == CBManagerState.poweredOn && (scanning ?? false);
    }
  }

  Future<void> stopScan() async {
    await _ensureReady();
    final revision = ++_scanRevision;
    await _host.invokeMethod<void>('centralManager.stopScan', {'managerId': _identifier});
    _checkNotDisposed();
    if (revision == _scanRevision) _isScanning = false;
  }

  Future<void> _create({
    CentralManagerOptions? options,
    required bool shared,
  }) async {
    final pendingEvents = <Map<Object?, Object?>>[];
    _eventsSubscription = _host.events.listen((event) {
      if (_disposed) return;
      if (_identifier == null) {
        pendingEvents.add(event);
        return;
      }
      _handleEvent(event);
    });

    try {
      final result = Map<Object?, Object?>.from(
        await _host.invokeMethod<Map<Object?, Object?>>(
              'centralManager.create',
              {
                'options': _centralManagerOptionsToPayload(options),
                'shared': shared,
              },
            ) ??
            const <Object?, Object?>{},
      );

      _identifier = (result['managerId'] as num?)?.toInt();
      if (_disposed) return;
      _wasReattached = result['wasReattached'] as bool? ?? false;
      _applyManagerSnapshot(result);
      for (final event in pendingEvents) {
        // Match ordinary stream delivery: a callback error is not a creation failure.
        Zone.current.runGuarded(() => _handleEvent(event));
      }
    } catch (_) {
      await _eventsSubscription?.cancel();
      _eventsSubscription = null;
      _identifier = null;
      _creation = null;
      _isScanning = false;
      _peripheralsByIdentifier.clear();
      rethrow;
    } finally {
      pendingEvents.clear();
    }
  }

  void _applyManagerSnapshot(Map<Object?, Object?> map) {
    _updateState(cbManagerStateFromRawValue((map['state'] as num?)?.toInt() ?? 0));
    _isScanning = state == CBManagerState.poweredOn && (map['isScanning'] as bool? ?? false);
    if (state != CBManagerState.poweredOn) {
      _scanRevision++;
      // Power-off need not deliver a disconnect callback for each peripheral.
      for (final peripheral in _peripheralsByIdentifier.values) {
        peripheral._state = CBPeripheralState.disconnected;
        peripheral._clearGattCache();
      }
    }
  }

  List<CBPeripheral> _decodePeripherals(List<Object?>? rawList) {
    return (rawList ?? const <Object?>[]).map((raw) {
      return _upsertPeripheral(Map<Object?, Object?>.from(raw as Map));
    }).toList();
  }

  CBPeripheral _upsertPeripheral(Map<Object?, Object?> map) {
    final identifier = UUID(map['identifier'] as String? ?? '00000000-0000-0000-0000-000000000000');
    final peripheral = _peripheralsByIdentifier.putIfAbsent(
      identifier.uuidString,
      () => CBPeripheral._(manager: this, identifier: identifier),
    );

    if (map.containsKey('services')) {
      peripheral._services = (map['services'] as List<Object?>?)
          ?.map((raw) => CBService.fromMap(peripheral: peripheral, map: Map<Object?, Object?>.from(raw as Map)))
          .toList();
      peripheral._pruneGattCache();
    }
    peripheral._name = map['name'] as String?;
    peripheral._ancsAuthorized = map['ancsAuthorized'] as bool? ?? false;
    peripheral._canSendWriteWithoutResponse = map['canSendWriteWithoutResponse'] as bool? ?? true;
    peripheral._state = cbPeripheralStateFromRawValue((map['state'] as num?)?.toInt() ?? 0);
    return peripheral;
  }

  void _handleStateUpdate(Map<Object?, Object?> payload) {
    _applyManagerSnapshot(payload);
    _didUpdateStateController.add(state);
    delegate?.centralManagerDidUpdateState(this);
  }

  void _handleDiscoveredPeripheral(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final advertisementData = _advertisementDataFromPayload(
      Map<Object?, Object?>.from(payload['advertisementData'] as Map? ?? const {}),
    );
    final rssi = (payload['rssi'] as num?)?.toInt();
    _didDiscoverPeripheralController.add(
      DidDiscoverPeripheralResult(
        peripheral: peripheral,
        peripheralName: peripheral.name,
        advertisementData: advertisementData,
        rssi: rssi,
      ),
    );
    delegate?.centralManagerDidDiscover(this, peripheral, advertisementData, rssi);
  }

  void _handleConnectedPeripheral(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    peripheral._state = CBPeripheralState.connected;
    _didConnectPeripheralController.add(peripheral);
    delegate?.centralManagerDidConnect(this, peripheral);
  }

  void _handleFailedConnection(Map<Object?, Object?> payload) {
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
  }

  void _handleDisconnectedPeripheral(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    peripheral._clearGattCache();
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
  }

  void _handleConnectionEvent(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final connectionEvent = cbConnectionEventFromRawValue((payload['event'] as num?)?.toInt() ?? 0);
    _connectionEventDidOccurController.add(
      ConnectionEventDidOccurResult(
        event: connectionEvent,
        peripheral: peripheral,
      ),
    );
    delegate?.centralManagerConnectionEventDidOccur(this, connectionEvent, peripheral);
  }

  void _handleANCSAuthorizationUpdate(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final result = DidUpdateANCSAuthorizationForPeripheralResult(peripheral: peripheral);
    _didUpdateANCSAuthorizationForPeripheralController.add(result);
    peripheral._didUpdateANCSAuthorizationController.add(result);
    delegate?.centralManagerDidUpdateANCSAuthorizationFor(this, peripheral);
  }

  void _handleRestoredState(Map<Object?, Object?> payload) {
    final peripherals = _decodePeripherals((payload['peripherals'] as List<Object?>?) ?? const <Object?>[]);
    final scanServices = (payload['scanServices'] as List<Object?>?)?.map((uuid) => CBUUID(uuid as String)).toList();
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
  }

  void _handleWriteReadiness(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    peripheral._canSendWriteWithoutResponse = true;
    peripheral._isReadyToSendWriteWithoutResponseController.add(
      IsReadyToSendWriteWithoutResponseResult(
        peripheral: peripheral,
      ),
    );
    peripheral.delegate?.peripheralIsReadyToSendWriteWithoutResponse(peripheral);
  }

  void _handleNameUpdate(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final update = DidUpdateNameResult(peripheral: peripheral, name: peripheral.name);
    _didUpdateNameController.add(update);
    peripheral._didUpdateNameController.add(update);
    peripheral.delegate?.peripheralDidUpdateName(peripheral);
  }

  void _handleModifiedServices(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final invalidatedServices = (payload['invalidatedServices'] as List<Object?>? ?? const [])
        .map(
          (raw) => CBService.fromMap(
            peripheral: peripheral,
            map: Map<Object?, Object?>.from(raw as Map),
          ),
        )
        .toList();
    if (payload.containsKey('services')) {
      peripheral._services = (payload['services'] as List<Object?>?)
          ?.map((raw) => CBService.fromMap(peripheral: peripheral, map: Map<Object?, Object?>.from(raw as Map)))
          .toList();
      peripheral._pruneGattCache();
    }
    final update = DidModifyServicesResult(
        peripheral: peripheral, invalidatedServices: invalidatedServices, name: peripheral.name);
    _didModifyServicesController.add(update);
    peripheral._didModifyServicesController.add(update);
    peripheral.delegate?.peripheralDidModifyServices(peripheral, invalidatedServices);
  }

  void _handleDiscoveredServices(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    peripheral._services = (payload['services'] as List<Object?>?)
        ?.map(
          (raw) => CBService.fromMap(
            peripheral: peripheral,
            map: Map<Object?, Object?>.from(raw as Map),
          ),
        )
        .toList();
    peripheral._pruneGattCache();
    final error = cbErrorFromPayload(payload);
    peripheral._didDiscoverServicesController.add(
      DidDiscoverServicesResult(
        peripheral: peripheral,
        error: error,
        services: peripheral.services,
      ),
    );
    peripheral.delegate?.peripheralDidDiscoverServices(
      peripheral,
      peripheral.services,
      error,
    );
  }

  void _handleDiscoveredIncludedServices(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final service = peripheral._findServiceByHandle(payload['serviceHandle'] as String?);
    if (service == null) {
      return;
    }
    service.updateIncludedServices((payload['includedServices'] as List<Object?>?)
        ?.map(
          (raw) => CBService.fromMap(
            peripheral: peripheral,
            map: Map<Object?, Object?>.from(raw as Map),
          ),
        )
        .toList());
    peripheral._pruneGattCache();
    final error = cbErrorFromPayload(payload);
    peripheral._didDiscoverIncludedServicesForServiceController.add(
      DidDiscoverIncludedServicesForServiceResult(
        peripheral: peripheral,
        service: service,
        includedServices: service.includedServices,
        error: error,
      ),
    );
    peripheral.delegate?.peripheralDidDiscoverIncludedServicesForService(
      peripheral,
      service,
      service.includedServices,
      error,
    );
  }

  void _handleDiscoveredCharacteristics(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final service = peripheral._findServiceByHandle(payload['serviceHandle'] as String?);
    if (service == null) {
      return;
    }
    service.updateCharacteristics((payload['characteristics'] as List<Object?>?)
        ?.map(
          (raw) => CBCharacteristic.fromMap(
            service: service,
            map: Map<Object?, Object?>.from(raw as Map),
          ),
        )
        .toList());
    peripheral._pruneGattCache();
    final error = cbErrorFromPayload(payload);
    peripheral._didDiscoverCharacteristicsForServiceController.add(
      DidDiscoverCharacteristicsForServiceResult(
        peripheral: peripheral,
        service: service,
        characteristics: service.characteristics,
        error: error,
      ),
    );
    peripheral.delegate?.peripheralDidDiscoverCharacteristicsForService(
      peripheral,
      service,
      service.characteristics,
      error,
    );
  }

  void _handleDiscoveredDescriptors(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final characteristic = peripheral._findCharacteristicByHandle(payload['characteristicHandle'] as String?);
    if (characteristic == null) {
      return;
    }
    characteristic.updateDescriptors((payload['descriptors'] as List<Object?>?)
        ?.map(
          (raw) => CBDescriptor.fromMap(
            characteristic: characteristic,
            map: Map<Object?, Object?>.from(raw as Map),
          ),
        )
        .toList());
    peripheral._pruneGattCache();
    final error = cbErrorFromPayload(payload);
    peripheral._didDiscoverDescriptorsForCharacteristicController.add(
      DidDiscoverDescriptorsForCharacteristicResult(
        peripheral: peripheral,
        characteristic: characteristic,
        descriptors: characteristic.descriptors,
        error: error,
      ),
    );
    peripheral.delegate?.peripheralDidDiscoverDescriptorsForCharacteristic(
      peripheral,
      characteristic,
      characteristic.descriptors,
      error,
    );
  }

  void _handleCharacteristicValue(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final characteristic = peripheral._findCharacteristicByHandle(payload['characteristicHandle'] as String?);
    if (characteristic == null) {
      return;
    }
    characteristic.updateValue(bytesFromNullable(payload['value']));
    final error = cbErrorFromPayload(payload);
    peripheral._didUpdateValueForCharacteristicController.add(
      DidUpdateValueForCharacteristicResult(
        peripheral: peripheral,
        characteristic: characteristic,
        error: error,
        value: characteristic.value,
      ),
    );
    peripheral.delegate?.peripheralDidUpdateValueForCharacteristic(
      peripheral,
      characteristic,
      error,
    );
  }

  void _handleCharacteristicWrite(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final characteristic = peripheral._findCharacteristicByHandle(payload['characteristicHandle'] as String?);
    if (characteristic == null) {
      return;
    }
    final error = cbErrorFromPayload(payload);
    peripheral._didWriteValueForCharacteristicController.add(
      DidWriteValueForCharacteristicResult(
        peripheral: peripheral,
        characteristic: characteristic,
        error: error,
      ),
    );
    peripheral.delegate?.peripheralDidWriteValueForCharacteristic(
      peripheral,
      characteristic,
      error,
    );
  }

  void _handleNotificationState(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final characteristic = peripheral._findCharacteristicByHandle(payload['characteristicHandle'] as String?);
    if (characteristic == null) {
      return;
    }
    characteristic.updateIsNotifying(payload['isNotifying'] as bool? ?? characteristic.isNotifying);
    final error = cbErrorFromPayload(payload);
    peripheral._didUpdateNotificationStateForCharacteristicController.add(
      DidUpdateNotificationStateForCharacteristicResult(
        peripheral: peripheral,
        characteristic: characteristic,
        error: error,
        isNotifying: characteristic.isNotifying,
      ),
    );
    peripheral.delegate?.peripheralDidUpdateNotificationStateForCharacteristic(
      peripheral,
      characteristic,
      error,
    );
  }

  void _handleRSSIRead(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final error = cbErrorFromPayload(payload);
    peripheral._didReadRSSIController.add(
      DidReadRssiResult(
        peripheral: peripheral,
        rssi: (payload['rssi'] as num?)?.toInt(),
        error: error,
      ),
    );
    peripheral.delegate?.peripheralDidReadRSSI(
      peripheral,
      (payload['rssi'] as num?)?.toInt(),
      error,
    );
  }

  void _handleOpenedL2CAPChannel(Map<Object?, Object?> payload) {
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
  }

  void _handleDescriptorValue(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final descriptor = peripheral._findDescriptorByHandle(payload['descriptorHandle'] as String?);
    if (descriptor == null) {
      return;
    }
    descriptor.updateValue(payload['value']);
    final error = cbErrorFromPayload(payload);
    peripheral._didUpdateValueForDescriptorController.add(
      DidUpdateValueForDescriptorResult(
        peripheral: peripheral,
        descriptor: descriptor,
        error: error,
        value: descriptor.value,
      ),
    );
    peripheral.delegate?.peripheralDidUpdateValueForDescriptor(
      peripheral,
      descriptor,
      error,
    );
  }

  void _handleDescriptorWrite(Map<Object?, Object?> payload) {
    final peripheral = _upsertPeripheral(Map<Object?, Object?>.from(payload['peripheral'] as Map));
    final descriptor = peripheral._findDescriptorByHandle(payload['descriptorHandle'] as String?);
    if (descriptor == null) {
      return;
    }
    final error = cbErrorFromPayload(payload);
    peripheral._didWriteValueForDescriptorController.add(
      DidWriteValueForDescriptorResult(
        peripheral: peripheral,
        descriptor: descriptor,
        error: error,
      ),
    );
    peripheral.delegate?.peripheralDidWriteValueForDescriptor(
      peripheral,
      descriptor,
      error,
    );
  }

  void _handleEvent(Map<Object?, Object?> event) {
    if (_disposed || (event['managerId'] as num?)?.toInt() != _identifier) {
      return;
    }

    final kind = event['kind'] as String? ?? '';
    final payload = Map<Object?, Object?>.from(event['payload'] as Map? ?? const {});

    switch (kind) {
      case 'didUpdateState':
        _handleStateUpdate(payload);
      case 'didDiscoverPeripheral':
        _handleDiscoveredPeripheral(payload);
      case 'didConnectPeripheral':
        _handleConnectedPeripheral(payload);
      case 'didFailToConnectPeripheral':
        _handleFailedConnection(payload);
      case 'didDisconnectPeripheral':
        _handleDisconnectedPeripheral(payload);
      case 'connectionEventDidOccur':
        _handleConnectionEvent(payload);
      case 'didUpdateANCSAuthorizationForPeripheral':
        _handleANCSAuthorizationUpdate(payload);
      case 'willRestoreState':
        _handleRestoredState(payload);
      case 'peripheralIsReadyToSendWriteWithoutResponse':
        _handleWriteReadiness(payload);
      case 'peripheralDidUpdateName':
        _handleNameUpdate(payload);
      case 'peripheralDidModifyServices':
        _handleModifiedServices(payload);
      case 'peripheralDidDiscoverServices':
        _handleDiscoveredServices(payload);
      case 'peripheralDidDiscoverIncludedServicesForService':
        _handleDiscoveredIncludedServices(payload);
      case 'peripheralDidDiscoverCharacteristicsForService':
        _handleDiscoveredCharacteristics(payload);
      case 'peripheralDidDiscoverDescriptorsForCharacteristic':
        _handleDiscoveredDescriptors(payload);
      case 'peripheralDidUpdateValueForCharacteristic':
        _handleCharacteristicValue(payload);
      case 'peripheralDidWriteValueForCharacteristic':
        _handleCharacteristicWrite(payload);
      case 'peripheralDidUpdateNotificationStateForCharacteristic':
        _handleNotificationState(payload);
      case 'peripheralDidReadRSSI':
        _handleRSSIRead(payload);
      case 'peripheralDidOpenL2CAPChannel':
        _handleOpenedL2CAPChannel(payload);
      case 'peripheralDidUpdateValueForDescriptor':
        _handleDescriptorValue(payload);
      case 'peripheralDidWriteValueForDescriptor':
        _handleDescriptorWrite(payload);
    }
  }
}
