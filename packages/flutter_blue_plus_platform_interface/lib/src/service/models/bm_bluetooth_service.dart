import '../../characteristic/models/bm_bluetooth_characteristic.dart';
import '../../common/models/device_identifier.dart';
import '../../common/models/guid.dart';

class BmBluetoothService {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  bool isPrimary;
  List<BmBluetoothCharacteristic> characteristics;
  List<BmBluetoothService> includedServices;

  BmBluetoothService({
    required this.serviceUuid,
    required this.remoteId,
    required this.isPrimary,
    required this.characteristics,
    required this.includedServices,
  });

  factory BmBluetoothService.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBluetoothService(
      serviceUuid: Guid(json['service_uuid']),
      remoteId: DeviceIdentifier(json['remote_id']),
      isPrimary: json['is_primary'] == 1,
      characteristics: (json['characteristics'] as List<dynamic>?)
              ?.map((characteristic) =>
                  BmBluetoothCharacteristic.fromMap(characteristic))
              .toList() ??
          [],
      includedServices: (json['included_services'] as List<dynamic>?)
              ?.map((includedService) =>
                  BmBluetoothService.fromMap(includedService))
              .toList() ??
          [],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'is_primary': isPrimary ? 1 : 0,
      'characteristics': characteristics
          .map((characteristic) => characteristic.toMap())
          .toList(),
      'included_services': includedServices
          .map((includedService) => includedService.toMap())
          .toList(),
    };
  }
}
