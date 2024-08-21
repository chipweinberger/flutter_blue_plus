import '../../common/models/device_identifier.dart';
import '../enums/bm_connection_state_enum.dart';

class BmConnectionStateResponse {
  final DeviceIdentifier remoteId;
  final BmConnectionStateEnum connectionState;
  final int? disconnectReasonCode;
  final String? disconnectReasonString;

  BmConnectionStateResponse({
    required this.remoteId,
    required this.connectionState,
    this.disconnectReasonCode,
    this.disconnectReasonString,
  });

  factory BmConnectionStateResponse.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmConnectionStateResponse(
      remoteId: DeviceIdentifier(json['remote_id']),
      connectionState:
          BmConnectionStateEnum.values[json['connection_state'] as int],
      disconnectReasonCode: json['disconnect_reason_code'],
      disconnectReasonString: json['disconnect_reason_string'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'connection_state': connectionState.index,
      'disconnectReasonCode': disconnectReasonCode,
      'disconnectReasonString': disconnectReasonString,
    };
  }
}
