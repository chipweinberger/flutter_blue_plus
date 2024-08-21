import 'device_identifier.dart';

class BmMtuChangeRequest {
  final DeviceIdentifier remoteId;
  final int mtu;

  BmMtuChangeRequest({
    required this.remoteId,
    required this.mtu,
  });

  factory BmMtuChangeRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmMtuChangeRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      mtu: json['mtu'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'mtu': mtu,
    };
  }
}
