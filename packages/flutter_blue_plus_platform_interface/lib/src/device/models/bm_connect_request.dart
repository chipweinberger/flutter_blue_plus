import '../../common/models/device_identifier.dart';

class BmConnectRequest {
  DeviceIdentifier remoteId;
  bool autoConnect;

  BmConnectRequest({
    required this.remoteId,
    required this.autoConnect,
  });

  factory BmConnectRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmConnectRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      autoConnect: json['auto_connect'] == 1,
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'auto_connect': autoConnect ? 1 : 0,
    };
  }
}
