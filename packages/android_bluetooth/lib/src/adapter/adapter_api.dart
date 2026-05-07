import 'dart:async';

import '../device/device.dart';
import '../device/device_types.dart';
import '../internal/channels.dart';
import '../scan/le_scanner.dart';
import 'adapter_state.dart';

final class BluetoothAdapterApi {
  BluetoothAdapterApi._();

  static Stream<BluetoothAdapterState>? _adapterStateChanged;

  static Future<String?> getAdapterName() async {
    return BluetoothChannels.method.invokeMethod<String>('getAdapterName');
  }

  static Future<String?> getAdapterAddress() async {
    return BluetoothChannels.method.invokeMethod<String>('getAdapterAddress');
  }

  static Future<bool> setAdapterName(String name) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('setAdapterName', name)) ?? false;
  }

  static Future<BluetoothLeScanner?> getBluetoothLeScanner() async {
    final hasBluetoothLeScanner = (await BluetoothChannels.method.invokeMethod<bool>('getBluetoothLeScanner')) ?? false;
    return hasBluetoothLeScanner ? BluetoothLeScanner.instance : null;
  }

  static Future<bool> isOffloadedFilteringSupported() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('isOffloadedFilteringSupported')) ?? false;
  }

  static Future<bool> isOffloadedScanBatchingSupported() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('isOffloadedScanBatchingSupported')) ?? false;
  }

  static Future<bool> isLe2MPhySupported() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('isLe2MPhySupported')) ?? false;
  }

  static Future<bool> isLeCodedPhySupported() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('isLeCodedPhySupported')) ?? false;
  }

  static Future<BluetoothDevice?> getRemoteLeDevice(
    String address,
    BluetoothAddressType addressType,
  ) async {
    final device = await BluetoothChannels.method.invokeMapMethod<Object?, Object?>(
      'getRemoteLeDevice',
      <String, Object?>{
        'address': address,
        'addressType': addressType.value,
      },
    );
    if (device == null) {
      return null;
    }

    return BluetoothDevice.fromMap(device);
  }

  static Future<BluetoothAdapterState> getAdapterState() async {
    final stateName = await BluetoothChannels.method.invokeMethod<String>('getAdapterState');
    return _parseAdapterState(stateName);
  }

  static Future<bool> isEnabled() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('isEnabled')) ?? false;
  }

  static Future<bool> enable() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('enable')) ?? false;
  }

  static Future<bool> disable() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('disable')) ?? false;
  }

  static Future<bool> isSupported() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('isSupported')) ?? false;
  }

  static Future<bool> checkBluetoothAddress(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('checkBluetoothAddress', address)) ?? false;
  }

  static Stream<BluetoothAdapterState> get onAdapterStateChanged {
    return _adapterStateChanged ??= (() async* {
      yield await getAdapterState();
      yield* BluetoothChannels.adapterStateChanged.receiveBroadcastStream().map((dynamic stateName) {
        return _parseAdapterState(stateName as String?);
      });
    })();
  }

  static BluetoothAdapterState _parseAdapterState(String? stateName) {
    return BluetoothAdapterState.values.byName(stateName ?? 'unknown');
  }
}
