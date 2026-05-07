import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

Map<String, Object?> _snapshot(cb.CBMutableService service, int permissions, Object? descriptorValue) {
  final characteristic = service.characteristics!.single as cb.CBMutableCharacteristic;
  final descriptor = characteristic.descriptors!.single as cb.CBMutableDescriptor;
  return {
    ...service.toMap(),
    'handle': 's',
    'characteristics': [
      {
        ...characteristic.toMap(),
        'handle': 'c',
        'permissions': permissions,
        'descriptors': [
          {...descriptor.toMap(), 'handle': 'd', 'value': descriptorValue}
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
  final format = Uint8List.fromList([4, 0, 0, 0x27, 1, 0, 0]);
  setUp(() async {
    host = CoreBluetoothTestHost()..setUp();
    manager = host.track(cb.CBPeripheralManager.createIsolated());
    await manager.ready;
    descriptor = cb.CBMutableDescriptor.type(type: cb.CBUUID('2904'), value: format);
    characteristic = cb.CBMutableCharacteristic.type(
      type: cb.CBUUID('2a19'),
      properties: const cb.CBCharacteristicProperties(10),
      permissions: const cb.CBAttributePermissions(3),
      descriptors: [descriptor],
    );
    service = cb.CBMutableService.type(type: cb.CBUUID('180f'), primary: true, characteristics: [characteristic]);
  });
  tearDown(() => host.tearDown());

  test('add and restoration refresh broadcast state on the retained characteristic', () async {
    Map<String, Object?> snapshot(bool broadcasted) {
      final result = _snapshot(service, 3, format);
      final nativeCharacteristic = (result['characteristics'] as List).single as Map;
      nativeCharacteristic['isBroadcasted'] = broadcasted;
      return result;
    }

    expect(characteristic.isBroadcasted, isFalse);
    await manager.add(service);
    final added = manager.onDidAddService.first;
    await host.emit('peripheralManagerDidAddService', {'service': snapshot(true)});
    expect((await added).service.characteristics!.single, same(characteristic));
    expect(characteristic.isBroadcasted, isTrue);
    final restored = manager.onWillRestoreState.first;
    await host.emit('peripheralManagerWillRestoreState', {
      'services': [snapshot(false)]
    });
    expect((await restored).services.single.characteristics!.single, same(characteristic));
    expect(characteristic.isBroadcasted, isFalse);
  });

  for (final permissions in [3, 12, 0]) {
    test('add callback and republishing preserve permission bits $permissions and typed descriptor bytes', () async {
      await manager.add(service);
      final added = manager.onDidAddService.first;
      await host.emit('peripheralManagerDidAddService', {'service': _snapshot(service, permissions, format)});
      expect((await added).service, same(service));
      expect(service.characteristics!.single, same(characteristic));
      expect(characteristic.permissions.rawValue, permissions);
      expect(characteristic.descriptors!.single, same(descriptor));
      expect(descriptor.value, isA<Uint8List>());
      expect(descriptor.value, format);
      await manager.removeAllServices();
      await manager.add(service);
      final submitted = (host.calls.last.arguments as Map)['service'] as Map;
      final submittedCharacteristic = (submitted['characteristics'] as List).single as Map;
      final submittedDescriptor = (submittedCharacteristic['descriptors'] as List).single as Map;
      expect(submittedCharacteristic['permissions'], permissions);
      expect(submittedDescriptor['value'], isA<Uint8List>());
      expect(submittedDescriptor['value'], format);
    });
  }

  test('restoration refreshes permissions and descriptor bytes on the retained caller objects', () async {
    await manager.add(service);
    await host.emit('peripheralManagerDidAddService', {'service': _snapshot(service, 3, format)});
    final refreshed = Uint8List.fromList([6, 0, 0, 0x27, 1, 0, 0]);
    final restoring = manager.onWillRestoreState.first;
    await host.emit('peripheralManagerWillRestoreState', {
      'services': [_snapshot(service, 12, refreshed)]
    });
    expect((await restoring).services.single, same(service));
    expect(service.characteristics!.single, same(characteristic));
    expect(characteristic.permissions.rawValue, 12);
    expect(characteristic.descriptors!.single, same(descriptor));
    expect(descriptor.value, refreshed);
  });

  for (final uuid in ['2901', '2904']) {
    test('a rejected $uuid descriptor can be corrected and the same service retried', () async {
      final invalid = uuid == '2901' ? null : 'wrong type';
      final Object valid = uuid == '2901' ? 'Description' : format;
      descriptor = cb.CBMutableDescriptor.type(type: cb.CBUUID(uuid), value: invalid);
      characteristic.descriptors = [descriptor];
      host.handle = (call) {
        if (call.method == 'peripheralManager.addService') {
          final submitted = (call.arguments as Map)['service'] as Map;
          final submittedCharacteristic = (submitted['characteristics'] as List).single as Map;
          expect((submittedCharacteristic['descriptors'] as List).single['value'], invalid);
          throw PlatformException(code: 'invalid_args', message: 'Invalid descriptor value');
        }
        return null;
      };
      await expectLater(manager.add(service),
          throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'invalid_args')));
      expect(manager.services, isEmpty);
      descriptor.value = valid;
      host.handle = null;
      await manager.add(service);
      final added = manager.onDidAddService.first;
      await host.emit('peripheralManagerDidAddService', {'service': _snapshot(service, 3, valid)});
      expect((await added).error, isNull);
      expect(manager.services.single, same(service));
      expect(characteristic.descriptors!.single, same(descriptor));
      expect(descriptor.value, valid);
    });
  }
}
