//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaMtuSizeRequest {
  /// Returns a new [SchemaMtuSizeRequest] instance.
  SchemaMtuSizeRequest({
    required this.remoteId,
    required this.mtu,
  });

  String remoteId;

  int mtu;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaMtuSizeRequest &&
     other.remoteId == remoteId &&
     other.mtu == mtu;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (remoteId.hashCode) +
    (mtu.hashCode);

  @override
  String toString() => 'SchemaMtuSizeRequest[remoteId=$remoteId, mtu=$mtu]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'remote_id'] = this.remoteId;
      json[r'mtu'] = this.mtu;
    return json;
  }

  /// Returns a new [SchemaMtuSizeRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaMtuSizeRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaMtuSizeRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaMtuSizeRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaMtuSizeRequest(
        remoteId: mapValueOfType<String>(json, r'remote_id')!,
        mtu: mapValueOfType<int>(json, r'mtu')!,
      );
    }
    return null;
  }

  static List<SchemaMtuSizeRequest>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaMtuSizeRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaMtuSizeRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaMtuSizeRequest> mapFromJson(dynamic json) {
    final map = <String, SchemaMtuSizeRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaMtuSizeRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaMtuSizeRequest-objects as value to a dart map
  static Map<String, List<SchemaMtuSizeRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaMtuSizeRequest>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaMtuSizeRequest.listFromJson(entry.value, growable: growable,);
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
    'mtu',
  };
}

