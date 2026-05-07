import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('typed advertising listeners share buffered callbacks and finish after stop', () async {
    final id = 'advertising-set-replay-${host.sequence++}';
    host.override = (call) async {
      if (call.method == 'advertise.startSet') {
        await emit({'owner': id, 'type': 'onAdvertisingSetStarted', 'status': 0, 'txPower': -7});
        await emit({'owner': id, 'type': 'onAdvertisingEnabled', 'status': 0, 'enabled': true});
        return id;
      }
      if (call.method == 'advertise.stopSet') return true;
      return null;
    };
    final set = await BluetoothLeAdvertiser.shared.startAdvertisingSet(parameters: const AdvertisingSetParameters());
    final started = set.onAdvertisingSetStarted.toList();
    final enabled = set.onAdvertisingEnabled.toList();
    final all = set.events.toList();
    await tick();
    await set.stop();
    await emit({'owner': id, 'type': 'onAdvertisingSetStopped'});
    expect((await started).single.txPower, -7);
    expect((await enabled).single.enabled, isTrue);
    expect((await all).map((event) => event.type),
        ['onAdvertisingSetStarted', 'onAdvertisingEnabled', 'onAdvertisingSetStopped']);
  });

  test('advertising stop delivers its final callback before stream completion', () async {
    final id = 'advertising-set-lifecycle-${host.sequence++}';
    host.override = (call) async => switch (call.method) {
          'advertise.startSet' => id,
          'advertise.stopSet' => true,
          _ => null,
        };
    final set = await BluetoothLeAdvertiser.shared.startAdvertisingSet(parameters: const AdvertisingSetParameters());
    final received = <AdvertisingSetCallback>[];
    final finished = set.events.toList().then(received.addAll);
    await emit({'owner': id, 'type': 'onAdvertisingSetStarted', 'status': 0, 'txPower': -7});
    await set.stop();
    await set.stop();
    await emit({'owner': id, 'type': 'onAdvertisingSetStopped'});
    await finished;
    expect(received.map((event) => event.type), ['onAdvertisingSetStarted', 'onAdvertisingSetStopped']);
    expect(host.calls.where((call) => call.method == 'advertise.stopSet'), hasLength(1));
    await expectLater(set.enableAdvertising(true), throwsStateError);
  });

  for (final listenAfterStop in [false, true]) {
    test('pending cancellation finishes without native callbacks (late listener: $listenAfterStop)', () async {
      final id = 'advertising-set-cancel-${host.sequence++}';
      host.override = (call) async => switch (call.method) {
            'advertise.startSet' => id,
            'advertise.stopSet' => false,
            _ => null,
          };
      final globalEvents = <BluetoothEvent>[];
      final global = AndroidBluetooth.events.listen(globalEvents.add);
      final set = await BluetoothLeAdvertiser.shared.startAdvertisingSet(parameters: const AdvertisingSetParameters());
      final listening = listenAfterStop ? null : set.events.toList();
      try {
        await Future.wait([set.stop(), set.stop()]);
        await set.stop();
        expect(await (listening ?? set.events.toList()).timeout(const Duration(seconds: 1)), isEmpty);
        expect(await set.onAdvertisingSetStopped.toList(), isEmpty);
        expect(host.calls.where((call) => call.method == 'advertise.stopSet'), hasLength(1));
        await emit({'owner': id, 'type': 'onAdvertisingSetStarted', 'status': 0, 'txPower': -7});
        await emit({'owner': id, 'type': 'onAdvertisingSetStopped'});
        expect(globalEvents, isEmpty);
        await expectLater(set.enableAdvertising(true), throwsStateError);
      } finally {
        await global.cancel();
      }
    });
  }

  test('failed pending stop can receive startup and retry with a terminal callback', () async {
    final id = 'advertising-set-retry-${host.sequence++}';
    var attempts = 0;
    host.override = (call) async {
      if (call.method == 'advertise.startSet') return id;
      if (call.method == 'advertise.stopSet') {
        if (attempts++ == 0) throw PlatformException(code: 'permission_denied');
        return true;
      }
      return null;
    };
    final set = await BluetoothLeAdvertiser.shared.startAdvertisingSet(parameters: const AdvertisingSetParameters());
    var done = false;
    final received = <AdvertisingSetCallback>[];
    final subscription = set.events.listen(received.add, onDone: () => done = true);
    try {
      await expectLater(set.stop(), throwsA(isA<PlatformException>()));
      await tick();
      expect(done, isFalse);
      await emit({'owner': id, 'type': 'onAdvertisingSetStarted', 'status': 0, 'txPower': -7});
      await set.enableAdvertising(true);
      await set.stop();
      await tick();
      expect(done, isFalse);
      await emit({'owner': id, 'type': 'onAdvertisingSetStopped'});
      await tick();
      expect(done, isTrue);
      expect(received.map((event) => event.type), ['onAdvertisingSetStarted', 'onAdvertisingSetStopped']);
      expect(attempts, 2);
    } finally {
      await subscription.cancel();
    }
  });

  test('stopped callback before the stop reply is preserved exactly once', () async {
    final id = 'advertising-set-early-stop-${host.sequence++}';
    host.override = (call) async {
      if (call.method == 'advertise.startSet') return id;
      if (call.method == 'advertise.stopSet') {
        await emit({'owner': id, 'type': 'onAdvertisingSetStopped'});
        return true;
      }
      return null;
    };
    final set = await BluetoothLeAdvertiser.shared.startAdvertisingSet(parameters: const AdvertisingSetParameters());
    final received = set.events.toList();
    await emit({'owner': id, 'type': 'onAdvertisingSetStarted', 'status': 0, 'txPower': -7});
    await set.stop();
    await set.stop();
    expect((await received).map((event) => event.type), ['onAdvertisingSetStarted', 'onAdvertisingSetStopped']);
    expect(host.calls.where((call) => call.method == 'advertise.stopSet'), hasLength(1));
  });

  test('global observers preserve an early failed advertisement until its owner listens', () async {
    final id = 'advertisement-failed-${host.sequence++}';
    final globalEvents = <BluetoothEvent>[];
    final global = AndroidBluetooth.events.listen(globalEvents.add);
    host.override = (call) async {
      if (call.method == 'advertise.start') {
        await emit({'owner': id, 'type': 'onStartFailure', 'errorCode': 5});
        return id;
      }
      return null;
    };
    try {
      final advertisement = await BluetoothLeAdvertiser.shared.startAdvertising(data: const AdvertiseData());
      expect((await advertisement.events.toList()).single, isA<AdvertiseFailedResult>());
      expect(globalEvents.single, isA<AdvertiseFailedResult>());
      await advertisement.stop();
      expect(host.calls.where((call) => call.method == 'advertise.stop'), isEmpty);
    } finally {
      await global.cancel();
    }
  });
}
