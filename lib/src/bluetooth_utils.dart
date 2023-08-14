part of flutter_blue_plus;

enum BluetoothDeviceType { unknown, classic, le, dual }

BluetoothDeviceType _bmToBluetoothDeviceType(BmBluetoothSpecEnum value) {
  switch (value) {
    case BmBluetoothSpecEnum.unknown:
      return BluetoothDeviceType.unknown;
    case BmBluetoothSpecEnum.classic:
      return BluetoothDeviceType.classic;
    case BmBluetoothSpecEnum.le:
      return BluetoothDeviceType.le;
    case BmBluetoothSpecEnum.dual:
      return BluetoothDeviceType.dual;
  }
}

class DisconnectReason {
  final ErrorPlatform platform;
  final int? code; // specific to platform
  final String? description;
  DisconnectReason(this.platform, this.code, this.description);
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

BluetoothConnectionState _bmToBluetoothConnectionState(BmConnectionStateEnum value) {
  switch (value) {
    case BmConnectionStateEnum.disconnected:
      return BluetoothConnectionState.disconnected;
    case BmConnectionStateEnum.connected:
      return BluetoothConnectionState.connected;
  }
}

BluetoothAdapterState _bmToBluetoothAdapterState(BmAdapterStateEnum value) {
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

BmConnectionPriorityEnum _bmConnectionPriorityEnum(ConnectionPriority value) {
  switch (value) {
    case ConnectionPriority.balanced:
      return BmConnectionPriorityEnum.balanced;
    case ConnectionPriority.high:
      return BmConnectionPriorityEnum.high;
    case ConnectionPriority.lowPower:
      return BmConnectionPriorityEnum.lowPower;
  }
}

BluetoothBondState _bmToBluetoothBondState(BmBondStateResponse value) {
  switch (value.bondState) {
    case BmBondStateEnum.none:
      if (value.bondFailed) {
        return BluetoothBondState.failed;
      }
      if (value.bondLost) {
        return BluetoothBondState.lost;
      }
      return BluetoothBondState.none;
    case BmBondStateEnum.bonding:
      return BluetoothBondState.bonding;
    case BmBondStateEnum.bonded:
      return BluetoothBondState.bonded;
  }
}

// [none] no bond
// [bonding] bonding is underway
// [bonded] bond success
// [failed] a bonding attempt failed
// [lost] a previous bond was deleted (you should reconnect to force a rebond)
enum BluetoothBondState { none, bonding, bonded, failed, lost }

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
