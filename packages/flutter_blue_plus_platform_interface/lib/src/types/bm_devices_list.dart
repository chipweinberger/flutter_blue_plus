import 'dart:collection';

import 'bm_bluetooth_device.dart';

class BmDevicesList extends ListBase<BmBluetoothDevice> {
  final List<BmBluetoothDevice> devices;

  BmDevicesList({
    required this.devices,
  });

  factory BmDevicesList.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmDevicesList(
      devices: (json['devices'] as List<dynamic>?)
              ?.map((device) => BmBluetoothDevice.fromMap(device))
              .toList() ??
          [],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'devices': devices.map((device) => device.toMap()).toList(),
    };
  }

  @override
  int get length {
    return devices.length;
  }

  @override
  set length(int newLength) {
    devices.length = newLength;
  }

  @override
  BmBluetoothDevice operator [](int index) {
    return devices[index];
  }

  @override
  void operator []=(int index, BmBluetoothDevice value) {
    devices[index] = value;
  }
}
