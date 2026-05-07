import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

const _id = '12345678-1234-1234-1234-123456789abc';
Map<String, Object?> _peripheral() => {'identifier': _id, 'state': 2};
Map<String, Object?> _service({String suffix = ''}) => {
      'handle': 's$suffix',
      'uuid': '180f',
      'isPrimary': true,
      'includedServices': suffix.isEmpty ? [_service(suffix: '-included')] : [],
      'characteristics': [
        {
          'handle': 'c$suffix',
          'uuid': '2a19',
          'properties': 18,
          'permissions': 1,
          'isNotifying': true,
          'descriptors': [],
          'subscribedCentrals': [
            {'identifier': _id, 'maximumUpdateValueLength': 20}
          ],
        }
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  setUp(() => host = CoreBluetoothTestHost()..setUp());
  tearDown(() => host.tearDown());

  for (final state in [0, 1, 2, 3, 4]) {
    test('central state $state clears connections and GATT without individual disconnects', () async {
      host.handle = (call) => call.method == 'centralManager.retrievePeripherals' ? [_peripheral()] : null;
      final manager = host.trackCentral(cb.CBCentralManager.createIsolated());
      final peripheral = (await manager.retrievePeripherals([cb.UUID(_id)])).single;
      await host.emitCentral('peripheralDidDiscoverServices', {
        'peripheral': _peripheral(),
        'services': [_service()]
      });
      final old = peripheral.services!.single;
      final characteristic = old.characteristics!.single;
      final included = old.includedServices!.single.characteristics!.single;
      final disconnects = <cb.DidDisconnectPeripheralResult>[];
      final subscription = manager.onDidDisconnectPeripheral.listen(disconnects.add);
      addTearDown(subscription.cancel);
      final updated = manager.onDidUpdateState.first;
      await host.emitCentral('didUpdateState', {'state': state, 'isScanning': true});
      expect(await updated, cb.CBManagerState.values[state]);
      expect(manager.isScanning, isFalse);
      expect(manager.connectedPeripherals, isEmpty);
      expect(peripheral.state, cb.CBPeripheralState.disconnected);
      expect(peripheral.services, isNull);
      expect(characteristic.isNotifying, isFalse);
      expect(included.isNotifying, isFalse);
      expect(disconnects, isEmpty); // FBP already synthesizes its own adapter-off event.
      await host.emitCentral('didUpdateState', {'state': 5});
      final retrieved = (await manager.retrievePeripherals([cb.UUID(_id)])).single;
      expect(retrieved, same(peripheral));
      expect(retrieved.services, isNull);
      await host.emitCentral('peripheralDidDiscoverServices', {
        'peripheral': _peripheral(),
        'services': [_service()]
      });
      expect(peripheral.services!.single, isNot(same(old)));
    });
  }

  test('powered-on updates preserve central GATT and other managers remain isolated', () async {
    host.handle = (call) => call.method == 'centralManager.retrievePeripherals' ? [_peripheral()] : null;
    final managers = [
      host.trackCentral(cb.CBCentralManager.createIsolated()),
      host.trackCentral(cb.CBCentralManager.createIsolated()),
    ];
    final peripherals = <cb.CBPeripheral>[];
    for (var i = 0; i < managers.length; i++) {
      peripherals.add((await managers[i].retrievePeripherals([cb.UUID(_id)])).single);
      await host.emitCentral(
          'peripheralDidDiscoverServices',
          {
            'peripheral': _peripheral(),
            'services': [_service()]
          },
          id: i + 1);
    }
    final service = peripherals[0].services!.single;
    final peerService = peripherals[1].services!.single;
    await host.emitCentral('didUpdateState', {'state': 5, 'isScanning': true});
    expect(peripherals[0].services!.single, same(service));
    expect(managers[0].isScanning, isTrue);
    await host.emitCentral('didUpdateState', {'state': 4});
    expect(peripherals[1].services!.single, same(peerService));
    expect(managers[1].connectedPeripherals.single, same(peripherals[1]));
  });

  for (final state in [1, 4]) {
    test('server state $state retires services, subscriptions and pending adds; explicit re-add works', () async {
      final manager = host.track(cb.CBPeripheralManager.createIsolated());
      await manager.ready;
      await host.emit('peripheralManagerWillRestoreState', {
        'services': [_service()]
      });
      final service = manager.services.single;
      final characteristic = service.characteristics!.single as cb.CBMutableCharacteristic;
      final included = service.includedServices!.single.characteristics!.single as cb.CBMutableCharacteristic;
      final pending = cb.CBMutableService.type(type: cb.CBUUID('180a'), primary: true);
      await manager.add(pending);
      final pendingSnapshot = {...pending.toMap(), 'handle': 'pending'};
      final updated = manager.onDidUpdateState.first;
      await host.emit('peripheralManagerDidUpdateState', {'state': state, 'isAdvertising': true});
      expect(await updated, cb.CBManagerState.values[state]);
      expect(manager.services, isEmpty);
      expect(manager.isAdvertising, isFalse);
      expect(characteristic.subscribedCentrals, isEmpty);
      expect(included.subscribedCentrals, isEmpty);
      await host.emit('peripheralManagerDidAddService', {'service': pendingSnapshot});
      await host.emit('peripheralManagerDidStartAdvertising', {'isAdvertising': true});
      expect(manager.services, isEmpty);
      expect(manager.isAdvertising, isFalse);
      await host.emit('peripheralManagerDidUpdateState', {'state': 5});
      expect(manager.services, isEmpty);
      await manager.add(service);
      await host.emit('peripheralManagerDidAddService', {
        'service': {...service.toMap(), 'handle': 'new-s'}
      });
      expect(manager.services.single, same(service));
      expect(characteristic.subscribedCentrals, isEmpty);
    });
  }

  test('power-off during a failing re-add cannot restore the previously published revision', () async {
    final manager = host.track(cb.CBPeripheralManager.createIsolated());
    await manager.ready;
    final service = cb.CBMutableService.type(type: cb.CBUUID('180f'), primary: true);
    await manager.add(service);
    await host.emit('peripheralManagerDidAddService', {
      'service': {...service.toMap(), 'handle': 's'}
    });
    final submitted = Completer<void>();
    final reply = Completer<Object?>();
    host.handle = (call) {
      if (call.method != 'peripheralManager.addService') return null;
      submitted.complete();
      return reply.future;
    };
    final add = manager.add(service);
    final failed = expectLater(add, throwsA(isA<PlatformException>()));
    await submitted.future;
    await host.emit('peripheralManagerDidUpdateState', {'state': 4});
    reply.completeError(PlatformException(code: 'unavailable'));
    await failed;
    await host.emit('peripheralManagerDidUpdateState', {'state': 5});
    await host.emit('peripheralManagerDidAddService', {
      'service': {...service.toMap(), 'handle': 's'}
    });
    expect(manager.services, isEmpty);
  });
}
