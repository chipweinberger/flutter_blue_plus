//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaScanResult {
  /// Returns a new [SchemaScanResult] instance.
  SchemaScanResult({
    required this.device,
    required this.advertisementData,
    required this.rssi,
  });

  SchemaBluetoothDevice device;

  SchemaAdvertisementData advertisementData;

  int rssi;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaScanResult &&
     other.device == device &&
     other.advertisementData == advertisementData &&
     other.rssi == rssi;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (device.hashCode) +
    (advertisementData.hashCode) +
    (rssi.hashCode);

  @override
  String toString() => 'SchemaScanResult[device=$device, advertisementData=$advertisementData, rssi=$rssi]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'device'] = this.device;
      json[r'advertisement_data'] = this.advertisementData;
      json[r'rssi'] = this.rssi;
    return json;
  }

  /// Returns a new [SchemaScanResult] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaScanResult? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaScanResult[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaScanResult[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaScanResult(
        device: SchemaBluetoothDevice.fromJson(json[r'device'])!,
        advertisementData: SchemaAdvertisementData.fromJson(json[r'advertisement_data'])!,
        rssi: mapValueOfType<int>(json, r'rssi')!,
      );
    }
    return null;
  }

  static List<SchemaScanResult>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaScanResult>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaScanResult.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaScanResult> mapFromJson(dynamic json) {
    final map = <String, SchemaScanResult>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaScanResult.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaScanResult-objects as value to a dart map
  static Map<String, List<SchemaScanResult>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaScanResult>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaScanResult.listFromJson(entry.value, growable: growable,);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'device',
    'advertisement_data',
    'rssi',
  };
}

