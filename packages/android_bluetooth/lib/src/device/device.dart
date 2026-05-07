import 'dart:typed_data';

import '../gatt/gatt_api.dart';
import '../gatt/gatt.dart';
import '../gatt/gatt_types.dart';
import '../socket/socket.dart';
import '../socket/socket_api.dart';
import 'device_api.dart';
import 'device_types.dart';

final class BluetoothDevice {
  const BluetoothDevice({
    required this.address,
    required this.bondState,
    required this.platformName,
    required this.type,
    required this.uuids,
  });

  factory BluetoothDevice.fromMap(Map<Object?, Object?> map) {
    return BluetoothDevice(
      address: map['address'] as String,
      bondState: BluetoothBondState.values.byName(map['bondState'] as String? ?? 'unknown'),
      platformName: map['platformName'] as String?,
      type: BluetoothDeviceType.values.byName(map['type'] as String? ?? 'unknown'),
      uuids: (map['uuids'] as List<Object?>? ?? const []).cast<String>(),
    );
  }

  final String address;
  final BluetoothBondState bondState;
  final String? platformName;
  final BluetoothDeviceType type;
  final List<String> uuids;

  Future<String?> getAddress() async {
    return BluetoothDeviceApi.getAddress(address);
  }

  Future<String?> getName() async {
    return BluetoothDeviceApi.getName(address);
  }

  Future<BluetoothDeviceType> getType() async {
    return BluetoothDeviceApi.getDeviceType(address);
  }

  Future<BluetoothBondState> getBondState() async {
    return BluetoothDeviceApi.getBondState(address);
  }

  Future<List<String>> getUuids() async {
    return BluetoothDeviceApi.getUuids(address);
  }

  Future<bool> createBond() async {
    return BluetoothDeviceApi.createBond(address);
  }

  Future<bool> removeBond() async {
    return BluetoothDeviceApi.removeBond(address);
  }

  Future<bool> setPin(Uint8List pin) async {
    return BluetoothDeviceApi.setPin(address, pin);
  }

  Future<bool> setPairingConfirmation(bool confirm) async {
    return BluetoothDeviceApi.setPairingConfirmation(address, confirm);
  }

  Future<bool> connectGatt({
    bool autoConnect = false,
    BluetoothGattHandler? handler,
    int? transport,
    int? phy,
  }) async {
    return BluetoothGattApi.connect(
      address,
      autoConnect: autoConnect,
      handler: handler,
      transport: transport,
      phy: phy,
    );
  }

  Future<BluetoothGattConnectionState> getGattConnectionState() async {
    return BluetoothGattApi.getConnectionState(address);
  }

  BluetoothGatt getGatt() {
    return BluetoothGatt(address);
  }

  Future<BluetoothSocket?> createL2capChannel(int psm) async {
    return BluetoothSocketApi.createL2capChannel(address, psm, insecure: false);
  }

  Future<BluetoothSocket?> createInsecureL2capChannel(int psm) async {
    return BluetoothSocketApi.createL2capChannel(address, psm, insecure: true);
  }

  Stream<BluetoothBondStateChangedEvent> get onBondStateChanged {
    return BluetoothDeviceApi.onBondStateChanged.where((event) => event.device.address == address);
  }
}
