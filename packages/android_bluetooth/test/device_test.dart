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

  test('explicit random LE address type reaches native connection requests', () async {
    host.override = (call) async => call.method == 'adapter.remoteLeDevice'
        ? {'address': address, 'addressType': BluetoothDevice.addressTypeRandom}
        : call.method == 'gatt.open'
            ? 'gatt-typed-address'
            : null;
    final device = await BluetoothAdapter.shared.getRemoteLeDevice(address, BluetoothDevice.addressTypeRandom);
    final gatt = await device.connectGatt();
    expect(host.calls.last.arguments, containsPair('addressType', BluetoothDevice.addressTypeRandom));
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
