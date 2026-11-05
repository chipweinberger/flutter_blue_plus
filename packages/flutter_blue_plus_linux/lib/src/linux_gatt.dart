part of '../flutter_blue_plus_linux.dart';

base mixin _GattOperations on _LinuxBackend {
  @override
  Future<bool> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) async {
    await _initFlutterBluePlus();

    final device = _client.devices.singleWhere(
      (device) {
        return device.remoteId == request.remoteId;
      },
    );

    final found = _findCharacteristic(
      device,
      request.serviceUuid,
      request.characteristicUuid,
      request.instanceId,
    );
    final characteristic = found.characteristic;

    if (request.enable) {
      await characteristic.startNotify();
    } else {
      await characteristic.stopNotify();
    }

    // No CCCD write on Linux; no separate response event expected
    return false;
  }

  @override
  Future<bool> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final found = _findCharacteristic(
        device,
        request.serviceUuid,
        request.characteristicUuid,
        request.instanceId,
      );
      final service = found.service;
      final characteristic = found.characteristic;

      final value = await characteristic.readValue();

      _onCharacteristicReceivedController.add(
        BmCharacteristicData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          instanceId: _instanceId(device, service, characteristic),
          value: value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onCharacteristicReceivedController.add(
        BmCharacteristicData(
          remoteId: request.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          value: [],
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }

  @override
  Future<bool> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final found = _findCharacteristic(
        device,
        request.serviceUuid,
        request.characteristicUuid,
        request.instanceId,
      );
      final service = found.service;
      final characteristic = found.characteristic;

      await characteristic.writeValue(
        request.value,
        type: request.writeType == BmWriteType.withResponse
            ? BlueZGattCharacteristicWriteType.request
            : BlueZGattCharacteristicWriteType.command,
      );

      _onCharacteristicWrittenController.add(
        BmCharacteristicData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          instanceId: _instanceId(device, service, characteristic),
          value: request.value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onCharacteristicWrittenController.add(
        BmCharacteristicData(
          remoteId: request.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          value: request.value,
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }

  @override
  Future<bool> readDescriptor(
    BmReadDescriptorRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final found = _findCharacteristic(
        device,
        request.serviceUuid,
        request.characteristicUuid,
        request.instanceId,
      );
      final service = found.service;
      final characteristic = found.characteristic;

      final descriptor = characteristic.descriptors.singleWhere(
        (descriptor) {
          final uuid = Guid.fromBytes(
            descriptor.uuid.value,
          );

          return uuid == request.descriptorUuid;
        },
      );

      final value = await descriptor.readValue();

      _onDescriptorReadController.add(
        BmDescriptorData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          instanceId: _instanceId(device, service, characteristic),
          descriptorUuid: Guid.fromBytes(
            descriptor.uuid.value,
          ),
          value: value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onDescriptorReadController.add(
        BmDescriptorData(
          remoteId: request.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          descriptorUuid: request.descriptorUuid,
          value: [],
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }

  @override
  Future<bool> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) async {
    try {
      await _initFlutterBluePlus();

      final device = _client.devices.singleWhere(
        (device) {
          return device.remoteId == request.remoteId;
        },
      );

      final found = _findCharacteristic(
        device,
        request.serviceUuid,
        request.characteristicUuid,
        request.instanceId,
      );
      final service = found.service;
      final characteristic = found.characteristic;

      final descriptor = characteristic.descriptors.singleWhere(
        (descriptor) {
          final uuid = Guid.fromBytes(
            descriptor.uuid.value,
          );

          return uuid == request.descriptorUuid;
        },
      );

      await descriptor.writeValue(request.value);

      _onDescriptorWrittenController.add(
        BmDescriptorData(
          remoteId: device.remoteId,
          primaryServiceUuid: null,
          serviceUuid: Guid.fromBytes(
            service.uuid.value,
          ),
          characteristicUuid: Guid.fromBytes(
            characteristic.uuid.value,
          ),
          instanceId: _instanceId(device, service, characteristic),
          descriptorUuid: Guid.fromBytes(
            descriptor.uuid.value,
          ),
          value: request.value,
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      );

      return true;
    } catch (e) {
      _onDescriptorWrittenController.add(
        BmDescriptorData(
          remoteId: request.remoteId,
          primaryServiceUuid: null,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          descriptorUuid: request.descriptorUuid,
          value: request.value,
          success: false,
          errorCode: 0,
          errorString: e.toString(),
        ),
      );

      return false;
    }
  }
}
