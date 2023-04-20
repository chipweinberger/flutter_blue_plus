//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaBluetoothState {
  /// Returns a new [SchemaBluetoothState] instance.
  SchemaBluetoothState({
    required this.state,
  });

  SchemaBluetoothStateStateEnum state;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaBluetoothState &&
     other.state == state;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (state.hashCode);

  @override
  String toString() => 'SchemaBluetoothState[state=$state]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'state'] = this.state;
    return json;
  }

  /// Returns a new [SchemaBluetoothState] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaBluetoothState? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaBluetoothState[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaBluetoothState[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaBluetoothState(
        state: SchemaBluetoothStateStateEnum.fromJson(json[r'state'])!,
      );
    }
    return null;
  }

  static List<SchemaBluetoothState>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaBluetoothState>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaBluetoothState.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaBluetoothState> mapFromJson(dynamic json) {
    final map = <String, SchemaBluetoothState>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaBluetoothState.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaBluetoothState-objects as value to a dart map
  static Map<String, List<SchemaBluetoothState>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaBluetoothState>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaBluetoothState.listFromJson(entry.value, growable: growable,);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'state',
  };
}


class SchemaBluetoothStateStateEnum {
  /// Instantiate a new enum with the provided [value].
  const SchemaBluetoothStateStateEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const UNKNOWN = SchemaBluetoothStateStateEnum._(r'UNKNOWN');
  static const UNAVAILABLE = SchemaBluetoothStateStateEnum._(r'UNAVAILABLE');
  static const UNAUTHORIZED = SchemaBluetoothStateStateEnum._(r'UNAUTHORIZED');
  static const TURNING_ON = SchemaBluetoothStateStateEnum._(r'TURNING_ON');
  static const true_ = SchemaBluetoothStateStateEnum._(r'true');
  static const TURNING_OFF = SchemaBluetoothStateStateEnum._(r'TURNING_OFF');
  static const false_ = SchemaBluetoothStateStateEnum._(r'false');

  /// List of all possible values in this [enum][SchemaBluetoothStateStateEnum].
  static const values = <SchemaBluetoothStateStateEnum>[
    UNKNOWN,
    UNAVAILABLE,
    UNAUTHORIZED,
    TURNING_ON,
    true_,
    TURNING_OFF,
    false_,
  ];

  static SchemaBluetoothStateStateEnum? fromJson(dynamic value) => SchemaBluetoothStateStateEnumTypeTransformer().decode(value);

  static List<SchemaBluetoothStateStateEnum>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaBluetoothStateStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaBluetoothStateStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SchemaBluetoothStateStateEnum] to String,
/// and [decode] dynamic data back to [SchemaBluetoothStateStateEnum].
class SchemaBluetoothStateStateEnumTypeTransformer {
  factory SchemaBluetoothStateStateEnumTypeTransformer() => _instance ??= const SchemaBluetoothStateStateEnumTypeTransformer._();

  const SchemaBluetoothStateStateEnumTypeTransformer._();

  String encode(SchemaBluetoothStateStateEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SchemaBluetoothStateStateEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SchemaBluetoothStateStateEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'UNKNOWN': return SchemaBluetoothStateStateEnum.UNKNOWN;
        case r'UNAVAILABLE': return SchemaBluetoothStateStateEnum.UNAVAILABLE;
        case r'UNAUTHORIZED': return SchemaBluetoothStateStateEnum.UNAUTHORIZED;
        case r'TURNING_ON': return SchemaBluetoothStateStateEnum.TURNING_ON;
        case r'true': return SchemaBluetoothStateStateEnum.true_;
        case r'TURNING_OFF': return SchemaBluetoothStateStateEnum.TURNING_OFF;
        case r'false': return SchemaBluetoothStateStateEnum.false_;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SchemaBluetoothStateStateEnumTypeTransformer] instance.
  static SchemaBluetoothStateStateEnumTypeTransformer? _instance;
}


