//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaDeviceStateResponse {
  /// Returns a new [SchemaDeviceStateResponse] instance.
  SchemaDeviceStateResponse({
    required this.remoteId,
    required this.state,
  });

  String remoteId;

  SchemaDeviceStateResponseStateEnum state;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaDeviceStateResponse &&
     other.remoteId == remoteId &&
     other.state == state;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (remoteId.hashCode) +
    (state.hashCode);

  @override
  String toString() => 'SchemaDeviceStateResponse[remoteId=$remoteId, state=$state]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'remote_id'] = this.remoteId;
      json[r'state'] = this.state;
    return json;
  }

  /// Returns a new [SchemaDeviceStateResponse] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaDeviceStateResponse? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaDeviceStateResponse[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaDeviceStateResponse[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaDeviceStateResponse(
        remoteId: mapValueOfType<String>(json, r'remote_id')!,
        state: SchemaDeviceStateResponseStateEnum.fromJson(json[r'state'])!,
      );
    }
    return null;
  }

  static List<SchemaDeviceStateResponse>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaDeviceStateResponse>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaDeviceStateResponse.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaDeviceStateResponse> mapFromJson(dynamic json) {
    final map = <String, SchemaDeviceStateResponse>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaDeviceStateResponse.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaDeviceStateResponse-objects as value to a dart map
  static Map<String, List<SchemaDeviceStateResponse>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaDeviceStateResponse>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaDeviceStateResponse.listFromJson(entry.value, growable: growable,);
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
    'state',
  };
}


class SchemaDeviceStateResponseStateEnum {
  /// Instantiate a new enum with the provided [value].
  const SchemaDeviceStateResponseStateEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const DISCONNECTED = SchemaDeviceStateResponseStateEnum._(r'DISCONNECTED');
  static const CONNECTING = SchemaDeviceStateResponseStateEnum._(r'CONNECTING');
  static const CONNECTED = SchemaDeviceStateResponseStateEnum._(r'CONNECTED');
  static const DISCONNECTING = SchemaDeviceStateResponseStateEnum._(r'DISCONNECTING');

  /// List of all possible values in this [enum][SchemaDeviceStateResponseStateEnum].
  static const values = <SchemaDeviceStateResponseStateEnum>[
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    DISCONNECTING,
  ];

  static SchemaDeviceStateResponseStateEnum? fromJson(dynamic value) => SchemaDeviceStateResponseStateEnumTypeTransformer().decode(value);

  static List<SchemaDeviceStateResponseStateEnum>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaDeviceStateResponseStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaDeviceStateResponseStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SchemaDeviceStateResponseStateEnum] to String,
/// and [decode] dynamic data back to [SchemaDeviceStateResponseStateEnum].
class SchemaDeviceStateResponseStateEnumTypeTransformer {
  factory SchemaDeviceStateResponseStateEnumTypeTransformer() => _instance ??= const SchemaDeviceStateResponseStateEnumTypeTransformer._();

  const SchemaDeviceStateResponseStateEnumTypeTransformer._();

  String encode(SchemaDeviceStateResponseStateEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SchemaDeviceStateResponseStateEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SchemaDeviceStateResponseStateEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'DISCONNECTED': return SchemaDeviceStateResponseStateEnum.DISCONNECTED;
        case r'CONNECTING': return SchemaDeviceStateResponseStateEnum.CONNECTING;
        case r'CONNECTED': return SchemaDeviceStateResponseStateEnum.CONNECTED;
        case r'DISCONNECTING': return SchemaDeviceStateResponseStateEnum.DISCONNECTING;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SchemaDeviceStateResponseStateEnumTypeTransformer] instance.
  static SchemaDeviceStateResponseStateEnumTypeTransformer? _instance;
}


