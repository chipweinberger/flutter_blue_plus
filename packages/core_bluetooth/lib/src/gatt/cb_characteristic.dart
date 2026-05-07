part of '../core_bluetooth.dart';

final class CBCharacteristic extends CBAttribute {
  CBCharacteristic({
    required this.handle,
    required CBService? service,
    required super.uuid,
    required CBCharacteristicProperties properties,
    required bool isNotifying,
    required Uint8List? value,
    required List<CBDescriptor>? descriptors,
  })  : _service = service,
        _isNotifying = isNotifying,
        _value = value {
    _properties = properties;
    updateDescriptors(descriptors);
  }

  String handle;
  List<CBDescriptor>? _descriptors;
  bool _isNotifying;
  CBCharacteristicProperties _properties = const CBCharacteristicProperties(0);
  CBService? _service;
  Uint8List? _value;

  List<CBDescriptor>? get descriptors => _descriptors;
  bool get isBroadcasted => properties.contains(CBCharacteristicProperties.broadcast);
  bool get isNotifying => _isNotifying;
  CBCharacteristicProperties get properties => _properties;
  CBService? get service => _service;
  Uint8List? get value => _value;

  void updateDescriptors(List<CBDescriptor>? descriptors) {
    _descriptors = descriptors;
    for (final descriptor in descriptors ?? const <CBDescriptor>[]) {
      descriptor._updateCharacteristic(this);
    }
  }

  void updateIsNotifying(bool isNotifying) {
    _isNotifying = isNotifying;
  }

  void _updateService(CBService? service) {
    _service = service;
  }

  void _updateProperties(CBCharacteristicProperties properties) {
    _properties = properties;
  }

  void updateValue(Uint8List? value) {
    _value = value;
  }

  factory CBCharacteristic.fromMap({
    required CBService service,
    required Map<Object?, Object?> map,
  }) {
    return CBCharacteristic(
      handle: map['handle'] as String? ?? '',
      service: service,
      uuid: CBUUID(map['uuid'] as String? ?? ''),
      properties: CBCharacteristicProperties((map['properties'] as num?)?.toInt() ?? 0),
      isNotifying: map['isNotifying'] as bool? ?? false,
      value: bytesFromNullable(map['value']),
      descriptors: null,
    );
  }
}

final class CBMutableCharacteristic extends CBCharacteristic {
  CBMutableCharacteristic({
    required super.handle,
    required super.service,
    required super.uuid,
    required super.properties,
    required super.isNotifying,
    required super.value,
    required super.descriptors,
    required CBAttributePermissions permissions,
    String? clientReference,
  }) : _clientReference = clientReference ?? _nextCoreBluetoothLocalReference() {
    _permissions = permissions;
  }

  CBMutableCharacteristic.type({
    required CBUUID type,
    required super.properties,
    super.value,
    required CBAttributePermissions permissions,
    super.service,
    super.handle = '',
    super.descriptors,
    String? clientReference,
  })  : _clientReference = clientReference ?? _nextCoreBluetoothLocalReference(),
        super(
          uuid: type,
          isNotifying: false,
        ) {
    _permissions = permissions;
  }

  final String _clientReference;
  CBAttributePermissions _permissions = const CBAttributePermissions(0);
  List<CBCentral>? _subscribedCentrals;

  set descriptors(List<CBDescriptor>? descriptors) {
    updateDescriptors(descriptors);
  }

  set properties(CBCharacteristicProperties properties) {
    _updateProperties(properties);
  }

  set value(Uint8List? value) {
    updateValue(value);
  }

  CBAttributePermissions get permissions => _permissions;

  List<CBCentral> get subscribedCentrals => _subscribedCentrals ?? const [];

  factory CBMutableCharacteristic.fromMap(Map<Object?, Object?> map) {
    final characteristic = CBMutableCharacteristic(
      handle: map['handle'] as String? ?? '',
      service: null,
      uuid: CBUUID(map['uuid'] as String? ?? ''),
      properties: CBCharacteristicProperties((map['properties'] as num?)?.toInt() ?? 0),
      isNotifying: map['isNotifying'] as bool? ?? false,
      value: bytesFromNullable(map['value']),
      descriptors: (map['descriptors'] as List<Object?>? ?? const [])
          .map((descriptor) => CBMutableDescriptor.fromMap(Map<Object?, Object?>.from(descriptor as Map)))
          .toList(),
      permissions: CBAttributePermissions((map['permissions'] as num?)?.toInt() ?? 0),
      clientReference: map['clientReference'] as String?,
    );
    characteristic.updateSubscribedCentrals(
      (map['subscribedCentrals'] as List<Object?>? ?? const [])
          .map((central) => CBCentral.fromMap(Map<Object?, Object?>.from(central as Map)))
          .toList(),
    );
    characteristic._permissions = CBAttributePermissions((map['permissions'] as num?)?.toInt() ?? 0);
    return characteristic;
  }

  Map<String, Object?> toMap() {
    return {
      'clientReference': _clientReference,
      'handle': handle.isEmpty ? null : handle,
      'uuid': uuid.uuidString,
      'properties': properties.rawValue,
      'value': value,
      'permissions': permissions.rawValue,
      'descriptors': descriptors?.whereType<CBMutableDescriptor>().map((descriptor) => descriptor.toMap()).toList(),
    };
  }

  void updateSubscribedCentrals(List<CBCentral>? subscribedCentrals) {
    _subscribedCentrals = subscribedCentrals;
  }

  void _applyNativeState(CBMutableCharacteristic nativeCharacteristic) {
    handle = nativeCharacteristic.handle;
    _updateProperties(nativeCharacteristic.properties);
    _permissions = nativeCharacteristic.permissions;
    updateValue(nativeCharacteristic.value);
    _subscribedCentrals = nativeCharacteristic.subscribedCentrals;
    final nativeDescriptors = nativeCharacteristic.descriptors?.whereType<CBMutableDescriptor>().toList();
    updateDescriptors(_reconcileDescriptors(nativeDescriptors));
  }

  List<CBMutableDescriptor>? _reconcileDescriptors(List<CBMutableDescriptor>? nativeDescriptors) {
    if (nativeDescriptors == null) {
      return null;
    }

    final localDescriptors = _descriptors?.whereType<CBMutableDescriptor>().toList() ?? const [];
    return nativeDescriptors.map((nativeDescriptor) {
      final matches = localDescriptors.where((localDescriptor) {
        if (localDescriptor._clientReference == nativeDescriptor._clientReference) {
          return true;
        }

        return localDescriptor.handle.isNotEmpty &&
            nativeDescriptor.handle.isNotEmpty &&
            localDescriptor.handle == nativeDescriptor.handle;
      });
      final localMatch = matches.isEmpty ? null : matches.first;

      if (localMatch == null) {
        return nativeDescriptor;
      }

      if (!identical(localMatch, nativeDescriptor)) {
        localMatch._applyNativeState(nativeDescriptor);
      }
      return localMatch;
    }).toList();
  }
}
