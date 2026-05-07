part of '../android_bluetooth.dart';

/// Android 16/API 36 raw BLE ranging. Exchange peer parameters through your own protocol.
final class BleCsRangingParams {
  const BleCsRangingParams(
      {required this.peerBluetoothAddress,
      this.rangingUpdateRate,
      this.securityLevel,
      this.locationType,
      this.sightType});
  final String peerBluetoothAddress;
  final int? rangingUpdateRate, securityLevel, locationType, sightType;
  _Map _toMap() => {
        'peerBluetoothAddress': peerBluetoothAddress,
        'rangingUpdateRate': rangingUpdateRate,
        'securityLevel': securityLevel,
        'locationType': locationType,
        'sightType': sightType
      };
}

final class BleRssiRangingParams {
  const BleRssiRangingParams({required this.peerBluetoothAddress, this.rangingUpdateRate});
  final String peerBluetoothAddress;
  final int? rangingUpdateRate;
  _Map _toMap() => {'peerBluetoothAddress': peerBluetoothAddress, 'rangingUpdateRate': rangingUpdateRate};
}

final class RawRangingDevice {
  RawRangingDevice({required String uuid, this.csRangingParams, this.bleRssiRangingParams}) : uuid = _uuid(uuid);
  final String uuid;
  final BleCsRangingParams? csRangingParams;
  final BleRssiRangingParams? bleRssiRangingParams;
  _Map _toMap() => {
        'uuid': uuid,
        'csRangingParams': csRangingParams?._toMap(),
        'bleRssiRangingParams': bleRssiRangingParams?._toMap()
      };
}

final class SessionConfig {
  const SessionConfig(
      {this.angleOfArrivalNeeded = false,
      this.rangingMeasurementsLimit,
      this.sensorFusionEnabled,
      this.notificationConfigType,
      this.proximityNearCm,
      this.proximityFarCm});
  final bool angleOfArrivalNeeded;
  final bool? sensorFusionEnabled;
  final int? rangingMeasurementsLimit, notificationConfigType;
  final int? proximityNearCm, proximityFarCm;
  _Map _toMap() => {
        'angleOfArrivalNeeded': angleOfArrivalNeeded,
        'rangingMeasurementsLimit': rangingMeasurementsLimit,
        'sensorFusionEnabled': sensorFusionEnabled,
        'notificationConfigType': notificationConfigType,
        'proximityNearCm': proximityNearCm,
        'proximityFarCm': proximityFarCm
      };
}

final class RangingPreference {
  const RangingPreference(
      {required this.deviceRole, required this.devices, this.sessionConfig = const SessionConfig()});
  static const deviceRoleInitiator = 1, deviceRoleResponder = 0;
  final int deviceRole;
  final List<RawRangingDevice> devices;
  final SessionConfig sessionConfig;
  _Map _toMap() => {
        'deviceRole': deviceRole,
        'devices': devices.map((d) => d._toMap()).toList(),
        'sessionConfig': sessionConfig._toMap()
      };
}

final class RangingMeasurement {
  RangingMeasurement._(_Map m)
      : measurement = (m['measurement']! as num).toDouble(),
        confidence = m['confidence']! as int;
  final double measurement;
  final int confidence;
}

final class RangingData {
  RangingData._(_Map data) : data = _map(data);
  final Map<String, Object?> data;
  int get rangingTechnology => data['rangingTechnology']! as int;
  int get timestampMillis => data['timestampMillis']! as int;
  int? get rssi => data['rssi'] as int?;
  RangingMeasurement? get distance => data['distance'] == null ? null : RangingMeasurement._(_map(data['distance']));
  RangingMeasurement? get azimuth => data['azimuth'] == null ? null : RangingMeasurement._(_map(data['azimuth']));
  RangingMeasurement? get elevation => data['elevation'] == null ? null : RangingMeasurement._(_map(data['elevation']));
}

final class RangingCapabilities {
  RangingCapabilities._(_Map data) : data = _map(data);
  final Map<String, Object?> data;
  Map<int, int> get technologyAvailability =>
      Map.unmodifiable(_map(data['technologyAvailability']).map((k, v) => MapEntry(int.parse(k), v! as int)));
  List<int> get csSupportedSecurityLevels =>
      List<int>.unmodifiable((data['csSupportedSecurityLevels'] as List? ?? []).cast<int>());
}

/// Native callback union. Individual callback streams expose the corresponding typed result.
class RangingSessionCallback extends BluetoothEvent {
  RangingSessionCallback._base(super.data) : super._();
  factory RangingSessionCallback._(_Map data) => switch (data['type']) {
        'onOpened' => RangingOpenedResult._(data),
        'onOpenFailed' => RangingOpenFailedResult._(data),
        'onClosed' => RangingClosedResult._(data),
        'onStarted' => RangingStartedResult._(data),
        'onStopped' => RangingStoppedResult._(data),
        'onResults' => RangingResultsResult._(data),
        _ => RangingSessionCallback._base(data),
      };
  String? get peerUuid => data['peerUuid'] as String?;
  int? get reason => data['reason'] as int?;
  int? get technology => data['technology'] as int?;
  RangingData? get result => data['result'] == null ? null : RangingData._(_map(data['result']));
}

final class RangingSession {
  RangingSession._(String id) : _session = _Session(id);
  final _Session _session;
  String get id => _session.id;
  Stream<RangingSessionCallback> get events => _session.events().map(RangingSessionCallback._);
  Stream<RangingResultsResult> get onResults =>
      events.where((event) => event.type == 'onResults').cast<RangingResultsResult>();
  Stream<RangingStoppedResult> get onStopped =>
      events.where((event) => event.type == 'onStopped').cast<RangingStoppedResult>();
  Stream<RangingStartedResult> get onStarted =>
      events.where((event) => event.type == 'onStarted').cast<RangingStartedResult>();
  Stream<RangingClosedResult> get onClosed =>
      events.where((event) => event.type == 'onClosed').cast<RangingClosedResult>();
  Stream<RangingOpenFailedResult> get onOpenFailed =>
      events.where((event) => event.type == 'onOpenFailed').cast<RangingOpenFailedResult>();
  Stream<RangingOpenedResult> get onOpened =>
      events.where((event) => event.type == 'onOpened').cast<RangingOpenedResult>();

  /// API 36+. Requires granted RANGING permission. Completion/results arrive through the session callback streams.
  Future<void> start(RangingPreference preference) =>
      _session.call<void>('ranging.start', {'preference': preference._toMap()});

  /// API 36+. Requires granted RANGING permission. Completion/results arrive through the session callback streams.
  Future<void> stop() => _session.call<void>('ranging.stop');

  /// Cancels the CancellationSignal returned by the most recent native start.
  ///
  /// API 36+. Requires granted RANGING permission. Completion/results arrive through the session callback streams.
  Future<void> cancelStart() => _session.call<void>('ranging.cancelStart');

  /// Idempotently requests close. An outstanding start delivers onClosed or onOpenFailed
  /// before its streams finish. Without an outstanding start, they finish after native close.
  Future<void> close() => _session.close('ranging.close', awaitTerminalEvent: true);

  /// API 36+. Requires granted RANGING permission. Completion/results arrive through the session callback streams.
  Future<void> reconfigureRangingInterval(int interval) =>
      _session.call<void>('ranging.reconfigure', {'interval': interval});

  /// API 36+. Requests dynamic peer addition using Android's RawResponderRangingConfig.
  /// Requires RANGING permission. Support depends on the native technology;
  /// Android reports unsupported additions through the session callback streams.
  Future<void> addDeviceToRangingSession(RawRangingDevice device) =>
      _session.call<void>('ranging.addDevice', {'device': device._toMap()});

  /// Currently throws PlatformException with code unsupported: Android's raw peer
  /// removal supports UWB multicast only. Create a new BLE session with the desired peers.
  Future<void> removeDeviceFromRangingSession(String uuid) =>
      _session.call<void>('ranging.removeDevice', {'uuid': _uuid(uuid)});
}

final class RangingManager {
  RangingManager._();
  static final shared = RangingManager._();
  static const bleCs = 1, bleRssi = 3;
  Stream<RangingCapabilities> get onRangingCapabilities =>
      _Host.events('ranging', 'onRangingCapabilities').map((m) => RangingCapabilities._(_map(m['capabilities'])));

  /// API 36+. Requires applicable RANGING permission and compatible BLE ranging hardware. No Wi-Fi/UWB ranging is selected.
  Future<void> registerCapabilitiesCallback() => _Host.call<void>('ranging.registerCapabilities');

  /// API 36+. Requires applicable RANGING permission and compatible BLE ranging hardware. No Wi-Fi/UWB ranging is selected.
  Future<void> unregisterCapabilitiesCallback() => _Host.call<void>('ranging.unregisterCapabilities');

  /// API 36+. Requires applicable RANGING permission and compatible BLE ranging hardware. No Wi-Fi/UWB ranging is selected.
  Future<RangingSession> createRangingSession() async => RangingSession._(await _Host.call<String>('ranging.create'));
}

/// Result delivered by `RangingSession.onOpened`.
final class RangingOpenedResult extends RangingSessionCallback {
  RangingOpenedResult._(super.data) : super._base();
}

/// Result delivered by `RangingSession.onOpenFailed`.
final class RangingOpenFailedResult extends RangingSessionCallback {
  RangingOpenFailedResult._(super.data) : super._base();
  @override
  int get reason => super.reason!;
}

/// Result delivered by `RangingSession.onClosed`.
final class RangingClosedResult extends RangingSessionCallback {
  RangingClosedResult._(super.data) : super._base();
  @override
  int get reason => super.reason!;
}

/// Result delivered by `RangingSession.onStarted`.
final class RangingStartedResult extends RangingSessionCallback {
  RangingStartedResult._(super.data) : super._base();
  @override
  String get peerUuid => super.peerUuid!;
  @override
  int get technology => super.technology!;
}

/// Result delivered by `RangingSession.onStopped`.
final class RangingStoppedResult extends RangingSessionCallback {
  RangingStoppedResult._(super.data) : super._base();
  @override
  String get peerUuid => super.peerUuid!;
  @override
  int get technology => super.technology!;
}

/// Result delivered by `RangingSession.onResults`.
final class RangingResultsResult extends RangingSessionCallback {
  RangingResultsResult._(super.data) : super._base();
  @override
  String get peerUuid => super.peerUuid!;
  @override
  RangingData get result => super.result!;
}
