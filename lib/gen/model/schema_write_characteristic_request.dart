//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaWriteCharacteristicRequest {
  /// Returns a new [SchemaWriteCharacteristicRequest] instance.
  SchemaWriteCharacteristicRequest({
    required this.remoteId,
    required this.characteristicUuid,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.writeType,
    required this.value,
  });

  String remoteId;

  String characteristicUuid;

  String serviceUuid;

  String secondaryServiceUuid;

  SchemaWriteCharacteristicRequestWriteTypeEnum writeType;

  String value;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaWriteCharacteristicRequest &&
     other.remoteId == remoteId &&
     other.characteristicUuid == characteristicUuid &&
     other.serviceUuid == serviceUuid &&
     other.secondaryServiceUuid == secondaryServiceUuid &&
     other.writeType == writeType &&
     other.value == value;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (remoteId.hashCode) +
    (characteristicUuid.hashCode) +
    (serviceUuid.hashCode) +
    (secondaryServiceUuid.hashCode) +
    (writeType.hashCode) +
    (value.hashCode);

  @override
  String toString() => 'SchemaWriteCharacteristicRequest[remoteId=$remoteId, characteristicUuid=$characteristicUuid, serviceUuid=$serviceUuid, secondaryServiceUuid=$secondaryServiceUuid, writeType=$writeType, value=$value]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'remote_id'] = this.remoteId;
      json[r'characteristic_uuid'] = this.characteristicUuid;
      json[r'service_uuid'] = this.serviceUuid;
      json[r'secondary_service_uuid'] = this.secondaryServiceUuid;
      json[r'write_type'] = this.writeType;
      json[r'value'] = this.value;
    return json;
  }

  /// Returns a new [SchemaWriteCharacteristicRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaWriteCharacteristicRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaWriteCharacteristicRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaWriteCharacteristicRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaWriteCharacteristicRequest(
        remoteId: mapValueOfType<String>(json, r'remote_id')!,
        characteristicUuid: mapValueOfType<String>(json, r'characteristic_uuid')!,
        serviceUuid: mapValueOfType<String>(json, r'service_uuid')!,
        secondaryServiceUuid: mapValueOfType<String>(json, r'secondary_service_uuid')!,
        writeType: SchemaWriteCharacteristicRequestWriteTypeEnum.fromJson(json[r'write_type'])!,
        value: mapValueOfType<String>(json, r'value')!,
      );
    }
    return null;
  }

  static List<SchemaWriteCharacteristicRequest>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaWriteCharacteristicRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaWriteCharacteristicRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaWriteCharacteristicRequest> mapFromJson(dynamic json) {
    final map = <String, SchemaWriteCharacteristicRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaWriteCharacteristicRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaWriteCharacteristicRequest-objects as value to a dart map
  static Map<String, List<SchemaWriteCharacteristicRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaWriteCharacteristicRequest>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaWriteCharacteristicRequest.listFromJson(entry.value, growable: growable,);
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
    'characteristic_uuid',
    'service_uuid',
    'secondary_service_uuid',
    'write_type',
    'value',
  };
}


class SchemaWriteCharacteristicRequestWriteTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const SchemaWriteCharacteristicRequestWriteTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const WITH_RESPONSE = SchemaWriteCharacteristicRequestWriteTypeEnum._(r'WITH_RESPONSE');
  static const WITHOUT_RESPONSE = SchemaWriteCharacteristicRequestWriteTypeEnum._(r'WITHOUT_RESPONSE');

  /// List of all possible values in this [enum][SchemaWriteCharacteristicRequestWriteTypeEnum].
  static const values = <SchemaWriteCharacteristicRequestWriteTypeEnum>[
    WITH_RESPONSE,
    WITHOUT_RESPONSE,
  ];

  static SchemaWriteCharacteristicRequestWriteTypeEnum? fromJson(dynamic value) => SchemaWriteCharacteristicRequestWriteTypeEnumTypeTransformer().decode(value);

  static List<SchemaWriteCharacteristicRequestWriteTypeEnum>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaWriteCharacteristicRequestWriteTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaWriteCharacteristicRequestWriteTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SchemaWriteCharacteristicRequestWriteTypeEnum] to String,
/// and [decode] dynamic data back to [SchemaWriteCharacteristicRequestWriteTypeEnum].
class SchemaWriteCharacteristicRequestWriteTypeEnumTypeTransformer {
  factory SchemaWriteCharacteristicRequestWriteTypeEnumTypeTransformer() => _instance ??= const SchemaWriteCharacteristicRequestWriteTypeEnumTypeTransformer._();

  const SchemaWriteCharacteristicRequestWriteTypeEnumTypeTransformer._();

  String encode(SchemaWriteCharacteristicRequestWriteTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SchemaWriteCharacteristicRequestWriteTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SchemaWriteCharacteristicRequestWriteTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'WITH_RESPONSE': return SchemaWriteCharacteristicRequestWriteTypeEnum.WITH_RESPONSE;
        case r'WITHOUT_RESPONSE': return SchemaWriteCharacteristicRequestWriteTypeEnum.WITHOUT_RESPONSE;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SchemaWriteCharacteristicRequestWriteTypeEnumTypeTransformer] instance.
  static SchemaWriteCharacteristicRequestWriteTypeEnumTypeTransformer? _instance;
}


