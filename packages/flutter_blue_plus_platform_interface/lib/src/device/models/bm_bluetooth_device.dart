import '../../common/models/device_identifier.dart';

class BmBluetoothDevice {
  DeviceIdentifier remoteId;
  String? platformName;

  BmBluetoothDevice({
    required this.remoteId,
    this.platformName,
  });

  factory BmBluetoothDevice.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBluetoothDevice(
      remoteId: DeviceIdentifier(json['remote_id']),
      platformName: json['platform_name'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'platform_name': platformName,
    };
  }
}
