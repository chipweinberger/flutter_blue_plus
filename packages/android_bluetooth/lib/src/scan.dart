part of '../android_bluetooth.dart';

_Map _scanArguments(List<ScanFilter> filters, ScanSettings settings, [ScanDeliveryOptions? deliveryOptions]) => {
      'filters': filters.map((filter) => filter._toMap()).toList(),
      'settings': settings._toMap(),
      if (deliveryOptions != null) 'deliveryOptions': deliveryOptions._toMap(),
    };

/// Native callback delivery controls, applied before serialization and channel delivery.
/// These are package extensions, independent of Android's hardware scan filters.
/// FIRST_MATCH and MATCH_LOST callbacks always pass through without changing
/// advertisement counters or duplicate history.
final class ScanDeliveryOptions {
  const ScanDeliveryOptions({
    this.advertisementDivisor = 1,
    this.suppressDuplicates = false,
    this.includeBatchResults = true,
  });

  /// Deliver the first advertisement per device, then every Nth advertisement.
  /// Sampling follows Android's hardware filters and optional duplicate suppression,
  /// before serialization/channel delivery and any filters applied in Dart.
  /// Must be between 1 and 2147483647. Counters reset with each scan or options update.
  final int advertisementDivisor;

  /// Suppress consecutive identical advertisement bytes per device, ignoring RSSI.
  /// Runs before sampling. A/B/A delivers all three when the divisor is 1.
  final bool suppressDuplicates;

  /// Whether to deliver and count batch results. Defaults to preserving native batches.
  final bool includeBatchResults;

  _Map _toMap() {
    RangeError.checkValueInInterval(advertisementDivisor, 1, 2147483647, 'advertisementDivisor');
    return {
      'advertisementDivisor': advertisementDivisor,
      'suppressDuplicates': suppressDuplicates,
      'includeBatchResults': includeBatchResults,
    };
  }
}

final class ScanFilter {
  const ScanFilter(
      {this.deviceName,
      this.deviceAddress,
      this.serviceUuid,
      this.serviceUuidMask,
      this.serviceSolicitationUuid,
      this.serviceSolicitationUuidMask,
      this.serviceDataUuid,
      this.serviceData,
      this.serviceDataMask,
      this.manufacturerId,
      this.manufacturerData,
      this.manufacturerDataMask,
      this.advertisingDataType,
      this.advertisingData,
      this.advertisingDataMask});
  final String? deviceName, deviceAddress, serviceUuid, serviceUuidMask;
  final String? serviceSolicitationUuid, serviceSolicitationUuidMask, serviceDataUuid;
  final Uint8List? serviceData, serviceDataMask, manufacturerData, manufacturerDataMask;
  final int? manufacturerId, advertisingDataType;
  final Uint8List? advertisingData, advertisingDataMask;
  _Map _toMap() => {
        'deviceName': deviceName,
        'deviceAddress': deviceAddress,
        'serviceUuid': serviceUuid == null ? null : _uuid(serviceUuid!),
        'serviceUuidMask': serviceUuidMask == null ? null : _uuid(serviceUuidMask!),
        'serviceSolicitationUuid': serviceSolicitationUuid == null ? null : _uuid(serviceSolicitationUuid!),
        'serviceSolicitationUuidMask': serviceSolicitationUuidMask == null ? null : _uuid(serviceSolicitationUuidMask!),
        'serviceDataUuid': serviceDataUuid == null ? null : _uuid(serviceDataUuid!),
        'serviceData': serviceData,
        'serviceDataMask': serviceDataMask,
        'manufacturerId': manufacturerId,
        'manufacturerData': manufacturerData,
        'manufacturerDataMask': manufacturerDataMask,
        'advertisingDataType': advertisingDataType,
        'advertisingData': advertisingData,
        'advertisingDataMask': advertisingDataMask,
      };
}

final class ScanSettings {
  const ScanSettings(
      {this.scanMode = scanModeLowPower,
      this.callbackType = callbackTypeAllMatches,
      this.reportDelayMillis = 0,
      this.matchMode,
      this.numOfMatches,
      this.legacy,
      this.phy,
      this.scanType,
      this.rssiThreshold});
  static const scanModeOpportunistic = -1, scanModeLowPower = 0, scanModeBalanced = 1, scanModeLowLatency = 2;
  static const callbackTypeAllMatches = 1, callbackTypeFirstMatch = 2, callbackTypeMatchLost = 4;
  static const callbackTypeAllMatchesAutoBatch = 8, autoBatchMinReportDelayMillis = 600000;
  static const scanTypeUnknown = 0, scanTypePassive = 1, scanTypeActive = 2;
  static const matchModeAggressive = 1, matchModeSticky = 2;
  static const matchNumOneAdvertisement = 1, matchNumFewAdvertisement = 2, matchNumMaxAdvertisement = 3;
  static const phyLeAllSupported = 255;
  final int scanMode, callbackType, reportDelayMillis;
  final int? matchMode, numOfMatches, phy;
  final bool? legacy;

  /// API 36.1: use Android's SCAN_TYPE_* values.
  final int? scanType, rssiThreshold;
  _Map _toMap() => {
        'scanMode': scanMode,
        'callbackType': callbackType,
        'reportDelayMillis': reportDelayMillis,
        'matchMode': matchMode,
        'numOfMatches': numOfMatches,
        'legacy': legacy,
        'phy': phy,
        'scanType': scanType,
        'rssiThreshold': rssiThreshold
      };
}

final class ScanRecord {
  ScanRecord._(this.data);
  final Map<String, Object?> data;
  Uint8List get bytes => _bytes(data['bytes']);
  String? get deviceName => data['deviceName'] as String?;
  int get advertiseFlags => data['advertiseFlags']! as int;
  int get txPowerLevel => data['txPowerLevel']! as int;
  List<String> get serviceUuids => List<String>.unmodifiable((data['serviceUuids'] as List).cast<String>());
  List<String> get serviceSolicitationUuids =>
      List<String>.unmodifiable((data['serviceSolicitationUuids'] as List? ?? []).cast<String>());
  Map<int, Uint8List> get manufacturerSpecificData =>
      Map.unmodifiable(_map(data['manufacturerSpecificData']).map((k, v) => MapEntry(int.parse(k), _bytes(v))));
  Map<String, Uint8List> get serviceData =>
      Map.unmodifiable(_map(data['serviceData']).map((k, v) => MapEntry(k, _bytes(v))));

  /// Raw AD structures, preserving repeated AD types and unknown/vendor fields.
  Map<int, List<Uint8List>> get advertisingData {
    final result = <int, List<Uint8List>>{};
    final raw = bytes;
    for (var offset = 0; offset < raw.length;) {
      final length = raw[offset];
      if (length == 0 || offset + length >= raw.length) break;
      result.putIfAbsent(raw[offset + 1], () => []).add(Uint8List.sublistView(raw, offset + 2, offset + length + 1));
      offset += length + 1;
    }
    return Map.unmodifiable(result.map((type, values) => MapEntry(type, List<Uint8List>.unmodifiable(values))));
  }
}

final class ScanResult {
  ScanResult._(this.data);
  final Map<String, Object?> data;
  BluetoothDevice get device => BluetoothDevice._(_map(data['device']));
  int get rssi => data['rssi']! as int;
  int get timestampNanos => data['timestampNanos']! as int;
  ScanRecord? get scanRecord => data['scanRecord'] == null ? null : ScanRecord._(_map(data['scanRecord']));
  bool? get isConnectable => data['isConnectable'] as bool?;
  bool? get isLegacy => data['isLegacy'] as bool?;
  int? get primaryPhy => data['primaryPhy'] as int?;
  int? get secondaryPhy => data['secondaryPhy'] as int?;
  int? get advertisingSid => data['advertisingSid'] as int?;
  int? get txPower => data['txPower'] as int?;
  int? get periodicAdvertisingInterval => data['periodicAdvertisingInterval'] as int?;
  int? get dataStatus => data['dataStatus'] as int?;
}

/// Native callback union. Individual callback streams expose the corresponding typed result.
class ScanCallback extends BluetoothEvent {
  ScanCallback._base(super.data) : super._();
  factory ScanCallback._(_Map data) => switch (data['type']) {
        'onScanResult' => ScanResultEvent._(data),
        'onBatchScanResults' => BatchScanResultsEvent._(data),
        'onScanFailed' => ScanFailedEvent._(data),
        _ => ScanCallback._base(data),
      };
  static const scanFailedAlreadyStarted = 1, scanFailedApplicationRegistrationFailed = 2;
  static const scanFailedInternalError = 3, scanFailedFeatureUnsupported = 4;
  static const scanFailedOutOfHardwareResources = 5, scanFailedScanningTooFrequently = 6;
  int? get errorCode => data['errorCode'] as int?;
  int? get callbackType => data['callbackType'] as int?;
  List<ScanResult> get results => _decodeList(data['results'], ScanResult._);
}

/// An independent native ScanCallback registration. Android's scan quotas still apply.
final class BluetoothScan {
  BluetoothScan._(String id) : _session = _Session(id);
  final _Session _session;
  String get id => _session.id;
  Stream<ScanCallback> get events => _session.events().map(ScanCallback._);

  /// API 21+. Requires BLUETOOTH_SCAN on API 31+. This registration is independent of the default scan.
  Future<void> stop() => _session.close('scan.stopSession');

  /// API 21+. Requires BLUETOOTH_SCAN on API 31+. This registration is independent of the default scan.
  Future<void> flushPendingScanResults() => _session.call<void>('scan.flushSession');

  /// Replaces native delivery controls and resets per-device history without restarting the radio scan.
  Future<void> setDeliveryOptions(ScanDeliveryOptions options) =>
      _session.call<void>('scan.setDeliveryOptions', {'deliveryOptions': options._toMap()});
}

final class BluetoothLeScanner {
  BluetoothLeScanner._();
  static final shared = BluetoothLeScanner._();

  /// Independent scans with their own settings and callback identity.
  ///
  /// API 21+. Requires BLUETOOTH_SCAN on API 31+; API 23–30 scanning requires granted location permission and applicable system settings.
  Future<BluetoothScan> startScanSession(
          {List<ScanFilter> filters = const [],
          ScanSettings settings = const ScanSettings(),
          ScanDeliveryOptions? deliveryOptions}) async =>
      BluetoothScan._(
          await _Host.call<String>('scan.startSession', _scanArguments(filters, settings, deliveryOptions)));
  Stream<ScanCallback> get events => _Host.events('scanner').map(ScanCallback._);
  Stream<ScanResultEvent> get onScanResult =>
      _Host.events('scanner', 'onScanResult').map(ScanCallback._).cast<ScanResultEvent>();
  Stream<BatchScanResultsEvent> get onBatchScanResults =>
      _Host.events('scanner', 'onBatchScanResults').map(ScanCallback._).cast<BatchScanResultsEvent>();
  Stream<ScanFailedEvent> get onScanFailed =>
      _Host.events('scanner', 'onScanFailed').map(ScanCallback._).cast<ScanFailedEvent>();

  /// API 21+. Requires BLUETOOTH_SCAN on API 31+; API 23–30 scanning requires granted location permission and applicable system settings.
  Future<void> startScan(
          {List<ScanFilter> filters = const [],
          ScanSettings settings = const ScanSettings(),
          ScanDeliveryOptions? deliveryOptions}) =>
      _Host.call<void>('scan.start', _scanArguments(filters, settings, deliveryOptions));

  /// API 21+. Requires BLUETOOTH_SCAN on API 31+; API 23–30 scanning requires granted location permission and applicable system settings.
  Future<void> stopScan() => _Host.call<void>('scan.stop');

  /// API 21+. Requires BLUETOOTH_SCAN on API 31+; API 23–30 scanning requires granted location permission and applicable system settings.
  Future<void> flushPendingScanResults() => _Host.call<void>('scan.flush');

  /// API 26+. Native PendingIntent scanning survives a missing Flutter engine.
  /// Results are buffered in memory while no Flutter engine listens; process death loses the buffer.
  /// Keep the integer scan ID for stopping after an engine restart.
  Future<int> startBackgroundScan(
          {required int id, required List<ScanFilter> filters, ScanSettings settings = const ScanSettings()}) =>
      _Host.call<int>('scan.backgroundStart', {'id': id, ..._scanArguments(filters, settings)});

  /// API 26+. Stops the PendingIntent scan identified by id; already buffered results remain available.
  Future<void> stopBackgroundScan(int id) => _Host.call<void>('scan.backgroundStop', {'id': id});
}

/// Result delivered by `BluetoothLeScanner.onScanResult`.
final class ScanResultEvent extends ScanCallback {
  ScanResultEvent._(super.data) : super._base();
  @override
  int get callbackType => super.callbackType!;
}

/// Result delivered by `BluetoothLeScanner.onBatchScanResults`.
final class BatchScanResultsEvent extends ScanCallback {
  BatchScanResultsEvent._(super.data) : super._base();
}

/// Result delivered by `BluetoothLeScanner.onScanFailed`.
final class ScanFailedEvent extends ScanCallback {
  ScanFailedEvent._(super.data) : super._base();
  @override
  int get errorCode => super.errorCode!;
}
