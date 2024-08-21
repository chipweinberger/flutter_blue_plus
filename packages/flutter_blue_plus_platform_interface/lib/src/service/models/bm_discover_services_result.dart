import 'package:collection/collection.dart';

import '../../common/models/device_identifier.dart';
import 'bm_bluetooth_service.dart';

class BmDiscoverServicesResult {
  final DeviceIdentifier remoteId;
  final List<BmBluetoothService> services;
  final bool success;
  final int errorCode;
  final String errorString;

  BmDiscoverServicesResult({
    required this.remoteId,
    required this.services,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmDiscoverServicesResult.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmDiscoverServicesResult(
      remoteId: DeviceIdentifier(json['remote_id']),
      services: (json['services'] as List<dynamic>?)
              ?.map((service) =>
                  BmBluetoothService.fromMap(service as Map<dynamic, dynamic>))
              .toList() ??
          [],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        const ListEquality<BmBluetoothService>().hash(services) ^
        success.hashCode ^
        errorCode.hashCode ^
        errorString.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmDiscoverServicesResult && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'services': services.map((service) => service.toMap()).toList(),
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
  }
}
