//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaScanSettings {
  /// Returns a new [SchemaScanSettings] instance.
  SchemaScanSettings({
    required this.androidScanMode,
    this.serviceUuids = const [],
    required this.allowDuplicates,
    this.macAddresses = const [],
  });

  int androidScanMode;

  List<String> serviceUuids;

  bool allowDuplicates;

  List<String> macAddresses;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaScanSettings &&
     other.androidScanMode == androidScanMode &&
     other.serviceUuids == serviceUuids &&
     other.allowDuplicates == allowDuplicates &&
     other.macAddresses == macAddresses;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (androidScanMode.hashCode) +
    (serviceUuids.hashCode) +
    (allowDuplicates.hashCode) +
    (macAddresses.hashCode);

  @override
  String toString() => 'SchemaScanSettings[androidScanMode=$androidScanMode, serviceUuids=$serviceUuids, allowDuplicates=$allowDuplicates, macAddresses=$macAddresses]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'android_scan_mode'] = this.androidScanMode;
      json[r'service_uuids'] = this.serviceUuids;
      json[r'allow_duplicates'] = this.allowDuplicates;
      json[r'mac_addresses'] = this.macAddresses;
    return json;
  }

  /// Returns a new [SchemaScanSettings] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaScanSettings? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaScanSettings[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaScanSettings[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaScanSettings(
        androidScanMode: mapValueOfType<int>(json, r'android_scan_mode')!,
        serviceUuids: json[r'service_uuids'] is List
            ? (json[r'service_uuids'] as List).cast<String>()
            : const [],
        allowDuplicates: mapValueOfType<bool>(json, r'allow_duplicates')!,
        macAddresses: json[r'mac_addresses'] is List
            ? (json[r'mac_addresses'] as List).cast<String>()
            : const [],
      );
    }
    return null;
  }

  static List<SchemaScanSettings>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaScanSettings>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaScanSettings.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaScanSettings> mapFromJson(dynamic json) {
    final map = <String, SchemaScanSettings>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaScanSettings.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaScanSettings-objects as value to a dart map
  static Map<String, List<SchemaScanSettings>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaScanSettings>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaScanSettings.listFromJson(entry.value, growable: growable,);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'android_scan_mode',
    'service_uuids',
    'allow_duplicates',
    'mac_addresses',
  };
}

