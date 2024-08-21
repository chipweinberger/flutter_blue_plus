import 'package:collection/collection.dart';
import 'package:convert/convert.dart';

import '../../common/models/device_identifier.dart';
import '../../common/models/guid.dart';
import '../enums/bm_write_type.dart';

class BmWriteCharacteristicRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final BmWriteType writeType;
  final bool allowLongWrite;
  final List<int> value;

  BmWriteCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.writeType,
    required this.allowLongWrite,
    required this.value,
  });

  factory BmWriteCharacteristicRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmWriteCharacteristicRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      writeType: BmWriteType.values[json['write_type'] as int],
      allowLongWrite: json['allow_long_write'] != 0,
      value: json['value'] != null ? hex.decode(json['value']) : [],
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        writeType.hashCode ^
        allowLongWrite.hashCode ^
        const ListEquality<int>().hash(value);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmWriteCharacteristicRequest && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'write_type': writeType.index,
      'allow_long_write': allowLongWrite ? 1 : 0,
      'value': hex.encode(value),
    };
  }
}
