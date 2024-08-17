import 'package:convert/convert.dart';

import '../../common/models/device_identifier.dart';
import '../../common/models/guid.dart';

class BmScanAdvertisement {
  final DeviceIdentifier remoteId;
  final String? platformName;
  final String? advName;
  final bool connectable;
  final int? txPowerLevel;
  final int? appearance; // not supported on iOS / macOS
  final Map<int, List<int>> manufacturerData;
  final Map<Guid, List<int>> serviceData;
  final List<Guid> serviceUuids;
  final int rssi;

  BmScanAdvertisement({
    required this.remoteId,
    this.platformName,
    this.advName,
    required this.connectable,
    this.txPowerLevel,
    this.appearance,
    required this.manufacturerData,
    required this.serviceData,
    required this.serviceUuids,
    required this.rssi,
  });

  factory BmScanAdvertisement.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmScanAdvertisement(
      remoteId: DeviceIdentifier(json['remote_id']),
      platformName: json['platform_name'],
      advName: json['adv_name'],
      connectable: json['connectable'] == 1,
      txPowerLevel: json['tx_power_level'],
      appearance: json['appearance'],
      manufacturerData: (json['manufacturer_data'] as Map<dynamic, dynamic>?)
              ?.map((key, value) => MapEntry(key, hex.decode(value))) ??
          {},
      serviceData: (json['service_data'] as Map<dynamic, dynamic>?)
              ?.map((key, value) => MapEntry(Guid(key), hex.decode(value))) ??
          {},
      serviceUuids: (json['service_uuids'] as List<dynamic>?)
              ?.map((str) => Guid(str))
              .toList() ??
          [],
      rssi: json['rssi'] ?? 0,
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'platform_name': platformName,
      'adv_name': advName,
      'connectable': connectable ? 1 : 0,
      'tx_power_level': txPowerLevel,
      'appearance': appearance,
      'manufacturer_data': manufacturerData
          .map((key, value) => MapEntry(key, hex.encode(value))),
      'service_data':
          serviceData.map((key, value) => MapEntry(key.str, hex.encode(value))),
      'service_uuids': serviceUuids.map((uuid) => uuid.str).toList(),
      'rssi': rssi,
    };
  }
}
