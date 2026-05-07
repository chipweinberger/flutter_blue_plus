part of '../core_bluetooth.dart';

final class CBDescriptor extends CBAttribute {
  CBDescriptor({
    required this.handle,
    required CBCharacteristic? characteristic,
    required super.uuid,
    required Object? value,
  })  : _characteristic = characteristic,
        _value = value;

  String handle;
  CBCharacteristic? _characteristic;
  Object? _value;

  CBCharacteristic? get characteristic => _characteristic;
  Object? get value => _value;

  void _updateCharacteristic(CBCharacteristic? characteristic) {
    _characteristic = characteristic;
  }

  void updateValue(Object? value) {
    _value = value;
  }

  factory CBDescriptor.fromMap({
    required CBCharacteristic characteristic,
    required Map<Object?, Object?> map,
  }) {
    return CBDescriptor(
      handle: map['handle'] as String? ?? '',
      characteristic: characteristic,
      uuid: CBUUID(map['uuid'] as String? ?? ''),
      value: map['value'],
    );
  }
}

final class CBMutableDescriptor extends CBDescriptor {
  CBMutableDescriptor({
    required super.handle,
    required super.characteristic,
    required super.uuid,
    required super.value,
    String? clientReference,
  }) : _clientReference = clientReference ?? _nextCoreBluetoothLocalReference();

  CBMutableDescriptor.type({
    required CBUUID type,
    super.value,
    super.characteristic,
    super.handle = '',
    String? clientReference,
  })  : _clientReference = clientReference ?? _nextCoreBluetoothLocalReference(),
        super(
          uuid: type,
        );

  final String _clientReference;

  set value(Object? value) {
    updateValue(value);
  }

  factory CBMutableDescriptor.fromMap(Map<Object?, Object?> map) {
    return CBMutableDescriptor(
      handle: map['handle'] as String? ?? '',
      characteristic: null,
      uuid: CBUUID(map['uuid'] as String? ?? ''),
      value: map['value'],
      clientReference: map['clientReference'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'clientReference': _clientReference,
      'handle': handle.isEmpty ? null : handle,
      'uuid': uuid.uuidString,
      'value': value,
    };
  }

  void _applyNativeState(CBMutableDescriptor nativeDescriptor) {
    handle = nativeDescriptor.handle;
    _value = nativeDescriptor.value;
  }
}
