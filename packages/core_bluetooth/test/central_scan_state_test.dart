import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  late cb.CBCentralManager manager;
  setUp(() async {
    host = CoreBluetoothTestHost()..setUp();
    manager = host.trackCentral(cb.CBCentralManager.createIsolated());
    await manager.ready;
  });
  tearDown(() => host.tearDown());

  for (final scanning in [false, true]) {
    test('scan state reflects native activity (scanning: $scanning)', () async {
      host.handle = (call) => call.method == 'centralManager.scanForPeripherals' ? scanning : null;
      await manager.scanForPeripherals(
        withServices: [cb.CBUUID('180f')],
        options: const cb.CentralManagerScanOptions(allowDuplicates: true),
      );
      expect(manager.isScanning, scanning);
      final arguments = host.calls.last.arguments as Map;
      expect(arguments['serviceUUIDs'], ['180f']);
      expect((arguments['options'] as Map)['allowDuplicates'], isTrue);
    });
  }

  test('scan requests cannot report activity while the adapter is unavailable', () async {
    for (final state in [0, 1, 2, 3, 4]) {
      await host.emitCentral('didUpdateState', {'state': state});
      await manager.scanForPeripherals();
      expect(manager.isScanning, isFalse);
    }
  });

  test('a pending scan reply cannot revive activity after power-off and recovery', () async {
    final reply = Completer<Object?>();
    host.handle = (call) => call.method == 'centralManager.scanForPeripherals' ? reply.future : null;
    final scan = manager.scanForPeripherals();
    await host.pump();
    await host.emitCentral('didUpdateState', {'state': 4});
    await host.emitCentral('didUpdateState', {'state': 5});
    reply.complete(true);
    await scan;
    expect(manager.isScanning, isFalse);
  });

  test('an older scan reply cannot overwrite a later successful stop', () async {
    final reply = Completer<Object?>();
    host.handle = (call) => call.method == 'centralManager.scanForPeripherals' ? reply.future : null;
    final scan = manager.scanForPeripherals();
    await host.pump();
    await manager.stopScan();
    reply.complete(true);
    await scan;
    expect(manager.isScanning, isFalse);
  });

  test('an older stop reply cannot overwrite a later successful scan', () async {
    await manager.scanForPeripherals();
    final reply = Completer<Object?>();
    host.handle = (call) => call.method == 'centralManager.stopScan' ? reply.future : null;
    final stop = manager.stopScan();
    await host.pump();
    await manager.scanForPeripherals();
    reply.complete(null);
    await stop;
    expect(manager.isScanning, isTrue);
  });

  test('a refused replacement scan clears previous scanning state', () async {
    await manager.scanForPeripherals();
    expect(manager.isScanning, isTrue);
    host.handle = (call) => call.method == 'centralManager.scanForPeripherals' ? false : null;
    await manager.scanForPeripherals();
    expect(manager.isScanning, isFalse);
  });

  test('scan submission errors preserve the previous activity and error', () async {
    await manager.scanForPeripherals();
    final error = PlatformException(code: 'scan_failed', message: 'Native scan failure', details: 7);
    host.handle = (call) {
      if (call.method == 'centralManager.scanForPeripherals') throw error;
      return null;
    };
    await expectLater(
      manager.scanForPeripherals(),
      throwsA(isA<PlatformException>()
          .having((error) => error.code, 'code', 'scan_failed')
          .having((error) => error.message, 'message', 'Native scan failure')
          .having((error) => error.details, 'details', 7)),
    );
    expect(manager.isScanning, isTrue);
  });
}
