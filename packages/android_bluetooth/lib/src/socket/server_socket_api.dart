import '../internal/channels.dart';
import 'server_socket.dart';
import 'socket.dart';

final class BluetoothServerSocketApi {
  BluetoothServerSocketApi._();

  static Future<BluetoothServerSocket?> listenUsingL2capChannel({
    required bool insecure,
  }) async {
    final serverSocketId = await BluetoothChannels.method.invokeMethod<int>(
      insecure ? 'listenUsingInsecureL2capChannel' : 'listenUsingL2capChannel',
    );
    if (serverSocketId == null) {
      return null;
    }
    return BluetoothServerSocket(serverSocketId);
  }

  static Future<BluetoothSocket?> acceptServerSocket(
    int serverSocketId, {
    int? timeoutMillis,
  }) async {
    final socketId = await BluetoothChannels.method.invokeMethod<int>(
      'acceptServerSocket',
      <String, Object>{
        'serverSocketId': serverSocketId,
        if (timeoutMillis != null) 'timeoutMillis': timeoutMillis,
      },
    );
    if (socketId == null) {
      return null;
    }
    return BluetoothSocket(socketId);
  }

  static Future<bool> closeServerSocket(int serverSocketId) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('closeServerSocket', serverSocketId)) ?? false;
  }

  static Future<int?> getServerSocketPsm(int serverSocketId) async {
    return BluetoothChannels.method.invokeMethod<int>('getServerSocketPsm', serverSocketId);
  }
}
