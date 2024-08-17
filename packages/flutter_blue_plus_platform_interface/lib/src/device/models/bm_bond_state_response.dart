import '../../common/models/device_identifier.dart';
import '../enums/bm_bond_state_enum.dart';

class BmBondStateResponse {
  final DeviceIdentifier remoteId;
  final BmBondStateEnum bondState;
  final BmBondStateEnum? prevState;

  BmBondStateResponse({
    required this.remoteId,
    required this.bondState,
    this.prevState,
  });

  factory BmBondStateResponse.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBondStateResponse(
      remoteId: DeviceIdentifier(json['remote_id']),
      bondState: BmBondStateEnum.values[json['bond_state'] as int],
      prevState: json['prev_state'] != null
          ? BmBondStateEnum.values[json['prev_state'] as int]
          : null,
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'bond_state': bondState.index,
      'prev_state': prevState?.index,
    };
  }
}
