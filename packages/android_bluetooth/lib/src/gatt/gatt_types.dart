final class BluetoothGattCharacteristicId {
  const BluetoothGattCharacteristicId({
    required this.characteristicInstanceId,
    required this.characteristicUuid,
    required this.serviceInstanceId,
    required this.serviceUuid,
  });

  Map<String, Object?> toMap() {
    return {
      'characteristicInstanceId': characteristicInstanceId,
      'characteristicUuid': characteristicUuid,
      'serviceInstanceId': serviceInstanceId,
      'serviceUuid': serviceUuid,
    };
  }

  final int characteristicInstanceId;
  final String characteristicUuid;
  final int serviceInstanceId;
  final String serviceUuid;
}

final class BluetoothGattConnectionPriority {
  const BluetoothGattConnectionPriority._(this.value);

  static const balanced = BluetoothGattConnectionPriority._(0);
  static const high = BluetoothGattConnectionPriority._(1);
  static const lowPower = BluetoothGattConnectionPriority._(2);
  static const dck = BluetoothGattConnectionPriority._(3);

  static BluetoothGattConnectionPriority fromValue(int value) {
    switch (value) {
      case 0:
        return balanced;
      case 1:
        return high;
      case 2:
        return lowPower;
      case 3:
        return dck;
      default:
        return balanced;
    }
  }

  final int value;
}

enum BluetoothGattConnectionState {
  disconnected(0),
  connecting(1),
  connected(2),
  disconnecting(3),
  unknown(-1);

  const BluetoothGattConnectionState(this.value);

  factory BluetoothGattConnectionState.fromValue(int value) {
    for (final connectionState in BluetoothGattConnectionState.values) {
      if (connectionState.value == value) {
        return connectionState;
      }
    }

    return BluetoothGattConnectionState.unknown;
  }

  final int value;
}

final class BluetoothGattDescriptorId {
  const BluetoothGattDescriptorId({
    required this.characteristic,
    required this.descriptorUuid,
  });

  Map<String, Object?> toMap() {
    return {
      ...characteristic.toMap(),
      'descriptorUuid': descriptorUuid,
    };
  }

  final BluetoothGattCharacteristicId characteristic;
  final String descriptorUuid;
}

final class BluetoothGattHandler {
  const BluetoothGattHandler._(this.name);

  static const main = BluetoothGattHandler._('main');

  final String name;

  Map<String, Object> toMap() {
    return <String, Object>{'name': name};
  }
}

final class BluetoothGattPhy {
  const BluetoothGattPhy._(this.value);

  static const le1m = BluetoothGattPhy._(1);
  static const le2m = BluetoothGattPhy._(2);
  static const lecoded = BluetoothGattPhy._(3);

  final int value;
}

final class BluetoothGattStatus {
  const BluetoothGattStatus._();

  static const success = 0;
  static const readNotPermitted = 2;
  static const writeNotPermitted = 3;
  static const insufficientAuthentication = 5;
  static const requestNotSupported = 6;
  static const invalidOffset = 7;
  static const insufficientAuthorization = 8;
  static const invalidAttributeLength = 13;
  static const insufficientEncryption = 15;
  static const connectionCongested = 143;
  static const failure = 257;
}
