import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_darwin/flutter_blue_plus_darwin.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('main package logs Darwin requests and callbacks while forwarding native log settings', () async {
    final backend = FlutterBluePlusDarwin();
    FlutterBluePlusPlatform.instance = backend;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(backend.methodChannel, (call) async {
      calls.add(call);
      return call.method == 'flutterRestart' ? 0 : true;
    });
    final logs = <String>[];
    final subscription = FlutterBluePlus.logs.listen(logs.add);
    try {
      await FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);
      expect(await FlutterBluePlus.isSupported, isTrue);
      // ignore: deprecated_member_use
      await messenger.handlePlatformMessage(
          backend.methodChannel.name,
          const StandardMethodCodec().encodeMethodCall(const MethodCall('OnReadRssi', {
            'remote_id': 'AA:BB:CC:DD:EE:FF',
            'rssi': -39,
            'success': 1,
            'error_code': 0,
            'error_string': '',
          })),
          (_) {});
      await Future<void>.delayed(Duration.zero);
      expect(calls.singleWhere((call) => call.method == 'setLogLevel').arguments, LogLevel.verbose.index);
      expect(logs.where((line) => line.contains('<isSupported> args:')), hasLength(1));
      expect(logs.where((line) => line.contains('(isSupported) result: true')), hasLength(1));
      expect(logs.where((line) => line.contains('[[ OnReadRssi ]]')), hasLength(1));
      expect(logs.singleWhere((line) => line.contains('[[ OnReadRssi ]]')), contains('rssi: -39'));
      expect(logs.any((line) => line.contains('\x1b')), isFalse);
    } finally {
      await subscription.cancel();
      messenger.setMockMethodCallHandler(backend.methodChannel, null);
    }
  });
}
