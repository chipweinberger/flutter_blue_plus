part of '../android_bluetooth.dart';

abstract final class BluetoothProfile {
  static const stateDisconnected = 0, stateConnecting = 1, stateConnected = 2, stateDisconnecting = 3;
  static const gatt = 7, gattServer = 8;
}

final class BluetoothAdapterEvent extends BluetoothEvent {
  BluetoothAdapterEvent._(super.data) : super._();
  int get state => data['state']! as int;
  int get previousState => data['previousState']! as int;
  String? get name => data['name'] as String?;
}

final class BluetoothEnableResponse extends BluetoothEvent {
  BluetoothEnableResponse._(super.data) : super._();
  bool get userAccepted => data['userAccepted']! as bool;
  String? get errorCode => data['errorCode'] as String?;
}

final class BluetoothDeviceEvent extends BluetoothEvent {
  BluetoothDeviceEvent._(super.data) : super._();
  Map<String, Object?> get extras => _map(data['extras'] ?? const <String, Object?>{});
  int? _int(String key) => extras['android.bluetooth.device.extra.$key'] as int?;
  int? get transport => _int('TRANSPORT');
  int? get bondState => _int('BOND_STATE');
  int? get previousBondState => _int('PREVIOUS_BOND_STATE');
  int? get pairingVariant => _int('PAIRING_VARIANT');
  int? get pairingKey => _int('PAIRING_KEY');
  int? get encryptionStatus => _int('ENCRYPTION_STATUS');
  bool? get encryptionEnabled => extras['android.bluetooth.device.extra.ENCRYPTION_ENABLED'] as bool?;
  int? get encryptionAlgorithm => _int('EXTRA_ENCRYPTION_ALGORITHM');
  int? get keySize => _int('KEY_SIZE');
}

final class BluetoothManager {
  BluetoothManager._();
  static final shared = BluetoothManager._();
  BluetoothAdapter get adapter => BluetoothAdapter.shared;

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+; queried profiles are GATT/GATT_SERVER.
  Future<List<BluetoothDevice>> getConnectedDevices({int profile = BluetoothProfile.gatt}) async =>
      _decodeList(await _Host.call<Object>('manager.connectedDevices', {'profile': profile}), BluetoothDevice._);

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+; queried profiles are GATT/GATT_SERVER.
  Future<List<BluetoothDevice>> getDevicesMatchingConnectionStates(List<int> states,
          {int profile = BluetoothProfile.gatt}) async =>
      _decodeList(await _Host.call<Object>('manager.matchingDevices', {'profile': profile, 'states': states}),
          BluetoothDevice._);

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+; queried profiles are GATT/GATT_SERVER.
  Future<int> getConnectionState(BluetoothDevice device, {int profile = BluetoothProfile.gatt}) =>
      _Host.call<int>('manager.connectionState', {...device._address, 'profile': profile});

  /// Creates an independent local GATT server registration.
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. Applications own attribute values and responses.
  Future<BluetoothGattServer> openGattServer() async => BluetoothGattServer._(await _Host.call<String>('server.open'));
}

final class BluetoothAdapter {
  BluetoothAdapter._();
  static final shared = BluetoothAdapter._();
  static const stateOff = 10, stateTurningOn = 11, stateOn = 12, stateTurningOff = 13;
  BluetoothLeScanner get bluetoothLeScanner => BluetoothLeScanner.shared;
  BluetoothLeAdvertiser get bluetoothLeAdvertiser => BluetoothLeAdvertiser.shared;
  Stream<BluetoothAdapterEvent> get events =>
      _Host.events('adapter').where((event) => event['type'] != 'onEnableResponse').map(BluetoothAdapterEvent._);
  Stream<BluetoothEnableResponse> get onEnableResponse =>
      _Host.events('adapter', 'onEnableResponse').map(BluetoothEnableResponse._);

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+ unless documented otherwise.
  Future<int> get state => _Host.call<int>('adapter.state');

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+ unless documented otherwise.
  Future<bool> get isEnabled => _Host.call<bool>('adapter.isEnabled');

  /// Reports competing Classic inquiry. Requires BLUETOOTH_SCAN on API 31+.
  Future<bool> get isDiscovering => _Host.call<bool>('adapter.isDiscovering');

  /// API 26+. Unlike the optional capability snapshot, propagates permission failures.
  Future<bool> get isLe2MPhySupported => _Host.call<bool>('adapter.isLe2MPhySupported');

  /// API 26+. Unlike the optional capability snapshot, propagates permission failures.
  Future<bool> get isLeCodedPhySupported => _Host.call<bool>('adapter.isLeCodedPhySupported');

  /// Cancels competing Classic inquiry. Requires BLUETOOTH_SCAN on API 31+.
  Future<bool> cancelDiscovery() => _Host.call<bool>('adapter.cancelDiscovery');

  /// Deprecated/restricted by Android. Ordinary apps should use requestEnable.
  ///
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+ unless documented otherwise.
  Future<bool> enable() => _Host.call<bool>('adapter.enable');

  /// Android 13+ generally rejects this for ordinary apps.
  ///
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+ unless documented otherwise.
  Future<bool> disable() => _Host.call<bool>('adapter.disable');

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+ unless documented otherwise.
  Future<String?> get name => _Host.call<String?>('adapter.name');

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+ unless documented otherwise.
  Future<bool> setName(String name) => _Host.call<bool>('adapter.setName', {'name': name});

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+ unless documented otherwise.
  Future<List<BluetoothDevice>> get bondedDevices async =>
      _decodeList(await _Host.call<Object>('adapter.bondedDevices'), BluetoothDevice._);

  /// Opens Android's system enable dialog. Requires an attached Activity and CONNECT on API 31+.
  /// With [waitForResult] false, resolves once the dialog is launched; the later
  /// user decision arrives on [onEnableResponse]. Launch failures still throw.
  Future<bool> requestEnable({bool waitForResult = true}) =>
      _Host.call<bool>('adapter.requestEnable', {'waitForResult': waitForResult});

  /// Opens Android Bluetooth settings; does not enable Bluetooth silently.
  Future<void> openSettings() => _Host.call<void>('adapter.openSettings');
  BluetoothDevice getRemoteDevice(String address) => BluetoothDevice(address);

  /// API 33+. Carries the supplied public/random LE address type through subsequent device operations.
  Future<BluetoothDevice> getRemoteLeDevice(String address, int addressType) async => BluetoothDevice._(
      _map(await _Host.call<Object>('adapter.remoteLeDevice', {'address': address, 'addressType': addressType})));

  /// API 29+. Creates a secure LE CoC listener with an Android-assigned dynamic PSM. Requires CONNECT on API 31+.
  Future<BluetoothServerSocket> listenUsingL2capChannel() => _listen(true);

  /// API 29+. Creates an unauthenticated LE CoC listener with a dynamic PSM. Requires CONNECT on API 31+.
  Future<BluetoothServerSocket> listenUsingInsecureL2capChannel() => _listen(false);

  /// API 36+. LE-only socket settings; authentication/encryption requirements are independent. Requires CONNECT on API 31+.
  Future<BluetoothServerSocket> listenUsingSocketSettings(BluetoothSocketSettings settings) async =>
      BluetoothServerSocket._(_map(await _Host.call<Object>('socket.listenSettings', {'settings': settings._toMap()})));
  Future<BluetoothServerSocket> _listen(bool secure) async =>
      BluetoothServerSocket._(_map(await _Host.call<Object>('socket.listen', {'secure': secure})));
}

final class BluetoothDevice {
  BluetoothDevice(String address) : this._({'address': address.toUpperCase()});
  BluetoothDevice._(this._snapshot);
  static const bondNone = 10, bondBonding = 11, bondBonded = 12;
  static const transportAuto = 0, transportBredr = 1, transportLe = 2;
  static const phyLe1m = 1, phyLe2m = 2, phyLeCoded = 3;
  static const phyLe1mMask = 1, phyLe2mMask = 2, phyLeCodedMask = 4;
  static const addressTypePublic = 0, addressTypeRandom = 1;
  static const addressTypeAnonymous = 255, addressTypeUnknown = 65535;
  static const deviceTypeUnknown = 0, deviceTypeClassic = 1, deviceTypeLe = 2, deviceTypeDual = 3;
  static const phyOptionNoPreferred = 0, phyOptionS2 = 1, phyOptionS8 = 2;
  static const actionAclConnected = 'android.bluetooth.device.action.ACL_CONNECTED';
  static const actionAclDisconnected = 'android.bluetooth.device.action.ACL_DISCONNECTED';
  static const actionAclDisconnectRequested = 'android.bluetooth.device.action.ACL_DISCONNECT_REQUESTED';
  static const actionBondStateChanged = 'android.bluetooth.device.action.BOND_STATE_CHANGED';
  static const actionPairingRequest = 'android.bluetooth.device.action.PAIRING_REQUEST';
  static const actionEncryptionChange = 'android.bluetooth.device.action.ENCRYPTION_CHANGE';
  final _Map _snapshot;
  _Map get _address =>
      {'address': address, if (addressType != null && addressType != addressTypeUnknown) 'addressType': addressType};
  Future<T> _call<T>(String method, [_Map args = const {}]) => _Host.call<T>('device.$method', {..._address, ...args});
  String get address => _snapshot['address']! as String;

  /// Open clients created for this address through AndroidBluetooth in this isolate.
  ///
  /// Includes clients owned by wrappers such as FlutterBluePlus. These are the
  /// existing objects and callback streams; no additional connection is opened.
  List<BluetoothGatt> get gattClients =>
      List.unmodifiable(BluetoothGatt._clients.where((client) => client._address == address));
  String? get name => _snapshot['name'] as String?;
  int? get type => _snapshot['deviceType'] as int?;
  int? get bondState => _snapshot['bondState'] as int?;
  String? get alias => _snapshot['alias'] as String?;
  int? get addressType => _snapshot['addressType'] as int?;
  List<String>? get uuids => (_snapshot['uuids'] as List?)?.cast<String>();

  /// API 36+. Requires both BLUETOOTH_CONNECT and signature/privileged BLUETOOTH_PRIVILEGED permission.
  /// An unavailable identity retains Android's null address and unknown address type.
  Future<BluetoothAddress> get identityAddressWithType async =>
      BluetoothAddress._(_map(await _call<Object>('identityAddressWithType')));

  /// Broadcasts device actions for all addresses, including system bond changes.
  static Stream<BluetoothDeviceEvent> get allEvents => _Host.events('device').map(BluetoothDeviceEvent._);

  Stream<BluetoothDeviceEvent> get events => allEvents.where((e) => e.device?.address == address);

  /// Returns an updated device-property snapshot.
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+.
  Future<BluetoothDevice> refresh() async => BluetoothDevice._(_map(await _call<Object>('get')));

  /// Reads the current bond state and propagates permission failures.
  /// The nullable [bondState] field is optional metadata from a previous snapshot.
  Future<int> getBondState() => _call<int>('bondState');

  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. Completion is reported by native callback events.
  /// Optionally arms [pin] atomically before starting bonding. It is applied once
  /// inside Android's pairing receiver, subject to Android's pairing permissions.
  Future<bool> createBond({Uint8List? pin}) => _call<bool>('createBond', {if (pin != null) 'pin': pin});

  /// Applies [pin] synchronously to the next pairing request. Pass null to clear.
  /// Cleared on use, disconnect, terminal bond state, adapter shutdown or engine reset.
  Future<void> setPinForNextPairing(Uint8List? pin) => _call<void>('setPinForNextPairing', {'pin': pin});

  /// API 31+. Subject to Android's CONNECT, companion-association or privileged-permission requirements; native status is preserved.
  /// Pass null to clear the locally stored alias.
  Future<int> setAlias(String? alias) => _call<int>('setAlias', {'alias': alias});

  /// Requires Android's privileged pairing eligibility; requesting CONNECT alone does not grant this capability.
  Future<bool> setPairingConfirmation(bool confirm) => _call<bool>('setPairingConfirmation', {'confirm': confirm});

  /// Supplies a PIN for the current pairing request; returns whether Android accepted it.
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+.
  Future<bool> setPin(Uint8List pin) => _call<bool>('setPin', {'pin': pin});

  /// Hidden Android API. Best effort: may throw `restricted_api` on any OS/device.
  ///
  /// API 21+. Requires BLUETOOTH_CONNECT on API 31+. Completion is reported by native callback events.
  Future<bool> removeBond() => _call<bool>('removeBond');

  /// Creates an independent GATT client registration. Subscribe to onConnectionStateChange for completion.
  /// LE transport is explicit on API 23+ and best-effort through the hidden overload on API 21–22.
  /// PHY selection requires API 26+.
  /// [preserveAttributeHandles] keeps handles usable after refresh and Service Changed
  /// until the next successful discovery. This supports wrappers that own invalidation policy.
  Future<BluetoothGatt> connectGatt(
          {bool autoConnect = false, int phy = phyLe1mMask, bool preserveAttributeHandles = false}) async =>
      BluetoothGatt._(
          await _Host.call<String>('gatt.open', {
            ..._address,
            'autoConnect': autoConnect,
            'phy': phy,
            'preserveAttributeHandles': preserveAttributeHandles,
          }),
          address);

  /// API 29+. Creates a secure LE CoC socket; call connect() to establish it. Obtain the peer's PSM through your protocol.
  Future<BluetoothSocket> createL2capChannel(int psm) => _channel(psm, true);

  /// API 29+. Creates an unauthenticated LE CoC socket; call connect() to establish it.
  Future<BluetoothSocket> createInsecureL2capChannel(int psm) => _channel(psm, false);

  /// API 36+. Creates a TYPE_LE socket with explicit authentication/encryption settings.
  Future<BluetoothSocket> createUsingSocketSettings(BluetoothSocketSettings settings) async => BluetoothSocket._(
      _map(await _Host.call<Object>('socket.createSettings', {..._address, 'settings': settings._toMap()})));
  Future<BluetoothSocket> _channel(int psm, bool secure) async =>
      BluetoothSocket._(_map(await _Host.call<Object>('socket.create', {..._address, 'psm': psm, 'secure': secure})));

  @override
  bool operator ==(Object other) => other is BluetoothDevice && other.address == address;
  @override
  int get hashCode => address.hashCode;
  @override
  String toString() => 'BluetoothDevice($address, $name)';
}

final class BluetoothAddress {
  BluetoothAddress._(_Map m)
      : address = m['address'] as String?,
        addressType = m['addressType']! as int;

  /// Null when Android cannot provide the identity address, including when Bluetooth is disabled.
  final String? address;
  final int addressType;
}
