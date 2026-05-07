import '../device/device.dart';
import '../gatt/gatt_types.dart';
import '../internal/channels.dart';

final class BluetoothManagerApi {
  BluetoothManagerApi._();

  static const int _gattProfile = 7;

  static Future<List<BluetoothDevice>> getConnectedDevices() async {
    final devices = await BluetoothChannels.method.invokeListMethod<Map<Object?, Object?>>(
      'getConnectedDevices',
      _gattProfile,
    );
    return devices?.map(BluetoothDevice.fromMap).toList() ?? const [];
  }

  static Future<List<BluetoothDevice>> getDevicesMatchingConnectionStates(List<int> states) async {
    final devices = await BluetoothChannels.method.invokeListMethod<Map<Object?, Object?>>(
      'getDevicesMatchingConnectionStates',
      <String, Object>{
        'profile': _gattProfile,
        'states': states,
      },
    );
    return devices?.map(BluetoothDevice.fromMap).toList() ?? const [];
  }

  static Future<BluetoothGattConnectionState> getConnectionState(String address) async {
    final stateName = await BluetoothChannels.method.invokeMethod<String>(
      'getConnectionState',
      <String, Object>{
        'address': address,
        'profile': _gattProfile,
      },
    );
    return BluetoothGattConnectionState.values.byName(stateName ?? 'unknown');
  }
}
