import 'package:convert/convert.dart';

import '../../common/models/device_identifier.dart';
import '../../common/models/guid.dart';

class BmCharacteristicData {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final List<int> value;
  final bool success;
  final int errorCode;
  final String errorString;

  BmCharacteristicData({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmCharacteristicData.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmCharacteristicData(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      value: json['value'] != null ? hex.decode(json['value']) : [],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'value': hex.encode(value),
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
  }
}
