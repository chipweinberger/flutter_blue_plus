import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothHost host;
  setUp(() {
    host = CoreBluetoothHost();
  });
  tearDown(() => host.tearDown());

  test('connect rechecks Bluetooth power after peripheral retrieval', () async {
    await host.setUp();
    final started = Completer<void>();
    final reply = Completer<Object?>();
    host.handle = (call) async {
      if (call.method == 'centralManager.retrievePeripherals') {
        started.complete();
        return await reply.future;
      }
      return null;
    };
    final result = expectLater(
        host.backend.connect(BmConnectRequest(remoteId: DeviceIdentifier(deviceId), autoConnect: false)),
        throwsA(isA<PlatformException>()
            .having((error) => error.code, 'code', 'connect')
            .having((error) => error.message, 'message', contains('CBManagerStatePoweredOff'))));
    await started.future;
    await host.emit('didUpdateState', {'state': 4});
    reply.complete([peripheral(state: 0)]);
    await result;
    expect(host.calls.where((call) => call.method == 'centralManager.connect'), isEmpty);

    host.handle = null;
    await host.emit('didUpdateState', {'state': 5});
    await host.connect();
    expect(host.calls.where((call) => call.method == 'centralManager.connect'), hasLength(1));
  });

  test('startup retries a temporary failure without duplicating listeners', () async {
    await host.setUp(initialize: false);
    host.handle = (call) {
      if (call.method == 'centralManager.disconnectAllPeripherals') throw PlatformException(code: 'temporary_failure');
      return null;
    };
    await expectLater(host.backend.isSupported(BmIsSupportedRequest()), throwsA(isA<PlatformException>()));
    host.handle = null;
    expect(await host.backend.isSupported(BmIsSupportedRequest()), isTrue);
    expect(host.calls.where((call) => call.method == 'centralManager.disconnectAllPeripherals'), hasLength(2));
    final states = <BmBluetoothAdapterState>[];
    final subscription = host.backend.onAdapterStateChanged.listen(states.add);
    await host.emit('didUpdateState', {'state': 4});
    expect(states, hasLength(1));
    expect(host.calls.where((call) => call.method == 'centralManager.stopScan'), hasLength(1));
    await subscription.cancel();
  });

  for (final queryFails in [false, true]) {
    test('disposing ignores an outstanding MTU ${queryFails ? 'error' : 'value'}', () async {
      await host.setUp();
      await host.connect();
      final started = Completer<void>();
      final reply = Completer<int>();
      host.handle = (call) async {
        if (call.method == 'peripheral.maximumWriteValueLength') {
          if (!started.isCompleted) started.complete();
          return await reply.future;
        }
        return null;
      };
      final values = <BmMtuChangedResponse>[];
      final subscription = host.backend.onMtuChanged.listen(values.add);
      await started.future;
      await host.backend.dispose().timeout(const Duration(seconds: 1));
      if (queryFails) {
        reply.completeError(PlatformException(code: 'retired_query'));
      } else {
        reply.complete(20);
      }
      await host.pump();
      expect(values, isEmpty);
      await expectLater(host.backend.isSupported(BmIsSupportedRequest()), throwsStateError);
      await host.backend.dispose();
      await subscription.cancel();
    });
  }

  test('a canceled MTU query cannot leak into a new connection', () async {
    await host.setUp();
    await host.connect();
    final started = Completer<void>();
    final oldReply = Completer<int>();
    host.handle = (call) async {
      if (call.method == 'peripheral.maximumWriteValueLength') {
        if (!started.isCompleted) started.complete();
        return await oldReply.future;
      }
      return null;
    };
    final values = <int>[];
    final subscription = host.backend.onMtuChanged.listen((event) => values.add(event.mtu));
    await started.future;
    host.handle = null;
    host.maxPayload = 100;
    await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
    await host.connect();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    expect(values, [103]);
    oldReply.complete(20);
    await host.pump();
    expect(values, [103]);
    await subscription.cancel();
  });

  test('MTU query failures are handled and stop that monitor', () async {
    await host.setUp();
    await host.backend.setLogLevel(BmSetLogLevelRequest(logLevel: LogLevel.error, logColor: false));
    final logs = <String>[];
    final subscription = FlutterBluePlusPlatform.logs.listen(logs.add);
    host.handle = (call) {
      if (call.method == 'peripheral.maximumWriteValueLength') throw PlatformException(code: 'sample_failed');
      return null;
    };
    await host.connect();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(logs.where((line) => line.contains('sample_failed')), hasLength(1));
    expect(host.calls.where((call) => call.method == 'peripheral.maximumWriteValueLength'), hasLength(1));
    await subscription.cancel();
  });

  for (final reconnect in [false, true]) {
    test('obsolete discovery failure is ignored ${reconnect ? 'after reconnection' : 'after another discovery starts'}',
        () async {
      await host.setUp();
      await host.connect();
      final oldReply = Completer<Object?>();
      host.handle = (call) async {
        if (call.method == 'peripheral.discoverCharacteristics') return await oldReply.future;
        return null;
      };
      await host.gatt();
      host.handle = null;
      if (reconnect) {
        await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
        await host.connect();
      }
      final results = <BmDiscoverServicesResult>[];
      final subscription = host.backend.onDiscoveredServices.listen(results.add);
      await host.backend.discoverServices(BmDiscoverServicesRequest(remoteId: DeviceIdentifier(deviceId)));
      oldReply.completeError(PlatformException(code: 'invalid_args', message: 'retired discovery'));
      await host.pump();
      expect(results, isEmpty);
      await host.gatt(services: []);
      expect(results.single.success, isTrue);
      await subscription.cancel();
    });
  }
}
