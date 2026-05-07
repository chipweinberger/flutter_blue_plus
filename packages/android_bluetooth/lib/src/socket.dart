part of '../android_bluetooth.dart';

/// API 36+. LE-only subset; Android chooses the listening PSM when omitted.
final class BluetoothSocketSettings {
  const BluetoothSocketSettings({this.l2capPsm, this.authenticationRequired = false, this.encryptionRequired = false});
  final int? l2capPsm;
  final bool authenticationRequired, encryptionRequired;
  _Map _toMap() => {
        'l2capPsm': l2capPsm,
        'authenticationRequired': authenticationRequired,
        'encryptionRequired': encryptionRequired
      };
}

final class BluetoothSocket {
  BluetoothSocket._(_Map m)
      : _session = _Session(m['id']! as String),
        remoteDevice = BluetoothDevice._(_map(m['device']));
  final _Session _session;
  String get id => _session.id;
  final BluetoothDevice remoteDevice;
  static const typeLe = 4;

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Blocking I/O runs on native worker threads.
  Future<int> get connectionType => _call<int>('connectionType');
  Future<T> _call<T>(String method, [_Map args = const {}]) => _session.call<T>('socket.$method', args);

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Blocking I/O runs on native worker threads.
  /// close() cancels pending I/O.
  Future<void> connect() => _call<void>('connect');

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Blocking I/O runs on native worker threads.
  Future<void> close() => _session.close('socket.close');

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Blocking I/O runs on native worker threads.
  Future<bool> get isConnected => _call<bool>('isConnected');

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Blocking I/O runs on native worker threads.
  Future<int> get maxReceivePacketSize => _call<int>('maxReceivePacketSize');

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Blocking I/O runs on native worker threads.
  Future<int> get maxTransmitPacketSize => _call<int>('maxTransmitPacketSize');

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Blocking I/O runs on native worker threads.
  Future<int> get available => _call<int>('available');

  /// A single read, which may return fewer bytes. Empty bytes mean EOF.
  /// Frame application messages yourself; reads do not preserve write boundaries.
  ///
  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Blocking I/O runs on native worker threads.
  Future<Uint8List> read({int maxLength = 4096}) async => _bytes(await _call<Object>('read', {'maxLength': maxLength}));

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Blocking I/O runs on native worker threads.
  Future<void> write(Uint8List value) => _call<void>('write', {'value': value});

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Blocking I/O runs on native worker threads.
  Future<void> flush() => _call<void>('flush');
}

final class BluetoothServerSocket {
  BluetoothServerSocket._(_Map m)
      : _session = _Session(m['id']! as String),
        psm = m['psm']! as int;
  final _Session _session;
  String get id => _session.id;
  final int psm;

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. The PSM is dynamic; publish it to peers through your protocol.
  /// close() unblocks a pending accept. A timeout of -1 waits indefinitely.
  Future<BluetoothSocket> accept({int timeoutMillis = -1}) async =>
      BluetoothSocket._(_map(await _session.call<Object>('socket.accept', {'timeoutMillis': timeoutMillis})));

  /// API 29+. Requires BLUETOOTH_CONNECT on API 31+. Closing cancels a pending accept.
  Future<void> close() => _session.close('socket.closeServer');
}
