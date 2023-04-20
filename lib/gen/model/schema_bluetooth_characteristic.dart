//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaBluetoothCharacteristic {
  /// Returns a new [SchemaBluetoothCharacteristic] instance.
  SchemaBluetoothCharacteristic({
    required this.uuid,
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    this.descriptors = const [],
    required this.properties,
    required this.value,
  });

  String uuid;

  String remoteId;

  String serviceUuid;

  String secondaryServiceUuid;

  List<SchemaBluetoothDescriptor> descriptors;

  SchemaCharacteristicProperties properties;

  String value;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaBluetoothCharacteristic &&
     other.uuid == uuid &&
     other.remoteId == remoteId &&
     other.serviceUuid == serviceUuid &&
     other.secondaryServiceUuid == secondaryServiceUuid &&
     other.descriptors == descriptors &&
     other.properties == properties &&
     other.value == value;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (uuid.hashCode) +
    (remoteId.hashCode) +
    (serviceUuid.hashCode) +
    (secondaryServiceUuid.hashCode) +
    (descriptors.hashCode) +
    (properties.hashCode) +
    (value.hashCode);

  @override
  String toString() => 'SchemaBluetoothCharacteristic[uuid=$uuid, remoteId=$remoteId, serviceUuid=$serviceUuid, secondaryServiceUuid=$secondaryServiceUuid, descriptors=$descriptors, properties=$properties, value=$value]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'uuid'] = this.uuid;
      json[r'remote_id'] = this.remoteId;
      json[r'serviceUuid'] = this.serviceUuid;
      json[r'secondaryServiceUuid'] = this.secondaryServiceUuid;
      json[r'descriptors'] = this.descriptors;
      json[r'properties'] = this.properties;
      json[r'value'] = this.value;
    return json;
  }

  /// Returns a new [SchemaBluetoothCharacteristic] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaBluetoothCharacteristic? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaBluetoothCharacteristic[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaBluetoothCharacteristic[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaBluetoothCharacteristic(
        uuid: mapValueOfType<String>(json, r'uuid')!,
        remoteId: mapValueOfType<String>(json, r'remote_id')!,
        serviceUuid: mapValueOfType<String>(json, r'serviceUuid')!,
        secondaryServiceUuid: mapValueOfType<String>(json, r'secondaryServiceUuid')!,
        descriptors: SchemaBluetoothDescriptor.listFromJson(json[r'descriptors'])!,
        properties: SchemaCharacteristicProperties.fromJson(json[r'properties'])!,
        value: mapValueOfType<String>(json, r'value')!,
      );
    }
    return null;
  }

  static List<SchemaBluetoothCharacteristic>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaBluetoothCharacteristic>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaBluetoothCharacteristic.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaBluetoothCharacteristic> mapFromJson(dynamic json) {
    final map = <String, SchemaBluetoothCharacteristic>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaBluetoothCharacteristic.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaBluetoothCharacteristic-objects as value to a dart map
  static Map<String, List<SchemaBluetoothCharacteristic>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaBluetoothCharacteristic>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaBluetoothCharacteristic.listFromJson(entry.value, growable: growable,);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'uuid',
    'remote_id',
    'serviceUuid',
    'secondaryServiceUuid',
    'descriptors',
    'properties',
    'value',
  };
}

