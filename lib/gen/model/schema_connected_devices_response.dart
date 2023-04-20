//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaConnectedDevicesResponse {
  /// Returns a new [SchemaConnectedDevicesResponse] instance.
  SchemaConnectedDevicesResponse({
    this.devices = const [],
  });

  List<SchemaBluetoothDevice> devices;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaConnectedDevicesResponse &&
     other.devices == devices;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (devices.hashCode);

  @override
  String toString() => 'SchemaConnectedDevicesResponse[devices=$devices]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'devices'] = this.devices;
    return json;
  }

  /// Returns a new [SchemaConnectedDevicesResponse] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaConnectedDevicesResponse? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaConnectedDevicesResponse[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaConnectedDevicesResponse[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaConnectedDevicesResponse(
        devices: SchemaBluetoothDevice.listFromJson(json[r'devices'])!,
      );
    }
    return null;
  }

  static List<SchemaConnectedDevicesResponse>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaConnectedDevicesResponse>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaConnectedDevicesResponse.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaConnectedDevicesResponse> mapFromJson(dynamic json) {
    final map = <String, SchemaConnectedDevicesResponse>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaConnectedDevicesResponse.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaConnectedDevicesResponse-objects as value to a dart map
  static Map<String, List<SchemaConnectedDevicesResponse>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaConnectedDevicesResponse>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaConnectedDevicesResponse.listFromJson(entry.value, growable: growable,);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'devices',
  };
}

