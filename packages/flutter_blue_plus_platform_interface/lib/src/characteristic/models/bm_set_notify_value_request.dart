import '../../common/models/device_identifier.dart';
import '../../common/models/guid.dart';

class BmSetNotifyValueRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final bool forceIndications;
  final bool enable;

  BmSetNotifyValueRequest({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.forceIndications,
    required this.enable,
  });

  factory BmSetNotifyValueRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmSetNotifyValueRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      forceIndications: json['force_indications'],
      enable: json['enable'],
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        forceIndications.hashCode ^
        enable.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmSetNotifyValueRequest && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'force_indications': forceIndications,
      'enable': enable,
    };
  }
}
