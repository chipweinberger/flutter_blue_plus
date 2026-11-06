part of '../flutter_blue_plus_android.dart';

final class _Connection {
  _Connection(this.remoteId, this.autoConnect, {this.previous});
  final String remoteId;
  final bool autoConnect;
  // Retain an auto-connect registration until its replacement opens or is canceled.
  _Connection? previous;
  ab.BluetoothGatt? gatt;
  StreamSubscription<ab.BluetoothGattCallback>? subscription;
  final ready = Completer<void>();
  bool connecting = true;
  bool connected = false;
  bool explicitDisconnect = false;
  bool canceling = false;
  int mtu = _defaultMtu;
  _AttributeGraph graph = _AttributeGraph([]);
}

final class _GattTarget {
  final DeviceIdentifier remoteId;
  final String? primaryServiceUuid;
  final String serviceUuid, characteristicUuid;
  final int instanceId;

  _GattTarget(this.remoteId, Guid? primary, Guid service, Guid characteristic, this.instanceId)
      : primaryServiceUuid = primary?.str,
        serviceUuid = service.str,
        characteristicUuid = characteristic.str;
}

typedef _WriteKey = ({
  String remoteId,
  String? primaryServiceUuid,
  String serviceUuid,
  String characteristicUuid,
  int instanceId,
  String? descriptorUuid,
});

final class _Attribute {
  final ab.BluetoothGattService service;
  final ab.BluetoothGattCharacteristic characteristic;
  final int instanceId;
  final String? primaryServiceUuid;
  final String serviceUuid, characteristicUuid;

  _Attribute(this.service, this.characteristic, ab.BluetoothGattService? primary, this.instanceId)
      : primaryServiceUuid = primary == null ? null : _shortUuid(primary.uuid),
        serviceUuid = _shortUuid(service.uuid),
        characteristicUuid = _shortUuid(characteristic.uuid);

  _WriteKey writeKey(String remoteId, [String? descriptor]) => (
        remoteId: remoteId,
        primaryServiceUuid: primaryServiceUuid,
        serviceUuid: serviceUuid,
        characteristicUuid: characteristicUuid,
        instanceId: instanceId,
        descriptorUuid: descriptor,
      );

  Map<String, Object?> identity(String remoteId) => {
        'remote_id': remoteId,
        if (primaryServiceUuid != null) 'primary_service_uuid': primaryServiceUuid,
        'service_uuid': serviceUuid,
        'characteristic_uuid': characteristicUuid,
        'instance_id': instanceId,
      };
}

final class _AttributeGraph {
  final List<ab.BluetoothGattService> services;
  final byHandle = <String, _Attribute>{};
  final Map<String, _Attribute> retired;

  _AttributeGraph(this.services, [_AttributeGraph? previous])
      : retired = {...?previous?.retired, ...?previous?.byHandle} {
    for (final service in services.expand((primary) => [primary, ...primary.includedServices])) {
      for (final characteristic in service.characteristics) {
        byHandle[characteristic.handle] = _attribute(service, characteristic);
      }
    }
  }

  ab.BluetoothGattService? _primary(ab.BluetoothGattService service) {
    if (service.type == ab.BluetoothGattService.serviceTypePrimary) return null;
    for (final primary in services) {
      if (primary.includedServices.any((secondary) => _sameUuid(secondary.uuid, service.uuid))) return primary;
    }
    return null;
  }

  List<ab.BluetoothGattService> _matching(String? primaryUuid, String uuid) {
    final candidates = primaryUuid == null
        ? services
        : services
            .where((primary) => _sameUuid(primary.uuid, primaryUuid))
            .expand((primary) => primary.includedServices);
    return candidates.where((service) => _sameUuid(service.uuid, uuid)).toList();
  }

  int _instanceId(ab.BluetoothGattService? primary, ab.BluetoothGattService service,
      ab.BluetoothGattCharacteristic characteristic) {
    final matching = _matching(primary?.uuid, service.uuid);
    if (matching.length > 1) {
      var instanceId = 0;
      for (final candidate in matching.expand((service) => service.characteristics)) {
        if (candidate.handle == characteristic.handle) return instanceId;
        instanceId++;
      }
      return 0;
    }
    final duplicates = service.characteristics.where((c) => _sameUuid(c.uuid, characteristic.uuid)).length > 1;
    return duplicates ? characteristic.instanceId : 0;
  }

  _Attribute _attribute(ab.BluetoothGattService service, ab.BluetoothGattCharacteristic characteristic) {
    final primary = _primary(service);
    return _Attribute(service, characteristic, primary, _instanceId(primary, service, characteristic));
  }

  Map<String, int> _propertiesMap(int flags) {
    const properties = [
      'broadcast',
      'read',
      'write_without_response',
      'write',
      'notify',
      'indicate',
      'authenticated_signed_writes',
      'extended_properties',
      'notify_encryption_required',
      'indicate_encryption_required'
    ];
    return {for (var bit = 0; bit < properties.length; bit++) properties[bit]: flags & (1 << bit) != 0 ? 1 : 0};
  }

  Map<String, Object?> _characteristicMap(String remoteId, _Attribute attribute) {
    final characteristic = attribute.characteristic;
    final identity = attribute.identity(remoteId);
    return {
      ...identity,
      'properties': _propertiesMap(characteristic.properties),
      'descriptors': [
        for (final descriptor in characteristic.descriptors)
          {...identity, 'descriptor_uuid': _shortUuid(descriptor.uuid)},
      ],
    };
  }

  Map<String, Object?> _serviceMap(String remoteId, ab.BluetoothGattService primary, ab.BluetoothGattService service) =>
      {
        'remote_id': remoteId,
        if (service.handle != primary.handle) 'primary_service_uuid': _shortUuid(primary.uuid),
        'service_uuid': _shortUuid(service.uuid),
        'characteristics': [
          for (final characteristic in service.characteristics)
            _characteristicMap(remoteId, byHandle[characteristic.handle]!),
        ],
      };

  _Attribute callback(ab.BluetoothGattCharacteristic characteristic) {
    final existing = byHandle[characteristic.handle];
    if (existing != null) return existing;
    // Android can deliver an old attribute after refresh or rediscovery.
    final old = retired[characteristic.handle];
    if (old != null) return _attribute(old.service, old.characteristic);
    final service = characteristic.service;
    if (service == null) throw StateError('Android omitted callback service identity');
    return _attribute(service, characteristic);
  }

  _Attribute locate(String method, _GattTarget target) {
    final primary = target.primaryServiceUuid;
    final uuid = target.serviceUuid;
    final matches = _matching(primary, uuid);
    if (matches.isEmpty) {
      if (primary != null) _fail(method, "secondary service not found '$uuid' (primary service '$primary')");
      _fail(method, "primary service not found '$uuid'");
    }
    for (final characteristic in matches.expand((service) => service.characteristics)) {
      final attribute = byHandle[characteristic.handle]!;
      if (attribute.characteristicUuid == target.characteristicUuid && attribute.instanceId == target.instanceId) {
        return attribute;
      }
    }
    _fail(method, "characteristic not found in service (chr: '${target.characteristicUuid}' svc: '$uuid')");
  }

  List<Map<String, Object?>> toMap(String remoteId) => [
        for (final primary in services)
          for (final service in [primary, ...primary.includedServices]) _serviceMap(remoteId, primary, service),
      ];
}
