//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaReadDescriptorRequest {
  /// Returns a new [SchemaReadDescriptorRequest] instance.
  SchemaReadDescriptorRequest({
    required this.remoteId,
    required this.descriptorUuid,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
  });

  String remoteId;

  String descriptorUuid;

  String serviceUuid;

  String secondaryServiceUuid;

  String characteristicUuid;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaReadDescriptorRequest &&
     other.remoteId == remoteId &&
     other.descriptorUuid == descriptorUuid &&
     other.serviceUuid == serviceUuid &&
     other.secondaryServiceUuid == secondaryServiceUuid &&
     other.characteristicUuid == characteristicUuid;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (remoteId.hashCode) +
    (descriptorUuid.hashCode) +
    (serviceUuid.hashCode) +
    (secondaryServiceUuid.hashCode) +
    (characteristicUuid.hashCode);

  @override
  String toString() => 'SchemaReadDescriptorRequest[remoteId=$remoteId, descriptorUuid=$descriptorUuid, serviceUuid=$serviceUuid, secondaryServiceUuid=$secondaryServiceUuid, characteristicUuid=$characteristicUuid]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'remote_id'] = this.remoteId;
      json[r'descriptor_uuid'] = this.descriptorUuid;
      json[r'service_uuid'] = this.serviceUuid;
      json[r'secondary_service_uuid'] = this.secondaryServiceUuid;
      json[r'characteristic_uuid'] = this.characteristicUuid;
    return json;
  }

  /// Returns a new [SchemaReadDescriptorRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaReadDescriptorRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaReadDescriptorRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaReadDescriptorRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaReadDescriptorRequest(
        remoteId: mapValueOfType<String>(json, r'remote_id')!,
        descriptorUuid: mapValueOfType<String>(json, r'descriptor_uuid')!,
        serviceUuid: mapValueOfType<String>(json, r'service_uuid')!,
        secondaryServiceUuid: mapValueOfType<String>(json, r'secondary_service_uuid')!,
        characteristicUuid: mapValueOfType<String>(json, r'characteristic_uuid')!,
      );
    }
    return null;
  }

  static List<SchemaReadDescriptorRequest>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaReadDescriptorRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaReadDescriptorRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaReadDescriptorRequest> mapFromJson(dynamic json) {
    final map = <String, SchemaReadDescriptorRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaReadDescriptorRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaReadDescriptorRequest-objects as value to a dart map
  static Map<String, List<SchemaReadDescriptorRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaReadDescriptorRequest>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaReadDescriptorRequest.listFromJson(entry.value, growable: growable,);
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
    'descriptor_uuid',
    'service_uuid',
    'secondary_service_uuid',
    'characteristic_uuid',
  };
}

