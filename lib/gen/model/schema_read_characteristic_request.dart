//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaReadCharacteristicRequest {
  /// Returns a new [SchemaReadCharacteristicRequest] instance.
  SchemaReadCharacteristicRequest({
    required this.remoteId,
    required this.characteristicUuid,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
  });

  String remoteId;

  String characteristicUuid;

  String serviceUuid;

  String secondaryServiceUuid;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaReadCharacteristicRequest &&
     other.remoteId == remoteId &&
     other.characteristicUuid == characteristicUuid &&
     other.serviceUuid == serviceUuid &&
     other.secondaryServiceUuid == secondaryServiceUuid;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (remoteId.hashCode) +
    (characteristicUuid.hashCode) +
    (serviceUuid.hashCode) +
    (secondaryServiceUuid.hashCode);

  @override
  String toString() => 'SchemaReadCharacteristicRequest[remoteId=$remoteId, characteristicUuid=$characteristicUuid, serviceUuid=$serviceUuid, secondaryServiceUuid=$secondaryServiceUuid]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'remote_id'] = this.remoteId;
      json[r'characteristic_uuid'] = this.characteristicUuid;
      json[r'service_uuid'] = this.serviceUuid;
      json[r'secondary_service_uuid'] = this.secondaryServiceUuid;
    return json;
  }

  /// Returns a new [SchemaReadCharacteristicRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaReadCharacteristicRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaReadCharacteristicRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaReadCharacteristicRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaReadCharacteristicRequest(
        remoteId: mapValueOfType<String>(json, r'remote_id')!,
        characteristicUuid: mapValueOfType<String>(json, r'characteristic_uuid')!,
        serviceUuid: mapValueOfType<String>(json, r'service_uuid')!,
        secondaryServiceUuid: mapValueOfType<String>(json, r'secondary_service_uuid')!,
      );
    }
    return null;
  }

  static List<SchemaReadCharacteristicRequest>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaReadCharacteristicRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaReadCharacteristicRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaReadCharacteristicRequest> mapFromJson(dynamic json) {
    final map = <String, SchemaReadCharacteristicRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaReadCharacteristicRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaReadCharacteristicRequest-objects as value to a dart map
  static Map<String, List<SchemaReadCharacteristicRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaReadCharacteristicRequest>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaReadCharacteristicRequest.listFromJson(entry.value, growable: growable,);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'remote_id',
    'characteristic_uuid',
    'service_uuid',
    'secondary_service_uuid',
  };
}

