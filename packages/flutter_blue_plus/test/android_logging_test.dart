import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../flutter_blue_plus_android/test/support/android_host.dart' as native;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('main package logs Android requests and callbacks without backend duplicates', () async {
    final host = native.AndroidHost();
    await host.setUp();
    final logs = host.collect(FlutterBluePlus.logs);
    try {
      await FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);
      await FlutterBluePlus.startScan();
      await host.advertisement([0]);
      await native.tick();
      expect(logs.where((line) => line.contains('<startScan> args:')), hasLength(1));
      expect(logs.where((line) => line.contains('(startScan) result: true')), hasLength(1));
      expect(logs.where((line) => line.contains('[[ OnScanResponse ]]')), hasLength(1));
      expect(logs.any((line) => line.contains('\x1b')), isFalse);
    } finally {
      await FlutterBluePlus.stopScan();
      await host.tearDown();
    }
  });
}
