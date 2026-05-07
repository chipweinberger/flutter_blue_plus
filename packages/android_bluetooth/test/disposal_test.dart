import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('concurrent and repeated close share one native call and finish the stream', () async {
    final gatt = await BluetoothDevice(address).connectGatt();
    final done = gatt.events.drain<void>();
    await Future.wait([gatt.close(), gatt.close()]);
    await gatt.close();
    await done;
    expect(host.calls.where((call) => call.method == 'gatt.close'), hasLength(1));
    await expectLater(gatt.discoverServices(), throwsStateError);
    expect(await gatt.events.toList(), isEmpty);
  });

  test('close can be retried after a native failure', () async {
    final gatt = await BluetoothDevice(address).connectGatt();
    var attempts = 0;
    host.override = (call) async {
      if (call.method == 'gatt.close' && attempts++ == 0) {
        throw PlatformException(code: 'permission_denied');
      }
      return null;
    };
    await expectLater(gatt.close(), throwsA(isA<PlatformException>()));
    await gatt.close();
    expect(attempts, 2);
  });
}
