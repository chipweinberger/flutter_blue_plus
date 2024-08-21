import '../../common/models/device_identifier.dart';
import '../../common/models/guid.dart';
import '../../descriptor/models/bm_bluetooth_descriptor.dart';
import 'bm_characteristic_properties.dart';

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
    required this.secondaryServiceUuid,
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
