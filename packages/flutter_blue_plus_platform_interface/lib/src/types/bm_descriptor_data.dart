import 'package:collection/collection.dart';
import 'package:convert/convert.dart';

import 'guid.dart';
import 'device_identifier.dart';

class BmDescriptorData {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final List<int> value;
  final bool success;
  final int errorCode;
  final String errorString;

  BmDescriptorData({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmDescriptorData.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmDescriptorData(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
      value: json['value'] != null ? hex.decode(json['value']) : [],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        descriptorUuid.hashCode ^
        const ListEquality<int>().hash(value) ^
        success.hashCode ^
        errorCode.hashCode ^
        errorString.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmDescriptorData && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'descriptor_uuid': descriptorUuid.str,
      'value': hex.encode(value),
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
  }
}
