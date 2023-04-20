//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaBluetoothDevice {
  /// Returns a new [SchemaBluetoothDevice] instance.
  SchemaBluetoothDevice({
    required this.remoteId,
    required this.name,
    required this.type,
  });

  String remoteId;

  String name;

  SchemaBluetoothDeviceTypeEnum type;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaBluetoothDevice &&
     other.remoteId == remoteId &&
     other.name == name &&
     other.type == type;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (remoteId.hashCode) +
    (name.hashCode) +
    (type.hashCode);

  @override
  String toString() => 'SchemaBluetoothDevice[remoteId=$remoteId, name=$name, type=$type]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'remote_id'] = this.remoteId;
      json[r'name'] = this.name;
      json[r'type'] = this.type;
    return json;
  }

  /// Returns a new [SchemaBluetoothDevice] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaBluetoothDevice? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaBluetoothDevice[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaBluetoothDevice[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaBluetoothDevice(
        remoteId: mapValueOfType<String>(json, r'remote_id')!,
        name: mapValueOfType<String>(json, r'name')!,
        type: SchemaBluetoothDeviceTypeEnum.fromJson(json[r'type'])!,
      );
    }
    return null;
  }

  static List<SchemaBluetoothDevice>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaBluetoothDevice>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaBluetoothDevice.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaBluetoothDevice> mapFromJson(dynamic json) {
    final map = <String, SchemaBluetoothDevice>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaBluetoothDevice.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaBluetoothDevice-objects as value to a dart map
  static Map<String, List<SchemaBluetoothDevice>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaBluetoothDevice>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaBluetoothDevice.listFromJson(entry.value, growable: growable,);
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
    'name',
    'type',
  };
}


class SchemaBluetoothDeviceTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const SchemaBluetoothDeviceTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const UNKNOWN = SchemaBluetoothDeviceTypeEnum._(r'UNKNOWN');
  static const CLASSIC = SchemaBluetoothDeviceTypeEnum._(r'CLASSIC');
  static const LE = SchemaBluetoothDeviceTypeEnum._(r'LE');
  static const DUAL = SchemaBluetoothDeviceTypeEnum._(r'DUAL');

  /// List of all possible values in this [enum][SchemaBluetoothDeviceTypeEnum].
  static const values = <SchemaBluetoothDeviceTypeEnum>[
    UNKNOWN,
    CLASSIC,
    LE,
    DUAL,
  ];

  static SchemaBluetoothDeviceTypeEnum? fromJson(dynamic value) => SchemaBluetoothDeviceTypeEnumTypeTransformer().decode(value);

  static List<SchemaBluetoothDeviceTypeEnum>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaBluetoothDeviceTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaBluetoothDeviceTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SchemaBluetoothDeviceTypeEnum] to String,
/// and [decode] dynamic data back to [SchemaBluetoothDeviceTypeEnum].
class SchemaBluetoothDeviceTypeEnumTypeTransformer {
  factory SchemaBluetoothDeviceTypeEnumTypeTransformer() => _instance ??= const SchemaBluetoothDeviceTypeEnumTypeTransformer._();

  const SchemaBluetoothDeviceTypeEnumTypeTransformer._();

  String encode(SchemaBluetoothDeviceTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SchemaBluetoothDeviceTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SchemaBluetoothDeviceTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'UNKNOWN': return SchemaBluetoothDeviceTypeEnum.UNKNOWN;
        case r'CLASSIC': return SchemaBluetoothDeviceTypeEnum.CLASSIC;
        case r'LE': return SchemaBluetoothDeviceTypeEnum.LE;
        case r'DUAL': return SchemaBluetoothDeviceTypeEnum.DUAL;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SchemaBluetoothDeviceTypeEnumTypeTransformer] instance.
  static SchemaBluetoothDeviceTypeEnumTypeTransformer? _instance;
}


