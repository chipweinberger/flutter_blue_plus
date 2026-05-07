import 'dart:typed_data';

import 'socket_api.dart';

final class BluetoothOutputStream {
  const BluetoothOutputStream(this._socketId);

  final int _socketId;

  Future<bool> flush() async {
    return BluetoothSocketApi.flushSocketOutputStream(_socketId);
  }

  Future<bool> writeByte(int value) async {
    return BluetoothSocketApi.writeSocketOutputStreamByte(_socketId, value);
  }

  Future<bool> write(Uint8List bytes) async {
    return BluetoothSocketApi.writeSocketOutputStream(_socketId, bytes);
  }
}
