import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

Map<String, Object?> _peripheral() => {
      'identifier': '12345678-1234-1234-1234-123456789abc',
      'name': 'Device',
      'state': 2,
      'canSendWriteWithoutResponse': true,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  setUp(() {
    host = CoreBluetoothTestHost()..setUp();
  });
  tearDown(() => host.tearDown());

  test('readiness callbacks cannot dispose a manager before a later native scan', () async {
    var disposing = false;
    final callStates = <bool>[];
    host.handle = (call) {
      if (call.method == 'centralManager.scanForPeripherals') callStates.add(disposing);
      return null;
    };
    final manager = host.trackCentral(cb.CBCentralManager.createIsolated());
    final scan = manager.scanForPeripherals().onError<StateError>((error, stack) {});
    final disposal = manager.ready.then((_) {
      disposing = true;
      return manager.dispose();
    });
    await Future.wait([scan, disposal]);
    expect(callStates.where((disposed) => disposed), isEmpty);
    expect(manager.isScanning, isFalse);
  });

  test('disposal during creation prevents a queued scan and discards startup events', () async {
    final started = Completer<void>();
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'centralManager.create') {
        started.complete();
        return await reply.future;
      }
      return null;
    };
    final manager = host.trackCentral(cb.CBCentralManager.createIsolated());
    final connections = <cb.CBPeripheral>[];
    final subscription = manager.onDidConnectPeripheral.listen(connections.add);
    final scan = expectLater(manager.scanForPeripherals(), throwsStateError);
    await started.future;
    await host.emitCentral('didConnectPeripheral', {'peripheral': _peripheral()}, id: 8);
    final disposal = manager.dispose();
    await host.emitCentral('didUpdateState', {'state': 5, 'isScanning': true}, id: 8);
    reply.complete({'managerId': 8, 'state': 5, 'isScanning': true});
    await Future.wait([scan, disposal]);
    expect(connections, isEmpty);
    expect(manager.connectedPeripherals, isEmpty);
    expect(manager.isInitialized, isFalse);
    expect(manager.isScanning, isFalse);
    expect(host.calls.where((call) => call.method == 'centralManager.scanForPeripherals'), isEmpty);
    expect(host.calls.where((call) => call.method == 'centralManager.dispose'), hasLength(1));
    expect((host.calls.last.arguments as Map)['managerId'], 8);
    await subscription.cancel();
  });

  test('an in-flight scan response cannot restore scanning state after disposal', () async {
    final manager = host.trackCentral(cb.CBCentralManager.createIsolated());
    await manager.ready;
    final started = Completer<void>();
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'centralManager.scanForPeripherals') {
        started.complete();
        return await reply.future;
      }
      return null;
    };
    final scan = expectLater(manager.scanForPeripherals(), throwsStateError);
    await started.future;
    await manager.dispose();
    reply.complete(null);
    await scan;
    expect(manager.isScanning, isFalse);
    expect(manager.connectedPeripherals, isEmpty);
  });

  for (final method in ['retrievePeripherals', 'retrieveConnectedPeripherals', 'disconnectAllPeripherals']) {
    test('a pending $method result cannot repopulate a disposed manager', () async {
      final manager = host.trackCentral(cb.CBCentralManager.createIsolated());
      await manager.ready;
      final started = Completer<void>();
      final reply = Completer<Object?>();
      host.handle = (call) async {
        if (call.method == 'centralManager.$method') {
          started.complete();
          return await reply.future;
        }
        return null;
      };
      final Future<List<cb.CBPeripheral>> operation;
      switch (method) {
        case 'retrievePeripherals':
          operation = manager.retrievePeripherals([cb.UUID('12345678-1234-1234-1234-123456789abc')]);
        case 'retrieveConnectedPeripherals':
          operation = manager.retrieveConnectedPeripherals([cb.CBUUID('180f')]);
        default:
          operation = manager.disconnectAllPeripherals();
      }
      final failure = expectLater(operation, throwsStateError);
      await started.future;
      await manager.dispose();
      reply.complete([_peripheral()]);
      await failure;
      expect(manager.connectedPeripherals, isEmpty);
      expect(manager.isScanning, isFalse);
    });
  }

  test('disposed managers reject operations without additional native calls', () async {
    final manager = host.trackCentral(cb.CBCentralManager.createIsolated());
    await manager.ready;
    await manager.scanForPeripherals();
    expect(manager.isScanning, isTrue);
    await manager.dispose();
    final calls = host.calls.length;
    await expectLater(manager.scanForPeripherals(), throwsStateError);
    await expectLater(manager.stopScan(), throwsStateError);
    await expectLater(manager.retrievePeripherals([]), throwsStateError);
    await expectLater(manager.registerForConnectionEvents(), throwsStateError);
    expect(host.calls, hasLength(calls));
    expect(manager.isScanning, isFalse);
  });
}
