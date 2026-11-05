part of '../flutter_blue_plus_linux.dart';

extension on BlueZDevice {
  DeviceIdentifier get remoteId {
    return DeviceIdentifier(address);
  }
}

extension on BlueZGattCharacteristic {
  int localInstanceId(BlueZGattService service) {
    final target = Guid.fromBytes(uuid.value);
    var idx = 0;
    for (final c in service.characteristics) {
      if (Guid.fromBytes(c.uuid.value) == target) {
        // BlueZ recreates wrappers; streams for the same cached object compare equal.
        if (c.propertiesChanged == propertiesChanged) return idx;
        idx++;
      }
    }
    return 0;
  }
}

extension on BlueZGattService {
  Guid get guid {
    return Guid.fromBytes(uuid.value);
  }
}

List<BlueZGattService> _matchingServices(BlueZDevice device, Guid serviceUuid) {
  return device.gattServices.where((service) => service.guid == serviceUuid).toList();
}

int _instanceId(BlueZDevice device, BlueZGattService service, BlueZGattCharacteristic target) {
  final services = _matchingServices(device, service.guid);
  if (services.length <= 1) {
    return target.localInstanceId(service);
  }

  var idx = 0;
  for (final candidateService in services) {
    for (final characteristic in candidateService.characteristics) {
      if (characteristic.propertiesChanged == target.propertiesChanged) {
        return idx;
      }
      idx++;
    }
  }

  return 0;
}

_LinuxFoundCharacteristic _findCharacteristic(
  BlueZDevice device,
  Guid serviceUuid,
  Guid characteristicUuid,
  int instanceId,
) {
  final services = _matchingServices(device, serviceUuid);
  if (services.isEmpty) {
    throw StateError('service not found: $serviceUuid');
  }

  if (services.length <= 1) {
    final service = services.single;
    final characteristic = service.characteristics.singleWhere((characteristic) {
      final uuid = Guid.fromBytes(characteristic.uuid.value);
      return uuid == characteristicUuid && characteristic.localInstanceId(service) == instanceId;
    });
    return _LinuxFoundCharacteristic(service: service, characteristic: characteristic);
  }

  var idx = 0;
  for (final service in services) {
    for (final characteristic in service.characteristics) {
      final uuid = Guid.fromBytes(characteristic.uuid.value);
      if (idx == instanceId && uuid == characteristicUuid) {
        return _LinuxFoundCharacteristic(service: service, characteristic: characteristic);
      }
      idx++;
    }
  }

  throw StateError('characteristic not found: $characteristicUuid/$instanceId');
}

BmDiscoverServicesResult _discoveryResult(BlueZDevice device) {
  return BmDiscoverServicesResult(
    remoteId: device.remoteId,
    services: device.gattServices.map(
      (service) {
        return BmBluetoothService(
          primaryServiceUuid: null,
          serviceUuid: Guid.fromBytes(service.uuid.value),
          remoteId: device.remoteId,
          characteristics: service.characteristics.map(
            (characteristic) {
              return BmBluetoothCharacteristic(
                remoteId: device.remoteId,
                primaryServiceUuid: null,
                serviceUuid: Guid.fromBytes(service.uuid.value),
                characteristicUuid: Guid.fromBytes(characteristic.uuid.value),
                instanceId: _instanceId(device, service, characteristic),
                descriptors: characteristic.descriptors.map(
                  (descriptor) {
                    return BmBluetoothDescriptor(
                      remoteId: device.remoteId,
                      primaryServiceUuid: null,
                      serviceUuid: Guid.fromBytes(service.uuid.value),
                      characteristicUuid: Guid.fromBytes(characteristic.uuid.value),
                      instanceId: _instanceId(device, service, characteristic),
                      descriptorUuid: Guid.fromBytes(descriptor.uuid.value),
                    );
                  },
                ).toList(),
                properties: BmCharacteristicProperties(
                  broadcast: characteristic.flags.contains(BlueZGattCharacteristicFlag.broadcast),
                  read: characteristic.flags.contains(BlueZGattCharacteristicFlag.read),
                  writeWithoutResponse: characteristic.flags.contains(BlueZGattCharacteristicFlag.writeWithoutResponse),
                  write: characteristic.flags.contains(BlueZGattCharacteristicFlag.write),
                  notify: characteristic.flags.contains(BlueZGattCharacteristicFlag.notify),
                  indicate: characteristic.flags.contains(BlueZGattCharacteristicFlag.indicate),
                  authenticatedSignedWrites:
                      characteristic.flags.contains(BlueZGattCharacteristicFlag.authenticatedSignedWrites),
                  extendedProperties: characteristic.flags.contains(BlueZGattCharacteristicFlag.extendedProperties),
                  notifyEncryptionRequired: false,
                  indicateEncryptionRequired: false,
                ),
              );
            },
          ).toList(),
        );
      },
    ).toList(),
    success: true,
    errorCode: 0,
    errorString: '',
  );
}
