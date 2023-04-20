//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaBluetoothService {
  /// Returns a new [SchemaBluetoothService] instance.
  SchemaBluetoothService({
    required this.uuid,
    required this.remoteId,
    required this.isPrimary,
    this.characteristics = const [],
    this.includedServices = const [],
  });

  String uuid;

  String remoteId;

  bool isPrimary;

  List<SchemaBluetoothCharacteristic> characteristics;

  List<SchemaBluetoothService> includedServices;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaBluetoothService &&
     other.uuid == uuid &&
     other.remoteId == remoteId &&
     other.isPrimary == isPrimary &&
     other.characteristics == characteristics &&
     other.includedServices == includedServices;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (uuid.hashCode) +
    (remoteId.hashCode) +
    (isPrimary.hashCode) +
    (characteristics.hashCode) +
    (includedServices.hashCode);

  @override
  String toString() => 'SchemaBluetoothService[uuid=$uuid, remoteId=$remoteId, isPrimary=$isPrimary, characteristics=$characteristics, includedServices=$includedServices]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'uuid'] = this.uuid;
      json[r'remote_id'] = this.remoteId;
      json[r'is_primary'] = this.isPrimary;
      json[r'characteristics'] = this.characteristics;
      json[r'included_services'] = this.includedServices;
    return json;
  }

  /// Returns a new [SchemaBluetoothService] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaBluetoothService? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaBluetoothService[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaBluetoothService[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaBluetoothService(
        uuid: mapValueOfType<String>(json, r'uuid')!,
        remoteId: mapValueOfType<String>(json, r'remote_id')!,
        isPrimary: mapValueOfType<bool>(json, r'is_primary')!,
        characteristics: SchemaBluetoothCharacteristic.listFromJson(json[r'characteristics'])!,
        includedServices: SchemaBluetoothService.listFromJson(json[r'included_services'])!,
      );
    }
    return null;
  }

  static List<SchemaBluetoothService>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaBluetoothService>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaBluetoothService.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaBluetoothService> mapFromJson(dynamic json) {
    final map = <String, SchemaBluetoothService>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaBluetoothService.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaBluetoothService-objects as value to a dart map
  static Map<String, List<SchemaBluetoothService>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaBluetoothService>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaBluetoothService.listFromJson(entry.value, growable: growable,);
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
    'is_primary',
    'characteristics',
    'included_services',
  };
}

