part of '../core_bluetooth.dart';

base class CBPeripheralManagerDelegate {
  const CBPeripheralManagerDelegate();

  void peripheralManagerDidAddService(
    CBPeripheralManager peripheral,
    CBMutableService service,
    CBError? error,
  ) {}

  void peripheralManagerDidStartAdvertising(
    CBPeripheralManager peripheral,
    CBError? error,
  ) {}

  void peripheralManagerDidReceiveRead(CBPeripheralManager peripheral, CBATTRequest request) {}

  void peripheralManagerDidReceiveWrite(CBPeripheralManager peripheral, List<CBATTRequest> requests) {}

  void peripheralManagerDidPublishL2CAPChannel(
    CBPeripheralManager peripheral,
    CBL2CAPPSM psm,
    CBError? error,
  ) {}

  void peripheralManagerDidSubscribeToCharacteristic(
    CBPeripheralManager peripheral,
    CBCentral central,
    CBMutableCharacteristic characteristic,
  ) {}

  void peripheralManagerDidUnsubscribeFromCharacteristic(
    CBPeripheralManager peripheral,
    CBCentral central,
    CBMutableCharacteristic characteristic,
  ) {}

  void peripheralManagerDidUnpublishL2CAPChannel(
    CBPeripheralManager peripheral,
    CBL2CAPPSM psm,
    CBError? error,
  ) {}

  void peripheralManagerDidUpdateState(CBPeripheralManager peripheral) {}

  void peripheralManagerDidOpen(
    CBPeripheralManager peripheral,
    CBL2CAPChannel? channel,
    CBError? error,
  ) {}

  void peripheralManagerIsReadyToUpdateSubscribers(CBPeripheralManager peripheral) {}

  void peripheralManagerWillRestoreState(
    CBPeripheralManager peripheral,
    PeripheralManagerWillRestoreStateResult state,
  ) {}
}
