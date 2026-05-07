import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

Map<String, Object?> _serviceSnapshot(cb.CBMutableService service,
        {bool includeReference = true, String handle = 'native-service'}) =>
    {
      ...service.toMap(),
      'handle': handle,
      if (!includeReference) 'clientReference': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  late cb.CBPeripheralManager manager;
  late cb.CBMutableService service;
  setUp(() async {
    host = CoreBluetoothTestHost()..setUp();
    manager = host.track(cb.CBPeripheralManager.createIsolated());
    await manager.ready;
    service = cb.CBMutableService.type(type: cb.CBUUID('180f'), primary: true);
  });
  tearDown(() => host.tearDown());

  test('successful service adds preserve caller identity', () async {
    await manager.add(service);
    final callback = manager.onDidAddService.first;
    await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service)});
    expect((await callback).service, same(service));
    expect(manager.services.single, same(service));
    expect(service.handle, 'native-service');
  });

  for (final includeReference in [true, false]) {
    test('removeAllServices keeps late add callbacks out of services (reference: $includeReference)', () async {
      await manager.add(service);
      final snapshot = _serviceSnapshot(service, includeReference: includeReference);
      await manager.removeAllServices();
      final callback = manager.onDidAddService.first;
      await host.emit('peripheralManagerDidAddService', {'service': snapshot});
      expect((await callback).error, isNull);
      expect(manager.services, isEmpty);
    });
  }

  test('removing a published service does not let a duplicate add callback revive it', () async {
    await manager.add(service);
    await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service)});
    final snapshot = _serviceSnapshot(service);
    await manager.remove(service);
    final callback = manager.onDidAddService.first;
    await host.emit('peripheralManagerDidAddService', {'service': snapshot});
    expect((await callback).service.handle, service.handle);
    expect(manager.services, isEmpty);
  });

  test('failed service submission cannot leave a pending add that accepts a later callback', () async {
    host.handle = (call) {
      if (call.method == 'peripheralManager.addService') throw PlatformException(code: 'add_failed');
      return null;
    };
    await expectLater(manager.add(service), throwsA(isA<PlatformException>()));
    final callback = manager.onDidAddService.first;
    await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service)});
    await callback;
    expect(manager.services, isEmpty);
  });

  test('a failed remove leaves the published service tracked', () async {
    await manager.add(service);
    await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service)});
    host.handle = (call) {
      if (call.method == 'peripheralManager.removeService') throw PlatformException(code: 'remove_failed');
      return null;
    };
    await expectLater(manager.remove(service), throwsA(isA<PlatformException>()));
    expect(manager.services.single, same(service));
  });

  for (final callbackBeforeReply in [true, false]) {
    test('removeAllServices preserves newer adds (callback before reply: $callbackBeforeReply)', () async {
      await manager.add(service);
      await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service)});
      final pending = cb.CBMutableService.type(type: cb.CBUUID('180a'), primary: true);
      await manager.add(pending);
      final reply = Completer<Object?>();
      host.handle = (call) async {
        if (call.method == 'peripheralManager.removeAllServices') return await reply.future;
        return null;
      };
      final removing = manager.removeAllServices();
      await host.pump();
      final newer = cb.CBMutableService.type(type: cb.CBUUID('180d'), primary: true);
      await manager.add(newer);
      final snapshot = _serviceSnapshot(newer, handle: 'newer-service');
      if (callbackBeforeReply) await host.emit('peripheralManagerDidAddService', {'service': snapshot});
      reply.complete(null);
      await removing;
      if (!callbackBeforeReply) await host.emit('peripheralManagerDidAddService', {'service': snapshot});
      expect(manager.services.single, same(newer));
      await host.emit('peripheralManagerDidAddService', {
        'service': _serviceSnapshot(pending, handle: 'removed-pending-service'),
      });
      expect(manager.services.single, same(newer));
    });
  }

  for (final removeAll in [true, false]) {
    test('an older removal preserves a newer add of the same service (all: $removeAll)', () async {
      await manager.add(service);
      await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service)});
      final reply = Completer<Object?>();
      host.handle = (call) async {
        if (call.method == (removeAll ? 'peripheralManager.removeAllServices' : 'peripheralManager.removeService')) {
          return await reply.future;
        }
        return null;
      };
      final removing = removeAll ? manager.removeAllServices() : manager.remove(service);
      await host.pump();
      await manager.add(service);
      await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service, handle: 'replacement')});
      reply.complete(null);
      await removing;
      expect(manager.services.single, same(service));
      expect(service.handle, 'replacement');
    });
  }

  for (final failBeforeRemoval in [true, false]) {
    test('a failed re-add cannot restore a removed service (failure before removal: $failBeforeRemoval)', () async {
      await manager.add(service);
      await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service)});
      final removeReply = Completer<Object?>();
      final addReply = Completer<Object?>();
      host.handle = (call) async {
        if (call.method == 'peripheralManager.removeAllServices') return await removeReply.future;
        if (call.method == 'peripheralManager.addService') return await addReply.future;
        return null;
      };
      final removing = manager.removeAllServices();
      await host.pump();
      final adding = expectLater(manager.add(service), throwsA(isA<PlatformException>()));
      await host.pump();
      if (failBeforeRemoval) {
        addReply.completeError(PlatformException(code: 'add_failed'));
        await adding;
        expect(manager.services.single, same(service));
      }
      removeReply.complete(null);
      await removing;
      expect(manager.services, isEmpty);
      if (!failBeforeRemoval) {
        addReply.completeError(PlatformException(code: 'add_failed'));
        await adding;
      }
      expect(manager.services, isEmpty);
    });
  }

  test('a re-add pending at removal completion becomes published only on its own callback', () async {
    await manager.add(service);
    await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service)});
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'peripheralManager.removeAllServices') return await reply.future;
      return null;
    };
    final removing = manager.removeAllServices();
    await host.pump();
    await manager.add(service);
    reply.complete(null);
    await removing;
    expect(manager.services, isEmpty);
    await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service, handle: 'replacement')});
    expect(manager.services.single, same(service));
    await manager.remove(service);
    expect(manager.services, isEmpty);
  });

  test('removeAllServices failure preserves earlier and newer service tracking', () async {
    await manager.add(service);
    await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service)});
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'peripheralManager.removeAllServices') return await reply.future;
      return null;
    };
    final removing = expectLater(manager.removeAllServices(), throwsA(isA<PlatformException>()));
    await host.pump();
    final newer = cb.CBMutableService.type(type: cb.CBUUID('180d'), primary: true);
    await manager.add(newer);
    reply.completeError(PlatformException(code: 'remove_failed'));
    await removing;
    await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(newer, handle: 'newer-service')});
    expect(manager.services, [same(service), same(newer)]);
  });

  test('removal accepts another wrapper for the same native handle', () async {
    await manager.add(service);
    await host.emit('peripheralManagerDidAddService', {'service': _serviceSnapshot(service)});
    final alias = cb.CBMutableService.fromMap(_serviceSnapshot(service, includeReference: false));
    await manager.remove(alias);
    expect(manager.services, isEmpty);
  });

  test('restored services remain removable and a newer restoration survives an older removal', () async {
    final snapshot = _serviceSnapshot(service, includeReference: false);
    await host.emit('peripheralManagerWillRestoreState', {
      'services': [snapshot]
    });
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'peripheralManager.removeAllServices') return await reply.future;
      return null;
    };
    final removing = manager.removeAllServices();
    await host.pump();
    await host.emit('peripheralManagerWillRestoreState', {
      'services': [snapshot]
    });
    reply.complete(null);
    await removing;
    expect(manager.services, hasLength(1));
    await manager.remove(manager.services.single);
    expect(manager.services, isEmpty);
  });

  test('stopping advertising clears the flag and still delivers late start callbacks', () async {
    await manager.startAdvertising(null);
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
    expect(manager.isAdvertising, isTrue);
    await manager.stopAdvertising();
    expect(manager.isAdvertising, isFalse);
    final callback = manager.onDidStartAdvertising.first;
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
    expect((await callback).error, isNull);
    expect(manager.isAdvertising, isFalse);
    await manager.startAdvertising(null);
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
    expect(manager.isAdvertising, isTrue);
  });

  test('failed stop preserves advertising state and subsequent callbacks', () async {
    await manager.startAdvertising(null);
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
    host.handle = (call) {
      if (call.method == 'peripheralManager.stopAdvertising') throw PlatformException(code: 'stop_failed');
      return null;
    };
    await expectLater(manager.stopAdvertising(), throwsA(isA<PlatformException>()));
    expect(manager.isAdvertising, isTrue);
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': false});
    expect(manager.isAdvertising, isFalse);
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
    expect(manager.isAdvertising, isTrue);
  });

  test('an older stop reply cannot overwrite a newer advertising start', () async {
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'peripheralManager.stopAdvertising') return await reply.future;
      return null;
    };
    final stopping = manager.stopAdvertising();
    await host.pump();
    await manager.startAdvertising(null);
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
    reply.complete(null);
    await stopping;
    expect(manager.isAdvertising, isTrue);
  });

  test('a stop reply after disposal cannot change cleared state', () async {
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'peripheralManager.stopAdvertising') return await reply.future;
      return null;
    };
    await manager.startAdvertising(null);
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
    final stopping = manager.stopAdvertising();
    await host.pump();
    await manager.dispose();
    reply.complete(null);
    await stopping;
    expect(manager.isAdvertising, isFalse);
    expect(manager.services, isEmpty);
  });

  test('a second failed stop cannot invalidate an earlier successful stop', () async {
    final reply = Completer<Object?>();
    var stops = 0;
    host.handle = (call) async {
      if (call.method == 'peripheralManager.stopAdvertising') {
        if (++stops == 1) return await reply.future;
        throw PlatformException(code: 'stop_failed');
      }
      return null;
    };
    await manager.startAdvertising(null);
    await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
    final stopping = manager.stopAdvertising();
    await host.pump();
    await expectLater(manager.stopAdvertising(), throwsA(isA<PlatformException>()));
    reply.complete(null);
    await stopping;
    expect(manager.isAdvertising, isFalse);
  });
}
