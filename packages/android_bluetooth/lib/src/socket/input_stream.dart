import 'dart:typed_data';

import 'socket_api.dart';

final class BluetoothInputStream {
  const BluetoothInputStream(this._socketId);

  final int _socketId;

  Future<int> available() async {
    return BluetoothSocketApi.getSocketInputStreamAvailable(_socketId);
  }

  Future<int?> readByte() async {
    return BluetoothSocketApi.readSocketInputStreamByte(_socketId);
  }

  Future<Uint8List?> read({
    int? maxBytes,
  }) async {
    return BluetoothSocketApi.readSocketInputStream(
      _socketId,
      maxBytes: maxBytes,
    );
  }

  Future<int?> skip(int byteCount) async {
    return BluetoothSocketApi.skipSocketInputStream(
      _socketId,
      byteCount,
    );
  }
}
