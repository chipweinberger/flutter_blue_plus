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

final class CBPeripheralManager extends CBManager {
  static CBPeripheralManager? _sharedInstance;

  static CBPeripheralManager get shared => _sharedInstance ??= CBPeripheralManager.init();

  static CBPeripheralManager ensureShared({
    CBPeripheralManagerDelegate? delegate,
    Object? queue,
    PeripheralManagerOptions? options,
  }) {
    final existing = _sharedInstance;
    if (existing == null) {
      final manager = CBPeripheralManager.init(
        delegate: delegate,
        queue: queue,
        options: options,
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
    this.delegate,
    Object? queue,
    PeripheralManagerOptions? options,
  })  : _sharedOptions = options,
        super() {
    _ready = _create(options: options);
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

  late final Future<void> _ready;
  int? _identifier;
  var _isAdvertising = false;
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

  bool get isAdvertising => _isAdvertising;
  List<CBMutableService> get services => List.unmodifiable(_services);

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

  Future<void> dispose() async {
    await _ready;
    await _eventsSubscription?.cancel();
    await _host.invokeMethod<void>('peripheralManager.dispose', {'managerId': _identifier});
  }

  Future<void> add(CBMutableService service) async {
    await _ready;
    _pendingAddedServicesByReference[service._clientReference] = service;
    await _host.invokeMethod<void>(
      'peripheralManager.addService',
      {
        'managerId': _identifier,
        'service': service.toMap(),
      },
    );
  }

  Future<void> remove(CBMutableService service) async {
    await _ready;
    await _host.invokeMethod<void>(
      'peripheralManager.removeService',
      {
        'managerId': _identifier,
        'serviceHandle': service.handle,
      },
    );
    _pendingAddedServicesByReference.remove(service._clientReference);
    _removeTrackedService(service);
  }

  Future<void> removeAllServices() async {
    await _ready;
    await _host.invokeMethod<void>('peripheralManager.removeAllServices', {'managerId': _identifier});
    _pendingAddedServicesByReference.clear();
    _services.clear();
  }

  Future<bool> updateValue(
    Uint8List value, {
    required CBMutableCharacteristic forCharacteristic,
    List<CBCentral>? onSubscribedCentrals,
  }) async {
    await _ready;
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
    await _ready;
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
    await _ready;
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
    await _ready;
    await _host.invokeMethod<void>(
      'peripheralManager.publishL2CAPChannel',
      {
        'managerId': _identifier,
        'withEncryption': withEncryption,
      },
    );
  }

  Future<void> unpublishL2CAPChannel(CBL2CAPPSM psm) async {
    await _ready;
    await _host.invokeMethod<void>(
      'peripheralManager.unpublishL2CAPChannel',
      {
        'managerId': _identifier,
        'psm': psm,
      },
    );
  }

  Future<void> startAdvertising(PeripheralManagerAdvertisingData? advertisementData) async {
    await _ready;
    await _host.invokeMethod<void>(
      'peripheralManager.startAdvertising',
      {
        'managerId': _identifier,
        'advertisementData': _peripheralManagerAdvertisingDataToPayload(advertisementData),
      },
    );
  }

  Future<void> stopAdvertising() async {
    await _ready;
    await _host.invokeMethod<void>('peripheralManager.stopAdvertising', {'managerId': _identifier});
  }

  Future<void> _create({
    PeripheralManagerOptions? options,
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
            'peripheralManager.create',
            {
              'options': _peripheralManagerOptionsToPayload(options),
            },
          ) ??
          const <Object?, Object?>{},
    );

    _identifier = (result['managerId'] as num?)?.toInt();
    _applySnapshot(result);
    for (final event in pendingEvents) {
      _handleEvent(event);
    }
  }

  void _applySnapshot(Map<Object?, Object?> map) {
    _updateState(cbManagerStateFromRawValue((map['state'] as num?)?.toInt() ?? 0));
    _isAdvertising = map['isAdvertising'] as bool? ?? false;
  }

  void _handleEvent(Map<Object?, Object?> event) {
    if ((event['peripheralManagerId'] as num?)?.toInt() != _identifier) {
      return;
    }

    final kind = event['kind'] as String? ?? '';
    final payload = Map<Object?, Object?>.from(event['payload'] as Map? ?? const {});

    switch (kind) {
      case 'peripheralManagerDidUpdateState':
        _applySnapshot(payload);
        _didUpdateStateController.add(state);
        delegate?.peripheralManagerDidUpdateState(this);
      case 'peripheralManagerWillRestoreState':
        final advertisingDataMap = payload['advertisingData'] as Map?;
        _pendingAddedServicesByReference.clear();
        final services = (payload['services'] as List<Object?>? ?? const [])
            .map((service) => _reconcileTrackedService(
                  CBMutableService.fromMap(Map<Object?, Object?>.from(service as Map)),
                ))
            .toList();
        _services
          ..clear()
          ..addAll(services);
        final state = PeripheralManagerWillRestoreStateResult(
          advertisingData: advertisingDataMap == null
              ? null
              : _peripheralManagerAdvertisingDataFromPayload(Map<Object?, Object?>.from(advertisingDataMap)),
          services: List.unmodifiable(_services),
        );
        _willRestoreStateController.add(state);
        delegate?.peripheralManagerWillRestoreState(this, state);
      case 'peripheralManagerDidStartAdvertising':
        _isAdvertising = payload['isAdvertising'] as bool? ?? _isAdvertising;
        final error = cbErrorFromPayload(payload);
        final result = PeripheralManagerDidStartAdvertisingResult(error: error);
        _didStartAdvertisingController.add(result);
        delegate?.peripheralManagerDidStartAdvertising(this, error);
      case 'peripheralManagerDidAddService':
        final rawService = payload['service'] as Map?;
        if (rawService == null) {
          return;
        }
        final decodedService = CBMutableService.fromMap(Map<Object?, Object?>.from(rawService));
        final service = _reconcileTrackedService(decodedService);
        final error = cbErrorFromPayload(payload);
        if (error == null) {
          final existingIndex = _services.indexWhere((element) => _isSameTrackedService(element, service));
          if (existingIndex >= 0) {
            _services[existingIndex] = service;
          } else {
            _services.add(service);
          }
        }
        final result = DidAddServiceResult(service: service, error: error);
        _didAddServiceController.add(result);
        delegate?.peripheralManagerDidAddService(this, service, error);
      case 'peripheralManagerDidSubscribeToCharacteristic':
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
      case 'peripheralManagerDidUnsubscribeFromCharacteristic':
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
      case 'peripheralManagerIsReadyToUpdateSubscribers':
        const result = IsReadyToUpdateSubscribersResult();
        _isReadyToUpdateSubscribersController.add(result);
        delegate?.peripheralManagerIsReadyToUpdateSubscribers(this);
      case 'peripheralManagerDidReceiveRead':
        final request = _requestFromPayload(payload);
        if (request == null) {
          return;
        }
        final result = DidReceiveReadRequestResult(request: request);
        _didReceiveReadRequestController.add(result);
        delegate?.peripheralManagerDidReceiveRead(this, request);
      case 'peripheralManagerDidReceiveWrite':
        final requests = (payload['requests'] as List<Object?>? ?? const [])
            .map((request) => _requestFromPayload(Map<Object?, Object?>.from(request as Map)))
            .whereType<CBATTRequest>()
            .toList();
        final result = DidReceiveWriteRequestsResult(requests: requests);
        _didReceiveWriteRequestsController.add(result);
        delegate?.peripheralManagerDidReceiveWrite(this, requests);
      case 'peripheralManagerDidPublishL2CAPChannel':
        final psm = (payload['psm'] as num?)?.toInt() ?? 0;
        final error = cbErrorFromPayload(payload);
        final result = DidPublishL2CAPChannelResult(
          psm: psm,
          error: error,
        );
        _didPublishL2CAPChannelController.add(result);
        delegate?.peripheralManagerDidPublishL2CAPChannel(this, psm, error);
      case 'peripheralManagerDidUnpublishL2CAPChannel':
        final psm = (payload['psm'] as num?)?.toInt() ?? 0;
        final error = cbErrorFromPayload(payload);
        final result = DidUnpublishL2CAPChannelResult(
          psm: psm,
          error: error,
        );
        _didUnpublishL2CAPChannelController.add(result);
        delegate?.peripheralManagerDidUnpublishL2CAPChannel(this, psm, error);
      case 'peripheralManagerDidOpenL2CAPChannel':
        final channelMap = payload['channel'] as Map?;
        final error = cbErrorFromPayload(payload);
        final result = PeripheralManagerDidOpenL2CAPChannelResult(
          channel: channelMap == null ? null : CBL2CAPChannel.fromMap(map: Map<Object?, Object?>.from(channelMap)),
          error: error,
        );
        _didOpenL2CAPChannelController.add(result);
        delegate?.peripheralManagerDidOpen(this, result.channel, error);
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

    for (final service in _services) {
      for (final characteristic
          in service.characteristics?.whereType<CBMutableCharacteristic>() ?? const <CBMutableCharacteristic>[]) {
        if (characteristic.handle == handle) {
          return characteristic;
        }
      }
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

  void _removeTrackedService(CBMutableService service) {
    _services.removeWhere((existing) => _isSameTrackedService(existing, service));
  }
}
