import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

final class _CentralDelegate extends cb.CBCentralManagerDelegate {
  _CentralDelegate(this.onUpdate);
  final void Function(cb.CBCentralManager) onUpdate;
  @override
  void centralManagerDidUpdateState(cb.CBCentralManager manager) => onUpdate(manager);
}

final class _PeripheralDelegate extends cb.CBPeripheralManagerDelegate {
  _PeripheralDelegate(this.onUpdate);
  final void Function(cb.CBPeripheralManager) onUpdate;
  @override
  void peripheralManagerDidUpdateState(cb.CBPeripheralManager manager) => onUpdate(manager);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  setUp(() => host = CoreBluetoothTestHost()..setUp());
  tearDown(() => host.tearDown());

  for (final central in [true, false]) {
    for (final disposeInCallback in [false, true]) {
      test('startup callback errors preserve native ownership (central: $central, dispose: $disposeInCallback)',
          () async {
        final method = central ? 'centralManager' : 'peripheralManager';
        final reply = Completer<Object?>();
        final outcome = Completer<Object?>();
        host.handle = (call) => call.method == '$method.create' ? reply.future : null;
        final failure = StateError('application callback failed');
        final errors = <Object>[];
        Future<void>? disposal;
        cb.CBCentralManager? centralManager;
        cb.CBPeripheralManager? peripheralManager;
        runZonedGuarded(() {
          final Future<void> ready;
          if (central) {
            centralManager = host.trackCentral(cb.CBCentralManager.createIsolated(delegate: _CentralDelegate((manager) {
              if (disposeInCallback) unawaited(disposal = manager.dispose());
              throw failure;
            })));
            ready = centralManager!.ready;
          } else {
            peripheralManager =
                host.track(cb.CBPeripheralManager.createIsolated(delegate: _PeripheralDelegate((manager) {
              if (disposeInCallback) unawaited(disposal = manager.dispose());
              throw failure;
            })));
            ready = peripheralManager!.ready;
          }
          unawaited(ready.then((_) => outcome.complete(null), onError: (Object error, StackTrace stack) {
            outcome.complete(error);
          }));
        }, (error, stack) => errors.add(error));
        await host.pump();
        for (var i = 0; i < 2; i++) {
          if (central) {
            await host.emitCentral('didUpdateState', {'state': 5, 'isScanning': false}, id: 8);
          } else {
            await host.emit('peripheralManagerDidUpdateState', {'state': 5, 'isAdvertising': false}, id: 8);
          }
        }
        reply.complete({'managerId': 8, 'state': 5, 'isScanning': false, 'isAdvertising': false});
        expect(await outcome.future, isNull);
        expect(errors, hasLength(disposeInCallback ? 1 : 2));
        expect(errors.every((error) => identical(error, failure)), isTrue);
        if (disposeInCallback) {
          await disposal;
        } else if (central) {
          expect(centralManager!.isInitialized, isTrue);
          await centralManager!.scanForPeripherals();
          expect(host.calls.where((call) => call.method == '$method.dispose'), isEmpty);
          await centralManager!.dispose();
        } else {
          expect(peripheralManager!.isInitialized, isTrue);
          await peripheralManager!.startAdvertising(null);
          expect(host.calls.where((call) => call.method == '$method.dispose'), isEmpty);
          await peripheralManager!.dispose();
        }
        expect(host.calls.where((call) => call.method == '$method.create'), hasLength(1));
        final disposals = host.calls.where((call) => call.method == '$method.dispose').toList();
        expect(disposals, hasLength(1));
        expect((disposals.single.arguments as Map)['managerId'], 8);
      });
    }
  }
}
