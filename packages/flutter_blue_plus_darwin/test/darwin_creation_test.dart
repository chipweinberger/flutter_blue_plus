import 'dart:async';
import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothHost host;
  setUp(() async {
    host = CoreBluetoothHost();
    await host.setUp(initialize: false);
  });
  tearDown(() => host.tearDown());

  test('native manager creation failure is retryable', () async {
    host.handle = (call) {
      if (call.method == 'centralManager.create') throw PlatformException(code: 'create_failed');
      return null;
    };
    await expectLater(host.backend.isSupported(BmIsSupportedRequest()), throwsA(isA<PlatformException>()));
    host.handle = null;
    expect(await host.backend.isSupported(BmIsSupportedRequest()), isTrue);
    expect(host.calls.where((call) => call.method == 'centralManager.create'), hasLength(2));
    expect(cb.CBCentralManager.shared.isInitialized, isTrue);
  });

  test('disposing during creation prevents initialization from continuing', () async {
    await cb.CBCentralManager.shared.dispose();
    host.calls.clear();
    final reply = Completer<Map<String, Object?>>();
    final started = Completer<void>();
    host.handle = (call) async {
      if (call.method == 'centralManager.create') {
        started.complete();
        return await reply.future;
      }
      return null;
    };
    final failure = expectLater(host.backend.isSupported(BmIsSupportedRequest()), throwsStateError);
    await started.future;
    await host.backend.dispose().timeout(const Duration(seconds: 1));
    reply.complete({'managerId': 1, 'state': 5, 'wasReattached': true});
    await failure;
    expect(host.calls.where((call) => call.method == 'centralManager.disconnectAllPeripherals'), isEmpty);
  });

  test('repeated manager disposal waits for the same native cleanup', () async {
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'centralManager.create') return {'managerId': 2, 'state': 5};
      if (call.method == 'centralManager.dispose') return await reply.future;
      return null;
    };
    final manager = cb.CBCentralManager.createIsolated();
    await manager.ready;
    final first = manager.dispose();
    var secondCompleted = false;
    final second = manager.dispose().then((_) {
      secondCompleted = true;
    });
    await host.pump();
    expect(secondCompleted, isFalse);
    expect(host.calls.where((call) => call.method == 'centralManager.dispose'), hasLength(1));
    reply.complete(null);
    await Future.wait([first, second]);
    expect(secondCompleted, isTrue);
  });
}
