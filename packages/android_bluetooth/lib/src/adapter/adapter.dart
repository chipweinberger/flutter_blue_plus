import '../device/device.dart';
import '../device/device_types.dart';
import '../scan/le_scanner.dart';
import '../socket/server_socket.dart';
import '../socket/server_socket_api.dart';
import 'adapter_api.dart';
import 'adapter_state.dart';

final class BluetoothAdapter {
  const BluetoothAdapter._();

  static const instance = BluetoothAdapter._();

  Future<String?> getName() async {
    return BluetoothAdapterApi.getAdapterName();
  }

  Future<String?> getAddress() async {
    return BluetoothAdapterApi.getAdapterAddress();
  }

  Future<bool> setName(String name) async {
    return BluetoothAdapterApi.setAdapterName(name);
  }

  Future<BluetoothDevice?> getRemoteLeDevice(
    String address,
    BluetoothAddressType addressType,
  ) async {
    return BluetoothAdapterApi.getRemoteLeDevice(address, addressType);
  }

  Future<BluetoothLeScanner?> getBluetoothLeScanner() async {
    return BluetoothAdapterApi.getBluetoothLeScanner();
  }

  Future<bool> isOffloadedFilteringSupported() async {
    return BluetoothAdapterApi.isOffloadedFilteringSupported();
  }

  Future<bool> isOffloadedScanBatchingSupported() async {
    return BluetoothAdapterApi.isOffloadedScanBatchingSupported();
  }

  Future<bool> isLe2MPhySupported() async {
    return BluetoothAdapterApi.isLe2MPhySupported();
  }

  Future<bool> isLeCodedPhySupported() async {
    return BluetoothAdapterApi.isLeCodedPhySupported();
  }

  Future<BluetoothAdapterState> getState() async {
    return BluetoothAdapterApi.getAdapterState();
  }

  Future<bool> isEnabled() async {
    return BluetoothAdapterApi.isEnabled();
  }

  Future<bool> checkBluetoothAddress(String address) async {
    return BluetoothAdapterApi.checkBluetoothAddress(address);
  }

  Future<bool> enable() async {
    return BluetoothAdapterApi.enable();
  }

  Future<bool> disable() async {
    return BluetoothAdapterApi.disable();
  }

  Future<BluetoothServerSocket?> listenUsingL2capChannel() async {
    return BluetoothServerSocketApi.listenUsingL2capChannel(insecure: false);
  }

  Future<BluetoothServerSocket?> listenUsingInsecureL2capChannel() async {
    return BluetoothServerSocketApi.listenUsingL2capChannel(insecure: true);
  }

  Stream<BluetoothAdapterState> get onStateChanged {
    return BluetoothAdapterApi.onAdapterStateChanged;
  }
}
