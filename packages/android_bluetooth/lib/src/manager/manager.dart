import '../adapter/adapter.dart';
import '../adapter/adapter_api.dart';
import '../device/device.dart';
import '../gatt/gatt_types.dart';
import 'manager_api.dart';

final class BluetoothManager {
  const BluetoothManager._();

  static const instance = BluetoothManager._();

  Future<BluetoothAdapter?> getAdapter() async {
    return (await BluetoothAdapterApi.isSupported()) ? BluetoothAdapter.instance : null;
  }

  Future<List<BluetoothDevice>> getConnectedDevices() async {
    return BluetoothManagerApi.getConnectedDevices();
  }

  Future<BluetoothGattConnectionState> getConnectionState(String address) async {
    return BluetoothManagerApi.getConnectionState(address);
  }

  Future<List<BluetoothDevice>> getDevicesMatchingConnectionStates(
    List<BluetoothGattConnectionState> states,
  ) async {
    return BluetoothManagerApi.getDevicesMatchingConnectionStates(states.map((state) => state.value).toList());
  }
}
