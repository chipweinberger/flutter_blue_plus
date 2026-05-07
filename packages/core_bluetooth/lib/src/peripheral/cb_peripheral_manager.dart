part of '../core_bluetooth.dart';

final class PeripheralManagerOptions {
  const PeripheralManagerOptions({
    this.showPowerAlert,
    this.restoreIdentifier,
  });

  final String? restoreIdentifier;
  final bool? showPowerAlert;
}

bool _peripheralManagerOptionsEqual(PeripheralManagerOptions? a, PeripheralManagerOptions? b) {
  return a?.showPowerAlert == b?.showPowerAlert && a?.restoreIdentifier == b?.restoreIdentifier;
}

final class PeripheralManagerAdvertisingData {
  const PeripheralManagerAdvertisingData({
    this.localName,
    this.serviceUUIDs,
  });

  final String? localName;
  final List<CBUUID>? serviceUUIDs;
}

Map<String, Object?>? _peripheralManagerOptionsToPayload(PeripheralManagerOptions? options) {
  if (options == null) {
    return null;
  }

  return {
    'showPowerAlert': options.showPowerAlert,
    'restoreIdentifier': options.restoreIdentifier,
  };
}

PeripheralManagerAdvertisingData _peripheralManagerAdvertisingDataFromPayload(Map<Object?, Object?> map) {
  return PeripheralManagerAdvertisingData(
    localName: map['localName'] as String?,
    serviceUUIDs: (map['serviceUUIDs'] as List<Object?>?)?.map((uuid) => CBUUID(uuid as String)).toList(),
  );
}

Map<String, Object?>? _peripheralManagerAdvertisingDataToPayload(
  PeripheralManagerAdvertisingData? advertisementData,
) {
  if (advertisementData == null) {
    return null;
  }

  return {
    'localName': advertisementData.localName,
    'serviceUUIDs': advertisementData.serviceUUIDs?.map((uuid) => uuid.uuidString).toList(),
  };
}

final class PeripheralManagerWillRestoreStateResult {
  const PeripheralManagerWillRestoreStateResult({
    required this.advertisingData,
    required this.services,
  });

  final PeripheralManagerAdvertisingData? advertisingData;
  final List<CBMutableService> services;
}

final class PeripheralManagerDidStartAdvertisingResult {
  const PeripheralManagerDidStartAdvertisingResult({
    required this.error,
  });

  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
}

final class DidAddServiceResult {
  const DidAddServiceResult({
    required this.service,
    required this.error,
  });

  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBMutableService service;
}

final class DidSubscribeToCharacteristicResult {
  const DidSubscribeToCharacteristicResult({
    required this.central,
    required this.characteristic,
  });

  final CBCentral central;
  final CBMutableCharacteristic characteristic;
}

final class DidUnsubscribeFromCharacteristicResult {
  const DidUnsubscribeFromCharacteristicResult({
    required this.central,
    required this.characteristic,
  });

  final CBCentral central;
  final CBMutableCharacteristic characteristic;
}

final class IsReadyToUpdateSubscribersResult {
  const IsReadyToUpdateSubscribersResult();
}

final class DidReceiveReadRequestResult {
  const DidReceiveReadRequestResult({
    required this.request,
  });

  final CBATTRequest request;
}

final class DidReceiveWriteRequestsResult {
  const DidReceiveWriteRequestsResult({
    required this.requests,
  });

  final List<CBATTRequest> requests;
}

final class DidPublishL2CAPChannelResult {
  const DidPublishL2CAPChannelResult({
    required this.psm,
    required this.error,
  });

  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBL2CAPPSM psm;
}

final class DidUnpublishL2CAPChannelResult {
  const DidUnpublishL2CAPChannelResult({
    required this.psm,
    required this.error,
  });

  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBL2CAPPSM psm;
}

final class PeripheralManagerDidOpenL2CAPChannelResult {
  const PeripheralManagerDidOpenL2CAPChannelResult({
    required this.channel,
    required this.error,
  });

  final CBL2CAPChannel? channel;
  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
}

// Re-adding the same service creates a new revision without losing the outcome of an older removal.
final class _ServiceRevision {
  bool isPublished = false;
  bool isRemoved = false;
}

final class CBPeripheralManager extends CBManager {
  static CBPeripheralManager? _sharedInstance;

  static CBPeripheralManager get shared => _sharedInstance ??= CBPeripheralManager._internal(shared: true);

  static CBPeripheralManager ensureShared({
    CBPeripheralManagerDelegate? delegate,
    Object? queue,
    PeripheralManagerOptions? options,
  }) {
    final existing = _sharedInstance;
    if (existing == null) {
      final manager = CBPeripheralManager._internal(
        delegate: delegate,
        queue: queue,
        options: options,
        shared: true,
      );
      _sharedInstance = manager;
      return manager;
    }

    if (!_peripheralManagerOptionsEqual(existing._sharedOptions, options)) {
      throw StateError(
        'CBPeripheralManager.shared was already created with different options. '
        'Call CBPeripheralManager.ensureShared(options: ...) before first access to shared.',
      );
    }

    if (delegate != null) {
      existing.delegate = delegate;
    }

    return existing;
  }

  factory CBPeripheralManager.createIsolated({
    CBPeripheralManagerDelegate? delegate,
    Object? queue,
    PeripheralManagerOptions? options,
  }) {
    return CBPeripheralManager.init(
      delegate: delegate,
      queue: queue,
      options: options,
    );
  }

  CBPeripheralManager({
    CBPeripheralManagerDelegate? delegate,
    Object? queue,
    PeripheralManagerOptions? options,
  }) : this.init(
          delegate: delegate,
          queue: queue,
          options: options,
        );

  CBPeripheralManager.init({
    CBPeripheralManagerDelegate? delegate,
    Object? queue,
    PeripheralManagerOptions? options,
  }) : this._internal(delegate: delegate, queue: queue, options: options);

  CBPeripheralManager._internal({
    this.delegate,
    Object? queue,
    PeripheralManagerOptions? options,
    bool shared = false,
  })  : _sharedOptions = options,
        _shared = shared,
        super() {
    // Start eagerly while exposing failures through ready and allowing retries.
    unawaited(ready.catchError((Object error) {}));
  }

  CBPeripheralManager.delegateQueue(
    CBPeripheralManagerDelegate? delegate,
    Object? queue,
  ) : this.init(
          delegate: delegate,
          queue: queue,
        );

  CBPeripheralManager.delegateQueueOptions(
    CBPeripheralManagerDelegate? delegate,
    Object? queue,
    PeripheralManagerOptions? options,
  ) : this.init(
          delegate: delegate,
          queue: queue,
          options: options,
        );

  final _host = CoreBluetoothHost.instance;

  CBPeripheralManagerDelegate? delegate;
  final PeripheralManagerOptions? _sharedOptions;
  final bool _shared;

  bool _disposed = false;
  Future<void>? _creation;
  Future<void>? _disposal;
  int? _identifier;
  var _isAdvertising = false;
  var _advertisingStartRevision = 0;
  var _advertisingStopped = false;
  final _services = <CBMutableService>[];

  StreamSubscription<Map<Object?, Object?>>? _eventsSubscription;

  final _didUpdateStateController = StreamController<CBManagerState>.broadcast();
  final _willRestoreStateController = StreamController<PeripheralManagerWillRestoreStateResult>.broadcast();
  final _didStartAdvertisingController = StreamController<PeripheralManagerDidStartAdvertisingResult>.broadcast();
  final _didAddServiceController = StreamController<DidAddServiceResult>.broadcast();
  final _didSubscribeToCharacteristicController = StreamController<DidSubscribeToCharacteristicResult>.broadcast();
  final _didUnsubscribeFromCharacteristicController =
      StreamController<DidUnsubscribeFromCharacteristicResult>.broadcast();
  final _isReadyToUpdateSubscribersController = StreamController<IsReadyToUpdateSubscribersResult>.broadcast();
  final _didReceiveReadRequestController = StreamController<DidReceiveReadRequestResult>.broadcast();
  final _didReceiveWriteRequestsController = StreamController<DidReceiveWriteRequestsResult>.broadcast();
  final _didPublishL2CAPChannelController = StreamController<DidPublishL2CAPChannelResult>.broadcast();
  final _didUnpublishL2CAPChannelController = StreamController<DidUnpublishL2CAPChannelResult>.broadcast();
  final _didOpenL2CAPChannelController = StreamController<PeripheralManagerDidOpenL2CAPChannelResult>.broadcast();
  final _pendingAddedServicesByReference = <String, CBMutableService>{};
  final _serviceRevisions = <String, _ServiceRevision>{};

  bool get isAdvertising => _isAdvertising;
  List<CBMutableService> get services => List.unmodifiable(_services);

  /// Completes after the native manager and its initial state are available.
  Future<void> get ready {
    if (_disposed) return Future.error(StateError('CBPeripheralManager has been disposed'));
    return _creation ??= _create(options: _sharedOptions);
  }

  /// Whether the native manager has been created and its initial snapshot applied.
  bool get isInitialized => !_disposed && _identifier != null;

  void _checkNotDisposed() {
    if (_disposed) throw StateError('CBPeripheralManager has been disposed');
  }

  Future<void> _ensureReady() async {
    _checkNotDisposed();
    await ready;
    _checkNotDisposed();
  }

  void _removeServiceRevisions(Map<String, _ServiceRevision> revisions) {
    for (final entry in revisions.entries) {
      // Keep this fact on the captured revision so a failed re-add cannot restore it.
      entry.value.isRemoved = true;
      final current = _serviceRevisions[entry.key];
      if (identical(current, entry.value)) {
        _pendingAddedServicesByReference.remove(entry.key);
        _serviceRevisions.remove(entry.key);
      }
      if (identical(current, entry.value) || current?.isPublished != true) {
        _services.removeWhere((service) => service._clientReference == entry.key);
      }
    }
  }

  String _trackedServiceReference(CBMutableService service) {
    for (final existing in _services) {
      if (_isSameTrackedService(existing, service)) return existing._clientReference;
    }
    return service._clientReference;
  }

  List<CBMutableService> _restoreServiceGraph(List<Object?> snapshots) {
    final byHandle = <String, CBMutableService>{};
    final collected = Set<CBService>.identity();
    void collect(CBService service) {
      if (!collected.add(service)) return;
      if (service is CBMutableService && service.handle.isNotEmpty) {
        byHandle.putIfAbsent(service.handle, () => service);
      }
      service.includedServices?.forEach(collect);
    }

    // Prefer existing root objects if the same service is also included elsewhere.
    for (final service in _services) {
      if (service.handle.isNotEmpty) byHandle[service.handle] = service;
    }
    _services.forEach(collect);
    final services = snapshots
        .map((raw) => _reconcileTrackedService(CBMutableService.fromMap(Map<Object?, Object?>.from(raw as Map))))
        .toList();
    final linked = Set<CBService>.identity();
    CBMutableService link(CBMutableService source) {
      final service = source.handle.isEmpty ? source : byHandle.putIfAbsent(source.handle, () => source);
      if (!linked.add(service)) return service;
      if (!identical(service, source)) service._applyNativeState(source);
      // These are local services with no CBPeripheral. Relink shared children
      // directly without recursively walking them again through updateIncludedServices.
      service._includedServices =
          service.includedServices?.map((child) => child is CBMutableService ? link(child) : child).toList();
      return service;
    }

    return services.map(link).toList();
  }

  void _restoreServices(List<Object?> published, {List<Object?> pending = const []}) {
    _pendingAddedServicesByReference.clear();
    // Decode together so shared children have one identity across both groups.
    final services = _restoreServiceGraph([...published, ...pending]);
    _services
      ..clear()
      ..addAll(services.take(published.length));
    _serviceRevisions.clear();
    for (var i = 0; i < services.length; i++) {
      final service = services[i];
      final isPublished = i < published.length;
      _serviceRevisions[service._clientReference] = _ServiceRevision()..isPublished = isPublished;
      if (!isPublished) _pendingAddedServicesByReference[service._clientReference] = service;
    }
  }

  Stream<PeripheralManagerDidStartAdvertisingResult> get onDidStartAdvertising {
    return _didStartAdvertisingController.stream;
  }

  Stream<DidAddServiceResult> get onDidAddService => _didAddServiceController.stream;
  Stream<DidSubscribeToCharacteristicResult> get onDidSubscribeToCharacteristic {
    return _didSubscribeToCharacteristicController.stream;
  }

  Stream<DidUnsubscribeFromCharacteristicResult> get onDidUnsubscribeFromCharacteristic {
    return _didUnsubscribeFromCharacteristicController.stream;
  }

  Stream<IsReadyToUpdateSubscribersResult> get onIsReadyToUpdateSubscribers {
    return _isReadyToUpdateSubscribersController.stream;
  }

  Stream<DidReceiveReadRequestResult> get onDidReceiveReadRequest {
    return _didReceiveReadRequestController.stream;
  }

  Stream<DidReceiveWriteRequestsResult> get onDidReceiveWriteRequests {
    return _didReceiveWriteRequestsController.stream;
  }

  Stream<DidPublishL2CAPChannelResult> get onDidPublishL2CAPChannel {
    return _didPublishL2CAPChannelController.stream;
  }

  Stream<DidUnpublishL2CAPChannelResult> get onDidUnpublishL2CAPChannel {
    return _didUnpublishL2CAPChannelController.stream;
  }

  Stream<PeripheralManagerDidOpenL2CAPChannelResult> get onDidOpenL2CAPChannel {
    return _didOpenL2CAPChannelController.stream;
  }

  Stream<CBManagerState> get onDidUpdateState => _didUpdateStateController.stream;
  Stream<PeripheralManagerWillRestoreStateResult> get onWillRestoreState => _willRestoreStateController.stream;

  static Future<CBManagerAuthorization> get authorization async {
    final rawValue = await CoreBluetoothHost.instance.invokeMethod<int>('peripheralManager.authorization') ?? 0;
    return cbManagerAuthorizationFromRawValue(rawValue);
  }

  static Future<CBManagerAuthorization> authorizationStatus() async => authorization;

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> add(CBMutableService service) async {
    await _ensureReady();
    final reference = service._clientReference;
    final previousRevision = _serviceRevisions[reference];
    final revision = _ServiceRevision();
    _serviceRevisions[reference] = revision;
    _pendingAddedServicesByReference[reference] = service;
    try {
      await _host.invokeMethod<void>(
        'peripheralManager.addService',
        {
          'managerId': _identifier,
          'service': service.toMap(),
        },
      );
    } catch (_) {
      if (identical(_serviceRevisions[reference], revision)) {
        _pendingAddedServicesByReference.remove(reference);
        if (previousRevision != null && !previousRevision.isRemoved && previousRevision.isPublished) {
          _serviceRevisions[reference] = previousRevision;
        } else {
          _serviceRevisions.remove(reference);
        }
      }
      rethrow;
    }
  }

  Future<void> remove(CBMutableService service) async {
    await _ensureReady();
    final reference = _trackedServiceReference(service);
    final revision = _serviceRevisions[reference];
    await _host.invokeMethod<void>(
      'peripheralManager.removeService',
      {
        'managerId': _identifier,
        'serviceHandle': service.handle,
      },
    );
    if (revision != null) _removeServiceRevisions({reference: revision});
  }

  Future<void> removeAllServices() async {
    await _ensureReady();
    final revisions = Map.of(_serviceRevisions);
    await _host.invokeMethod<void>('peripheralManager.removeAllServices', {'managerId': _identifier});
    // Newer adds can finish before this removal's method-channel reply arrives.
    _removeServiceRevisions(revisions);
  }

  Future<bool> updateValue(
    Uint8List value, {
    required CBMutableCharacteristic forCharacteristic,
    List<CBCentral>? onSubscribedCentrals,
  }) async {
    await _ensureReady();
    return await _host.invokeMethod<bool>(
          'peripheralManager.updateValue',
          {
            'managerId': _identifier,
            'value': value,
            'characteristicHandle': forCharacteristic.handle,
            'centralIdentifiers': onSubscribedCentrals?.map((central) => central.identifier.uuidString).toList(),
          },
        ) ??
        false;
  }

  Future<void> respond({
    required CBATTRequest to,
    required CBATTErrorCode withResult,
  }) async {
    await _ensureReady();
    await _host.invokeMethod<void>(
      'peripheralManager.respondToRequest',
      {
        'managerId': _identifier,
        'requestHandle': to._handle,
        'value': to.value,
        'result': withResult.rawValue,
      },
    );
  }

  Future<void> setDesiredConnectionLatency(
    CBPeripheralManagerConnectionLatency latency, {
    required CBCentral forCentral,
  }) async {
    await _ensureReady();
    await _host.invokeMethod<void>(
      'peripheralManager.setDesiredConnectionLatency',
      {
        'managerId': _identifier,
        'latency': latency.rawValue,
        'centralIdentifier': forCentral.identifier.uuidString,
      },
    );
  }

  Future<void> publishL2CAPChannel({
    required bool withEncryption,
  }) async {
    await _ensureReady();
    await _host.invokeMethod<void>(
      'peripheralManager.publishL2CAPChannel',
      {
        'managerId': _identifier,
        'withEncryption': withEncryption,
      },
    );
  }

  Future<void> unpublishL2CAPChannel(CBL2CAPPSM psm) async {
    await _ensureReady();
    await _host.invokeMethod<void>(
      'peripheralManager.unpublishL2CAPChannel',
      {
        'managerId': _identifier,
        'psm': psm,
      },
    );
  }

  Future<void> startAdvertising(PeripheralManagerAdvertisingData? advertisementData) async {
    await _ensureReady();
    _advertisingStartRevision++;
    _advertisingStopped = false;
    await _host.invokeMethod<void>(
      'peripheralManager.startAdvertising',
      {
        'managerId': _identifier,
        'advertisementData': _peripheralManagerAdvertisingDataToPayload(advertisementData),
      },
    );
  }

  Future<void> stopAdvertising() async {
    await _ensureReady();
    final revision = _advertisingStartRevision;
    await _host.invokeMethod<void>('peripheralManager.stopAdvertising', {'managerId': _identifier});
    if (!_disposed && revision == _advertisingStartRevision) {
      _advertisingStopped = true;
      _isAdvertising = false;
    }
  }

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
        await _host.invokeMethod<void>('peripheralManager.dispose', {'managerId': _identifier});
      }
    } finally {
      _eventsSubscription = null;
      _identifier = null;
      _isAdvertising = false;
      _services.clear();
      _pendingAddedServicesByReference.clear();
      _serviceRevisions.clear();
      if (identical(_sharedInstance, this)) _sharedInstance = null;
    }
  }

  Future<void> _create({
    PeripheralManagerOptions? options,
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
              'peripheralManager.create',
              {'options': _peripheralManagerOptionsToPayload(options), 'shared': _shared},
            ) ??
            const <Object?, Object?>{},
      );
      _identifier = (result['managerId'] as num?)?.toInt();
      if (_disposed) return;
      _applySnapshot(result);
      if (result.containsKey('services')) {
        _restoreServices(result['services'] as List<Object?>? ?? const [],
            pending: result['pendingServices'] as List<Object?>? ?? const []);
      }
      for (final event in pendingEvents) {
        // Match ordinary stream delivery: a callback error is not a creation failure.
        Zone.current.runGuarded(() => _handleEvent(event));
      }
    } catch (_) {
      await _eventsSubscription?.cancel();
      _eventsSubscription = null;
      _identifier = null;
      _creation = null;
      _services.clear();
      _pendingAddedServicesByReference.clear();
      _serviceRevisions.clear();
      _isAdvertising = false;
      rethrow;
    } finally {
      pendingEvents.clear();
    }
  }

  void _clearSubscriptions() {
    final visited = Set<CBService>.identity();
    void clear(CBService service) {
      if (!visited.add(service)) return;
      for (final characteristic in service.characteristics ?? const <CBCharacteristic>[]) {
        if (characteristic is CBMutableCharacteristic) characteristic.updateSubscribedCentrals([]);
      }
      service.includedServices?.forEach(clear);
    }

    _services.forEach(clear);
    _pendingAddedServicesByReference.values.forEach(clear);
  }

  void _applySnapshot(Map<Object?, Object?> map) {
    _updateState(cbManagerStateFromRawValue((map['state'] as num?)?.toInt() ?? 0));
    _isAdvertising = state == CBManagerState.poweredOn && (map['isAdvertising'] as bool? ?? false);
    if (state != CBManagerState.poweredOn) {
      _advertisingStopped = true;
      _clearSubscriptions();
    }
    if (state == CBManagerState.poweredOff || state == CBManagerState.resetting) {
      // The local database is gone. Retire revisions so pending adds/removes
      // cannot republish it when their method-channel replies arrive.
      _removeServiceRevisions(Map.of(_serviceRevisions));
      _services.clear();
      _pendingAddedServicesByReference.clear();
    }
  }

  CBATTRequest? _requestFromPayload(Map<Object?, Object?> payload) {
    final centralMap = payload['central'] as Map?;
    final characteristic = _findMutableCharacteristicByHandle(payload['characteristicHandle'] as String?);
    if (centralMap == null || characteristic == null) {
      return null;
    }

    return CBATTRequest(
      central: CBCentral.fromMap(Map<Object?, Object?>.from(centralMap)),
      characteristic: characteristic,
      offset: (payload['offset'] as num?)?.toInt() ?? 0,
      value: bytesFromNullable(payload['value']),
      handle: payload['requestHandle'] as String?,
    );
  }

  CBMutableCharacteristic? _findMutableCharacteristicByHandle(String? handle) {
    if (handle == null) {
      return null;
    }

    final visited = Set<CBService>.identity();
    CBMutableCharacteristic? find(CBService service) {
      if (!visited.add(service)) return null;
      for (final characteristic
          in service.characteristics?.whereType<CBMutableCharacteristic>() ?? const <CBMutableCharacteristic>[]) {
        if (characteristic.handle == handle) {
          return characteristic;
        }
      }
      for (final included in service.includedServices ?? const <CBService>[]) {
        final match = find(included);
        if (match != null) return match;
      }
      return null;
    }

    for (final service in _services) {
      final match = find(service);
      if (match != null) return match;
    }

    return null;
  }

  bool _isSameTrackedService(CBMutableService left, CBMutableService right) {
    if (identical(left, right)) {
      return true;
    }

    if (left.handle.isNotEmpty && right.handle.isNotEmpty && left.handle == right.handle) {
      return true;
    }

    return left._clientReference == right._clientReference;
  }

  CBMutableService _reconcileTrackedService(CBMutableService decodedService) {
    final pendingService = _pendingAddedServicesByReference.remove(decodedService._clientReference);
    if (pendingService != null) {
      pendingService._applyNativeState(decodedService);
      return pendingService;
    }

    final trackedService = _services.where((existing) => _isSameTrackedService(existing, decodedService));
    if (trackedService.isEmpty) {
      return decodedService;
    }

    final service = trackedService.first;
    if (!identical(service, decodedService)) {
      service._applyNativeState(decodedService);
    }
    return service;
  }

  void _handleStateUpdate(Map<Object?, Object?> payload) {
    _applySnapshot(payload);
    _didUpdateStateController.add(state);
    delegate?.peripheralManagerDidUpdateState(this);
  }

  void _handleRestoredState(Map<Object?, Object?> payload) {
    final advertisingDataMap = payload['advertisingData'] as Map?;
    _restoreServices(payload['services'] as List<Object?>? ?? const []);
    final state = PeripheralManagerWillRestoreStateResult(
      advertisingData: advertisingDataMap == null
          ? null
          : _peripheralManagerAdvertisingDataFromPayload(Map<Object?, Object?>.from(advertisingDataMap)),
      services: List.unmodifiable(_services),
    );
    _willRestoreStateController.add(state);
    delegate?.peripheralManagerWillRestoreState(this, state);
  }

  void _handleAdvertisingStarted(Map<Object?, Object?> payload) {
    // A start callback can already be in transit when stopAdvertising completes.
    if (!_advertisingStopped) {
      _isAdvertising = payload['isAdvertising'] as bool? ?? _isAdvertising;
    }
    final error = cbErrorFromPayload(payload);
    final result = PeripheralManagerDidStartAdvertisingResult(error: error);
    _didStartAdvertisingController.add(result);
    delegate?.peripheralManagerDidStartAdvertising(this, error);
  }

  void _handleAddedService(Map<Object?, Object?> payload) {
    final rawService = payload['service'] as Map?;
    if (rawService == null) {
      return;
    }
    final decodedService = CBMutableService.fromMap(Map<Object?, Object?>.from(rawService));
    final isTracked = _pendingAddedServicesByReference.containsKey(decodedService._clientReference) ||
        _services.any((existing) => _isSameTrackedService(existing, decodedService));
    final service = _reconcileTrackedService(decodedService);
    final error = cbErrorFromPayload(payload);
    // Preserve late callbacks without republishing a service removed in the meantime.
    if (error == null && isTracked) {
      _serviceRevisions[service._clientReference]?.isPublished = true;
      final existingIndex = _services.indexWhere((element) => _isSameTrackedService(element, service));
      if (existingIndex >= 0) {
        _services[existingIndex] = service;
      } else {
        _services.add(service);
      }
    } else if (error != null) {
      if (_services.any((existing) => _isSameTrackedService(existing, service))) {
        // The failed re-add leaves the previous publication in place.
        _serviceRevisions[service._clientReference]?.isPublished = true;
      } else {
        _serviceRevisions.remove(service._clientReference);
      }
    }
    final result = DidAddServiceResult(service: service, error: error);
    _didAddServiceController.add(result);
    delegate?.peripheralManagerDidAddService(this, service, error);
  }

  void _handleSubscribedCentral(Map<Object?, Object?> payload) {
    final centralMap = payload['central'] as Map?;
    final characteristic = _findMutableCharacteristicByHandle(payload['characteristicHandle'] as String?);
    if (centralMap == null || characteristic == null) {
      return;
    }
    final central = CBCentral.fromMap(Map<Object?, Object?>.from(centralMap));
    characteristic.updateSubscribedCentrals(
      [
        ...characteristic.subscribedCentrals.where((existing) => existing.identifier != central.identifier),
        central,
      ],
    );
    final result = DidSubscribeToCharacteristicResult(central: central, characteristic: characteristic);
    _didSubscribeToCharacteristicController.add(result);
    delegate?.peripheralManagerDidSubscribeToCharacteristic(this, central, characteristic);
  }

  void _handleUnsubscribedCentral(Map<Object?, Object?> payload) {
    final centralMap = payload['central'] as Map?;
    final characteristic = _findMutableCharacteristicByHandle(payload['characteristicHandle'] as String?);
    if (centralMap == null || characteristic == null) {
      return;
    }
    final central = CBCentral.fromMap(Map<Object?, Object?>.from(centralMap));
    characteristic.updateSubscribedCentrals(
      characteristic.subscribedCentrals.where((existing) => existing.identifier != central.identifier).toList(),
    );
    final result = DidUnsubscribeFromCharacteristicResult(central: central, characteristic: characteristic);
    _didUnsubscribeFromCharacteristicController.add(result);
    delegate?.peripheralManagerDidUnsubscribeFromCharacteristic(this, central, characteristic);
  }

  void _handleSubscriberReadiness() {
    const result = IsReadyToUpdateSubscribersResult();
    _isReadyToUpdateSubscribersController.add(result);
    delegate?.peripheralManagerIsReadyToUpdateSubscribers(this);
  }

  void _handleReadRequest(Map<Object?, Object?> payload) {
    final request = _requestFromPayload(payload);
    if (request == null) {
      return;
    }
    final result = DidReceiveReadRequestResult(request: request);
    _didReceiveReadRequestController.add(result);
    delegate?.peripheralManagerDidReceiveRead(this, request);
  }

  void _handleWriteRequests(Map<Object?, Object?> payload) {
    final requests = (payload['requests'] as List<Object?>? ?? const [])
        .map((request) => _requestFromPayload(Map<Object?, Object?>.from(request as Map)))
        .whereType<CBATTRequest>()
        .toList();
    final result = DidReceiveWriteRequestsResult(requests: requests);
    _didReceiveWriteRequestsController.add(result);
    delegate?.peripheralManagerDidReceiveWrite(this, requests);
  }

  void _handlePublishedL2CAPChannel(Map<Object?, Object?> payload) {
    final psm = (payload['psm'] as num?)?.toInt() ?? 0;
    final error = cbErrorFromPayload(payload);
    final result = DidPublishL2CAPChannelResult(
      psm: psm,
      error: error,
    );
    _didPublishL2CAPChannelController.add(result);
    delegate?.peripheralManagerDidPublishL2CAPChannel(this, psm, error);
  }

  void _handleUnpublishedL2CAPChannel(Map<Object?, Object?> payload) {
    final psm = (payload['psm'] as num?)?.toInt() ?? 0;
    final error = cbErrorFromPayload(payload);
    final result = DidUnpublishL2CAPChannelResult(
      psm: psm,
      error: error,
    );
    _didUnpublishL2CAPChannelController.add(result);
    delegate?.peripheralManagerDidUnpublishL2CAPChannel(this, psm, error);
  }

  void _handleOpenedL2CAPChannel(Map<Object?, Object?> payload) {
    final channelMap = payload['channel'] as Map?;
    final error = cbErrorFromPayload(payload);
    final result = PeripheralManagerDidOpenL2CAPChannelResult(
      channel: channelMap == null ? null : CBL2CAPChannel.fromMap(map: Map<Object?, Object?>.from(channelMap)),
      error: error,
    );
    _didOpenL2CAPChannelController.add(result);
    delegate?.peripheralManagerDidOpen(this, result.channel, error);
  }

  void _handleEvent(Map<Object?, Object?> event) {
    if (_disposed || (event['peripheralManagerId'] as num?)?.toInt() != _identifier) {
      return;
    }

    final kind = event['kind'] as String? ?? '';
    final payload = Map<Object?, Object?>.from(event['payload'] as Map? ?? const {});

    switch (kind) {
      case 'peripheralManagerDidUpdateState':
        _handleStateUpdate(payload);
      case 'peripheralManagerWillRestoreState':
        _handleRestoredState(payload);
      case 'peripheralManagerDidStartAdvertising':
        _handleAdvertisingStarted(payload);
      case 'peripheralManagerDidAddService':
        _handleAddedService(payload);
      case 'peripheralManagerDidSubscribeToCharacteristic':
        _handleSubscribedCentral(payload);
      case 'peripheralManagerDidUnsubscribeFromCharacteristic':
        _handleUnsubscribedCentral(payload);
      case 'peripheralManagerIsReadyToUpdateSubscribers':
        _handleSubscriberReadiness();
      case 'peripheralManagerDidReceiveRead':
        _handleReadRequest(payload);
      case 'peripheralManagerDidReceiveWrite':
        _handleWriteRequests(payload);
      case 'peripheralManagerDidPublishL2CAPChannel':
        _handlePublishedL2CAPChannel(payload);
      case 'peripheralManagerDidUnpublishL2CAPChannel':
        _handleUnpublishedL2CAPChannel(payload);
      case 'peripheralManagerDidOpenL2CAPChannel':
        _handleOpenedL2CAPChannel(payload);
    }
  }
}
