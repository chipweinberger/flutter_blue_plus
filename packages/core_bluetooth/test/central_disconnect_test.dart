import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

const _id = '12345678-1234-1234-1234-123456789abc';
Map<String, Object?> _peripheral(int state) => {'identifier': _id, 'state': state};

Map<String, Object?> _service({String suffix = '', bool notifying = true}) => {
      'handle': 's$suffix',
      'uuid': '180f',
      'isPrimary': true,
      'characteristics': [
        {
          'handle': 'c$suffix',
          'uuid': '2a19',
          'properties': 18,
          'isNotifying': notifying,
          'descriptors': [
            {'handle': 'd$suffix', 'uuid': '2902'}
          ],
        }
      ],
      'includedServices': suffix.isEmpty ? [_service(suffix: '-included', notifying: notifying)] : [],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  late cb.CBCentralManager manager;
  late cb.CBPeripheral peripheral;
  setUp(() async {
    host = CoreBluetoothTestHost()..setUp();
    host.handle = (call) => call.method == 'centralManager.retrievePeripherals' ? [_peripheral(2)] : null;
    manager = host.trackCentral(cb.CBCentralManager.createIsolated());
    peripheral = (await manager.retrievePeripherals([cb.UUID(_id)])).single;
    await host.emitCentral('peripheralDidDiscoverServices', {
      'peripheral': _peripheral(2),
      'services': [_service()]
    });
  });
  tearDown(() => host.tearDown());

  for (final modern in [false, true]) {
    test('disconnect clears GATT before callbacks and preserves connection metadata (modern: $modern)', () async {
      final service = peripheral.services!.single;
      final characteristic = service.characteristics!.single;
      final included = service.includedServices!.single.characteristics!.single;
      final updates = <cb.DidUpdateValueForCharacteristicResult>[];
      final subscription = peripheral.onDidUpdateValueForCharacteristic.listen(updates.add);
      addTearDown(subscription.cancel);
      final disconnected = manager.onDidDisconnectPeripheral.first;
      await host.emitCentral('didDisconnectPeripheral', {
        'peripheral': _peripheral(0),
        if (modern) ...{'timestamp': 123.5, 'isReconnecting': true},
        'error': {'domain': 'CBErrorDomain', 'code': 7, 'localizedDescription': 'Link lost'},
      });
      final event = await disconnected;
      expect(event.peripheral, same(peripheral));
      expect(event.error!.code.rawValue, 7);
      expect(event.timestamp, modern ? 123.5 : null);
      expect(event.isReconnecting, modern ? true : null);
      expect(peripheral.services, isNull);
      expect(characteristic.isNotifying, isFalse);
      expect(included.isNotifying, isFalse);
      expect(manager.connectedPeripherals, isEmpty);
      await host.emitCentral('didConnectPeripheral', {'peripheral': _peripheral(2)});
      expect(manager.connectedPeripherals.single, same(peripheral));
      expect(peripheral.services, isNull);
      await host.emitCentral('peripheralDidUpdateValueForCharacteristic', {
        'peripheral': _peripheral(2),
        'characteristicHandle': 'c',
        'value': [7]
      });
      expect(updates, isEmpty);
      await host.emitCentral('peripheralDidDiscoverServices', {
        'peripheral': _peripheral(2),
        'services': [_service(suffix: '-new', notifying: false)]
      });
      expect(peripheral.services!.single, isNot(same(service)));
      final fresh = peripheral.services!.single.characteristics!.single;
      await host.emitCentral('peripheralDidUpdateValueForCharacteristic', {
        'peripheral': _peripheral(2),
        'characteristicHandle': 'c-new',
        'value': [8]
      });
      expect(updates.single.characteristic, same(fresh));
      expect(updates.single.value, [8]);
    });
  }

  test('rediscovery after disconnect creates new wrappers even if native handle strings are reused', () async {
    final service = peripheral.services!.single;
    final characteristic = service.characteristics!.single;
    final descriptor = characteristic.descriptors!.single;
    await host.emitCentral('didDisconnectPeripheral', {'peripheral': _peripheral(0)});
    await host.emitCentral('didConnectPeripheral', {'peripheral': _peripheral(2)});
    await host.emitCentral('peripheralDidDiscoverServices', {
      'peripheral': _peripheral(2),
      'services': [_service(notifying: false)]
    });
    final fresh = peripheral.services!.single;
    expect(fresh, isNot(same(service)));
    expect(fresh.characteristics!.single, isNot(same(characteristic)));
    expect(fresh.characteristics!.single.descriptors!.single, isNot(same(descriptor)));
    expect(characteristic.isNotifying, isFalse);
  });

  test('disconnect preserves another manager and its same-UUID peripheral graph', () async {
    final other = host.trackCentral(cb.CBCentralManager.createIsolated());
    final peer = (await other.retrievePeripherals([cb.UUID(_id)])).single;
    await host.emitCentral(
        'peripheralDidDiscoverServices',
        {
          'peripheral': _peripheral(2),
          'services': [_service(suffix: '-peer')]
        },
        id: 2);
    final peerService = peer.services!.single;
    await host.emitCentral('didDisconnectPeripheral', {'peripheral': _peripheral(0)});
    expect(peripheral.services, isNull);
    expect(peer.services!.single, same(peerService));
    expect(peerService.characteristics!.single.isNotifying, isTrue);
    expect(other.connectedPeripherals.single, same(peer));
  });
}
