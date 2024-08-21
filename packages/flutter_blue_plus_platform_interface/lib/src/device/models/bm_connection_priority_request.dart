import '../../common/models/device_identifier.dart';
import '../enums/bm_connection_priority_enum.dart';

class BmConnectionPriorityRequest {
  final DeviceIdentifier remoteId;
  final BmConnectionPriorityEnum connectionPriority;

  BmConnectionPriorityRequest({
    required this.remoteId,
    required this.connectionPriority,
  });

  factory BmConnectionPriorityRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmConnectionPriorityRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      connectionPriority:
          BmConnectionPriorityEnum.values[json['connection_priority'] as int],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'connection_priority': connectionPriority.index,
    };
  }
}
