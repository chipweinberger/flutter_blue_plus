import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

Map<String, Object?> _central() => {
      'identifier': '12345678-1234-1234-1234-123456789abc',
      'maximumUpdateValueLength': 20,
    };

Map<String, Object?> _shared({int value = 1, String handle = 'shared'}) => {
      'handle': handle,
      'uuid': '1810',
      'isPrimary': false,
      'includedServices': [],
      'characteristics': [
        {
          'handle': '$handle-c',
          'uuid': '2a35',
          'properties': 18,
          'permissions': 1,
          'value': [value],
          'descriptors': [
            {'handle': '$handle-d', 'uuid': '2901', 'value': 'value $value'}
          ],
          'subscribedCentrals': [],
        }
      ],
    };

Map<String, Object?> _root(String handle, {int value = 1, String includedHandle = 'shared'}) => {
      'handle': handle,
      'uuid': '180f',
      'isPrimary': true,
      'includedServices': [_shared(value: value, handle: includedHandle)],
      'characteristics': [],
    };

cb.CBMutableCharacteristic _characteristic(cb.CBService root) =>
    root.includedServices!.single.characteristics!.single as cb.CBMutableCharacteristic;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  late cb.CBPeripheralManager manager;
  setUp(() async {
    host = CoreBluetoothTestHost()..setUp();
    manager = host.track(cb.CBPeripheralManager.createIsolated());
    await manager.ready;
    await host.emit('peripheralManagerWillRestoreState', {
      'services': [_root('first'), _root('second')]
    });
  });
  tearDown(() => host.tearDown());

  test('shared restored services, characteristics and descriptors have one identity', () {
    final first = manager.services.first.includedServices!.single;
    final second = manager.services.last.includedServices!.single;
    expect(first, same(second));
    final characteristic = first.characteristics!.single;
    expect(characteristic, same(second.characteristics!.single));
    expect(characteristic.service, same(first));
    final descriptor = characteristic.descriptors!.single;
    expect(descriptor, same(second.characteristics!.single.descriptors!.single));
    expect(descriptor.characteristic, same(characteristic));
  });

  test('subscriptions remain consistent through either root and after one root is removed', () async {
    final characteristic = _characteristic(manager.services.first);
    final subscribed = manager.onDidSubscribeToCharacteristic.first;
    await host.emit('peripheralManagerDidSubscribeToCharacteristic', {
      'characteristicHandle': 'shared-c',
      'central': _central(),
    });
    expect((await subscribed).characteristic, same(characteristic));
    expect(_characteristic(manager.services.last).subscribedCentrals, hasLength(1));
    await manager.remove(manager.services.first);
    expect(_characteristic(manager.services.single), same(characteristic));
    expect(characteristic.subscribedCentrals, hasLength(1));
    final unsubscribed = manager.onDidUnsubscribeFromCharacteristic.first;
    await host.emit('peripheralManagerDidUnsubscribeFromCharacteristic', {
      'characteristicHandle': 'shared-c',
      'central': _central(),
    });
    expect((await unsubscribed).characteristic, same(characteristic));
    expect(characteristic.subscribedCentrals, isEmpty);
  });

  test('ATT reads and writes use the characteristic shared by both roots', () async {
    final characteristic = _characteristic(manager.services.last);
    final request = {
      'requestHandle': 'read',
      'characteristicHandle': 'shared-c',
      'central': _central(),
      'offset': 0,
    };
    final reading = manager.onDidReceiveReadRequest.first;
    await host.emit('peripheralManagerDidReceiveRead', request);
    final read = (await reading).request;
    expect(read.characteristic, same(characteristic));
    await manager.respond(to: read, withResult: cb.CBATTErrorCode.success);
    final writing = manager.onDidReceiveWriteRequests.first;
    await host.emit('peripheralManagerDidReceiveWrite', {
      'requests': [
        {
          ...request,
          'requestHandle': 'write',
          'value': [7]
        }
      ]
    });
    expect((await writing).requests.single.characteristic, same(characteristic));
  });

  test('replacement restoration preserves retained objects and applies fresh values', () async {
    final service = manager.services.first.includedServices!.single;
    final characteristic = _characteristic(manager.services.first);
    final descriptor = characteristic.descriptors!.single;
    final restored = manager.onWillRestoreState.first;
    await host.emit('peripheralManagerWillRestoreState', {
      'services': [_root('second', value: 7), _root('third', value: 7)]
    });
    expect((await restored).services.first, same(manager.services.first));
    for (final root in manager.services) {
      expect(root.includedServices!.single, same(service));
      expect(_characteristic(root), same(characteristic));
      expect(_characteristic(root).value, [7]);
      expect(_characteristic(root).descriptors!.single, same(descriptor));
    }
    expect(descriptor.value, 'value 7');
  });

  test('a published service retains caller identity when also restored as an included service', () async {
    await manager.removeAllServices();
    final shared = cb.CBMutableService.type(type: cb.CBUUID('1810'), primary: false);
    await manager.add(shared);
    final snapshot = {...shared.toMap(), 'handle': 'shared'};
    await host.emit('peripheralManagerDidAddService', {'service': snapshot});
    await host.emit('peripheralManagerWillRestoreState', {
      'services': [
        {
          ..._root('root'),
          'includedServices': [snapshot]
        },
        snapshot,
      ]
    });
    expect(manager.services.last, same(shared));
    expect(manager.services.first.includedServices!.single, same(shared));
  });

  test('replacement handles produce new objects and separate managers never share wrappers', () async {
    final previous = manager.services.first.includedServices!.single;
    await host.emit('peripheralManagerWillRestoreState', {
      'services': [_root('first', includedHandle: 'replacement'), _root('second', includedHandle: 'replacement')]
    });
    final replacement = manager.services.first.includedServices!.single;
    expect(replacement, isNot(same(previous)));
    expect(replacement, same(manager.services.last.includedServices!.single));
    final other = host.track(cb.CBPeripheralManager.createIsolated());
    await other.ready;
    await host.emit(
        'peripheralManagerWillRestoreState',
        {
          'services': [_root('first', includedHandle: 'replacement')]
        },
        id: 2);
    expect(other.services.first.includedServices!.single, isNot(same(replacement)));
  });

  test('Dart notification targets preserve null, empty and explicit selections', () async {
    final characteristic = _characteristic(manager.services.first);
    final central = cb.CBCentral.fromMap(_central());
    for (final selection in <List<cb.CBCentral>?>[
      null,
      [],
      [central]
    ]) {
      await manager.updateValue(characteristic.value!,
          forCharacteristic: characteristic, onSubscribedCentrals: selection);
      expect((host.calls.last.arguments as Map)['centralIdentifiers'],
          selection?.map((c) => c.identifier.uuidString).toList());
    }
  });

  test('publishing parents keeps an already published included service and attribute handles stable', () async {
    await manager.removeAllServices();
    final descriptor = cb.CBMutableDescriptor.type(type: cb.CBUUID('2901'), value: 'test');
    final characteristic = cb.CBMutableCharacteristic.type(
      type: cb.CBUUID('2a35'),
      properties: cb.CBCharacteristicProperties.notify,
      permissions: cb.CBAttributePermissions.readable,
      descriptors: [descriptor],
    );
    final leaf = cb.CBMutableService.type(type: cb.CBUUID('1810'), primary: false, characteristics: [characteristic]);
    await manager.add(leaf);
    await host.emit('peripheralManagerDidAddService', {
      'service': {
        ...leaf.toMap(),
        'handle': 'published-leaf',
        'characteristics': [
          {
            ...characteristic.toMap(),
            'handle': 'published-c',
            'descriptors': [
              {...descriptor.toMap(), 'handle': 'published-d'}
            ],
          }
        ],
      }
    });
    final parents = <cb.CBMutableService>[];
    for (var i = 0; i < 2; i++) {
      final parent = cb.CBMutableService.type(type: cb.CBUUID('180f'), primary: true, includedServices: [leaf]);
      parents.add(parent);
      await manager.add(parent);
      final submitted = (host.calls.last.arguments as Map)['service'] as Map;
      expect((submitted['includedServices'] as List).single['handle'], 'published-leaf');
      await host.emit('peripheralManagerDidAddService', {
        'service': {...parent.toMap(), 'handle': 'parent-$i'}
      });
      expect(parent.includedServices!.single, same(leaf));
      expect(leaf.characteristics!.single, same(characteristic));
      expect(characteristic.descriptors!.single, same(descriptor));
      expect([leaf.handle, characteristic.handle, descriptor.handle], ['published-leaf', 'published-c', 'published-d']);
    }
    await manager.remove(leaf);
    expect((host.calls.last.arguments as Map)['serviceHandle'], 'published-leaf');
    expect(manager.services, parents);
    final subscription = manager.onDidSubscribeToCharacteristic.first;
    await host.emit('peripheralManagerDidSubscribeToCharacteristic', {
      'characteristicHandle': 'published-c',
      'central': _central(),
    });
    expect((await subscription).characteristic, same(characteristic));
    expect(characteristic.subscribedCentrals, hasLength(1));
  });

  test('a central from an answered ATT request can be used for a latency request', () async {
    final callback = manager.onDidReceiveReadRequest.first;
    await host.emit('peripheralManagerDidReceiveRead', {
      'requestHandle': 'latency-read',
      'characteristicHandle': 'shared-c',
      'central': _central(),
      'offset': 0,
    });
    final request = (await callback).request;
    expect(_characteristic(manager.services.first).subscribedCentrals, isEmpty);
    await manager.respond(to: request, withResult: cb.CBATTErrorCode.success);
    await manager.setDesiredConnectionLatency(cb.CBPeripheralManagerConnectionLatency.medium,
        forCentral: request.central);
    expect(host.calls.last.method, 'peripheralManager.setDesiredConnectionLatency');
    expect(host.calls.last.arguments, {
      'managerId': 1,
      'centralIdentifier': request.central.identifier.uuidString,
      'latency': 1,
    });
  });
}
