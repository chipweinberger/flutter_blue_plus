import 'dart:async';
import 'dart:typed_data';

import '../internal/channels.dart';
import 'device_types.dart';

final class BluetoothDeviceApi {
  BluetoothDeviceApi._();

  static Stream<BluetoothBondStateChangedEvent>? _bondStateChanged;

  static Future<bool> createBond(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('createBond', address)) ?? false;
  }

  static Future<BluetoothBondState> getBondState(String address) async {
    final bondStateName = await BluetoothChannels.method.invokeMethod<String>('getBondState', address);
    return _parseBondState(bondStateName);
  }

  static Future<String?> getAddress(String address) async {
    return BluetoothChannels.method.invokeMethod<String>('getAddress', address);
  }

  static Future<bool> setPin(String address, Uint8List pin) async {
    return (await BluetoothChannels.method.invokeMethod<bool>(
          'setPin',
          <String, Object?>{
            'address': address,
            'pin': pin,
          },
        )) ??
        false;
  }

  static Future<bool> setPairingConfirmation(String address, bool confirm) async {
    return (await BluetoothChannels.method.invokeMethod<bool>(
          'setPairingConfirmation',
          <String, Object?>{
            'address': address,
            'confirm': confirm,
          },
        )) ??
        false;
  }

  static Future<BluetoothDeviceType> getDeviceType(String address) async {
    final deviceTypeName = await BluetoothChannels.method.invokeMethod<String>('getDeviceType', address);
    return _parseDeviceType(deviceTypeName);
  }

  static Future<String?> getName(String address) async {
    return BluetoothChannels.method.invokeMethod<String>('getName', address);
  }

  static Future<bool> removeBond(String address) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('removeBond', address)) ?? false;
  }

  static Future<List<String>> getUuids(String address) async {
    final uuids = await BluetoothChannels.method.invokeListMethod<Object?>('getUuids', address);
    return (uuids ?? const []).cast<String>();
  }

  static Stream<BluetoothBondStateChangedEvent> get onBondStateChanged {
    return _bondStateChanged ??= BluetoothChannels.bondStateChanged.receiveBroadcastStream().map((dynamic event) {
      return BluetoothBondStateChangedEvent.fromMap(event as Map<Object?, Object?>);
    });
  }

  static BluetoothBondState _parseBondState(String? stateName) {
    return BluetoothBondState.values.byName(stateName ?? 'unknown');
  }

  static BluetoothDeviceType _parseDeviceType(String? typeName) {
    return BluetoothDeviceType.values.byName(typeName ?? 'unknown');
  }
}
