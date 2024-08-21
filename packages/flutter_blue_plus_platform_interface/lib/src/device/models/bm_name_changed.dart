import '../../common/models/device_identifier.dart';

class BmNameChanged {
  DeviceIdentifier remoteId;
  String name;

  BmNameChanged({
    required this.remoteId,
    required this.name,
  });

  factory BmNameChanged.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmNameChanged(
      remoteId: DeviceIdentifier(json['remote_id']),
      name: json['name'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'name': name,
    };
  }
}
