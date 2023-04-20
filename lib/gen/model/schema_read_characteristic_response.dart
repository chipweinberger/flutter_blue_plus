//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaReadCharacteristicResponse {
  /// Returns a new [SchemaReadCharacteristicResponse] instance.
  SchemaReadCharacteristicResponse({
    required this.remoteId,
    required this.characteristic,
  });

  String remoteId;

  SchemaBluetoothCharacteristic characteristic;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaReadCharacteristicResponse &&
     other.remoteId == remoteId &&
     other.characteristic == characteristic;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (remoteId.hashCode) +
    (characteristic.hashCode);

  @override
  String toString() => 'SchemaReadCharacteristicResponse[remoteId=$remoteId, characteristic=$characteristic]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'remote_id'] = this.remoteId;
      json[r'characteristic'] = this.characteristic;
    return json;
  }

  /// Returns a new [SchemaReadCharacteristicResponse] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaReadCharacteristicResponse? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaReadCharacteristicResponse[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaReadCharacteristicResponse[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaReadCharacteristicResponse(
        remoteId: mapValueOfType<String>(json, r'remote_id')!,
        characteristic: SchemaBluetoothCharacteristic.fromJson(json[r'characteristic'])!,
      );
    }
    return null;
  }

  static List<SchemaReadCharacteristicResponse>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaReadCharacteristicResponse>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaReadCharacteristicResponse.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaReadCharacteristicResponse> mapFromJson(dynamic json) {
    final map = <String, SchemaReadCharacteristicResponse>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaReadCharacteristicResponse.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaReadCharacteristicResponse-objects as value to a dart map
  static Map<String, List<SchemaReadCharacteristicResponse>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaReadCharacteristicResponse>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaReadCharacteristicResponse.listFromJson(entry.value, growable: growable,);
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
    'characteristic',
  };
}

