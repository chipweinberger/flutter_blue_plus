part of '../android_bluetooth.dart';

typedef _Map = Map<String, Object?>;

abstract final class BluetoothStatusCodes {
  static const success = 0, errorBluetoothNotEnabled = 1, errorBluetoothNotAllowed = 2;
  static const errorDeviceNotBonded = 3, errorMissingBluetoothConnectPermission = 6;
  static const errorProfileServiceNotBound = 9, featureSupported = 10, featureNotSupported = 11;
  static const featureNotConfigured = 30, errorGattWriteNotAllowed = 200, errorGattWriteRequestBusy = 201;
  static const errorUnknown = 2147483647;
}

bool _supportsReadOnlyBytes() {
  try {
    (Uint8List(0) as dynamic).asUnmodifiableView();
    return true;
  } on NoSuchMethodError {
    return false;
  }
}

final bool _hasReadOnlyBytes = _supportsReadOnlyBytes();

Object? _freeze(Object? value) {
  if (value is Uint8List) {
    if (!_hasReadOnlyBytes) return List<int>.unmodifiable(value);
    final copy = Uint8List.fromList(value);
    return (copy as dynamic).asUnmodifiableView();
  }
  if (value is Map) return Map<Object?, Object?>.unmodifiable(value.map((k, v) => MapEntry(k, _freeze(v))));
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

_Map _map(Object? value) => Map<String, Object?>.unmodifiable(Map<String, Object?>.from(value! as Map));
List<T> _decodeList<T>(Object? value, T Function(_Map) decode) =>
    List<T>.unmodifiable((value as List? ?? []).map((entry) => decode(_map(entry))));
Uint8List _bytes(Object? value) {
  // Received typed bytes were already copied and made read-only by _freeze.
  if (_hasReadOnlyBytes && value is Uint8List) return value;
  final copy = Uint8List.fromList((value as List).cast<int>());
  // Dart 3.0–3.2 have no read-only typed-list view that also exists on modern Dart.
  // Return an isolated copy there; mutating it can never change a shared snapshot.
  return _hasReadOnlyBytes ? (copy as dynamic).asUnmodifiableView() as Uint8List : copy;
}

BluetoothEvent _event(_Map data) {
  final owner = data['owner']! as String;
  if (owner == 'scanner' || owner.startsWith('scan-')) return ScanCallback._(data);
  if (owner == 'device') return BluetoothDeviceEvent._(data);
  if (owner == 'adapter') {
    return data['type'] == 'onEnableResponse' ? BluetoothEnableResponse._(data) : BluetoothAdapterEvent._(data);
  }
  if (owner == 'engine') return BluetoothEngineEvent._(data);
  if (owner.startsWith('gatt-')) return BluetoothGattCallback._(data);
  if (owner.startsWith('server-')) return BluetoothGattServerCallback._(data);
  if (owner.startsWith('advertising-set-')) return AdvertisingSetCallback._(data);
  if (owner.startsWith('advertisement-')) return AdvertiseCallback._(data);
  if (owner.startsWith('ranging-')) return RangingSessionCallback._(data);
  if (owner == 'companion' || owner.startsWith('association-')) return CompanionDeviceCallback._(data);
  return BluetoothEvent._(data);
}

final _uuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

String _uuid(String value) {
  final short = value.toLowerCase();
  final expanded = switch (short.length) {
    4 => '0000$short-0000-1000-8000-00805f9b34fb',
    8 => '$short-0000-1000-8000-00805f9b34fb',
    _ => short,
  };
  if (!_uuidPattern.hasMatch(expanded)) {
    throw ArgumentError.value(value, 'uuid', 'Expected a 16, 32 or 128 bit Bluetooth UUID');
  }
  return expanded;
}

/// A native callback. [status] is Android's unmodified status, when supplied.
/// Successful method invocation only means the request was submitted; completion
/// is delivered separately as a callback, just as on Android.
class BluetoothEvent {
  // The host supplies an immutable snapshot shared by callback readers.
  BluetoothEvent._(this.data);
  final Map<String, Object?> data;
  String get type => data['type']! as String;

  int? get status => data['status'] as int?;
  String? get message => data['message'] as String?;
  BluetoothDevice? get device => data['device'] == null ? null : BluetoothDevice._(_map(data['device']));
}

/// Native engine lifecycle. A detach retires the engine's active registrations.
final class BluetoothEngineEvent extends BluetoothEvent {
  BluetoothEngineEvent._(super.data) : super._();
}

final class _EventHub {
  final pending = Queue<_Map>();
  bool finished = false;
  bool flushScheduled = false;
  late final StreamController<_Map> controller = StreamController<_Map>.broadcast(onListen: scheduleFlush);

  Stream<_Map> events([String? type]) {
    final stream = controller.stream;
    return type == null ? stream : stream.where((event) => event['type'] == type);
  }

  void flush() {
    flushScheduled = false;
    while (controller.hasListener && pending.isNotEmpty) {
      controller.add(pending.removeFirst());
    }
    if (finished && pending.isEmpty) unawaited(controller.close());
  }

  void scheduleFlush() {
    if (flushScheduled) return;
    flushScheduled = true;
    // Let all typed listeners installed in this synchronous block join the replay.
    scheduleMicrotask(flush);
  }

  void add(_Map event) {
    if (finished) return;
    if (controller.hasListener && !flushScheduled && pending.isEmpty) {
      controller.add(event);
    } else {
      pending.addLast(event);
    }
  }

  void finish() {
    if (finished) return;
    finished = true;
    if (controller.hasListener) {
      scheduleFlush();
    } else if (pending.isEmpty) {
      unawaited(controller.close());
    }
  }
}

/// One native registration. The cached hub remains valid after it is retired from the router.
final class _Session {
  _Session(this.id) : hub = _Host.hub(id) {
    if (hub.finished) {
      _Host.hubs.remove(id);
      _Host.retired.add(id);
    } else {
      _Host.sessions[id] = this;
    }
  }
  final String id;
  final _EventHub hub;
  bool closing = false;
  Future<void>? _closeFuture;

  Stream<_Map> events([String? type]) => hub.events(type);

  Future<T> call<T>(String method, [_Map args = const {}]) async {
    if (closing || hub.finished) throw StateError('Native session $id is closed');
    return _Host.call<T>(method, {'id': id, ...args});
  }

  void finish() {
    hub.finish();
    _Host.hubs.remove(id);
    _Host.sessions.remove(id);
    _Host.retired.add(id);
  }

  Future<void> close(String method, {bool awaitTerminalEvent = false}) {
    if (_closeFuture != null) return _closeFuture!;
    if (hub.finished) return Future.value();
    closing = true;
    return _closeFuture = _close(method, awaitTerminalEvent);
  }

  Future<void> _close(String method, bool awaitTerminalEvent) async {
    try {
      final callbackExpected = await _Host.call<Object?>(method, {'id': id});
      // Native ranging close returns false when no started session can send a final callback.
      if (!awaitTerminalEvent || callbackExpected == false) finish();
    } catch (_) {
      closing = false;
      _closeFuture = null;
      rethrow;
    }
  }
}

final class _Host {
  static const methods = MethodChannel('dev.android_bluetooth/methods');
  static const eventChannel = EventChannel('dev.android_bluetooth/events');
  static final controller = StreamController<_Map>.broadcast(sync: true);
  static StreamSubscription<Object?>? subscription;
  static final hubs = <String, _EventHub>{};
  static final sessions = <String, _Session>{};
  static final retired = <String>{};
  static _EventHub hub(String owner) => hubs.putIfAbsent(owner, _EventHub.new);

  static bool terminal(_Map event) {
    final owner = event['owner']! as String, type = event['type']! as String;
    if (owner.startsWith('advertising-set-')) {
      return type == 'onAdvertisingSetStopped' || type == 'onAdvertisingSetStarted' && event['status'] != 0;
    }
    if (owner.startsWith('advertisement-')) return type == 'onStartFailure';
    if (owner.startsWith('ranging-')) {
      return type == 'onClosed' || type == 'onOpenFailed' && event['isComplete'] == true;
    }
    if (owner.startsWith('scan-')) return type == 'onScanFailed';
    if (owner.startsWith('association-')) {
      return event['isComplete'] == true || type == 'onFailure' || type == 'onAssociationCancelled';
    }
    return false;
  }

  static void detachSessions() {
    BluetoothGatt._clients.clear();
    for (final session in sessions.values.toList()) {
      session.finish();
    }
    // A callback may arrive before its native registration's open result.
    for (final entry in hubs.entries.toList()) {
      if (entry.key.contains('-')) {
        entry.value.finish();
        hubs.remove(entry.key);
        retired.add(entry.key);
      }
    }
  }

  static void forwardError(Object error, StackTrace stack) {
    controller.addError(error, stack);
    for (final hub in hubs.values) {
      if (hub.controller.hasListener) hub.controller.addError(error, stack);
    }
  }

  static void accept(Object? raw) {
    final event = _map(_freeze(raw));
    final owner = event['owner']! as String;
    if (retired.contains(owner)) return;
    final target = hub(owner);
    target.add(event);
    controller.add(event);
    if (owner == 'engine' && event['type'] == 'onDetachedFromEngine') {
      detachSessions();
    }
    if (terminal(event)) {
      final session = sessions[owner];
      if (session != null) {
        session.finish();
      } else {
        target.finish();
      }
    }
  }

  static void listen() {
    if (subscription != null) return;
    late final StreamSubscription<Object?> current;
    current = eventChannel.receiveBroadcastStream().listen(accept, onError: forwardError, onDone: () {
      if (identical(subscription, current)) subscription = null;
    });
    subscription = current;
  }

  static Stream<_Map> events(String owner, [String? type]) {
    listen();
    return hub(owner).events(type);
  }

  static Future<T> call<T>(String method, [_Map args = const {}]) async {
    listen();
    return _freeze(await methods.invokeMethod<T>(method, args)) as T;
  }
}

/// Package entry point. Native names remain the primary public API.
abstract final class AndroidBluetooth {
  /// System location setting, without prompting or requiring an Activity.
  /// Wrappers can use this for Android 5–11 BLE scan preflight; API 31+ scanning
  /// normally depends on Bluetooth permissions instead of this setting.
  static Future<bool> get isLocationEnabled => _Host.call<bool>('environment.isLocationEnabled');

  static Stream<BluetoothEngineEvent> get onDetachedFromEngine =>
      _Host.events('engine', 'onDetachedFromEngine').map(BluetoothEngineEvent._);

  /// API level and the local adapter's BLE capabilities.
  ///
  /// Android only. Permission requests require an attached Activity; capability queries do not prompt.
  static Future<BluetoothCapabilities> get capabilities async =>
      BluetoothCapabilities._(_map(await _Host.call<Object>('adapter.capabilities')));

  /// All native callbacks, including buffered background scan/presence events.
  /// Global listeners do not consume callbacks buffered for owner streams.
  static Stream<BluetoothEvent> get events {
    _Host.listen();
    return _Host.controller.stream.map(_event);
  }

  /// Explicitly request permissions. Declare optional permissions in the app.
  /// Android 12+: SCAN/CONNECT/ADVERTISE. Earlier scanning: FINE_LOCATION.
  ///
  /// Android only. Permission requests require an attached Activity; capability queries do not prompt.
  static Future<Map<String, bool>> requestPermissions(List<String> permissions) async =>
      (await _Host.call<Map>('permissions.request', {'permissions': permissions})).cast<String, bool>();

  /// Checks current grants without prompting; no Activity is required.
  static Future<Map<String, bool>> checkPermissions(List<String> permissions) async =>
      (await _Host.call<Map>('permissions.check', {'permissions': permissions})).cast<String, bool>();
}

final class BluetoothCapabilities {
  BluetoothCapabilities._(this.values);
  final Map<String, Object?> values;
  int get apiLevel => values['apiLevel']! as int;
  bool get isSupported => values['isSupported']! as bool;

  /// Adapter presence, independent of the BLE feature flag and permission state.
  bool get hasAdapter => values['hasAdapter']! as bool;
  bool? get isEnabled => values['isEnabled'] as bool?;
  bool get permissionRequired => values['permissionRequired'] == true;
  bool? get isLe2MPhySupported => values['isLe2MPhySupported'] as bool?;
  bool? get isLeCodedPhySupported => values['isLeCodedPhySupported'] as bool?;
  bool? get isLeExtendedAdvertisingSupported => values['isLeExtendedAdvertisingSupported'] as bool?;
  bool? get isLePeriodicAdvertisingSupported => values['isLePeriodicAdvertisingSupported'] as bool?;
  bool? get isMultipleAdvertisementSupported => values['isMultipleAdvertisementSupported'] as bool?;
  bool? get isOffloadedFilteringSupported => values['isOffloadedFilteringSupported'] as bool?;
  bool? get isOffloadedScanBatchingSupported => values['isOffloadedScanBatchingSupported'] as bool?;
  int? get leMaximumAdvertisingDataLength => values['leMaximumAdvertisingDataLength'] as int?;
}
