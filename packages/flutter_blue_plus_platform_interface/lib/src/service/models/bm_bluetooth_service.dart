import 'package:collection/collection.dart';

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
    required this.remoteId,
    required this.serviceUuid,
    required this.isPrimary,
    required this.characteristics,
    required this.includedServices,
  });

  factory BmBluetoothService.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBluetoothService(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
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

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        isPrimary.hashCode ^
        const ListEquality<BmBluetoothCharacteristic>().hash(characteristics) ^
        const ListEquality<BmBluetoothService>().hash(includedServices);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmBluetoothService && hashCode == other.hashCode;
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
