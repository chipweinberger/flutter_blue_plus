import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../flutter_blue_plus_darwin/test/support/core_bluetooth_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('main package logs Darwin requests and callbacks once through CoreBluetooth', () async {
    final host = CoreBluetoothHost();
    await host.setUp();
    final logs = <String>[];
    final subscription = FlutterBluePlus.logs.listen(logs.add);
    try {
      await FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);
      expect(await FlutterBluePlus.isSupported, isTrue);
      await host.connect();
      await host.emit('peripheralDidReadRSSI', {'peripheral': peripheral(), 'rssi': -39});
      expect(logs.where((line) => line.contains('<isSupported> args:')), hasLength(1));
      expect(logs.where((line) => line.contains('(isSupported) result: true')), hasLength(1));
      expect(logs.where((line) => line.contains('[[ OnReadRssi ]]')), hasLength(1));
      expect(logs.singleWhere((line) => line.contains('[[ OnReadRssi ]]')), contains('rssi: -39'));
      expect(logs.any((line) => line.contains('\x1b')), isFalse);
    } finally {
      await subscription.cancel();
      await host.tearDown();
    }
  });
}
