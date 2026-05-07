part of '../core_bluetooth.dart';

final class DidUpdateNameResult {
  const DidUpdateNameResult({
    required this.peripheral,
  });

  final CBPeripheral peripheral;
}

final class DidModifyServicesResult {
  const DidModifyServicesResult({
    required this.peripheral,
    required this.invalidatedServices,
  });

  final List<CBService> invalidatedServices;
  final CBPeripheral peripheral;
}

final class DidDiscoverServicesResult {
  const DidDiscoverServicesResult({
    required this.peripheral,
    required this.services,
    required this.error,
  });

  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
  final List<CBService>? services;
}

final class DidDiscoverIncludedServicesForServiceResult {
  const DidDiscoverIncludedServicesForServiceResult({
    required this.peripheral,
    required this.service,
    required this.includedServices,
    required this.error,
  });

  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final List<CBService>? includedServices;
  final CBPeripheral peripheral;
  final CBService service;
}

final class DidDiscoverCharacteristicsForServiceResult {
  const DidDiscoverCharacteristicsForServiceResult({
    required this.peripheral,
    required this.service,
    required this.characteristics,
    required this.error,
  });

  final List<CBCharacteristic>? characteristics;
  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
  final CBService service;
}

final class DidDiscoverDescriptorsForCharacteristicResult {
  const DidDiscoverDescriptorsForCharacteristicResult({
    required this.peripheral,
    required this.characteristic,
    required this.descriptors,
    required this.error,
  });

  final CBCharacteristic characteristic;
  final List<CBDescriptor>? descriptors;
  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
}

final class DidUpdateValueForCharacteristicResult {
  const DidUpdateValueForCharacteristicResult({
    required this.peripheral,
    required this.characteristic,
    required this.error,
  });

  final CBCharacteristic characteristic;
  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
}

final class DidWriteValueForCharacteristicResult {
  const DidWriteValueForCharacteristicResult({
    required this.peripheral,
    required this.characteristic,
    required this.error,
  });

  final CBCharacteristic characteristic;
  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
}

final class DidUpdateNotificationStateForCharacteristicResult {
  const DidUpdateNotificationStateForCharacteristicResult({
    required this.peripheral,
    required this.characteristic,
    required this.error,
  });

  final CBCharacteristic characteristic;
  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
}

final class DidReadRssiResult {
  const DidReadRssiResult({
    required this.peripheral,
    required this.rssi,
    required this.error,
  });

  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
  final int? rssi;
}

final class IsReadyToSendWriteWithoutResponseResult {
  const IsReadyToSendWriteWithoutResponseResult({
    required this.peripheral,
  });

  final CBPeripheral peripheral;
}

final class DidUpdateValueForDescriptorResult {
  const DidUpdateValueForDescriptorResult({
    required this.peripheral,
    required this.descriptor,
    required this.error,
  });

  final CBDescriptor descriptor;
  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
}

final class DidWriteValueForDescriptorResult {
  const DidWriteValueForDescriptorResult({
    required this.peripheral,
    required this.descriptor,
    required this.error,
  });

  final CBDescriptor descriptor;
  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
}

final class DidUpdateANCSAuthorizationForPeripheralResult {
  const DidUpdateANCSAuthorizationForPeripheralResult({
    required this.peripheral,
  });

  final CBPeripheral peripheral;
}

final class DidOpenL2CAPChannelResult {
  const DidOpenL2CAPChannelResult({
    required this.peripheral,
    required this.channel,
    required this.error,
  });

  final CBL2CAPChannel? channel;
  final CBError? error;
  String? get errorDescription => error?.localizedDescription;
  final CBPeripheral peripheral;
}

final class CBPeripheral extends CBPeer {
  CBPeripheral._({
    required CBCentralManager manager,
    required super.identifier,
  }) : _manager = manager;

  final CBCentralManager _manager;
  CBPeripheralDelegate? delegate;

  String? _name;
  bool _ancsAuthorized = false;
  bool _canSendWriteWithoutResponse = true;
  CBPeripheralState _state = CBPeripheralState.disconnected;
  List<CBService>? _services;

  bool get ancsAuthorized => _ancsAuthorized;
  bool get canSendWriteWithoutResponse => _canSendWriteWithoutResponse;
  String? get name => _name;
  List<CBService>? get services => _services;
  CBPeripheralState get state => _state;

  final _didDiscoverServicesController = StreamController<DidDiscoverServicesResult>.broadcast();
  final _didUpdateNameController = StreamController<DidUpdateNameResult>.broadcast();
  final _didModifyServicesController = StreamController<DidModifyServicesResult>.broadcast();
  final _didDiscoverIncludedServicesForServiceController =
      StreamController<DidDiscoverIncludedServicesForServiceResult>.broadcast();
  final _didDiscoverCharacteristicsForServiceController =
      StreamController<DidDiscoverCharacteristicsForServiceResult>.broadcast();
  final _didDiscoverDescriptorsForCharacteristicController =
      StreamController<DidDiscoverDescriptorsForCharacteristicResult>.broadcast();
  final _didUpdateValueForCharacteristicController =
      StreamController<DidUpdateValueForCharacteristicResult>.broadcast();
  final _didWriteValueForCharacteristicController = StreamController<DidWriteValueForCharacteristicResult>.broadcast();
  final _didUpdateNotificationStateForCharacteristicController =
      StreamController<DidUpdateNotificationStateForCharacteristicResult>.broadcast();
  final _didReadRSSIController = StreamController<DidReadRssiResult>.broadcast();
  final _isReadyToSendWriteWithoutResponseController =
      StreamController<IsReadyToSendWriteWithoutResponseResult>.broadcast();
  final _didUpdateValueForDescriptorController = StreamController<DidUpdateValueForDescriptorResult>.broadcast();
  final _didWriteValueForDescriptorController = StreamController<DidWriteValueForDescriptorResult>.broadcast();
  final _didUpdateANCSAuthorizationController =
      StreamController<DidUpdateANCSAuthorizationForPeripheralResult>.broadcast();
  final _didOpenL2CAPChannelController = StreamController<DidOpenL2CAPChannelResult>.broadcast();

  Stream<DidDiscoverServicesResult> get onDidDiscoverServices => _didDiscoverServicesController.stream;
  Stream<DidUpdateNameResult> get onDidUpdateName => _didUpdateNameController.stream;
  Stream<DidModifyServicesResult> get onDidModifyServices => _didModifyServicesController.stream;

  Stream<DidDiscoverIncludedServicesForServiceResult> get onDidDiscoverIncludedServicesForService {
    return _didDiscoverIncludedServicesForServiceController.stream;
  }

  Stream<DidDiscoverCharacteristicsForServiceResult> get onDidDiscoverCharacteristicsForService {
    return _didDiscoverCharacteristicsForServiceController.stream;
  }

  Stream<DidDiscoverDescriptorsForCharacteristicResult> get onDidDiscoverDescriptorsForCharacteristic {
    return _didDiscoverDescriptorsForCharacteristicController.stream;
  }

  Stream<DidUpdateValueForCharacteristicResult> get onDidUpdateValueForCharacteristic {
    return _didUpdateValueForCharacteristicController.stream;
  }

  Stream<DidWriteValueForCharacteristicResult> get onDidWriteValueForCharacteristic {
    return _didWriteValueForCharacteristicController.stream;
  }

  Stream<DidUpdateNotificationStateForCharacteristicResult> get onDidUpdateNotificationStateForCharacteristic {
    return _didUpdateNotificationStateForCharacteristicController.stream;
  }

  Stream<DidReadRssiResult> get onDidReadRSSI => _didReadRSSIController.stream;

  Stream<IsReadyToSendWriteWithoutResponseResult> get onPeripheralIsReadyToSendWriteWithoutResponse {
    return _isReadyToSendWriteWithoutResponseController.stream;
  }

  Stream<DidUpdateValueForDescriptorResult> get onDidUpdateValueForDescriptor {
    return _didUpdateValueForDescriptorController.stream;
  }

  Stream<DidWriteValueForDescriptorResult> get onDidWriteValueForDescriptor {
    return _didWriteValueForDescriptorController.stream;
  }

  Stream<DidUpdateANCSAuthorizationForPeripheralResult> get onDidUpdateANCSAuthorizationForPeripheral {
    return _didUpdateANCSAuthorizationController.stream;
  }

  Stream<DidOpenL2CAPChannelResult> get onDidOpenL2CAPChannel {
    return _didOpenL2CAPChannelController.stream;
  }

  Future<void> discoverCharacteristics({
    required CBService forService,
    List<CBUUID>? characteristicUUIDs,
  }) {
    return _manager._host.invokeMethod<void>(
      'peripheral.discoverCharacteristics',
      {
        'managerId': _manager._identifier,
        'peripheralIdentifier': identifier.uuidString,
        'serviceHandle': forService.handle,
        'characteristicUUIDs': characteristicUUIDs?.map((uuid) => uuid.uuidString).toList(),
      },
    );
  }

  Future<void> discoverDescriptors(CBCharacteristic characteristic) {
    return _manager._host.invokeMethod<void>(
      'peripheral.discoverDescriptors',
      {
        'managerId': _manager._identifier,
        'peripheralIdentifier': identifier.uuidString,
        'characteristicHandle': characteristic.handle,
      },
    );
  }

  Future<void> discoverIncludedServices(
    List<CBUUID>? includedServiceUUIDs, {
    required CBService forService,
  }) {
    return _manager._host.invokeMethod<void>(
      'peripheral.discoverIncludedServices',
      {
        'managerId': _manager._identifier,
        'peripheralIdentifier': identifier.uuidString,
        'serviceHandle': forService.handle,
        'includedServiceUUIDs': includedServiceUUIDs?.map((uuid) => uuid.uuidString).toList(),
      },
    );
  }

  Future<void> discoverServices([List<CBUUID>? serviceUUIDs]) {
    return _manager._host.invokeMethod<void>(
      'peripheral.discoverServices',
      {
        'managerId': _manager._identifier,
        'peripheralIdentifier': identifier.uuidString,
        'serviceUUIDs': serviceUUIDs?.map((uuid) => uuid.uuidString).toList(),
      },
    );
  }

  Future<void> readRSSI() {
    return _manager._host.invokeMethod<void>(
      'peripheral.readRSSI',
      {
        'managerId': _manager._identifier,
        'peripheralIdentifier': identifier.uuidString,
      },
    );
  }

  Future<void> openL2CAPChannel(CBL2CAPPSM psm) {
    return _manager._host.invokeMethod<void>(
      'peripheral.openL2CAPChannel',
      {
        'managerId': _manager._identifier,
        'peripheralIdentifier': identifier.uuidString,
        'psm': psm,
      },
    );
  }

  Future<void> readValue(Object forAttribute) {
    if (forAttribute case final CBCharacteristic characteristic) {
      return _manager._host.invokeMethod<void>(
        'peripheral.readValueForCharacteristic',
        {
          'managerId': _manager._identifier,
          'peripheralIdentifier': identifier.uuidString,
          'characteristicHandle': characteristic.handle,
        },
      );
    }

    if (forAttribute case final CBDescriptor descriptor) {
      return _manager._host.invokeMethod<void>(
        'peripheral.readValueForDescriptor',
        {
          'managerId': _manager._identifier,
          'peripheralIdentifier': identifier.uuidString,
          'descriptorHandle': descriptor.handle,
        },
      );
    }

    throw ArgumentError.value(
      forAttribute,
      'forAttribute',
      'Expected a CBCharacteristic or CBDescriptor.',
    );
  }

  Future<void> setNotifyValue(bool enabled, CBCharacteristic forCharacteristic) {
    return _manager._host.invokeMethod<void>(
      'peripheral.setNotifyValue',
      {
        'managerId': _manager._identifier,
        'peripheralIdentifier': identifier.uuidString,
        'characteristicHandle': forCharacteristic.handle,
        'enabled': enabled,
      },
    );
  }

  Future<void> writeValue(
    Uint8List data, {
    required Object forAttribute,
    CBCharacteristicWriteType? type,
  }) {
    if (forAttribute case final CBCharacteristic characteristic) {
      final writeType = type;
      if (writeType == null) {
        throw ArgumentError.value(
          type,
          'type',
          'A CBCharacteristicWriteType is required when writing to a CBCharacteristic.',
        );
      }

      return _manager._host.invokeMethod<void>(
        'peripheral.writeValueForCharacteristic',
        {
          'managerId': _manager._identifier,
          'peripheralIdentifier': identifier.uuidString,
          'characteristicHandle': characteristic.handle,
          'value': data,
          'type': writeType.rawValue,
        },
      );
    }

    if (forAttribute case final CBDescriptor descriptor) {
      if (type != null) {
        throw ArgumentError.value(
          type,
          'type',
          'CBDescriptor writes do not accept a CBCharacteristicWriteType.',
        );
      }

      return _manager._host.invokeMethod<void>(
        'peripheral.writeValueForDescriptor',
        {
          'managerId': _manager._identifier,
          'peripheralIdentifier': identifier.uuidString,
          'descriptorHandle': descriptor.handle,
          'value': data,
        },
      );
    }

    throw ArgumentError.value(
      forAttribute,
      'forAttribute',
      'Expected a CBCharacteristic or CBDescriptor.',
    );
  }

  Future<int> maximumWriteValueLength(CBCharacteristicWriteType type) async {
    return await _manager._host.invokeMethod<int>(
          'peripheral.maximumWriteValueLength',
          {
            'managerId': _manager._identifier,
            'peripheralIdentifier': identifier.uuidString,
            'type': type.rawValue,
          },
        ) ??
        0;
  }

  CBCharacteristic? _findCharacteristicByHandle(String? handle) {
    if (handle == null) {
      return null;
    }

    for (final service in _services ?? const <CBService>[]) {
      for (final characteristic in service.characteristics ?? const <CBCharacteristic>[]) {
        if (characteristic.handle == handle) {
          return characteristic;
        }
      }
    }

    return null;
  }

  CBDescriptor? _findDescriptorByHandle(String? handle) {
    if (handle == null) {
      return null;
    }

    for (final service in _services ?? const <CBService>[]) {
      for (final characteristic in service.characteristics ?? const <CBCharacteristic>[]) {
        for (final descriptor in characteristic.descriptors ?? const <CBDescriptor>[]) {
          if (descriptor.handle == handle) {
            return descriptor;
          }
        }
      }
    }

    return null;
  }

  CBService? _findServiceByHandle(String? handle) {
    if (handle == null) {
      return null;
    }

    for (final service in _services ?? const <CBService>[]) {
      if (service.handle == handle) {
        return service;
      }
    }

    return null;
  }
}
