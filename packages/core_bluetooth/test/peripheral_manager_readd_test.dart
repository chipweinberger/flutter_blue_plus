import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

const _error = {'domain': 'ReAddTest', 'code': 7, 'localizedDescription': 'Re-add failed'};

Map<String, Object?> _snapshot(cb.CBMutableService service) {
  final characteristic = service.characteristics!.single as cb.CBMutableCharacteristic;
  final descriptor = characteristic.descriptors!.single as cb.CBMutableDescriptor;
  return {
    ...service.toMap(),
    'handle': 's',
    'characteristics': [
      {
        ...characteristic.toMap(),
        'handle': 'c',
        'descriptors': [
          {...descriptor.toMap(), 'handle': 'd'}
        ],
      }
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  late cb.CBPeripheralManager manager;
  late cb.CBMutableService service;
  late cb.CBMutableCharacteristic characteristic;
  late cb.CBMutableDescriptor descriptor;
  setUp(() async {
    host = CoreBluetoothTestHost()..setUp();
    manager = host.track(cb.CBPeripheralManager.createIsolated());
    descriptor = cb.CBMutableDescriptor.type(type: cb.CBUUID('2901'), value: 'Battery');
    characteristic = cb.CBMutableCharacteristic.type(
      type: cb.CBUUID('2a19'),
      properties: const cb.CBCharacteristicProperties(18),
      permissions: cb.CBAttributePermissions.readable,
      descriptors: [descriptor],
    );
    service = cb.CBMutableService.type(type: cb.CBUUID('180f'), primary: true, characteristics: [characteristic]);
    await manager.add(service);
    await host.emit('peripheralManagerDidAddService', {'service': _snapshot(service)});
  });
  tearDown(() => host.tearDown());

  test('failed re-add callbacks preserve published service identity, handles and native errors', () async {
    await manager.add(service);
    final callback = manager.onDidAddService.first;
    await host.emit('peripheralManagerDidAddService', {'service': _snapshot(service), 'error': _error});
    final result = await callback;
    expect(result.service, same(service));
    expect(result.error!.domain, 'ReAddTest');
    expect(result.error!.code.rawValue, 7);
    expect(result.error!.localizedDescription, 'Re-add failed');
    expect(manager.services.single, same(service));
    expect(service.characteristics!.single, same(characteristic));
    expect(characteristic.descriptors!.single, same(descriptor));
    expect([service.handle, characteristic.handle, descriptor.handle], ['s', 'c', 'd']);
    host.handle = (call) => call.method == 'peripheralManager.updateValue' ? true : null;
    expect(await manager.updateValue(Uint8List.fromList([1]), forCharacteristic: characteristic), isTrue);
    expect((host.calls.last.arguments as Map)['characteristicHandle'], 'c');
    await manager.remove(service);
    expect(manager.services, isEmpty);
  });

  test('a submission failure after a failed re-add callback preserves a removable publication', () async {
    for (var i = 0; i < 2; i++) {
      await manager.add(service);
      await host.emit('peripheralManagerDidAddService', {'service': _snapshot(service), 'error': _error});
    }
    host.handle = (call) {
      if (call.method == 'peripheralManager.addService') throw PlatformException(code: 'submission_failed');
      return null;
    };
    await expectLater(manager.add(service), throwsA(isA<PlatformException>()));
    expect(manager.services.single, same(service));
    await manager.remove(service);
    expect(manager.services, isEmpty);
  });

  for (final cleanup in ['remove', 'removeAll', 'poweredOff', 'resetting', 'dispose']) {
    test('late re-add failure cannot revive a service after $cleanup', () async {
      await manager.add(service);
      final snapshot = _snapshot(service);
      switch (cleanup) {
        case 'remove':
          await manager.remove(service);
        case 'removeAll':
          await manager.removeAllServices();
        case 'poweredOff':
          await host.emit('peripheralManagerDidUpdateState', {'state': 4});
        case 'resetting':
          await host.emit('peripheralManagerDidUpdateState', {'state': 1});
        case 'dispose':
          await manager.dispose();
      }
      await host.emit('peripheralManagerDidAddService', {'service': snapshot, 'error': _error});
      expect(manager.services, isEmpty);
      if (cleanup != 'dispose') {
        await host.emit('peripheralManagerDidUpdateState', {'state': 5});
        expect(manager.services, isEmpty);
      }
    });
  }
}
