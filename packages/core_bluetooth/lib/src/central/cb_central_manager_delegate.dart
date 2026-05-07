part of '../core_bluetooth.dart';

base class CBCentralManagerDelegate {
  const CBCentralManagerDelegate();

  void centralManagerConnectionEventDidOccur(
    CBCentralManager central,
    CBConnectionEvent connectionEvent,
    CBPeripheral peripheral,
  ) {}

  void centralManagerDidConnect(CBCentralManager central, CBPeripheral peripheral) {}

  void centralManagerDidDisconnectPeripheral(
    CBCentralManager central,
    CBPeripheral peripheral,
    CBError? error, {
    double? timestamp,
    bool? isReconnecting,
  }) {}

  void centralManagerDidDiscover(
    CBCentralManager central,
    CBPeripheral peripheral,
    AdvertisementData advertisementData,
    int? rssi,
  ) {}

  void centralManagerDidFailToConnect(
    CBCentralManager central,
    CBPeripheral peripheral,
    CBError? error,
  ) {}

  void centralManagerDidUpdateANCSAuthorizationFor(CBCentralManager central, CBPeripheral peripheral) {}

  void centralManagerDidUpdateState(CBCentralManager central) {}

  void centralManagerWillRestoreState(CBCentralManager central, WillRestoreStateResult state) {}
}
