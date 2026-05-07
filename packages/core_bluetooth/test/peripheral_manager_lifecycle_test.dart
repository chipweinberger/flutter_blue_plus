import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  setUp(() {
    host = CoreBluetoothTestHost()..setUp();
  });
  tearDown(() => host.tearDown());

  test('new local references cannot collide with objects recovered from an earlier Dart session', () {
    final service = cb.CBMutableService.type(type: cb.CBUUID('180f'), primary: true);
    expect(service.toMap()['clientReference'], isNot('local_1'));
  });

  for (final failPending in [false, true]) {
    test('shared reattachment recovers services before buffered requests (pending failure: $failPending)', () async {
      final reply = Completer<Object?>();
      host.handle = (call) {
        if (call.method == 'peripheralManager.create') return reply.future;
        if (call.method == 'peripheralManager.updateValue') return true;
        return null;
      };
      final manager = host.track(cb.CBPeripheralManager.shared);
      final restorations = <cb.PeripheralManagerWillRestoreStateResult>[];
      final subscription = manager.onWillRestoreState.listen(restorations.add);
      addTearDown(subscription.cancel);
      final request = manager.onDidReceiveReadRequest.first;
      await host.emit(
          'peripheralManagerDidReceiveRead',
          {
            'requestHandle': 'old-request',
            'characteristicHandle': 'old-c',
            'offset': 0,
            'central': {'identifier': '12345678-1234-1234-1234-123456789abc', 'maximumUpdateValueLength': 20},
          },
          id: 8);
      final pending = {
        'clientReference': 'old-pending',
        'handle': 'pending',
        'uuid': '1810',
        'isPrimary': true,
        'characteristics': [],
        'includedServices': [],
      };
      reply.complete({
        'managerId': 8,
        'state': 5,
        'isAdvertising': true,
        'services': [
          {
            'clientReference': 'old-service',
            'handle': 'old-s',
            'uuid': '180f',
            'isPrimary': true,
            'includedServices': [],
            'characteristics': [
              {
                'clientReference': 'old-characteristic',
                'handle': 'old-c',
                'uuid': '2a19',
                'properties': 18,
                'permissions': 1,
                'descriptors': [],
                'subscribedCentrals': [
                  {
                    'identifier': '12345678-1234-1234-1234-123456789abc',
                    'maximumUpdateValueLength': 20,
                  }
                ],
              }
            ],
          }
        ],
        'pendingServices': [pending],
      });
      await manager.ready;
      expect((host.calls.first.arguments as Map)['shared'], isTrue);
      expect(manager.isAdvertising, isTrue);
      expect(manager.services, hasLength(1));
      final characteristic = manager.services.single.characteristics!.single as cb.CBMutableCharacteristic;
      expect(characteristic.handle, 'old-c');
      expect(characteristic.subscribedCentrals, hasLength(1));
      final received = await request;
      expect(received.request.characteristic, same(characteristic));
      await manager.respond(to: received.request, withResult: cb.CBATTErrorCode.success);
      expect((host.calls.last.arguments as Map)['requestHandle'], 'old-request');
      expect(await manager.updateValue(Uint8List.fromList([7]), forCharacteristic: characteristic), isTrue);
      expect((host.calls.last.arguments as Map)['characteristicHandle'], 'old-c');
      final added = manager.onDidAddService.first;
      await host.emit(
          'peripheralManagerDidAddService',
          {
            'service': pending,
            if (failPending) 'error': {'domain': 'CBErrorDomain', 'code': 9, 'localizedDescription': 'Add failed'},
          },
          id: 8);
      expect((await added).service.handle, 'pending');
      expect(manager.services, hasLength(failPending ? 1 : 2));
      expect(restorations, isEmpty); // Reattachment does not invent an OS restoration callback.
      await manager.stopAdvertising();
      expect((host.calls.last.arguments as Map)['managerId'], 8);
      expect(manager.isAdvertising, isFalse);
      await manager.remove(manager.services.first);
      expect((host.calls.last.arguments as Map)['serviceHandle'], 'old-s');
    });
  }

  for (final shared in [false, true]) {
    test('peripheral manager creation selects native shared identity (shared: $shared)', () async {
      final manager = host.track(shared
          ? cb.CBPeripheralManager.ensureShared(options: const cb.PeripheralManagerOptions(restoreIdentifier: 'test'))
          : cb.CBPeripheralManager.createIsolated());
      await manager.ready;
      expect((host.calls.single.arguments as Map)['shared'], shared);
    });
  }

  test('readiness callbacks cannot dispose a manager before a later advertising call', () async {
    var disposing = false;
    final callStates = <bool>[];
    host.handle = (call) {
      if (call.method == 'peripheralManager.startAdvertising') callStates.add(disposing);
      return null;
    };
    final manager = host.track(cb.CBPeripheralManager.createIsolated());
    final advertising = manager.startAdvertising(null).onError<StateError>((error, stack) {});
    final disposal = manager.ready.then((_) {
      disposing = true;
      return manager.dispose();
    });
    await Future.wait([advertising, disposal]);
    expect(callStates.where((disposed) => disposed), isEmpty);
  });

  test('temporary creation failures retry without duplicating event listeners', () async {
    host.handle = (call) {
      if (call.method == 'peripheralManager.create') throw PlatformException(code: 'temporary_failure');
      return null;
    };
    final manager = host.track(cb.CBPeripheralManager.createIsolated());
    await expectLater(manager.startAdvertising(null), throwsA(isA<PlatformException>()));
    expect(manager.isInitialized, isFalse);
    host.handle = null;
    await manager.startAdvertising(null);
    expect(manager.isInitialized, isTrue);
    expect(host.calls.where((call) => call.method == 'peripheralManager.create'), hasLength(2));
    final events = <cb.PeripheralManagerDidStartAdvertisingResult>[];
    final subscription = manager.onDidStartAdvertising.listen(events.add);
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
    expect(events, hasLength(1));
    expect(manager.isAdvertising, isTrue);
    await subscription.cancel();
  });

  test('eager creation failure is handled and disposal does not retry it', () async {
    host.handle = (call) {
      if (call.method == 'peripheralManager.create') throw PlatformException(code: 'temporary_failure');
      return null;
    };
    final manager = host.track(cb.CBPeripheralManager.createIsolated());
    await host.pump();
    await manager.dispose();
    expect(host.calls.where((call) => call.method == 'peripheralManager.create'), hasLength(1));
    expect(host.calls.where((call) => call.method == 'peripheralManager.dispose'), isEmpty);
    await expectLater(manager.ready, throwsStateError);
  });

  test('disposing shared clears cached state and permits a fresh manager with new options', () async {
    final manager = host.track(cb.CBPeripheralManager.shared);
    await manager.ready;
    await host.emit('peripheralManagerWillRestoreState', {
      'services': [
        {'handle': 's', 'uuid': '180f', 'isPrimary': true, 'characteristics': [], 'includedServices': []}
      ]
    });
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
    expect(manager.services, hasLength(1));
    expect(manager.isAdvertising, isTrue);
    await manager.dispose();
    expect(manager.services, isEmpty);
    expect(manager.isAdvertising, isFalse);
    expect(manager.isInitialized, isFalse);
    final previousCalls = host.calls.length;
    await expectLater(manager.startAdvertising(null), throwsStateError);
    expect(host.calls, hasLength(previousCalls));

    final replacement = host.track(cb.CBPeripheralManager.ensureShared(
        options: const cb.PeripheralManagerOptions(restoreIdentifier: 'replacement')));
    expect(replacement, isNot(same(manager)));
    await replacement.startAdvertising(null);
    expect(host.calls.where((call) => call.method == 'peripheralManager.create'), hasLength(2));
    expect((host.calls.last.arguments as Map)['managerId'], 2);
  });

  test('disposal during creation releases the manager and prevents queued operations', () async {
    final started = Completer<void>();
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'peripheralManager.create') {
        started.complete();
        return await reply.future;
      }
      return null;
    };
    final manager = host.track(cb.CBPeripheralManager.createIsolated());
    final operation = expectLater(manager.startAdvertising(null), throwsStateError);
    await started.future;
    final disposal = manager.dispose();
    await expectLater(manager.stopAdvertising(), throwsStateError);
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true}, id: 8);
    reply.complete({'managerId': 8, 'state': 5, 'isAdvertising': true});
    await Future.wait([disposal, operation]);
    expect(manager.isAdvertising, isFalse);
    expect(host.calls.where((call) => call.method == 'peripheralManager.startAdvertising'), isEmpty);
    expect(host.calls.where((call) => call.method == 'peripheralManager.stopAdvertising'), isEmpty);
    expect(host.calls.where((call) => call.method == 'peripheralManager.dispose'), hasLength(1));
    expect((host.calls.last.arguments as Map)['managerId'], 8);
  });

  test('disposal tolerates creation failing while it waits', () async {
    final started = Completer<void>();
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'peripheralManager.create') {
        started.complete();
        return await reply.future;
      }
      return null;
    };
    final manager = host.track(cb.CBPeripheralManager.createIsolated());
    await started.future;
    final disposal = manager.dispose();
    reply.completeError(PlatformException(code: 'create_failed'));
    await disposal;
    expect(host.calls.where((call) => call.method == 'peripheralManager.dispose'), isEmpty);
    await expectLater(manager.startAdvertising(null), throwsStateError);
  });

  test('concurrent disposal waits for the same native cleanup', () async {
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'peripheralManager.dispose') return await reply.future;
      return null;
    };
    final manager = host.track(cb.CBPeripheralManager.createIsolated());
    await manager.ready;
    final first = manager.dispose();
    var secondCompleted = false;
    final second = manager.dispose().then((_) => secondCompleted = true);
    await host.pump();
    expect(secondCompleted, isFalse);
    expect(host.calls.where((call) => call.method == 'peripheralManager.dispose'), hasLength(1));
    reply.complete(null);
    await Future.wait([first, second]);
    expect(secondCompleted, isTrue);
  });
}
