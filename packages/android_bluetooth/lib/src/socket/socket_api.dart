import '../device/device.dart';
import '../internal/channels.dart';
import 'socket.dart';
import 'dart:typed_data';

final class BluetoothSocketApi {
  BluetoothSocketApi._();

  static Future<BluetoothSocket?> createL2capChannel(
    String address,
    int psm, {
    required bool insecure,
  }) async {
    final socketId = await BluetoothChannels.method.invokeMethod<int>(
      insecure ? 'createInsecureL2capChannel' : 'createL2capChannel',
      <String, Object>{
        'address': address,
        'psm': psm,
      },
    );
    if (socketId == null) {
      return null;
    }
    return BluetoothSocket(socketId);
  }

  static Future<bool> connectSocket(int socketId) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('connectSocket', socketId)) ?? false;
  }

  static Future<bool> closeSocket(int socketId) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('closeSocket', socketId)) ?? false;
  }

  static Future<bool> isSocketConnected(int socketId) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('isSocketConnected', socketId)) ?? false;
  }

  static Future<int?> getSocketConnectionType(int socketId) async {
    return BluetoothChannels.method.invokeMethod<int>('getSocketConnectionType', socketId);
  }

  static Future<int?> getSocketMaxReceivePacketSize(int socketId) async {
    return BluetoothChannels.method.invokeMethod<int>('getSocketMaxReceivePacketSize', socketId);
  }

  static Future<int?> getSocketMaxTransmitPacketSize(int socketId) async {
    return BluetoothChannels.method.invokeMethod<int>('getSocketMaxTransmitPacketSize', socketId);
  }

  static Future<int> getSocketInputStreamAvailable(int socketId) async {
    return (await BluetoothChannels.method.invokeMethod<int>('getSocketInputStreamAvailable', socketId)) ?? 0;
  }

  static Future<int?> readSocketInputStreamByte(int socketId) async {
    return BluetoothChannels.method.invokeMethod<int>('readSocketInputStreamByte', socketId);
  }

  static Future<Uint8List?> readSocketInputStream(
    int socketId, {
    int? maxBytes,
  }) async {
    return BluetoothChannels.method.invokeMethod<Uint8List>(
      'readSocketInputStream',
      <String, Object>{
        'socketId': socketId,
        if (maxBytes != null) 'maxBytes': maxBytes,
      },
    );
  }

  static Future<int?> skipSocketInputStream(int socketId, int byteCount) async {
    return BluetoothChannels.method.invokeMethod<int>(
      'skipSocketInputStream',
      <String, Object>{
        'socketId': socketId,
        'byteCount': byteCount,
      },
    );
  }

  static Future<bool> writeSocketOutputStreamByte(int socketId, int value) async {
    return (await BluetoothChannels.method.invokeMethod<bool>(
          'writeSocketOutputStreamByte',
          <String, Object>{
            'socketId': socketId,
            'value': value,
          },
        )) ??
        false;
  }

  static Future<bool> writeSocketOutputStream(int socketId, Uint8List bytes) async {
    return (await BluetoothChannels.method.invokeMethod<bool>(
          'writeSocketOutputStream',
          <String, Object>{
            'socketId': socketId,
            'bytes': bytes,
          },
        )) ??
        false;
  }

  static Future<bool> flushSocketOutputStream(int socketId) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('flushSocketOutputStream', socketId)) ?? false;
  }

  static Future<BluetoothDevice?> getSocketRemoteDevice(int socketId) async {
    final device = await BluetoothChannels.method.invokeMapMethod<Object?, Object?>('getSocketRemoteDevice', socketId);
    if (device == null) {
      return null;
    }
    return BluetoothDevice.fromMap(device);
  }
}
