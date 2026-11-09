part of '../flutter_blue_plus_darwin.dart';

Never _fail(String method, String message, [Object? details]) =>
    throw PlatformException(code: method, message: message, details: details);

String _remoteId(cb.CBPeripheral peripheral) => peripheral.identifier.uuidString.toUpperCase();
Guid _guid(cb.CBUUID uuid) => Guid(uuid.uuidString);

Future<int> _maximumPayload(cb.CBPeripheral peripheral, {bool longWrite = false}) async => math.min(
    512,
    await peripheral.maximumWriteValueLength(
        longWrite ? cb.CBCharacteristicWriteType.withResponse : cb.CBCharacteristicWriteType.withoutResponse));

BmAdapterStateEnum _adapterState(cb.CBManagerState state) => switch (state) {
      cb.CBManagerState.unknown => BmAdapterStateEnum.unknown,
      cb.CBManagerState.resetting => BmAdapterStateEnum.turningOn,
      cb.CBManagerState.unsupported => BmAdapterStateEnum.unavailable,
      cb.CBManagerState.unauthorized => BmAdapterStateEnum.unauthorized,
      cb.CBManagerState.poweredOff => BmAdapterStateEnum.off,
      cb.CBManagerState.poweredOn => BmAdapterStateEnum.on,
    };

String _stateName(cb.CBManagerState state) => 'CBManagerState${switch (state) {
      cb.CBManagerState.poweredOn => 'PoweredOn',
      cb.CBManagerState.poweredOff => 'PoweredOff',
      cb.CBManagerState.unknown => 'Unknown',
      cb.CBManagerState.resetting => 'Resetting',
      cb.CBManagerState.unsupported => 'Unsupported',
      cb.CBManagerState.unauthorized => 'Unauthorized',
    }}';

Uint8List _intBytes(int value) => (ByteData(4)..setInt32(0, value, Endian.little)).buffer.asUint8List();

Uint8List _descriptorBytes(Object? value) => switch (value) {
      String() => Uint8List.fromList(utf8.encode(value)),
      num() => _intBytes(value.toInt()),
      Uint8List() => Uint8List.fromList(value),
      List<int>() => Uint8List.fromList(value),
      _ => Uint8List(0),
    };

cb.CBService? _primaryService(cb.CBPeripheral peripheral, cb.CBCharacteristic characteristic) {
  final service = characteristic.service;
  if (service == null || service.isPrimary) return null;
  for (final primary in peripheral.services ?? <cb.CBService>[]) {
    for (final included in primary.includedServices ?? <cb.CBService>[]) {
      if (identical(included, service) || included.uuid == service.uuid) return primary;
    }
  }
  return null;
}

List<cb.CBService> _matchingServices(cb.CBPeripheral peripheral, Guid? primary, Guid service) {
  final services = peripheral.services ?? <cb.CBService>[];
  if (primary == null) return services.where((s) => _guid(s.uuid) == service).toList();
  return [
    for (final s in services)
      if (_guid(s.uuid) == primary)
        for (final included in s.includedServices ?? <cb.CBService>[])
          if (_guid(included.uuid) == service) included
  ];
}

int _instanceId(cb.CBPeripheral peripheral, cb.CBCharacteristic characteristic) {
  final service = characteristic.service!;
  final primary = _primaryService(peripheral, characteristic);
  final matches = _matchingServices(peripheral, primary == null ? null : _guid(primary.uuid), _guid(service.uuid));
  final candidates = matches.length <= 1
      ? (service.characteristics ?? <cb.CBCharacteristic>[]).where((c) => c.uuid == characteristic.uuid)
      : matches.expand((s) => s.characteristics ?? <cb.CBCharacteristic>[]);
  return math.max(0, candidates.toList().indexOf(characteristic));
}

BmCharacteristicProperties _properties(cb.CBCharacteristicProperties flags) => BmCharacteristicProperties(
      broadcast: flags.contains(cb.CBCharacteristicProperties.broadcast),
      read: flags.contains(cb.CBCharacteristicProperties.read),
      writeWithoutResponse: flags.contains(cb.CBCharacteristicProperties.writeWithoutResponse),
      write: flags.contains(cb.CBCharacteristicProperties.write),
      notify: flags.contains(cb.CBCharacteristicProperties.notify),
      indicate: flags.contains(cb.CBCharacteristicProperties.indicate),
      authenticatedSignedWrites: flags.contains(cb.CBCharacteristicProperties.authenticatedSignedWrites),
      extendedProperties: flags.contains(cb.CBCharacteristicProperties.extendedProperties),
      notifyEncryptionRequired: flags.contains(cb.CBCharacteristicProperties.notifyEncryptionRequired),
      indicateEncryptionRequired: flags.contains(cb.CBCharacteristicProperties.indicateEncryptionRequired),
    );

BmBluetoothCharacteristic _characteristicModel(cb.CBPeripheral peripheral, cb.CBCharacteristic characteristic) {
  final identity = _CharacteristicIdentity.fromNative(peripheral, characteristic);
  return BmBluetoothCharacteristic(
    remoteId: identity.remoteId,
    primaryServiceUuid: identity.primaryServiceUuid,
    serviceUuid: identity.serviceUuid,
    characteristicUuid: identity.characteristicUuid,
    instanceId: identity.instanceId,
    descriptors: [
      for (final descriptor in characteristic.descriptors ?? <cb.CBDescriptor>[])
        identity.descriptor(_guid(descriptor.uuid))
    ],
    properties: _properties(characteristic.properties),
  );
}

BmBluetoothService _serviceModel(cb.CBPeripheral peripheral, cb.CBService service) => BmBluetoothService(
      remoteId: DeviceIdentifier(_remoteId(peripheral)),
      primaryServiceUuid: null,
      serviceUuid: _guid(service.uuid),
      characteristics: [
        for (final c in service.characteristics ?? <cb.CBCharacteristic>[]) _characteristicModel(peripheral, c)
      ],
    );
