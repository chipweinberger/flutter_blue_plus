part of '../core_bluetooth.dart';

final class CBConnectionEvent {
  const CBConnectionEvent(this.rawValue);

  static const peerDisconnected = CBConnectionEvent(0);
  static const peerConnected = CBConnectionEvent(1);

  final int rawValue;

  @override
  bool operator ==(Object other) {
    return other is CBConnectionEvent && other.rawValue == rawValue;
  }

  @override
  int get hashCode => rawValue.hashCode;
}
