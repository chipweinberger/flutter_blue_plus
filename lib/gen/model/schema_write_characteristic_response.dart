//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaWriteCharacteristicResponse {
  /// Returns a new [SchemaWriteCharacteristicResponse] instance.
  SchemaWriteCharacteristicResponse({
    required this.request,
    required this.success,
  });

  SchemaWriteCharacteristicRequest request;

  bool success;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaWriteCharacteristicResponse &&
     other.request == request &&
     other.success == success;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (request.hashCode) +
    (success.hashCode);

  @override
  String toString() => 'SchemaWriteCharacteristicResponse[request=$request, success=$success]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'request'] = this.request;
      json[r'success'] = this.success;
    return json;
  }

  /// Returns a new [SchemaWriteCharacteristicResponse] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaWriteCharacteristicResponse? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaWriteCharacteristicResponse[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaWriteCharacteristicResponse[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaWriteCharacteristicResponse(
        request: SchemaWriteCharacteristicRequest.fromJson(json[r'request'])!,
        success: mapValueOfType<bool>(json, r'success')!,
      );
    }
    return null;
  }

  static List<SchemaWriteCharacteristicResponse>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaWriteCharacteristicResponse>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaWriteCharacteristicResponse.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaWriteCharacteristicResponse> mapFromJson(dynamic json) {
    final map = <String, SchemaWriteCharacteristicResponse>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaWriteCharacteristicResponse.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaWriteCharacteristicResponse-objects as value to a dart map
  static Map<String, List<SchemaWriteCharacteristicResponse>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaWriteCharacteristicResponse>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaWriteCharacteristicResponse.listFromJson(entry.value, growable: growable,);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'request',
    'success',
  };
}

