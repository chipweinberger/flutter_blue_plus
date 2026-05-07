import 'dart:typed_data';

import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('write callback listeners expose native response values, nulls and empty bytes', () async {
    final gatt = await BluetoothDevice(address).connectGatt();
    try {
      for (final response in <List<int>?>[
        [9, 8],
        [1, 2],
        null,
        [],
      ]) {
        final typed = gatt.onCharacteristicWrite.first;
        final all = gatt.events.first;
        await emit({
          'owner': gatt.id,
          'type': 'onCharacteristicWrite',
          'status': response == null ? BluetoothGatt.gattFailure : BluetoothGatt.gattSuccess,
          'characteristic': callbackCharacteristic(),
          'value': response == null ? null : Uint8List.fromList(response),
        });
        final result = await typed;
        final other = await all;
        expect(other, isA<GattCharacteristicWriteResult>());
        expect(result.characteristic.handle, 'char');
        expect(result.status, response == null ? BluetoothGatt.gattFailure : BluetoothGatt.gattSuccess);
        expect(result.value, response);
        expect(other.value, response);
        final bytes = result.value;
        if (bytes != null && bytes.isNotEmpty) {
          try {
            bytes[0] = 255;
          } on UnsupportedError {
            // Modern Dart returns read-only bytes; older Dart returns an isolated copy.
          }
          expect(result.value, response);
          expect(other.value, response);
        }
      }
    } finally {
      await gatt.close();
    }
  });

  test('UUID normalization and validation apply to local GATT models', () {
    expect(BluetoothGattService('180D').uuid, '0000180d-0000-1000-8000-00805f9b34fb');
    expect(BluetoothGattDescriptor('12345678', 1).uuid, '12345678-0000-1000-8000-00805f9b34fb');
    expect(() => BluetoothGattService('invalid'), throwsArgumentError);
    final a = BluetoothGattCharacteristic('2A37', 2, 1), b = BluetoothGattCharacteristic('2A37', 2, 1);
    expect(a.handle, isNot(b.handle));
  });

  test('local UUID lookup preserves first matches, normalization and empty-list behavior', () {
    final firstDescriptor = BluetoothGattDescriptor('2902', 1);
    final firstCharacteristic =
        BluetoothGattCharacteristic('2a37', 2, 1, descriptors: [firstDescriptor, BluetoothGattDescriptor('2902', 1)]);
    final service =
        BluetoothGattService('180d', characteristics: [firstCharacteristic, BluetoothGattCharacteristic('2a37', 2, 1)]);
    expect(service.getCharacteristic('2A37'), same(firstCharacteristic));
    expect(service.getCharacteristic('00002A37-0000-1000-8000-00805F9B34FB'), same(firstCharacteristic));
    expect(service.getCharacteristic('00002a37'), same(firstCharacteristic));
    expect(firstCharacteristic.getDescriptor('00002902'), same(firstDescriptor));
    expect(service.getCharacteristic('2a38'), isNull);
    expect(firstCharacteristic.getDescriptor('2901'), isNull);
    expect(() => service.getCharacteristic('invalid'), throwsArgumentError);
    expect(() => firstCharacteristic.getDescriptor('invalid'), throwsArgumentError);
    expect(BluetoothGattService('180d').getCharacteristic('invalid'), isNull);
    expect(BluetoothGattCharacteristic('2a37', 2, 1).getDescriptor('invalid'), isNull);
  });

  for (final isServer in [false, true]) {
    test('GATT ${isServer ? 'server' : 'client'} lookup retains matching and validation order', () async {
      final Future<BluetoothGattService?> Function(String) lookup;
      final Future<void> Function() close;
      if (isServer) {
        final server = await BluetoothManager.shared.openGattServer();
        lookup = server.getService;
        close = server.close;
      } else {
        final client = await BluetoothDevice(address).connectGatt();
        lookup = client.getService;
        close = client.close;
      }
      var graph = [service('s1', []), service('s2', [])];
      host.override = (call) async => call.method.endsWith('.getServices') ? graph : null;
      try {
        expect((await lookup('180D'))?.handle, 's1');
        expect((await lookup('0000180D-0000-1000-8000-00805F9B34FB'))?.handle, 's1');
        expect((await lookup('0000180d'))?.handle, 's1');
        expect(await lookup('180f'), isNull);
        await expectLater(lookup('invalid'), throwsArgumentError);
        graph = [];
        expect(await lookup('invalid'), isNull);
        host.override = (call) async {
          if (call.method.endsWith('.getServices')) throw PlatformException(code: 'permission_denied');
          return null;
        };
        await expectLater(lookup('invalid'),
            throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'permission_denied')));
      } finally {
        await close();
      }
    });
  }

  test('request acceptance resolves without manufacturing a completion event', () async {
    final gatt = await BluetoothDevice(address).connectGatt(autoConnect: true, phy: BluetoothDevice.phyLe2mMask);
    expect(host.calls.last.arguments, containsPair('autoConnect', true));
    expect(host.calls.last.arguments, containsPair('phy', 2));
    final received = <BluetoothGattCallback>[];
    final sub = gatt.events.listen(received.add);
    expect(await gatt.discoverServices(), true);
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
    await sub.cancel();
    await gatt.close();
  });

  test('duplicate UUIDs retain native instance handles across the complete graph', () async {
    final gatt = await BluetoothDevice(address).connectGatt();
    final services = await gatt.services;
    expect(services[0].uuid, services[1].uuid);
    expect(services[0].handle, isNot(services[1].handle));
    final c1 = services[0].characteristics.single, c2 = services[1].characteristics.single;
    expect(c1.uuid, c2.uuid);
    expect(c1.handle, isNot(c2.handle));
    expect(c1.getDescriptor('2902')?.handle, 'd1');
    expect(await gatt.readCharacteristic(c2), false);
    expect(host.calls.last.arguments, containsPair('handle', 'c2'));
    expect(await gatt.writeCharacteristic(c1, Uint8List.fromList([255, 0]), writeType: 1), 0);
    expect(host.calls.last.arguments, containsPair('handle', 'c1'));
    expect(host.calls.last.arguments, containsPair('value', [255, 0]));
    await gatt.close();
  });

  test('local notification routing does not silently issue a CCCD write', () async {
    final gatt = await BluetoothDevice(address).connectGatt();
    final c = (await gatt.services).first.characteristics.single;
    host.override = (_) async => true;
    host.calls.clear();
    expect(await gatt.setCharacteristicNotification(c, true), true);
    expect(host.calls.map((c) => c.method), ['gatt.setCharacteristicNotification']);
    host.override = null;
    await gatt.close();
  });
}
