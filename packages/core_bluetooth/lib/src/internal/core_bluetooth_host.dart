part of '../core_bluetooth.dart';

final class CoreBluetoothHost {
  CoreBluetoothHost._();

  static final instance = CoreBluetoothHost._();

  static const MethodChannel _methods = MethodChannel('dev.core_bluetooth/methods');
  static const EventChannel _events = EventChannel('dev.core_bluetooth/events');

  Stream<Map<Object?, Object?>>? _stream;

  Stream<Map<Object?, Object?>> get events {
    return _stream ??= _events.receiveBroadcastStream().map(
      (event) {
        return Map<Object?, Object?>.from(event as Map);
      },
    );
  }

  Future<T?> invokeMethod<T>(String method, [Object? arguments]) {
    return _methods.invokeMethod<T>(method, arguments);
  }
}
