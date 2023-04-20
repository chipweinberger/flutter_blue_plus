//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaAdvertisementData {
  /// Returns a new [SchemaAdvertisementData] instance.
  SchemaAdvertisementData({
    required this.localName,
    required this.txPowerLevel,
    required this.connectable,
    this.manufacturerData = const {},
    this.serviceData = const {},
    this.serviceUuids = const [],
  });

  String localName;

  int txPowerLevel;

  bool connectable;

  Map<String, String> manufacturerData;

  Map<String, String> serviceData;

  List<String> serviceUuids;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaAdvertisementData &&
     other.localName == localName &&
     other.txPowerLevel == txPowerLevel &&
     other.connectable == connectable &&
     other.manufacturerData == manufacturerData &&
     other.serviceData == serviceData &&
     other.serviceUuids == serviceUuids;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (localName.hashCode) +
    (txPowerLevel.hashCode) +
    (connectable.hashCode) +
    (manufacturerData.hashCode) +
    (serviceData.hashCode) +
    (serviceUuids.hashCode);

  @override
  String toString() => 'SchemaAdvertisementData[localName=$localName, txPowerLevel=$txPowerLevel, connectable=$connectable, manufacturerData=$manufacturerData, serviceData=$serviceData, serviceUuids=$serviceUuids]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'local_name'] = this.localName;
      json[r'tx_power_level'] = this.txPowerLevel;
      json[r'connectable'] = this.connectable;
      json[r'manufacturer_data'] = this.manufacturerData;
      json[r'service_data'] = this.serviceData;
      json[r'service_uuids'] = this.serviceUuids;
    return json;
  }

  /// Returns a new [SchemaAdvertisementData] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaAdvertisementData? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaAdvertisementData[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaAdvertisementData[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaAdvertisementData(
        localName: mapValueOfType<String>(json, r'local_name')!,
        txPowerLevel: mapValueOfType<int>(json, r'tx_power_level')!,
        connectable: mapValueOfType<bool>(json, r'connectable')!,
        manufacturerData: mapCastOfType<String, String>(json, r'manufacturer_data')!,
        serviceData: mapCastOfType<String, String>(json, r'service_data')!,
        serviceUuids: json[r'service_uuids'] is List
            ? (json[r'service_uuids'] as List).cast<String>()
            : const [],
      );
    }
    return null;
  }

  static List<SchemaAdvertisementData>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaAdvertisementData>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaAdvertisementData.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaAdvertisementData> mapFromJson(dynamic json) {
    final map = <String, SchemaAdvertisementData>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaAdvertisementData.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaAdvertisementData-objects as value to a dart map
  static Map<String, List<SchemaAdvertisementData>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaAdvertisementData>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaAdvertisementData.listFromJson(entry.value, growable: growable,);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'local_name',
    'tx_power_level',
    'connectable',
    'manufacturer_data',
    'service_data',
    'service_uuids',
  };
}

