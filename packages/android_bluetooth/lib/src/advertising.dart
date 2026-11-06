part of '../android_bluetooth.dart';

final class AdvertiseData {
  const AdvertiseData(
      {this.includeDeviceName = false,
      this.includeTxPowerLevel = false,
      this.serviceUuids = const [],
      this.serviceSolicitationUuids = const [],
      this.serviceData = const {},
      this.manufacturerData = const {}});
  final bool includeDeviceName, includeTxPowerLevel;
  final List<String> serviceUuids, serviceSolicitationUuids;
  final Map<String, Uint8List> serviceData;
  final Map<int, Uint8List> manufacturerData;
  _Map _toMap() => {
        'includeDeviceName': includeDeviceName,
        'includeTxPowerLevel': includeTxPowerLevel,
        'serviceUuids': serviceUuids.map(_uuid).toList(),
        'serviceSolicitationUuids': serviceSolicitationUuids.map(_uuid).toList(),
        'serviceData': serviceData.map((k, v) => MapEntry(_uuid(k), v)),
        'manufacturerData': manufacturerData.map((k, v) => MapEntry(k.toString(), v))
      };
}

final class AdvertiseSettings {
  const AdvertiseSettings(
      {this.mode = advertiseModeLowPower,
      this.txPowerLevel = advertiseTxPowerMedium,
      this.connectable = true,
      this.timeoutMillis = 0});
  static const advertiseModeLowPower = 0, advertiseModeBalanced = 1, advertiseModeLowLatency = 2;
  static const advertiseTxPowerUltraLow = 0,
      advertiseTxPowerLow = 1,
      advertiseTxPowerMedium = 2,
      advertiseTxPowerHigh = 3;
  AdvertiseSettings._(_Map data)
      : mode = data['mode']! as int,
        txPowerLevel = data['txPowerLevel']! as int,
        timeoutMillis = data['timeoutMillis']! as int,
        connectable = data['connectable']! as bool;
  final int mode, txPowerLevel, timeoutMillis;
  final bool connectable;
  _Map _toMap() =>
      {'mode': mode, 'txPowerLevel': txPowerLevel, 'connectable': connectable, 'timeoutMillis': timeoutMillis};
}

final class AdvertisingSetParameters {
  const AdvertisingSetParameters(
      {this.connectable = false,
      this.scannable = false,
      this.legacy = false,
      this.anonymous = false,
      this.includeTxPower = false,
      this.primaryPhy = BluetoothDevice.phyLe1m,
      this.secondaryPhy = BluetoothDevice.phyLe1m,
      this.interval = 160,
      this.txPowerLevel = -7});
  final bool connectable, scannable, legacy, anonymous, includeTxPower;
  final int primaryPhy, secondaryPhy, interval, txPowerLevel;
  _Map _toMap() => {
        'connectable': connectable,
        'scannable': scannable,
        'legacy': legacy,
        'anonymous': anonymous,
        'includeTxPower': includeTxPower,
        'primaryPhy': primaryPhy,
        'secondaryPhy': secondaryPhy,
        'interval': interval,
        'txPowerLevel': txPowerLevel
      };
}

final class PeriodicAdvertisingParameters {
  const PeriodicAdvertisingParameters({this.includeTxPower = false, this.interval = 80});
  final bool includeTxPower;
  final int interval;
  _Map _toMap() => {'includeTxPower': includeTxPower, 'interval': interval};
}

/// Native callback union. Individual callback streams expose the corresponding typed result.
class AdvertiseCallback extends BluetoothEvent {
  AdvertiseCallback._base(super.data) : super._();
  factory AdvertiseCallback._(_Map data) => switch (data['type']) {
        'onStartSuccess' => AdvertiseStartedResult._(data),
        'onStartFailure' => AdvertiseFailedResult._(data),
        _ => AdvertiseCallback._base(data),
      };
  int? get errorCode => data['errorCode'] as int?;
  AdvertiseSettings? get settingsInEffect =>
      data['settings'] == null ? null : AdvertiseSettings._(_map(data['settings']));
}

/// Native callback union. Individual callback streams expose the corresponding typed result.
class AdvertisingSetCallback extends BluetoothEvent {
  AdvertisingSetCallback._base(super.data) : super._();
  factory AdvertisingSetCallback._(_Map data) => switch (data['type']) {
        'onAdvertisingSetStarted' => AdvertisingSetStartedResult._(data),
        'onAdvertisingSetStopped' => AdvertisingSetStoppedResult._(data),
        'onAdvertisingEnabled' => AdvertisingEnabledResult._(data),
        'onAdvertisingDataSet' => AdvertisingDataSetResult._(data),
        'onScanResponseDataSet' => ScanResponseDataSetResult._(data),
        'onAdvertisingParametersUpdated' => AdvertisingParametersUpdatedResult._(data),
        'onPeriodicAdvertisingParametersUpdated' => PeriodicAdvertisingParametersUpdatedResult._(data),
        'onPeriodicAdvertisingDataSet' => PeriodicAdvertisingDataSetResult._(data),
        'onPeriodicAdvertisingEnabled' => PeriodicAdvertisingEnabledResult._(data),
        _ => AdvertisingSetCallback._base(data),
      };
  bool? get enabled => data['enabled'] as bool?;
  int? get txPower => data['txPower'] as int?;
}

/// A legacy advertisement's callback identity, used when stopping it.
final class BluetoothAdvertisement {
  BluetoothAdvertisement._(String id) : _session = _Session(id);
  final _Session _session;
  String get id => _session.id;
  Stream<AdvertiseCallback> _events([String? type]) => _session.events(type).map(AdvertiseCallback._);
  Stream<AdvertiseCallback> get events => _events();
  Stream<AdvertiseFailedResult> get onStartFailure => _events('onStartFailure').cast<AdvertiseFailedResult>();
  Stream<AdvertiseStartedResult> get onStartSuccess => _events('onStartSuccess').cast<AdvertiseStartedResult>();

  /// API 21+. Requires BLUETOOTH_ADVERTISE on API 31+. stop is idempotent and completes its event stream.
  Future<void> stop() => _session.close('advertise.stop');
}

/// API 26+. Wait for onAdvertisingSetStarted before changing the set.
final class AdvertisingSet {
  AdvertisingSet._(String id) : _session = _Session(id);
  final _Session _session;
  String get id => _session.id;
  Stream<AdvertisingSetCallback> _events([String? type]) => _session.events(type).map(AdvertisingSetCallback._);
  Stream<AdvertisingSetCallback> get events => _events();
  Stream<PeriodicAdvertisingEnabledResult> get onPeriodicAdvertisingEnabled =>
      _events('onPeriodicAdvertisingEnabled').cast<PeriodicAdvertisingEnabledResult>();
  Stream<PeriodicAdvertisingDataSetResult> get onPeriodicAdvertisingDataSet =>
      _events('onPeriodicAdvertisingDataSet').cast<PeriodicAdvertisingDataSetResult>();
  Stream<PeriodicAdvertisingParametersUpdatedResult> get onPeriodicAdvertisingParametersUpdated =>
      _events('onPeriodicAdvertisingParametersUpdated').cast<PeriodicAdvertisingParametersUpdatedResult>();
  Stream<AdvertisingParametersUpdatedResult> get onAdvertisingParametersUpdated =>
      _events('onAdvertisingParametersUpdated').cast<AdvertisingParametersUpdatedResult>();
  Stream<ScanResponseDataSetResult> get onScanResponseDataSet =>
      _events('onScanResponseDataSet').cast<ScanResponseDataSetResult>();
  Stream<AdvertisingDataSetResult> get onAdvertisingDataSet =>
      _events('onAdvertisingDataSet').cast<AdvertisingDataSetResult>();
  Stream<AdvertisingEnabledResult> get onAdvertisingEnabled =>
      _events('onAdvertisingEnabled').cast<AdvertisingEnabledResult>();
  Stream<AdvertisingSetStoppedResult> get onAdvertisingSetStopped =>
      _events('onAdvertisingSetStopped').cast<AdvertisingSetStoppedResult>();
  Stream<AdvertisingSetStartedResult> get onAdvertisingSetStarted =>
      _events('onAdvertisingSetStarted').cast<AdvertisingSetStartedResult>();
  Future<T> _call<T>(String method, [_Map args = const {}]) => _session.call<T>('advertise.$method', args);

  /// Idempotently requests stop. onAdvertisingSetStopped is delivered before the event streams finish; other operations are rejected once stopping starts.
  Future<void> stop() => _session.close('advertise.stopSet', awaitTerminalEvent: true);

  /// API 26+. Requires BLUETOOTH_ADVERTISE on API 31+. Wait for onAdvertisingSetStarted before updates; completion arrives on its corresponding callback stream.
  Future<void> enableAdvertising(bool enable, {int duration = 0, int maxExtendedAdvertisingEvents = 0}) =>
      _call<void>('enable', {'enable': enable, 'duration': duration, 'maxEvents': maxExtendedAdvertisingEvents});

  /// API 26+. Requires BLUETOOTH_ADVERTISE on API 31+. Wait for onAdvertisingSetStarted before updates; completion arrives on its corresponding callback stream.
  Future<void> setAdvertisingData(AdvertiseData data) => _call<void>('setData', {'data': data._toMap()});

  /// API 26+. Requires BLUETOOTH_ADVERTISE on API 31+. Wait for onAdvertisingSetStarted before updates; completion arrives on its corresponding callback stream.
  Future<void> setScanResponseData(AdvertiseData data) => _call<void>('setScanResponse', {'data': data._toMap()});

  /// API 26+. Requires BLUETOOTH_ADVERTISE on API 31+. Wait for onAdvertisingSetStarted before updates; completion arrives on its corresponding callback stream.
  Future<void> setAdvertisingParameters(AdvertisingSetParameters parameters) =>
      _call<void>('setParameters', {'parameters': parameters._toMap()});

  /// API 26+. Requires BLUETOOTH_ADVERTISE on API 31+. Wait for onAdvertisingSetStarted before updates; completion arrives on its corresponding callback stream.
  Future<void> setPeriodicAdvertisingParameters(PeriodicAdvertisingParameters parameters) =>
      _call<void>('setPeriodicParameters', {'parameters': parameters._toMap()});

  /// API 26+. Requires BLUETOOTH_ADVERTISE on API 31+. Wait for onAdvertisingSetStarted before updates; completion arrives on its corresponding callback stream.
  Future<void> setPeriodicAdvertisingData(AdvertiseData data) =>
      _call<void>('setPeriodicData', {'data': data._toMap()});

  /// API 26+. Requires BLUETOOTH_ADVERTISE on API 31+. Wait for onAdvertisingSetStarted before updates; completion arrives on its corresponding callback stream.
  Future<void> setPeriodicAdvertisingEnabled(bool enable) => _call<void>('setPeriodicEnabled', {'enable': enable});
}

final class BluetoothLeAdvertiser {
  BluetoothLeAdvertiser._();
  static final shared = BluetoothLeAdvertiser._();

  /// API 21+. Returns a legacy advertising registration; onStartSuccess/onStartFailure reports completion.
  Future<BluetoothAdvertisement> startAdvertising(
          {required AdvertiseData data,
          AdvertiseData? scanResponse,
          AdvertiseSettings settings = const AdvertiseSettings()}) async =>
      BluetoothAdvertisement._(await _Host.call<String>('advertise.start',
          {'data': data._toMap(), 'scanResponse': scanResponse?._toMap(), 'settings': settings._toMap()}));

  /// Idempotently stops a legacy registration and completes its streams.
  /// Requires BLUETOOTH_ADVERTISE on API 31+.
  Future<void> stopAdvertising(BluetoothAdvertisement advertisement) => advertisement.stop();

  /// API 26+. Returns an advertising-set registration; onAdvertisingSetStarted reports completion. Extended/periodic features depend on hardware.
  Future<AdvertisingSet> startAdvertisingSet(
          {required AdvertisingSetParameters parameters,
          AdvertiseData? data,
          AdvertiseData? scanResponse,
          PeriodicAdvertisingParameters? periodicParameters,
          AdvertiseData? periodicData,
          int duration = 0,
          int maxExtendedAdvertisingEvents = 0}) async =>
      AdvertisingSet._(await _Host.call<String>('advertise.startSet', {
        'parameters': parameters._toMap(),
        'data': data?._toMap(),
        'scanResponse': scanResponse?._toMap(),
        'periodicParameters': periodicParameters?._toMap(),
        'periodicData': periodicData?._toMap(),
        'duration': duration,
        'maxEvents': maxExtendedAdvertisingEvents
      }));

  /// Idempotently requests stop; onAdvertisingSetStopped precedes stream completion.
  /// API 26+. Requires BLUETOOTH_ADVERTISE on API 31+.
  Future<void> stopAdvertisingSet(AdvertisingSet set) => set.stop();
}

/// Result delivered by `BluetoothAdvertisement.onStartSuccess`.
final class AdvertiseStartedResult extends AdvertiseCallback {
  AdvertiseStartedResult._(super.data) : super._base();
  @override
  AdvertiseSettings get settingsInEffect => super.settingsInEffect!;
}

/// Result delivered by `BluetoothAdvertisement.onStartFailure`.
final class AdvertiseFailedResult extends AdvertiseCallback {
  AdvertiseFailedResult._(super.data) : super._base();
  @override
  int get errorCode => super.errorCode!;
}

/// Result delivered by `AdvertisingSet.onAdvertisingSetStarted`.
final class AdvertisingSetStartedResult extends AdvertisingSetCallback {
  AdvertisingSetStartedResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  int get txPower => super.txPower!;
}

/// Result delivered by `AdvertisingSet.onAdvertisingSetStopped`.
final class AdvertisingSetStoppedResult extends AdvertisingSetCallback {
  AdvertisingSetStoppedResult._(super.data) : super._base();
}

/// Result delivered by `AdvertisingSet.onAdvertisingEnabled`.
final class AdvertisingEnabledResult extends AdvertisingSetCallback {
  AdvertisingEnabledResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  bool get enabled => super.enabled!;
}

/// Result delivered by `AdvertisingSet.onAdvertisingDataSet`.
final class AdvertisingDataSetResult extends AdvertisingSetCallback {
  AdvertisingDataSetResult._(super.data) : super._base();
  @override
  int get status => super.status!;
}

/// Result delivered by `AdvertisingSet.onAdvertisingParametersUpdated`.
final class AdvertisingParametersUpdatedResult extends AdvertisingSetCallback {
  AdvertisingParametersUpdatedResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  int get txPower => super.txPower!;
}

/// Result delivered by `AdvertisingSet.onPeriodicAdvertisingParametersUpdated`.
final class PeriodicAdvertisingParametersUpdatedResult extends AdvertisingSetCallback {
  PeriodicAdvertisingParametersUpdatedResult._(super.data) : super._base();
  @override
  int get status => super.status!;
}

/// Result delivered by `AdvertisingSet.onPeriodicAdvertisingDataSet`.
final class PeriodicAdvertisingDataSetResult extends AdvertisingSetCallback {
  PeriodicAdvertisingDataSetResult._(super.data) : super._base();
  @override
  int get status => super.status!;
}

/// Result delivered by `AdvertisingSet.onPeriodicAdvertisingEnabled`.
final class PeriodicAdvertisingEnabledResult extends AdvertisingSetCallback {
  PeriodicAdvertisingEnabledResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  bool get enabled => super.enabled!;
}

/// Result delivered by `AdvertisingSet.onScanResponseDataSet`.
final class ScanResponseDataSetResult extends AdvertisingSetCallback {
  ScanResponseDataSetResult._(super.data) : super._base();
  @override
  int get status => super.status!;
}
