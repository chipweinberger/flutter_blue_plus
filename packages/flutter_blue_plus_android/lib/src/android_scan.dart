part of '../flutter_blue_plus_android.dart';

Uint8List? _scanMask(List<int>? mask) {
  if (mask == null || mask.isEmpty) return null;
  return Uint8List.fromList(mask);
}

ab.ScanDeliveryOptions _scanDelivery(BmScanSettings settings) => ab.ScanDeliveryOptions(
      advertisementDivisor: settings.continuousUpdates ? settings.continuousDivisor : 1,
      suppressDuplicates: !settings.continuousUpdates,
      includeBatchResults: false,
    );

({List<int> manufacturer, int? appearance}) _parseAdvertisingData(Uint8List bytes, {required bool useLastAppearance}) {
  final manufacturer = <int>[];
  int? appearance;
  var appearanceEnded = false;
  for (var offset = 0; offset < bytes.length;) {
    final length = bytes[offset];
    if (length == 0 || offset + length >= bytes.length) break;
    switch (bytes[offset + 1]) {
      case 0:
        appearanceEnded = true;
      case 0xff:
        if (length >= 2) manufacturer.addAll(bytes.getRange(offset + 2, offset + length + 1));
      case 0x19:
        if (length == 3 && (useLastAppearance || (!appearanceEnded && appearance == null))) {
          appearance = bytes[offset + 2] | bytes[offset + 3] << 8;
        }
    }
    offset += length + 1;
  }
  return (manufacturer: manufacturer, appearance: appearance);
}

final class _ScanFilters {
  _ScanFilters(this.settings)
      // Match the old method-channel copy before asynchronous work.
      : delivery = _scanDelivery(settings),
        remoteIds = List.of(settings.withRemoteIds),
        names = List.of(settings.withNames),
        keywords = List.of(settings.withKeywords),
        services = [for (final uuid in settings.withServices) ab.ScanFilter(serviceUuid: uuid.str)],
        manufacturers = [
          for (final filter in settings.withMsd)
            ab.ScanFilter(
              manufacturerId: filter.manufacturerId,
              manufacturerData: Uint8List.fromList(filter.data ?? []),
              manufacturerDataMask: _scanMask(filter.mask),
            ),
        ],
        serviceData = [
          for (final filter in settings.withServiceData)
            ab.ScanFilter(
              serviceDataUuid: filter.service.str,
              serviceData: Uint8List.fromList(filter.data),
              serviceDataMask: _scanMask(filter.mask),
            ),
        ];
  final BmScanSettings settings;
  final ab.ScanDeliveryOptions delivery;
  final List<String> remoteIds, names, keywords;
  final List<ab.ScanFilter> services, manufacturers, serviceData;

  List<ab.ScanFilter> forApi(int api) => [
        ...services,
        for (final address in remoteIds) ab.ScanFilter(deviceAddress: address),
        for (final name in names) ab.ScanFilter(deviceName: name),
        if (api >= 33 && keywords.isNotEmpty) ...[
          const ab.ScanFilter(advertisingDataType: 8),
          const ab.ScanFilter(advertisingDataType: 9),
        ],
        ...manufacturers,
        ...serviceData,
      ];
}

base mixin _ScanOperations on _AndroidBackend {
  @override
  Future<void> _stopScan() async {
    final scan = _scan;
    if (scan == null) return;
    final subscription = _scanSubscription;
    await scan.stop();
    if (identical(_scan, scan)) {
      _scan = null;
      _scanSubscription = null;
    }
    await subscription?.cancel();
  }

  Future<void> _requireScanAccess(BmScanSettings settings) async {
    final api = _capabilities.apiLevel;
    if (settings.androidCheckLocationServices && api < 31 && !await ab.AndroidBluetooth.isLocationEnabled) {
      _fail('startScan', 'Location services are required for Bluetooth scan');
    }
    final permissions = api >= 31
        ? [_bluetoothScan, if (settings.androidUsesFineLocation) _fineLocation, _bluetoothConnect]
        : [_fineLocation];
    await _requirePermission('startScan', permissions, 'to scan devices');
    if (!await _isAdapterOn()) _fail('startScan', 'Bluetooth must be turned on');
  }

  Future<void> _openScan(_ScanFilters filters) async {
    final api = _capabilities.apiLevel;
    final settings = filters.settings;
    try {
      final scan = await ab.BluetoothLeScanner.shared.startScanSession(
          filters: filters.forApi(api),
          deliveryOptions: filters.delivery,
          settings: ab.ScanSettings(
            scanMode: settings.androidScanMode,
            legacy: api >= 26 ? settings.androidLegacy : null,
            phy: api >= 26 ? ab.ScanSettings.phyLeAllSupported : null,
          ));
      _scan = scan;
      _scanSubscription = scan.events.listen(_scanCallback);
    } on PlatformException catch (error) {
      if (error.code == 'invalid_state' && (error.message ?? '').contains('scanner')) {
        _fail('startScan', 'getBluetoothLeScanner() is null. Is the Adapter on?');
      }
      rethrow;
    }
  }

  Map<String, Object?> _advertisement(ab.ScanResult result) {
    final device = result.device;
    final record = result.scanRecord;
    final (manufacturer: manufacturer, appearance: appearance) =
        _parseAdvertisingData(record?.bytes ?? Uint8List(0), useLastAppearance: _capabilities.apiLevel >= 33);
    final txPower = record?.txPowerLevel ?? -2147483648;
    return {
      'remote_id': device.address,
      if (device.name != null) 'platform_name': device.name,
      if (record?.deviceName != null) 'adv_name': record!.deviceName,
      if (result.isConnectable ?? true) 'connectable': 1,
      if (txPower != -2147483648) 'tx_power_level': txPower,
      if (appearance != null && appearance != 0) 'appearance': appearance,
      if (manufacturer.length >= 2)
        'manufacturer_data': {
          manufacturer[0] | manufacturer[1] << 8: Uint8List.fromList(manufacturer.sublist(2)),
        },
      if (record != null)
        'service_data': {
          for (final entry in record.serviceData.entries) _shortUuid(entry.key): Uint8List.fromList(entry.value),
        },
      if (record != null) 'service_uuids': record.serviceUuids.map(_shortUuid).toList(),
      if (result.rssi != 0) 'rssi': result.rssi,
    };
  }

  void _emitScanResponse(Map<String, Object?> data) =>
      _emit('OnScanResponse', _onScanResponseController, data, BmScanResponse.fromMap);

  void _scanFailure(int code) => _emitScanResponse({
        'advertisements': <Object>[],
        'success': 0,
        'error_code': code,
        'error_string': _scanFailed(code),
      });

  void _scanCallback(ab.ScanCallback event) {
    if (event is ab.ScanFailedEvent) {
      _scan = null;
      _scanFailure(event.errorCode);
      return;
    }
    // Legacy FBP deliberately does not process batch scan callbacks.
    if (event is! ab.ScanResultEvent) return;
    final keywords = _scanKeywords;
    for (final result in event.results) {
      final name = result.scanRecord?.deviceName;
      if (keywords.isNotEmpty && (name == null || !keywords.any(name.contains))) continue;
      _emitScanResponse({
        'advertisements': [_advertisement(result)]
      });
    }
  }

  @override
  Future<bool> stopScan(BmStopScanRequest request) => _run(() async {
        await _stopScan();
        return true;
      });

  @override
  Future<bool> startScan(BmScanSettings request) {
    final filters = _ScanFilters(request);
    return _run(() async {
      await _requireScanAccess(request);
      _scanKeywords = filters.keywords;
      if (_scan != null) {
        // Legacy repeated starts replace software filters/history but leave the radio scan intact.
        await _scan!.setDeliveryOptions(filters.delivery);
        _scanFailure(1);
        return true;
      }
      await _openScan(filters);
      return true;
    });
  }
}
