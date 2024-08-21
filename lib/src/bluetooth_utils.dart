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

class BluetoothConnectionEvent {
  BluetoothDevice device;
  BluetoothConnectionState connectionState;
  BluetoothConnectionEvent(this.device, this.connectionState);
}

enum BluetoothConnectionState {
  disconnected,
  connected,
  // Deprecated: To be more precise, 'connecting' is only returned by getConnectionState (android)
  // or CBPeripheral.state (iOS), which FlutterBluePlus does not use. FBP only uses the OS callbacks.
  @Deprecated('Android & iOS dont stream this state. You can delete')
  connecting,
  // Deprecated: To be more precise, 'disconnecting' is only returned by getConnectionState (android)
  // or CBPeripheral.state (iOS), which FlutterBluePlus does not use. FBP only uses the OS callbacks.
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

// [none] no bond
// [bonding] bonding is in progress
// [bonded] bond success
enum BluetoothBondState { none, bonding, bonded }

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
