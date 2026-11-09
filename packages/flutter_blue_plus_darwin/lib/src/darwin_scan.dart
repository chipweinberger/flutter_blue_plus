part of '../flutter_blue_plus_darwin.dart';

bool _maskedMatch(List<int> data, List<int> expected, List<int> mask) {
  final effective = mask.isEmpty ? List<int>.filled(expected.length, 1) : mask;
  if (expected.length != effective.length || data.length < expected.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (data[i] & effective[i] != expected[i] & effective[i]) return false;
  }
  return true;
}

BmScanSettings _snapshotScan(BmScanSettings request) => BmScanSettings(
      withServices: List.of(request.withServices),
      withRemoteIds: List.of(request.withRemoteIds),
      withNames: List.of(request.withNames),
      withKeywords: List.of(request.withKeywords),
      withMsd: [
        for (final f in request.withMsd) BmMsdFilter(f.manufacturerId, List.of(f.data ?? []), List.of(f.mask ?? []))
      ],
      withServiceData: [
        for (final f in request.withServiceData) BmServiceDataFilter(f.service, List.of(f.data), List.of(f.mask))
      ],
      continuousUpdates: request.continuousUpdates,
      continuousDivisor: request.continuousDivisor,
      androidLegacy: request.androidLegacy,
      androidScanMode: request.androidScanMode,
      androidUsesFineLocation: request.androidUsesFineLocation,
      androidCheckLocationServices: request.androidCheckLocationServices,
      webOptionalServices: List.of(request.webOptionalServices),
    );

bool _matchesAdvertisement(BmScanSettings settings, cb.DidDiscoverPeripheralResult event) {
  final data = event.advertisementData;
  final noFilters = settings.withServices.isEmpty &&
      settings.withRemoteIds.isEmpty &&
      settings.withNames.isEmpty &&
      settings.withKeywords.isEmpty &&
      settings.withMsd.isEmpty &&
      settings.withServiceData.isEmpty;
  if (noFilters) return true;
  if ((data.serviceUUIDs ?? []).any((uuid) => settings.withServices.contains(_guid(uuid)))) return true;
  if (settings.withRemoteIds.any((id) => id.toUpperCase() == _remoteId(event.peripheral))) return true;
  final name = data.localName;
  if (name != null && (settings.withNames.contains(name) || settings.withKeywords.any(name.contains))) return true;
  final manufacturer = data.manufacturerData;
  if (manufacturer != null && manufacturer.length >= 2) {
    final id = manufacturer[0] | manufacturer[1] << 8;
    if (settings.withMsd
        .any((f) => f.manufacturerId == id && _maskedMatch(manufacturer.sublist(2), f.data ?? [], f.mask ?? []))) {
      return true;
    }
  }
  return settings.withServiceData.any((f) => data.serviceData.entries
      .any((entry) => _guid(entry.key) == f.service && _maskedMatch(entry.value, f.data, f.mask)));
}

BmScanAdvertisement _advertisement(cb.DidDiscoverPeripheralResult event) {
  final data = event.advertisementData;
  final manufacturer = data.manufacturerData;
  return BmScanAdvertisement(
    remoteId: DeviceIdentifier(_remoteId(event.peripheral)),
    platformName: event.peripheralName,
    advName: data.localName,
    connectable: data.isConnectable ?? false,
    txPowerLevel: data.txPowerLevel,
    appearance: null,
    manufacturerData: {
      if (manufacturer != null && manufacturer.length >= 2)
        manufacturer[0] | manufacturer[1] << 8: manufacturer.sublist(2)
    },
    serviceData: {for (final entry in data.serviceData.entries) _guid(entry.key): entry.value},
    serviceUuids: (data.serviceUUIDs ?? []).map(_guid).toList(),
    rssi: event.rssi ?? 0,
  );
}

base mixin _ScanOperations on _DarwinBackend {
  @override
  void _onDiscovered(cb.DidDiscoverPeripheralResult event) {
    final id = _remoteId(event.peripheral);
    _known[id] = event.peripheral;
    final settings = _scanSettings;
    if (settings == null || !_matchesAdvertisement(settings, event)) return;
    _onScanResponseController
        .add(BmScanResponse(advertisements: [_advertisement(event)], success: true, errorCode: 0, errorString: ''));
  }

  @override
  Future<bool> startScan(BmScanSettings request) {
    final settings = _snapshotScan(request);
    return _run(() async {
      _requireAdapter('startScan');
      _scanSettings = settings;
      final hasCustom = settings.withRemoteIds.isNotEmpty ||
          settings.withNames.isNotEmpty ||
          settings.withKeywords.isNotEmpty ||
          settings.withMsd.isNotEmpty ||
          settings.withServiceData.isNotEmpty;
      await _manager.scanForPeripherals(
          withServices: hasCustom ? [] : settings.withServices.map((uuid) => cb.CBUUID(uuid.str)).toList(),
          advertisementDivisor: settings.continuousUpdates ? settings.continuousDivisor : 1,
          options: cb.CentralManagerScanOptions(allowDuplicates: settings.continuousUpdates ? true : null));
      return true;
    });
  }

  @override
  Future<bool> stopScan(BmStopScanRequest request) => _run(() async {
        await _manager.stopScan();
        return true;
      });
}
