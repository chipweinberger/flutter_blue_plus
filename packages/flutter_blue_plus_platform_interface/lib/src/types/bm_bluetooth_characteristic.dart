import 'package:collection/collection.dart';

import 'guid.dart';
import 'bm_bluetooth_descriptor.dart';
import 'bm_characteristic_properties.dart';
import 'device_identifier.dart';

class BmBluetoothCharacteristic {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  List<BmBluetoothDescriptor> descriptors;
  BmCharacteristicProperties properties;

  BmBluetoothCharacteristic({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptors,
    required this.properties,
  });

  factory BmBluetoothCharacteristic.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBluetoothCharacteristic(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptors: (json['descriptors'] as List<dynamic>?)
              ?.map((descriptor) => BmBluetoothDescriptor.fromMap(descriptor))
              .toList() ??
          [],
      properties: json['properties'] != null
          ? BmCharacteristicProperties.fromMap(json['properties'])
          : BmCharacteristicProperties(
              broadcast: false,
              read: false,
              writeWithoutResponse: false,
              write: false,
              notify: false,
              indicate: false,
              authenticatedSignedWrites: false,
              extendedProperties: false,
              notifyEncryptionRequired: false,
              indicateEncryptionRequired: false,
            ),
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        const ListEquality<BmBluetoothDescriptor>().hash(descriptors) ^
        properties.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmBluetoothCharacteristic && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'descriptors':
          descriptors.map((descriptor) => descriptor.toMap()).toList(),
      'properties': properties.toMap(),
    };
  }
}
