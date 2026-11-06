import 'dart:typed_data';

import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('device identities normalize addresses without conflating distinct devices', () {
    expect(BluetoothDevice(address.toLowerCase()), BluetoothDevice(address));
    expect(BluetoothDevice(address).hashCode, BluetoothDevice(address).hashCode);
    expect(BluetoothDevice(address), isNot(BluetoothDevice('00:00:00:00:00:01')));
  });

  test('device client lookup shares objects, distinguishes registrations and retires closed clients', () async {
    final device = BluetoothDevice(address);
    final first = await device.connectGatt();
    final second = await device.connectGatt(autoConnect: true);
    final other = await BluetoothDevice('00:00:00:00:00:01').connectGatt();
    expect(BluetoothDevice(address.toLowerCase()).gattClients, [first, second]);
    expect(() => device.gattClients.clear(), throwsUnsupportedError);
    await first.disconnect();
    expect(device.gattClients, [first, second]);
    await first.close();
    expect(device.gattClients, [second]);
    await second.close();
    await other.close();
    expect(device.gattClients, isEmpty);
  });

  test('engine detach clears direct client lookup', () async {
    await BluetoothDevice(address).connectGatt();
    expect(BluetoothDevice(address).gattClients, isNotEmpty);
    await emit({'owner': 'engine', 'type': 'onDetachedFromEngine'});
    expect(BluetoothDevice(address).gattClients, isEmpty);
  });

  test('explicit random LE address type reaches device and connection requests', () async {
    host.override = (call) async => switch (call.method) {
          'adapter.remoteLeDevice' || 'device.get' || 'device.identityAddressWithType' => {
              'address': address,
              'addressType': BluetoothDevice.addressTypeRandom
            },
          'gatt.open' => 'gatt-typed-address',
          'device.bondState' => BluetoothDevice.bondNone,
          'device.setAlias' => BluetoothStatusCodes.success,
          'device.createBond' || 'device.removeBond' || 'device.setPin' || 'device.setPairingConfirmation' => true,
          _ => null,
        };
    final device = await BluetoothAdapter.shared.getRemoteLeDevice(address, BluetoothDevice.addressTypeRandom);
    final gatt = await device.connectGatt();
    expect(host.calls.last.arguments, containsPair('addressType', BluetoothDevice.addressTypeRandom));
    final refreshed = await device.refresh();
    await refreshed.getBondState();
    await refreshed.createBond();
    await refreshed.setPinForNextPairing(Uint8List.fromList([49, 50]));
    await refreshed.setAlias('Sensor');
    await refreshed.setPairingConfirmation(true);
    await refreshed.setPin(Uint8List.fromList([49, 50]));
    await refreshed.removeBond();
    final identity = await refreshed.identityAddressWithType;
    expect(identity.addressType, BluetoothDevice.addressTypeRandom);
    for (final call in host.calls.where((call) => call.method.startsWith('device.'))) {
      expect(call.arguments, containsPair('address', address));
      expect(call.arguments, containsPair('addressType', BluetoothDevice.addressTypeRandom));
    }
    await gatt.close();
  });

  test('permission and unsupported native errors remain structured PlatformExceptions', () async {
    host.override = (_) async =>
        throw PlatformException(code: 'unsupported', message: 'Requires Android API 29', details: {'apiLevel': 26});
    await expectLater(
        BluetoothAdapter.shared.listenUsingL2capChannel(),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'unsupported')
            .having((e) => e.details['apiLevel'], 'apiLevel', 26)));
  });
}
