import '../utils/utils.dart';
import 'device_identifier.dart';
import 'guid.dart';

class BmWriteDescriptorRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final List<int> value;

  BmWriteDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.value,
  });

  factory BmWriteDescriptorRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmWriteDescriptorRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
      value: json['value'] != null ? hex.decode(json['value']) : [],
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        descriptorUuid.hashCode ^
        const ListEquality<int>().hash(value);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmWriteDescriptorRequest && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'descriptor_uuid': descriptorUuid.str,
      'value': hex.encode(value),
    };
  }
}
