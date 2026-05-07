import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class CoreBluetoothTestHost {
  static const methods = MethodChannel('dev.core_bluetooth/methods');
  static const events = EventChannel('dev.core_bluetooth/events');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final managers = <cb.CBPeripheralManager>[];
  final centrals = <cb.CBCentralManager>[];
  FutureOr<Object?> Function(MethodCall)? handle;
  int _nextId = 1;

  cb.CBPeripheralManager track(cb.CBPeripheralManager manager) {
    managers.add(manager);
    return manager;
  }

  cb.CBCentralManager trackCentral(cb.CBCentralManager manager) {
    centrals.add(manager);
    return manager;
  }

  void setUp() {
    messenger.setMockMethodCallHandler(MethodChannel(events.name), (_) async => null);
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (handle != null) {
        final reply = await handle!(call);
        if (reply != null) return reply;
      }
      if (call.method == 'peripheralManager.create') {
        return {'managerId': _nextId++, 'state': 5, 'isAdvertising': false};
      }
      if (call.method == 'centralManager.create') {
        return {'managerId': _nextId++, 'state': 5, 'isScanning': false};
      }
      if (call.method == 'centralManager.scanForPeripherals') return true;
      return null;
    });
  }

  Future<void> pump() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> emit(String kind, Map<String, Object?> payload, {int id = 1}) async {
    await _emit(kind, payload, 'peripheralManagerId', id);
  }

  Future<void> emitCentral(String kind, Map<String, Object?> payload, {int id = 1}) async {
    await _emit(kind, payload, 'managerId', id);
  }

  Future<void> _emit(String kind, Map<String, Object?> payload, String idKey, int id) async {
    // ignore: deprecated_member_use
    await messenger.handlePlatformMessage(events.name,
        const StandardMethodCodec().encodeSuccessEnvelope({'kind': kind, idKey: id, 'payload': payload}), (_) {});
    await pump();
  }

  Future<void> tearDown() async {
    for (final manager in managers) {
      await manager.dispose();
    }
    for (final manager in centrals) {
      await manager.dispose();
    }
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(MethodChannel(events.name), null);
  }
}
