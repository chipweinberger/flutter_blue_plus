part of '../core_bluetooth.dart';

CBManagerAuthorization cbManagerAuthorizationFromRawValue(int rawValue) {
  switch (rawValue) {
    case 1:
      return CBManagerAuthorization.restricted;
    case 2:
      return CBManagerAuthorization.denied;
    case 3:
      return CBManagerAuthorization.allowedAlways;
    case 0:
    default:
      return CBManagerAuthorization.notDetermined;
  }
}

CBManagerState cbManagerStateFromRawValue(int rawValue) {
  switch (rawValue) {
    case 1:
      return CBManagerState.resetting;
    case 2:
      return CBManagerState.unsupported;
    case 3:
      return CBManagerState.unauthorized;
    case 4:
      return CBManagerState.poweredOff;
    case 5:
      return CBManagerState.poweredOn;
    case 0:
    default:
      return CBManagerState.unknown;
  }
}

CBPeripheralState cbPeripheralStateFromRawValue(int rawValue) {
  switch (rawValue) {
    case 1:
      return CBPeripheralState.connecting;
    case 2:
      return CBPeripheralState.connected;
    case 3:
      return CBPeripheralState.disconnecting;
    case 0:
    default:
      return CBPeripheralState.disconnected;
  }
}

CBConnectionEvent cbConnectionEventFromRawValue(int rawValue) {
  return switch (rawValue) {
    1 => CBConnectionEvent.peerConnected,
    0 || _ => CBConnectionEvent.peerDisconnected,
  };
}

Uint8List bytesFromObject(Object? value) {
  return Uint8List.fromList((value as List<Object?>? ?? const []).cast<int>());
}

Uint8List? bytesFromNullable(Object? value) {
  if (value == null) {
    return null;
  }
  return bytesFromObject(value);
}

CBError? cbErrorFromPayload(Map<Object?, Object?> payload) {
  final errorMap = payload['error'] as Map?;
  if (errorMap == null) {
    return null;
  }
  return CBError.fromMap(Map<Object?, Object?>.from(errorMap));
}
