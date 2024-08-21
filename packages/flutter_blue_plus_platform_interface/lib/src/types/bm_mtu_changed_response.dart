import 'device_identifier.dart';

class BmMtuChangedResponse {
  final DeviceIdentifier remoteId;
  final int mtu;
  final bool success;
  final int errorCode;
  final String errorString;

  BmMtuChangedResponse({
    required this.remoteId,
    required this.mtu,
    this.success = true,
    this.errorCode = 0,
    this.errorString = '',
  });

  factory BmMtuChangedResponse.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmMtuChangedResponse(
      remoteId: DeviceIdentifier(json['remote_id']),
      mtu: json['mtu'],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'mtu': mtu,
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
  }
}
