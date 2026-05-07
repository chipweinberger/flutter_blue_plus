part of '../android_bluetooth.dart';

int _localAttributeId = 0;

T? _findByUuid<T>(Iterable<T> attributes, String uuid, String Function(T) uuidOf) {
  // Empty collections have always returned null without validating the UUID.
  late final normalized = _uuid(uuid);
  for (final attribute in attributes) {
    if (uuidOf(attribute) == normalized) return attribute;
  }
  return null;
}

final class BluetoothGattDescriptor {
  BluetoothGattDescriptor(String uuid, this.permissions)
      : uuid = _uuid(uuid),
        characteristic = null,
        handle = 'local-${_localAttributeId++}';
  BluetoothGattDescriptor._(_Map m)
      : uuid = m['uuid']! as String,
        permissions = m['permissions']! as int,
        handle = m['handle']! as String,
        characteristic = m['characteristic'] == null ? null : BluetoothGattCharacteristic._(_map(m['characteristic']));
  static const permissionRead = 1, permissionReadEncrypted = 2, permissionReadEncryptedMitm = 4;
  static const permissionWrite = 16, permissionWriteEncrypted = 32, permissionWriteEncryptedMitm = 64;
  static const permissionWriteSigned = 128, permissionWriteSignedMitm = 256;
  static Uint8List get enableNotificationValue => Uint8List.fromList([1, 0]);
  static Uint8List get enableIndicationValue => Uint8List.fromList([2, 0]);
  static Uint8List get disableNotificationValue => Uint8List.fromList([0, 0]);
  final String uuid, handle;
  final int permissions;

  /// Parent identity, including its service, when supplied by Android.
  final BluetoothGattCharacteristic? characteristic;
  _Map _toMap() => {'uuid': uuid, 'handle': handle, 'permissions': permissions};
}

final class BluetoothGattCharacteristic {
  BluetoothGattCharacteristic(String uuid, this.properties, this.permissions,
      {List<BluetoothGattDescriptor>? descriptors})
      : uuid = _uuid(uuid),
        service = null,
        handle = 'local-${_localAttributeId++}',
        instanceId = 0,
        descriptors = descriptors ?? [];
  BluetoothGattCharacteristic._(_Map m)
      : uuid = m['uuid']! as String,
        handle = m['handle']! as String,
        instanceId = m['instanceId']! as int,
        properties = m['properties']! as int,
        permissions = m['permissions']! as int,
        descriptors = _decodeList(m['descriptors'], BluetoothGattDescriptor._),
        service = m['service'] == null ? null : BluetoothGattService._(_map(m['service']));
  static const propertyBroadcast = 1, propertyRead = 2, propertyWriteNoResponse = 4, propertyWrite = 8;
  static const propertyNotify = 16, propertyIndicate = 32, propertySignedWrite = 64, propertyExtendedProps = 128;
  static const writeTypeNoResponse = 1, writeTypeDefault = 2, writeTypeSigned = 4;
  static const permissionRead = 1, permissionReadEncrypted = 2, permissionReadEncryptedMitm = 4;
  static const permissionWrite = 16, permissionWriteEncrypted = 32, permissionWriteEncryptedMitm = 64;
  static const permissionWriteSigned = 128, permissionWriteSignedMitm = 256;
  final String uuid, handle;
  final int instanceId, properties, permissions;
  final List<BluetoothGattDescriptor> descriptors;

  /// Parent service identity, also retained for callbacks from invalidated discoveries.
  final BluetoothGattService? service;
  BluetoothGattDescriptor? getDescriptor(String uuid) =>
      _findByUuid(descriptors, uuid, (descriptor) => descriptor.uuid);
  _Map _toMap() => {
        'uuid': uuid,
        'handle': handle,
        'instanceId': instanceId,
        'properties': properties,
        'permissions': permissions,
        'descriptors': descriptors.map((d) => d._toMap()).toList()
      };
}

final class BluetoothGattService {
  BluetoothGattService(String uuid,
      {this.type = serviceTypePrimary,
      List<BluetoothGattCharacteristic>? characteristics,
      List<BluetoothGattService>? includedServices})
      : uuid = _uuid(uuid),
        handle = 'local-${_localAttributeId++}',
        instanceId = 0,
        characteristics = characteristics ?? [],
        includedServices = includedServices ?? [];
  BluetoothGattService._(_Map m)
      : uuid = m['uuid']! as String,
        handle = m['handle']! as String,
        instanceId = m['instanceId']! as int,
        type = m['serviceType']! as int,
        characteristics = _decodeList(m['characteristics'], BluetoothGattCharacteristic._),
        includedServices = _decodeList(m['includedServices'], BluetoothGattService._);
  static const serviceTypePrimary = 0, serviceTypeSecondary = 1;
  final String uuid, handle;
  final int instanceId, type;
  final List<BluetoothGattCharacteristic> characteristics;
  final List<BluetoothGattService> includedServices;
  BluetoothGattCharacteristic? getCharacteristic(String uuid) =>
      _findByUuid(characteristics, uuid, (characteristic) => characteristic.uuid);
  _Map _toMap() => {
        'uuid': uuid,
        'handle': handle,
        'instanceId': instanceId,
        'serviceType': type,
        'characteristics': characteristics.map((c) => c._toMap()).toList(),
        'includedServices': includedServices.map((s) => {'handle': s.handle}).toList()
      };
}

/// Native callback union. Individual callback streams expose the corresponding typed result.
class BluetoothGattCallback extends BluetoothEvent {
  BluetoothGattCallback._base(super.data) : super._();
  factory BluetoothGattCallback._(_Map data) => switch (data['type']) {
        'onConnectionStateChange' => GattConnectionStateChangeResult._(data),
        'onServicesDiscovered' => GattServicesDiscoveredResult._(data),
        'onCharacteristicRead' => GattCharacteristicReadResult._(data),
        'onCharacteristicWrite' => GattCharacteristicWriteResult._(data),
        'onCharacteristicChanged' => GattCharacteristicChangedResult._(data),
        'onDescriptorRead' => GattDescriptorReadResult._(data),
        'onDescriptorWrite' => GattDescriptorWriteResult._(data),
        'onMtuChanged' => GattMtuChangedResult._(data),
        'onReadRemoteRssi' => GattReadRemoteRssiResult._(data),
        'onReliableWriteCompleted' => GattReliableWriteCompletedResult._(data),
        'onPhyRead' => GattPhyReadResult._(data),
        'onPhyUpdate' => GattPhyUpdateResult._(data),
        'onServiceChanged' => GattServiceChangedResult._(data),
        'onSubrateChange' => GattSubrateChangeResult._(data),
        _ => BluetoothGattCallback._base(data),
      };
  int? get newState => data['newState'] as int?;
  int? get mtu => data['mtu'] as int?;
  int? get rssi => data['rssi'] as int?;
  int? get txPhy => data['txPhy'] as int?;
  int? get rxPhy => data['rxPhy'] as int?;
  int? get subrateMode => data['subrateMode'] as int?;
  Uint8List? get value => data['value'] == null ? null : _bytes(data['value']);
  BluetoothGattCharacteristic? get characteristic =>
      data['characteristic'] == null ? null : BluetoothGattCharacteristic._(_map(data['characteristic']));
  BluetoothGattDescriptor? get descriptor =>
      data['descriptor'] == null ? null : BluetoothGattDescriptor._(_map(data['descriptor']));
  List<BluetoothGattService> get services => _decodeList(data['services'], BluetoothGattService._);
}

final class BluetoothGatt {
  BluetoothGatt._(String id, this._address) : _session = _Session(id) {
    if (!_session.hub.finished) _clients.add(this);
  }
  static final _clients = <BluetoothGatt>{};
  final String _address;
  final _Session _session;
  String get id => _session.id;
  static const gattSuccess = 0, gattReadNotPermitted = 2, gattWriteNotPermitted = 3;
  static const gattInsufficientAuthentication = 5, gattRequestNotSupported = 6, gattInvalidOffset = 7;
  static const gattInsufficientAuthorization = 8, gattInvalidAttributeLength = 13;
  static const gattInsufficientEncryption = 15, gattConnectionCongested = 143, gattFailure = 257;
  static const connectionPriorityBalanced = 0, connectionPriorityHigh = 1, connectionPriorityLowPower = 2;
  static const connectionPriorityDck = 3;
  static const subrateModeOff = 0, subrateModeLow = 1, subrateModeBalanced = 2, subrateModeHigh = 3;
  static const subrateModeSystemUpdate = 99, subrateModeNotUpdated = 255;
  Stream<BluetoothGattCallback> _events([String? type]) => _session.events(type).map(BluetoothGattCallback._);
  Stream<BluetoothGattCallback> get events => _events();
  Stream<GattConnectionStateChangeResult> get onConnectionStateChange =>
      _events('onConnectionStateChange').cast<GattConnectionStateChangeResult>();
  Stream<GattServicesDiscoveredResult> get onServicesDiscovered =>
      _events('onServicesDiscovered').cast<GattServicesDiscoveredResult>();
  Stream<GattCharacteristicReadResult> get onCharacteristicRead =>
      _events('onCharacteristicRead').cast<GattCharacteristicReadResult>();
  Stream<GattCharacteristicWriteResult> get onCharacteristicWrite =>
      _events('onCharacteristicWrite').cast<GattCharacteristicWriteResult>();
  Stream<GattCharacteristicChangedResult> get onCharacteristicChanged =>
      _events('onCharacteristicChanged').cast<GattCharacteristicChangedResult>();
  Stream<GattDescriptorReadResult> get onDescriptorRead => _events('onDescriptorRead').cast<GattDescriptorReadResult>();
  Stream<GattDescriptorWriteResult> get onDescriptorWrite =>
      _events('onDescriptorWrite').cast<GattDescriptorWriteResult>();
  Stream<GattMtuChangedResult> get onMtuChanged => _events('onMtuChanged').cast<GattMtuChangedResult>();
  Stream<GattReadRemoteRssiResult> get onReadRemoteRssi => _events('onReadRemoteRssi').cast<GattReadRemoteRssiResult>();
  Stream<GattReliableWriteCompletedResult> get onReliableWriteCompleted =>
      _events('onReliableWriteCompleted').cast<GattReliableWriteCompletedResult>();
  Stream<GattPhyReadResult> get onPhyRead => _events('onPhyRead').cast<GattPhyReadResult>();
  Stream<GattPhyUpdateResult> get onPhyUpdate => _events('onPhyUpdate').cast<GattPhyUpdateResult>();
  Stream<GattServiceChangedResult> get onServiceChanged => _events('onServiceChanged').cast<GattServiceChangedResult>();
  Stream<GattSubrateChangeResult> get onSubrateChange => _events('onSubrateChange').cast<GattSubrateChangeResult>();
  Future<T> _call<T>(String method, [_Map args = const {}]) => _session.call<T>('gatt.$method', args);

  /// Returns the device associated with this client.
  Future<BluetoothDevice> get device async => BluetoothDevice._(_map(await _call<Object>('getDevice')));

  /// Looks up a service in the current discovery snapshot.
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+.
  Future<BluetoothGattService?> getService(String uuid) async =>
      _findByUuid(await services, uuid, (service) => service.uuid);

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The Future reports request acceptance; use the corresponding callback stream for completion.
  Future<bool> connect() => _call<bool>('connect');

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The Future reports request acceptance; use the corresponding callback stream for completion.
  Future<void> disconnect() => _call<void>('disconnect');

  /// Releases this client's native registration; unlike disconnect, this is terminal.
  ///
  /// Idempotently releases the native registration and completes its callback streams. Further operations fail locally.
  /// If native close fails, retry cleanup; other native operations are rejected.
  Future<void> close() async {
    await _session.close('gatt.close');
    _clients.remove(this);
  }

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The Future reports request acceptance; use the corresponding callback stream for completion.
  Future<bool> discoverServices() => _call<bool>('discoverServices');

  /// Returns the immutable current discovery snapshot; does not initiate discovery.
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+.
  Future<List<BluetoothGattService>> get services async =>
      _decodeList(await _call<Object>('getServices'), BluetoothGattService._);

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The Future reports request acceptance; use the corresponding callback stream for completion.
  Future<bool> readCharacteristic(BluetoothGattCharacteristic characteristic) =>
      _call<bool>('readCharacteristic', {'handle': characteristic.handle});

  /// Returns BluetoothStatusCodes (0 = accepted), normalized on pre-33 Android.
  ///
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The Future reports request acceptance; use the corresponding callback stream for completion.
  Future<int> writeCharacteristic(BluetoothGattCharacteristic characteristic, Uint8List value,
          {int writeType = BluetoothGattCharacteristic.writeTypeDefault}) =>
      _call<int>('writeCharacteristic', {'handle': characteristic.handle, 'value': value, 'writeType': writeType});

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The Future reports request acceptance; use the corresponding callback stream for completion.
  Future<bool> readDescriptor(BluetoothGattDescriptor descriptor) =>
      _call<bool>('readDescriptor', {'handle': descriptor.handle});

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The Future reports request acceptance; use the corresponding callback stream for completion.
  Future<int> writeDescriptor(BluetoothGattDescriptor descriptor, Uint8List value) =>
      _call<int>('writeDescriptor', {'handle': descriptor.handle, 'value': value});

  /// Changes local notification routing; returns whether Android accepted the change.
  /// Write the CCCD separately to subscribe remotely. API 21+. Requires BLUETOOTH_CONNECT on API 31+.
  Future<bool> setCharacteristicNotification(BluetoothGattCharacteristic characteristic, bool enable) =>
      _call<bool>('setCharacteristicNotification', {'handle': characteristic.handle, 'enable': enable});

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The Future reports request acceptance; use the corresponding callback stream for completion.
  Future<bool> requestMtu(int mtu) => _call<bool>('requestMtu', {'mtu': mtu});

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The Future reports request acceptance; use the corresponding callback stream for completion.
  Future<bool> readRemoteRssi() => _call<bool>('readRemoteRssi');

  /// Requests a connection priority; returns whether Android accepted the request.
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. Android does not report completion through this wrapper.
  Future<bool> requestConnectionPriority(int priority) =>
      _call<bool>('requestConnectionPriority', {'priority': priority});

  /// API 26+. Requires CONNECT on API 31+; completion is onPhyRead.
  Future<void> readPhy() => _call<void>('readPhy');

  /// API 26+. A preference rather than a guarantee; completion is onPhyUpdate. Requires CONNECT on API 31+.
  Future<void> setPreferredPhy(int txPhy, int rxPhy, {int phyOptions = 0}) =>
      _call<void>('setPreferredPhy', {'txPhy': txPhy, 'rxPhy': rxPhy, 'phyOptions': phyOptions});

  /// API 36.1+. Requires CONNECT and companion association or privileged permission.
  /// Returns Android's request status; onSubrateChange reports subsequent changes.
  /// Missing public methods throw unsupported.
  Future<int> requestSubrateMode(int subrateMode) => _call<int>('requestSubrateMode', {'subrateMode': subrateMode});

  /// Begins a reliable-write transaction; returns whether Android accepted it.
  /// Compare each [onCharacteristicWrite] callback's value with the intended bytes
  /// before committing with [executeReliableWrite]; abort on a mismatch.
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+.
  Future<bool> beginReliableWrite() => _call<bool>('beginReliableWrite');

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The Future reports request acceptance; use the corresponding callback stream for completion.
  Future<bool> executeReliableWrite() => _call<bool>('executeReliableWrite');

  /// Aborts the current reliable-write transaction.
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+.
  Future<void> abortReliableWrite() => _call<void>('abortReliableWrite');

  /// Best-effort hidden Android API; may throw restricted_api on any OS/device.
  /// Returns whether the cache refresh was accepted and invalidates discovered handles on success.
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+.
  Future<bool> refresh() => _call<bool>('refresh');
}

/// Native callback union. Individual callback streams expose the corresponding typed result.
class BluetoothGattServerCallback extends BluetoothEvent {
  BluetoothGattServerCallback._base(super.data) : super._();
  factory BluetoothGattServerCallback._(_Map data) => switch (data['type']) {
        'onConnectionStateChange' => GattServerConnectionStateChangeResult._(data),
        'onServiceAdded' => GattServerServiceAddedResult._(data),
        'onCharacteristicReadRequest' => GattServerCharacteristicReadRequest._(data),
        'onCharacteristicWriteRequest' => GattServerCharacteristicWriteRequest._(data),
        'onDescriptorReadRequest' => GattServerDescriptorReadRequest._(data),
        'onDescriptorWriteRequest' => GattServerDescriptorWriteRequest._(data),
        'onExecuteWrite' => GattServerExecuteWriteRequest._(data),
        'onNotificationSent' => GattServerNotificationSentResult._(data),
        'onMtuChanged' => GattServerMtuChangedResult._(data),
        'onPhyRead' => GattServerPhyReadResult._(data),
        'onPhyUpdate' => GattServerPhyUpdateResult._(data),
        _ => BluetoothGattServerCallback._base(data),
      };
  int? get requestId => data['requestId'] as int?;
  int? get offset => data['offset'] as int?;
  bool? get preparedWrite => data['preparedWrite'] as bool?;
  bool? get responseNeeded => data['responseNeeded'] as bool?;
  bool? get execute => data['execute'] as bool?;
  int? get newState => data['newState'] as int?;
  int? get mtu => data['mtu'] as int?;
  int? get txPhy => data['txPhy'] as int?;
  int? get rxPhy => data['rxPhy'] as int?;
  Uint8List? get value => data['value'] == null ? null : _bytes(data['value']);
  BluetoothGattService? get service => data['service'] == null ? null : BluetoothGattService._(_map(data['service']));
  BluetoothGattCharacteristic? get characteristic =>
      data['characteristic'] == null ? null : BluetoothGattCharacteristic._(_map(data['characteristic']));
  BluetoothGattDescriptor? get descriptor =>
      data['descriptor'] == null ? null : BluetoothGattDescriptor._(_map(data['descriptor']));
}

final class BluetoothGattServer {
  BluetoothGattServer._(String id) : _session = _Session(id);
  final _Session _session;
  String get id => _session.id;
  Stream<BluetoothGattServerCallback> _events([String? type]) =>
      _session.events(type).map(BluetoothGattServerCallback._);
  Stream<BluetoothGattServerCallback> get events => _events();
  Stream<GattServerConnectionStateChangeResult> get onConnectionStateChange =>
      _events('onConnectionStateChange').cast<GattServerConnectionStateChangeResult>();
  Stream<GattServerServiceAddedResult> get onServiceAdded =>
      _events('onServiceAdded').cast<GattServerServiceAddedResult>();
  Stream<GattServerCharacteristicReadRequest> get onCharacteristicReadRequest =>
      _events('onCharacteristicReadRequest').cast<GattServerCharacteristicReadRequest>();
  Stream<GattServerCharacteristicWriteRequest> get onCharacteristicWriteRequest =>
      _events('onCharacteristicWriteRequest').cast<GattServerCharacteristicWriteRequest>();
  Stream<GattServerDescriptorReadRequest> get onDescriptorReadRequest =>
      _events('onDescriptorReadRequest').cast<GattServerDescriptorReadRequest>();
  Stream<GattServerDescriptorWriteRequest> get onDescriptorWriteRequest =>
      _events('onDescriptorWriteRequest').cast<GattServerDescriptorWriteRequest>();
  Stream<GattServerExecuteWriteRequest> get onExecuteWrite =>
      _events('onExecuteWrite').cast<GattServerExecuteWriteRequest>();
  Stream<GattServerNotificationSentResult> get onNotificationSent =>
      _events('onNotificationSent').cast<GattServerNotificationSentResult>();
  Stream<GattServerMtuChangedResult> get onMtuChanged => _events('onMtuChanged').cast<GattServerMtuChangedResult>();
  Stream<GattServerPhyReadResult> get onPhyRead => _events('onPhyRead').cast<GattServerPhyReadResult>();
  Stream<GattServerPhyUpdateResult> get onPhyUpdate => _events('onPhyUpdate').cast<GattServerPhyUpdateResult>();
  Future<T> _call<T>(String method, [_Map args = const {}]) => _session.call<T>('server.$method', args);

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The application owns values, CCCDs and prepared-write transactions.
  Future<BluetoothGattService?> getService(String uuid) async =>
      _findByUuid(await services, uuid, (service) => service.uuid);

  /// Idempotently releases the native server and completes its callback streams.
  /// If native close fails, retry cleanup; other native operations are rejected.
  Future<void> close() => _session.close('server.close');

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The application owns values, CCCDs and prepared-write transactions.
  Future<bool> addService(BluetoothGattService service) => _call<bool>('addService', {'service': service._toMap()});

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The application owns values, CCCDs and prepared-write transactions.
  Future<bool> removeService(BluetoothGattService service) => _call<bool>('removeService', {'handle': service.handle});

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The application owns values, CCCDs and prepared-write transactions.
  Future<void> clearServices() => _call<void>('clearServices');

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The application owns values, CCCDs and prepared-write transactions.
  /// Excludes failed additions even when Android retains them in its native service list.
  Future<List<BluetoothGattService>> get services async =>
      _decodeList(await _call<Object>('getServices'), BluetoothGattService._);

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The application owns values, CCCDs and prepared-write transactions.
  Future<bool> connect(BluetoothDevice device, {bool autoConnect = false}) =>
      _call<bool>('connect', {...device._address, 'autoConnect': autoConnect});

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The application owns values, CCCDs and prepared-write transactions.
  Future<void> cancelConnection(BluetoothDevice device) => _call<void>('cancelConnection', {...device._address});

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+.
  /// Applications own attribute values, CCCD state, offsets and prepared-write transactions.
  Future<bool> sendResponse(BluetoothDevice device, int requestId, int status, {int offset = 0, Uint8List? value}) =>
      _call<bool>('sendResponse',
          {...device._address, 'requestId': requestId, 'status': status, 'offset': offset, 'value': value});

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. The application owns values, CCCDs and prepared-write transactions.
  Future<int> notifyCharacteristicChanged(BluetoothDevice device, BluetoothGattCharacteristic characteristic,
          {required bool confirm, required Uint8List value}) =>
      _call<int>('notifyCharacteristicChanged',
          {...device._address, 'handle': characteristic.handle, 'confirm': confirm, 'value': value});

  /// API 26+. Requires CONNECT on API 31+; completion is onPhyRead.
  Future<void> readPhy(BluetoothDevice device) => _call<void>('readPhy', {...device._address});

  /// API 26+. Requires CONNECT on API 31+; completion is onPhyUpdate.
  Future<void> setPreferredPhy(BluetoothDevice device, int txPhy, int rxPhy, {int phyOptions = 0}) =>
      _call<void>('setPreferredPhy', {...device._address, 'txPhy': txPhy, 'rxPhy': rxPhy, 'phyOptions': phyOptions});
}

/// Result delivered by `BluetoothGatt.onConnectionStateChange`.
final class GattConnectionStateChangeResult extends BluetoothGattCallback {
  GattConnectionStateChangeResult._(super.data) : super._base();
  @override
  int get newState => super.newState!;
  @override
  int get status => super.status!;
  @override
  BluetoothDevice get device => super.device!;
}

/// Result delivered by `BluetoothGatt.onServicesDiscovered`.
final class GattServicesDiscoveredResult extends BluetoothGattCallback {
  GattServicesDiscoveredResult._(super.data) : super._base();
  @override
  int get status => super.status!;
}

/// Result delivered by `BluetoothGatt.onCharacteristicRead`.
final class GattCharacteristicReadResult extends BluetoothGattCallback {
  GattCharacteristicReadResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  BluetoothGattCharacteristic get characteristic => super.characteristic!;
}

/// Result delivered by `BluetoothGatt.onCharacteristicWrite`.
final class GattCharacteristicWriteResult extends BluetoothGattCallback {
  GattCharacteristicWriteResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  BluetoothGattCharacteristic get characteristic => super.characteristic!;

  /// Snapshot of the native characteristic value at callback time, when present.
  /// During a reliable write, Android supplies the peer's response here; compare
  /// it with the intended bytes before committing. Other writes may expose a
  /// cached value rather than the bytes submitted to [BluetoothGatt.writeCharacteristic].
  @override
  Uint8List? get value => super.value;
}

/// Result delivered by `BluetoothGatt.onCharacteristicChanged`.
final class GattCharacteristicChangedResult extends BluetoothGattCallback {
  GattCharacteristicChangedResult._(super.data) : super._base();
  @override
  BluetoothGattCharacteristic get characteristic => super.characteristic!;
}

/// Result delivered by `BluetoothGatt.onDescriptorRead`.
final class GattDescriptorReadResult extends BluetoothGattCallback {
  GattDescriptorReadResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  BluetoothGattDescriptor get descriptor => super.descriptor!;
}

/// Result delivered by `BluetoothGatt.onDescriptorWrite`.
final class GattDescriptorWriteResult extends BluetoothGattCallback {
  GattDescriptorWriteResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  BluetoothGattDescriptor get descriptor => super.descriptor!;
}

/// Result delivered by `BluetoothGatt.onMtuChanged`.
final class GattMtuChangedResult extends BluetoothGattCallback {
  GattMtuChangedResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  int get mtu => super.mtu!;
}

/// Result delivered by `BluetoothGatt.onReadRemoteRssi`.
final class GattReadRemoteRssiResult extends BluetoothGattCallback {
  GattReadRemoteRssiResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  int get rssi => super.rssi!;
}

/// Result delivered by `BluetoothGatt.onReliableWriteCompleted`.
final class GattReliableWriteCompletedResult extends BluetoothGattCallback {
  GattReliableWriteCompletedResult._(super.data) : super._base();
  @override
  int get status => super.status!;
}

/// Result delivered by `BluetoothGatt.onPhyRead`.
final class GattPhyReadResult extends BluetoothGattCallback {
  GattPhyReadResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  int get txPhy => super.txPhy!;
  @override
  int get rxPhy => super.rxPhy!;
}

/// Result delivered by `BluetoothGatt.onPhyUpdate`.
final class GattPhyUpdateResult extends BluetoothGattCallback {
  GattPhyUpdateResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  int get txPhy => super.txPhy!;
  @override
  int get rxPhy => super.rxPhy!;
}

/// Result delivered by `BluetoothGatt.onServiceChanged`.
final class GattServiceChangedResult extends BluetoothGattCallback {
  GattServiceChangedResult._(super.data) : super._base();
}

/// Result delivered by `BluetoothGatt.onSubrateChange`.
final class GattSubrateChangeResult extends BluetoothGattCallback {
  GattSubrateChangeResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  int get subrateMode => super.subrateMode!;
}

/// Result delivered by `BluetoothGattServer.onConnectionStateChange`.
final class GattServerConnectionStateChangeResult extends BluetoothGattServerCallback {
  GattServerConnectionStateChangeResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  int get newState => super.newState!;
  @override
  BluetoothDevice get device => super.device!;
}

/// Result delivered by `BluetoothGattServer.onServiceAdded`.
final class GattServerServiceAddedResult extends BluetoothGattServerCallback {
  GattServerServiceAddedResult._(super.data) : super._base();
  @override
  int get status => super.status!;
  @override
  BluetoothGattService get service => super.service!;
}

/// Result delivered by `BluetoothGattServer.onCharacteristicReadRequest`.
final class GattServerCharacteristicReadRequest extends BluetoothGattServerCallback {
  GattServerCharacteristicReadRequest._(super.data) : super._base();
  @override
  BluetoothDevice get device => super.device!;
  @override
  int get requestId => super.requestId!;
  @override
  int get offset => super.offset!;
  @override
  BluetoothGattCharacteristic get characteristic => super.characteristic!;
}

/// Result delivered by `BluetoothGattServer.onCharacteristicWriteRequest`.
final class GattServerCharacteristicWriteRequest extends BluetoothGattServerCallback {
  GattServerCharacteristicWriteRequest._(super.data) : super._base();
  @override
  BluetoothDevice get device => super.device!;
  @override
  int get requestId => super.requestId!;
  @override
  int get offset => super.offset!;
  @override
  BluetoothGattCharacteristic get characteristic => super.characteristic!;
  @override
  Uint8List get value => super.value!;
  @override
  bool get preparedWrite => super.preparedWrite!;
  @override
  bool get responseNeeded => super.responseNeeded!;
}

/// Result delivered by `BluetoothGattServer.onDescriptorReadRequest`.
final class GattServerDescriptorReadRequest extends BluetoothGattServerCallback {
  GattServerDescriptorReadRequest._(super.data) : super._base();
  @override
  BluetoothDevice get device => super.device!;
  @override
  int get requestId => super.requestId!;
  @override
  int get offset => super.offset!;
  @override
  BluetoothGattDescriptor get descriptor => super.descriptor!;
}

/// Result delivered by `BluetoothGattServer.onDescriptorWriteRequest`.
final class GattServerDescriptorWriteRequest extends BluetoothGattServerCallback {
  GattServerDescriptorWriteRequest._(super.data) : super._base();
  @override
  BluetoothDevice get device => super.device!;
  @override
  int get requestId => super.requestId!;
  @override
  int get offset => super.offset!;
  @override
  BluetoothGattDescriptor get descriptor => super.descriptor!;
  @override
  Uint8List get value => super.value!;
  @override
  bool get preparedWrite => super.preparedWrite!;
  @override
  bool get responseNeeded => super.responseNeeded!;
}

/// Result delivered by `BluetoothGattServer.onExecuteWrite`.
final class GattServerExecuteWriteRequest extends BluetoothGattServerCallback {
  GattServerExecuteWriteRequest._(super.data) : super._base();
  @override
  BluetoothDevice get device => super.device!;
  @override
  int get requestId => super.requestId!;
  @override
  bool get execute => super.execute!;
}

/// Result delivered by `BluetoothGattServer.onNotificationSent`.
final class GattServerNotificationSentResult extends BluetoothGattServerCallback {
  GattServerNotificationSentResult._(super.data) : super._base();
  @override
  BluetoothDevice get device => super.device!;
  @override
  int get status => super.status!;
}

/// Result delivered by `BluetoothGattServer.onMtuChanged`.
final class GattServerMtuChangedResult extends BluetoothGattServerCallback {
  GattServerMtuChangedResult._(super.data) : super._base();
  @override
  BluetoothDevice get device => super.device!;
  @override
  int get mtu => super.mtu!;
}

/// Result delivered by `BluetoothGattServer.onPhyRead`.
final class GattServerPhyReadResult extends BluetoothGattServerCallback {
  GattServerPhyReadResult._(super.data) : super._base();
  @override
  BluetoothDevice get device => super.device!;
  @override
  int get status => super.status!;
  @override
  int get txPhy => super.txPhy!;
  @override
  int get rxPhy => super.rxPhy!;
}

/// Result delivered by `BluetoothGattServer.onPhyUpdate`.
final class GattServerPhyUpdateResult extends BluetoothGattServerCallback {
  GattServerPhyUpdateResult._(super.data) : super._base();
  @override
  BluetoothDevice get device => super.device!;
  @override
  int get status => super.status!;
  @override
  int get txPhy => super.txPhy!;
  @override
  int get rxPhy => super.rxPhy!;
}
