import '../device/device.dart';
import 'input_stream.dart';
import 'output_stream.dart';
import 'socket_api.dart';

final class BluetoothSocket {
  const BluetoothSocket(this._id);

  final int _id;

  Future<bool> close() async {
    return BluetoothSocketApi.closeSocket(_id);
  }

  Future<bool> connect() async {
    return BluetoothSocketApi.connectSocket(_id);
  }

  Future<int?> getConnectionType() async {
    return BluetoothSocketApi.getSocketConnectionType(_id);
  }

  Future<int?> getMaxReceivePacketSize() async {
    return BluetoothSocketApi.getSocketMaxReceivePacketSize(_id);
  }

  Future<int?> getMaxTransmitPacketSize() async {
    return BluetoothSocketApi.getSocketMaxTransmitPacketSize(_id);
  }

  BluetoothInputStream getInputStream() {
    return BluetoothInputStream(_id);
  }

  BluetoothOutputStream getOutputStream() {
    return BluetoothOutputStream(_id);
  }

  Future<BluetoothDevice?> getRemoteDevice() async {
    return BluetoothSocketApi.getSocketRemoteDevice(_id);
  }

  Future<bool> isConnected() async {
    return BluetoothSocketApi.isSocketConnected(_id);
  }
}
