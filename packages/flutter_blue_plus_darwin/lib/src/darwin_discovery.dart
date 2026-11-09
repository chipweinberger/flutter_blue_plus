part of '../flutter_blue_plus_darwin.dart';

base mixin _DiscoveryOperations on _DarwinBackend {
  void _completeDiscovery(_PeripheralState state, _Discovery discovery) {
    if (!identical(state.discovery, discovery) || !discovery.isComplete) return;
    state.discovery = null;
    final error = discovery.error;
    _onDiscoveredServicesController.add(BmDiscoverServicesResult(
        remoteId: DeviceIdentifier(_remoteId(state.peripheral)),
        services: [
          for (final service in state.peripheral.services ?? <cb.CBService>[]) _serviceModel(state.peripheral, service)
        ],
        success: error == null,
        errorCode: error?.code.rawValue ?? 0,
        errorString: error?.localizedDescription ?? 'success'));
  }

  void _discoveryRequest(_PeripheralState state, _Discovery discovery, Future<void> request) {
    unawaited(request.catchError((Object error, StackTrace stack) {
      if (_disposed || !identical(state.discovery, discovery)) return;
      state.discovery = null;
      _onDiscoveredServicesController.add(BmDiscoverServicesResult(
          remoteId: DeviceIdentifier(_remoteId(state.peripheral)),
          services: [],
          success: false,
          errorCode: 0,
          errorString: error.toString()));
    }));
  }

  void _discoverService(_PeripheralState state, _Discovery discovery, cb.CBService service) {
    if (!discovery.requestedServices.add(service)) return;
    discovery.pendingCharacteristics.add(service);
    discovery.pendingIncludedServices.add(service);
    _discoveryRequest(state, discovery, state.peripheral.discoverCharacteristics(forService: service));
    _discoveryRequest(state, discovery, state.peripheral.discoverIncludedServices(null, forService: service));
  }

  void _onServices(_PeripheralState state, cb.DidDiscoverServicesResult event) {
    final discovery = state.discovery ??= _Discovery();
    discovery.recordError(event.error);
    final services = event.services ?? <cb.CBService>[];
    for (final service in services) {
      _discoverService(state, discovery, service);
    }
    _completeDiscovery(state, discovery);
  }

  void _onCharacteristics(_PeripheralState state, cb.DidDiscoverCharacteristicsForServiceResult event) {
    final discovery = state.discovery;
    if (discovery == null || !discovery.pendingCharacteristics.remove(event.service)) return;
    discovery.recordError(event.error);
    final characteristics = event.characteristics ?? <cb.CBCharacteristic>[];
    for (final characteristic in characteristics) {
      if (!discovery.pendingDescriptors.add(characteristic)) continue;
      _discoveryRequest(state, discovery, state.peripheral.discoverDescriptors(characteristic));
    }
    _completeDiscovery(state, discovery);
  }

  void _onIncludedServices(_PeripheralState state, cb.DidDiscoverIncludedServicesForServiceResult event) {
    final discovery = state.discovery;
    if (discovery == null || !discovery.pendingIncludedServices.remove(event.service)) return;
    discovery.recordError(event.error);
    for (final service in event.includedServices ?? <cb.CBService>[]) {
      _discoverService(state, discovery, service);
    }
    _completeDiscovery(state, discovery);
  }

  void _onDescriptors(_PeripheralState state, cb.DidDiscoverDescriptorsForCharacteristicResult event) {
    final discovery = state.discovery;
    if (discovery == null || !discovery.pendingDescriptors.remove(event.characteristic)) return;
    discovery.recordError(event.error);
    _completeDiscovery(state, discovery);
  }

  @override
  Future<bool> discoverServices(BmDiscoverServicesRequest request) => _run(() async {
        final state = _connectedState('discoverServices', request.remoteId);
        final discovery = _Discovery();
        state.discovery = discovery;
        try {
          await state.peripheral.discoverServices();
        } catch (_) {
          if (identical(state.discovery, discovery)) state.discovery = null;
          rethrow;
        }
        return true;
      });
}
