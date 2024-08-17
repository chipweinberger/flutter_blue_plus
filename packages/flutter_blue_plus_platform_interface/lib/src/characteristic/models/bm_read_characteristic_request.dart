import '../../common/models/device_identifier.dart';
import '../../common/models/guid.dart';

class BmReadCharacteristicRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;

  BmReadCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
  });

  factory BmReadCharacteristicRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmReadCharacteristicRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
    };
  }
}
