import 'dart:typed_data';

import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('L2CAP partial reads and EOF remain distinct from socket errors', () async {
    var reads = 0;
    host.override = (call) async {
      switch (call.method) {
        case 'socket.create':
          return {
            'id': 'test-socket',
            'device': {'address': address}
          };
        case 'socket.read':
          return reads++ == 0 ? Uint8List.fromList([1, 2]) : Uint8List(0);
        default:
          return null;
      }
    };
    final socket = await BluetoothDevice(address).createInsecureL2capChannel(129);
    expect(host.calls.last.arguments, containsPair('secure', false));
    expect(await socket.read(maxLength: 400), [1, 2]);
    expect(await socket.read(), isEmpty);
    host.override = (_) async => throw PlatformException(code: 'io_error', message: 'closed');
    await expectLater(socket.read(), throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'io_error')));
  });
}
