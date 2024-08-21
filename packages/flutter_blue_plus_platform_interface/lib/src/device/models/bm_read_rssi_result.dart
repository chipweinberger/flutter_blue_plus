import '../../common/models/device_identifier.dart';

class BmReadRssiResult {
  final DeviceIdentifier remoteId;
  final int rssi;
  final bool success;
  final int errorCode;
  final String errorString;

  BmReadRssiResult({
    required this.remoteId,
    required this.rssi,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmReadRssiResult.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmReadRssiResult(
      remoteId: DeviceIdentifier(json['remote_id']),
      rssi: json['rssi'],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'rssi': rssi,
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
  }
}
