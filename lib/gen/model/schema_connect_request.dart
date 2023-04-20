//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaConnectRequest {
  /// Returns a new [SchemaConnectRequest] instance.
  SchemaConnectRequest({
    required this.remoteId,
    required this.androidAutoConnect,
  });

  String remoteId;

  bool androidAutoConnect;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaConnectRequest &&
     other.remoteId == remoteId &&
     other.androidAutoConnect == androidAutoConnect;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (remoteId.hashCode) +
    (androidAutoConnect.hashCode);

  @override
  String toString() => 'SchemaConnectRequest[remoteId=$remoteId, androidAutoConnect=$androidAutoConnect]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'remote_id'] = this.remoteId;
      json[r'android_auto_connect'] = this.androidAutoConnect;
    return json;
  }

  /// Returns a new [SchemaConnectRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaConnectRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaConnectRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaConnectRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaConnectRequest(
        remoteId: mapValueOfType<String>(json, r'remote_id')!,
        androidAutoConnect: mapValueOfType<bool>(json, r'android_auto_connect')!,
      );
    }
    return null;
  }

  static List<SchemaConnectRequest>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaConnectRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaConnectRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaConnectRequest> mapFromJson(dynamic json) {
    final map = <String, SchemaConnectRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaConnectRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaConnectRequest-objects as value to a dart map
  static Map<String, List<SchemaConnectRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaConnectRequest>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaConnectRequest.listFromJson(entry.value, growable: growable,);
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
    'android_auto_connect',
  };
}

