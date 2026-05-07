import 'device.dart';

enum BluetoothAddressType {
  unknown(65535),
  public(0),
  random(1);

  const BluetoothAddressType(this.value);

  factory BluetoothAddressType.fromValue(int value) {
    for (final addressType in BluetoothAddressType.values) {
      if (addressType.value == value) {
        return addressType;
      }
    }

    return BluetoothAddressType.unknown;
  }

  final int value;
}

enum BluetoothBondState {
  none(10),
  bonding(11),
  bonded(12),
  unknown(-1);

  const BluetoothBondState(this.value);

  factory BluetoothBondState.fromValue(int value) {
    for (final bondState in BluetoothBondState.values) {
      if (bondState.value == value) {
        return bondState;
      }
    }

    return BluetoothBondState.unknown;
  }

  final int value;
}

final class BluetoothBondStateChangedEvent {
  const BluetoothBondStateChangedEvent({
    required this.device,
    required this.previousBondState,
  });

  factory BluetoothBondStateChangedEvent.fromMap(Map<Object?, Object?> map) {
    return BluetoothBondStateChangedEvent(
      device: BluetoothDevice.fromMap(map['device'] as Map<Object?, Object?>),
      previousBondState: BluetoothBondState.values.byName(map['previousBondState'] as String? ?? 'unknown'),
    );
  }

  final BluetoothDevice device;
  final BluetoothBondState previousBondState;
}

enum BluetoothDeviceType {
  unknown(0),
  classic(1),
  le(2),
  dual(3);

  const BluetoothDeviceType(this.value);

  factory BluetoothDeviceType.fromValue(int value) {
    for (final deviceType in BluetoothDeviceType.values) {
      if (deviceType.value == value) {
        return deviceType;
      }
    }

    return BluetoothDeviceType.unknown;
  }

  final int value;
}
