part of flutter_blue_plus;

/// State of the bluetooth adapter.
enum BluetoothAdapterState { unknown, unavailable, unauthorized, turningOn, on, turningOff, off }

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

enum BluetoothConnectionState {
  disconnected,
  connected,
  // Deprecated: To be more precise, 'connecting' is only returned by getConnectionState (android)
  // or CBPeripheral.state (iOS), which FlutterBluePlus does not need.
  @Deprecated('Android & iOS dont stream this state. You can delete')
  connecting,
  // Deprecated: To be more precise, 'disconnecting' is only returned by getConnectionState (android)
  // or CBPeripheral.state (iOS), which FlutterBluePlus does not need.
  @Deprecated('Android & iOS dont stream this state. You can delete')
  disconnecting
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

class BluetoothBondState {
  final BondState current;
  final BondState? prev;
  BluetoothBondState({required this.current, required this.prev});
  @override
  String toString() {
    return 'BluetoothBondState{'
        'current: $current, '
        'prev: $prev, '
        '}';
  }
}

// [none] no bond
// [bonding] bonding is in progress
// [bonded] bond success
enum BondState { none, bonding, bonded }

BondState _bmToBondStateEnum(BmBondStateEnum value) {
  switch (value) {
    case BmBondStateEnum.none:
      return BondState.none;
    case BmBondStateEnum.bonding:
      return BondState.bonding;
    case BmBondStateEnum.bonded:
      return BondState.bonded;
  }
}

BluetoothBondState _bmToBluetoothBondState(BmBondStateResponse value) {
  return BluetoothBondState(
      current: _bmToBondStateEnum(value.bondState),
      prev: value.prevState != null ? _bmToBondStateEnum(value.prevState!) : null);
}

enum ConnectionPriority { balanced, high, lowPower }

enum Phy { le1m, le2m, leCoded }

enum PhyCoding { noPreferred, s2, s8 }

extension PhyExt on Phy {
  int get mask {
    switch (this) {
      case Phy.le1m:
        return 1;
      case Phy.le2m:
        return 2;
      case Phy.leCoded:
        return 3;
      default:
        return 1;
    }
  }
}

@Deprecated('Use PhyCoding instead')
enum PhyOption { noPreferred, s2, s8 }

@Deprecated('Use Phy instead')
enum PhyType { le1m, le2m, leCoded }

@Deprecated('Use BluetoothConnectionState instead')
enum BluetoothDeviceState { disconnected, connecting, connected, disconnecting }

@Deprecated('Use BluetoothAdapterState instead')
enum BluetoothState { unknown, unavailable, unauthorized, turningOn, on, turningOff, off }
