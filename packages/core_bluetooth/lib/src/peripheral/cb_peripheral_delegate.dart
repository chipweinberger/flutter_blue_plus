part of '../core_bluetooth.dart';

base class CBPeripheralDelegate {
  const CBPeripheralDelegate();

  void peripheralDidDiscoverCharacteristicsForService(
    CBPeripheral peripheral,
    CBService service,
    List<CBCharacteristic>? characteristics,
    CBError? error,
  ) {}

  void peripheralDidDiscoverDescriptorsForCharacteristic(
    CBPeripheral peripheral,
    CBCharacteristic characteristic,
    List<CBDescriptor>? descriptors,
    CBError? error,
  ) {}

  void peripheralDidDiscoverIncludedServicesForService(
    CBPeripheral peripheral,
    CBService service,
    List<CBService>? includedServices,
    CBError? error,
  ) {}

  void peripheralDidDiscoverServices(
    CBPeripheral peripheral,
    List<CBService>? services,
    CBError? error,
  ) {}

  void peripheralDidModifyServices(
    CBPeripheral peripheral,
    List<CBService> invalidatedServices,
  ) {}

  void peripheralDidReadRSSI(
    CBPeripheral peripheral,
    int? rssi,
    CBError? error,
  ) {}

  void peripheralDidUpdateName(CBPeripheral peripheral) {}

  void peripheralDidUpdateNotificationStateForCharacteristic(
    CBPeripheral peripheral,
    CBCharacteristic characteristic,
    CBError? error,
  ) {}

  void peripheralDidUpdateValueForCharacteristic(
    CBPeripheral peripheral,
    CBCharacteristic characteristic,
    CBError? error,
  ) {}

  void peripheralDidUpdateValueForDescriptor(
    CBPeripheral peripheral,
    CBDescriptor descriptor,
    CBError? error,
  ) {}

  void peripheralDidWriteValueForCharacteristic(
    CBPeripheral peripheral,
    CBCharacteristic characteristic,
    CBError? error,
  ) {}

  void peripheralDidWriteValueForDescriptor(
    CBPeripheral peripheral,
    CBDescriptor descriptor,
    CBError? error,
  ) {}

  void peripheralDidOpen(
    CBPeripheral peripheral,
    CBL2CAPChannel? channel,
    CBError? error,
  ) {}

  void peripheralIsReadyToSendWriteWithoutResponse(CBPeripheral peripheral) {}
}
