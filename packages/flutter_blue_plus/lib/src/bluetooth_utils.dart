part of '../flutter_blue_plus.dart';

/// State of the bluetooth adapter.
enum BluetoothAdapterState { unknown, unavailable, unauthorized, turningOn, on, turningOff, off }

enum BluetoothConnectionState {
  disconnected,
  connected,
}

enum ConnectionPriority { balanced, high, lowPower }

enum Phy { le1m, le2m, leCoded }

enum PhyCoding { noPreferred, s2, s8 }

enum BluetoothBondState { none, bonding, bonded }

@Deprecated('Use PhyCoding instead')
enum PhyOption { noPreferred, s2, s8 }

@Deprecated('Use Phy instead')
enum PhyType { le1m, le2m, leCoded }

@Deprecated('Use BluetoothConnectionState instead')
enum BluetoothDeviceState { disconnected, connecting, connected, disconnecting }

@Deprecated('Use BluetoothAdapterState instead')
enum BluetoothState { unknown, unavailable, unauthorized, turningOn, on, turningOff, off }

extension PhyExt on Phy {
  int get mask {
    switch (this) {
      case Phy.le1m:
        return 1;
      case Phy.le2m:
        return 2;
      case Phy.leCoded:
        return 3;
    }
  }
}

class BluetoothConnectionEvent {
  BluetoothDevice device;
  BluetoothConnectionState connectionState;
  BluetoothConnectionEvent(this.device, this.connectionState);
}

class DisconnectReason {
  final ErrorPlatform platform;
  final int? code; // specific to platform
  final String? description;
  DisconnectReason(this.platform, this.code, this.description);
  @override
  String toString() {
    return 'DisconnectReason{'
        'platform: $platform, '
        'code: $code, '
        '$description'
        '}';
  }
}

BluetoothConnectionState _bmToConnectionState(BmConnectionStateEnum value) {
  switch (value) {
    case BmConnectionStateEnum.disconnected:
      return BluetoothConnectionState.disconnected;
    case BmConnectionStateEnum.connected:
      return BluetoothConnectionState.connected;
  }
}

BluetoothAdapterState _bmToAdapterState(BmAdapterStateEnum value) {
  switch (value) {
    case BmAdapterStateEnum.unknown:
      return BluetoothAdapterState.unknown;
    case BmAdapterStateEnum.unavailable:
      return BluetoothAdapterState.unavailable;
    case BmAdapterStateEnum.unauthorized:
      return BluetoothAdapterState.unauthorized;
    case BmAdapterStateEnum.turningOn:
      return BluetoothAdapterState.turningOn;
    case BmAdapterStateEnum.on:
      return BluetoothAdapterState.on;
    case BmAdapterStateEnum.turningOff:
      return BluetoothAdapterState.turningOff;
    case BmAdapterStateEnum.off:
      return BluetoothAdapterState.off;
  }
}

BmConnectionPriorityEnum _bmFromConnectionPriority(ConnectionPriority value) {
  switch (value) {
    case ConnectionPriority.balanced:
      return BmConnectionPriorityEnum.balanced;
    case ConnectionPriority.high:
      return BmConnectionPriorityEnum.high;
    case ConnectionPriority.lowPower:
      return BmConnectionPriorityEnum.lowPower;
  }
}

BluetoothBondState _bmToBondState(BmBondStateEnum value) {
  switch (value) {
    case BmBondStateEnum.none:
      return BluetoothBondState.none;
    case BmBondStateEnum.bonding:
      return BluetoothBondState.bonding;
    case BmBondStateEnum.bonded:
      return BluetoothBondState.bonded;
  }
}

bool _isBmServiceMatch(BmBluetoothService service, BluetoothCharacteristic characteristic) {
  return service.primaryServiceUuid == characteristic.primaryServiceUuid &&
      service.serviceUuid == characteristic.serviceUuid;
}

bool _isBmCharacteristicMatch(BmBluetoothCharacteristic bmCharacteristic, BluetoothCharacteristic characteristic) {
  return bmCharacteristic.characteristicUuid == characteristic.characteristicUuid &&
      bmCharacteristic.instanceId == characteristic.instanceId;
}

BmBluetoothCharacteristic? _findCharacteristic(
  BmDiscoverServicesResult? bmServices,
  BluetoothCharacteristic characteristic,
) {
  if (bmServices == null) return null;
  final services = bmServices.services.where(
    (s) => _isBmServiceMatch(s, characteristic),
  );
  for (var s in services) {
    for (var c in s.characteristics) {
      if (_isBmCharacteristicMatch(c, characteristic)) {
        return c;
      }
    }
  }
  return null;
}

List<BluetoothService> _findIncludedServices(BmDiscoverServicesResult? bmServices, Guid serviceUuid) {
  return bmServices?.services
          .where((s) => s.primaryServiceUuid == serviceUuid)
          .map((s) => BluetoothService.fromProto(s))
          .toList() ??
      [];
}

BluetoothService? _findPrimaryService(BmDiscoverServicesResult? bmServices, Guid? primaryServiceUuid) {
  if (primaryServiceUuid == null) return null;
  final service = bmServices?.services._firstWhereOrNull(
    (s) => s.serviceUuid == primaryServiceUuid,
  );
  return service != null ? BluetoothService.fromProto(service) : null;
}


