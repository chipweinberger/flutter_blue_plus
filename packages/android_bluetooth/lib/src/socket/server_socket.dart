import 'server_socket_api.dart';
import 'socket.dart';

final class BluetoothServerSocket {
  const BluetoothServerSocket(this._id);

  final int _id;

  Future<BluetoothSocket?> accept({
    int? timeoutMillis,
  }) async {
    return BluetoothServerSocketApi.acceptServerSocket(
      _id,
      timeoutMillis: timeoutMillis,
    );
  }

  Future<bool> close() async {
    return BluetoothServerSocketApi.closeServerSocket(_id);
  }

  Future<int?> getPsm() async {
    return BluetoothServerSocketApi.getServerSocketPsm(_id);
  }
}
