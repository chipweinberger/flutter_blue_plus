//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SchemaCharacteristicProperties {
  /// Returns a new [SchemaCharacteristicProperties] instance.
  SchemaCharacteristicProperties({
    required this.broadcast,
    required this.read,
    required this.writeWithoutResponse,
    required this.write,
    required this.notify,
    required this.indicate,
    required this.authenticatedSignedWrites,
    required this.extendedProperties,
    required this.notifyEncryptionRequired,
    required this.indicateEncryptionRequired,
  });

  bool broadcast;

  bool read;

  bool writeWithoutResponse;

  bool write;

  bool notify;

  bool indicate;

  bool authenticatedSignedWrites;

  bool extendedProperties;

  bool notifyEncryptionRequired;

  bool indicateEncryptionRequired;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SchemaCharacteristicProperties &&
     other.broadcast == broadcast &&
     other.read == read &&
     other.writeWithoutResponse == writeWithoutResponse &&
     other.write == write &&
     other.notify == notify &&
     other.indicate == indicate &&
     other.authenticatedSignedWrites == authenticatedSignedWrites &&
     other.extendedProperties == extendedProperties &&
     other.notifyEncryptionRequired == notifyEncryptionRequired &&
     other.indicateEncryptionRequired == indicateEncryptionRequired;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (broadcast.hashCode) +
    (read.hashCode) +
    (writeWithoutResponse.hashCode) +
    (write.hashCode) +
    (notify.hashCode) +
    (indicate.hashCode) +
    (authenticatedSignedWrites.hashCode) +
    (extendedProperties.hashCode) +
    (notifyEncryptionRequired.hashCode) +
    (indicateEncryptionRequired.hashCode);

  @override
  String toString() => 'SchemaCharacteristicProperties[broadcast=$broadcast, read=$read, writeWithoutResponse=$writeWithoutResponse, write=$write, notify=$notify, indicate=$indicate, authenticatedSignedWrites=$authenticatedSignedWrites, extendedProperties=$extendedProperties, notifyEncryptionRequired=$notifyEncryptionRequired, indicateEncryptionRequired=$indicateEncryptionRequired]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'broadcast'] = this.broadcast;
      json[r'read'] = this.read;
      json[r'write_without_response'] = this.writeWithoutResponse;
      json[r'write'] = this.write;
      json[r'notify'] = this.notify;
      json[r'indicate'] = this.indicate;
      json[r'authenticated_signed_writes'] = this.authenticatedSignedWrites;
      json[r'extended_properties'] = this.extendedProperties;
      json[r'notify_encryption_required'] = this.notifyEncryptionRequired;
      json[r'indicate_encryption_required'] = this.indicateEncryptionRequired;
    return json;
  }

  /// Returns a new [SchemaCharacteristicProperties] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SchemaCharacteristicProperties? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SchemaCharacteristicProperties[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SchemaCharacteristicProperties[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SchemaCharacteristicProperties(
        broadcast: mapValueOfType<bool>(json, r'broadcast')!,
        read: mapValueOfType<bool>(json, r'read')!,
        writeWithoutResponse: mapValueOfType<bool>(json, r'write_without_response')!,
        write: mapValueOfType<bool>(json, r'write')!,
        notify: mapValueOfType<bool>(json, r'notify')!,
        indicate: mapValueOfType<bool>(json, r'indicate')!,
        authenticatedSignedWrites: mapValueOfType<bool>(json, r'authenticated_signed_writes')!,
        extendedProperties: mapValueOfType<bool>(json, r'extended_properties')!,
        notifyEncryptionRequired: mapValueOfType<bool>(json, r'notify_encryption_required')!,
        indicateEncryptionRequired: mapValueOfType<bool>(json, r'indicate_encryption_required')!,
      );
    }
    return null;
  }

  static List<SchemaCharacteristicProperties>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SchemaCharacteristicProperties>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SchemaCharacteristicProperties.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SchemaCharacteristicProperties> mapFromJson(dynamic json) {
    final map = <String, SchemaCharacteristicProperties>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaCharacteristicProperties.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SchemaCharacteristicProperties-objects as value to a dart map
  static Map<String, List<SchemaCharacteristicProperties>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SchemaCharacteristicProperties>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SchemaCharacteristicProperties.listFromJson(entry.value, growable: growable,);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'broadcast',
    'read',
    'write_without_response',
    'write',
    'notify',
    'indicate',
    'authenticated_signed_writes',
    'extended_properties',
    'notify_encryption_required',
    'indicate_encryption_required',
  };
}

