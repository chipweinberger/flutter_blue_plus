part of '../core_bluetooth.dart';

final class CBService extends CBAttribute {
  CBService({
    required this.handle,
    required CBPeripheral? peripheral,
    required super.uuid,
    required bool isPrimary,
    required List<CBService>? includedServices,
    required List<CBCharacteristic>? characteristics,
  }) : _peripheral = peripheral {
    updateIncludedServices(includedServices);
    updateCharacteristics(characteristics);
    _isPrimary = isPrimary;
  }

  String handle;
  List<CBService>? _includedServices;
  List<CBCharacteristic>? _characteristics;
  bool _isPrimary = false;
  CBPeripheral? _peripheral;

  List<CBService>? get includedServices => _includedServices;
  List<CBCharacteristic>? get characteristics => _characteristics;
  bool get isPrimary => _isPrimary;
  CBPeripheral? get peripheral => _peripheral;

  void updateIncludedServices(List<CBService>? includedServices) {
    _includedServices = includedServices;
    for (final service in includedServices ?? const <CBService>[]) {
      service._updatePeripheral(_peripheral);
    }
  }

  void updateCharacteristics(List<CBCharacteristic>? characteristics) {
    _characteristics = characteristics;
    for (final characteristic in characteristics ?? const <CBCharacteristic>[]) {
      characteristic._updateService(this);
    }
  }

  void _updatePeripheral(CBPeripheral? peripheral) {
    _peripheral = peripheral;
    for (final service in _includedServices ?? const <CBService>[]) {
      service._updatePeripheral(peripheral);
    }
  }

  void _updateIsPrimary(bool isPrimary) {
    _isPrimary = isPrimary;
  }

  factory CBService.fromMap({
    required CBPeripheral peripheral,
    required Map<Object?, Object?> map,
  }) {
    return CBService(
      handle: map['handle'] as String? ?? '',
      peripheral: peripheral,
      uuid: CBUUID(map['uuid'] as String? ?? ''),
      isPrimary: map['isPrimary'] as bool? ?? false,
      includedServices: null,
      characteristics: null,
    );
  }
}

final class CBMutableService extends CBService {
  CBMutableService({
    required super.handle,
    required super.peripheral,
    required super.uuid,
    required super.isPrimary,
    required super.includedServices,
    required super.characteristics,
    String? clientReference,
  }) : _clientReference = clientReference ?? _nextCoreBluetoothLocalReference();

  CBMutableService.type({
    required CBUUID type,
    required bool primary,
    super.peripheral,
    super.handle = '',
    super.includedServices,
    super.characteristics,
    String? clientReference,
  })  : _clientReference = clientReference ?? _nextCoreBluetoothLocalReference(),
        super(
          uuid: type,
          isPrimary: primary,
        );

  final String _clientReference;

  set characteristics(List<CBCharacteristic>? characteristics) {
    updateCharacteristics(characteristics);
  }

  set includedServices(List<CBService>? includedServices) {
    updateIncludedServices(includedServices);
  }

  set isPrimary(bool isPrimary) {
    _updateIsPrimary(isPrimary);
  }

  factory CBMutableService.fromMap(Map<Object?, Object?> map) {
    return CBMutableService(
      handle: map['handle'] as String? ?? '',
      peripheral: null,
      uuid: CBUUID(map['uuid'] as String? ?? ''),
      isPrimary: map['isPrimary'] as bool? ?? false,
      includedServices: (map['includedServices'] as List<Object?>? ?? const [])
          .map((service) => CBMutableService.fromMap(Map<Object?, Object?>.from(service as Map)))
          .toList(),
      characteristics: (map['characteristics'] as List<Object?>? ?? const [])
          .map((characteristic) => CBMutableCharacteristic.fromMap(Map<Object?, Object?>.from(characteristic as Map)))
          .toList(),
      clientReference: map['clientReference'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'clientReference': _clientReference,
      'handle': handle.isEmpty ? null : handle,
      'uuid': uuid.uuidString,
      'isPrimary': isPrimary,
      'includedServices': includedServices?.whereType<CBMutableService>().map((service) => service.toMap()).toList(),
      'characteristics': characteristics
          ?.whereType<CBMutableCharacteristic>()
          .map((characteristic) => characteristic.toMap())
          .toList(),
    };
  }

  void _applyNativeState(CBMutableService nativeService) {
    handle = nativeService.handle;
    _updateIsPrimary(nativeService.isPrimary);
    final nativeIncludedServices = nativeService.includedServices?.whereType<CBMutableService>().toList();
    updateIncludedServices(_reconcileIncludedServices(nativeIncludedServices));

    final nativeCharacteristics = nativeService.characteristics?.whereType<CBMutableCharacteristic>().toList();
    updateCharacteristics(_reconcileCharacteristics(nativeCharacteristics));
  }

  List<CBMutableService>? _reconcileIncludedServices(List<CBMutableService>? nativeIncludedServices) {
    if (nativeIncludedServices == null) {
      return null;
    }

    final localIncludedServices = _includedServices?.whereType<CBMutableService>().toList() ?? const [];
    return nativeIncludedServices.map((nativeService) {
      final matches = localIncludedServices.where((localService) {
        if (localService._clientReference == nativeService._clientReference) {
          return true;
        }

        return localService.handle.isNotEmpty &&
            nativeService.handle.isNotEmpty &&
            localService.handle == nativeService.handle;
      });
      final localMatch = matches.isEmpty ? null : matches.first;

      if (localMatch == null) {
        return nativeService;
      }

      if (!identical(localMatch, nativeService)) {
        localMatch._applyNativeState(nativeService);
      }
      return localMatch;
    }).toList();
  }

  List<CBMutableCharacteristic>? _reconcileCharacteristics(List<CBMutableCharacteristic>? nativeCharacteristics) {
    if (nativeCharacteristics == null) {
      return null;
    }

    final localCharacteristics = _characteristics?.whereType<CBMutableCharacteristic>().toList() ?? const [];
    return nativeCharacteristics.map((nativeCharacteristic) {
      final matches = localCharacteristics.where((localCharacteristic) {
        if (localCharacteristic._clientReference == nativeCharacteristic._clientReference) {
          return true;
        }

        return localCharacteristic.handle.isNotEmpty &&
            nativeCharacteristic.handle.isNotEmpty &&
            localCharacteristic.handle == nativeCharacteristic.handle;
      });
      final localMatch = matches.isEmpty ? null : matches.first;

      if (localMatch == null) {
        return nativeCharacteristic;
      }

      if (!identical(localMatch, nativeCharacteristic)) {
        localMatch._applyNativeState(nativeCharacteristic);
      }
      return localMatch;
    }).toList();
  }
}
