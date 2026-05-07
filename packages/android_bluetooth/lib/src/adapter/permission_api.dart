import '../internal/channels.dart';

final class BluetoothPermissionApi {
  BluetoothPermissionApi._();

  static Future<bool> hasBluetoothConnectPermission() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('hasBluetoothConnectPermission')) ?? false;
  }

  static Future<bool> hasBluetoothScanPermission() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('hasBluetoothScanPermission')) ?? false;
  }
}
