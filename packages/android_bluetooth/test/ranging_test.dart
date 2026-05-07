import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('BLE ranging uses Android role/technology constants and centimeter thresholds', () async {
    host.override = (call) async => call.method == 'ranging.create' ? 'test-ranging' : null;
    final session = await RangingManager.shared.createRangingSession();
    await session.start(RangingPreference(
        deviceRole: RangingPreference.deviceRoleInitiator,
        devices: [
          RawRangingDevice(
              uuid: '12345678-1234-5678-1234-567812345678',
              bleRssiRangingParams: const BleRssiRangingParams(peerBluetoothAddress: address))
        ],
        sessionConfig: const SessionConfig(proximityNearCm: 100, proximityFarCm: 200)));
    expect(RangingManager.bleRssi, 3);
    final preference = (host.calls.last.arguments as Map)['preference'] as Map;
    expect(preference['deviceRole'], 1);
    expect(preference['sessionConfig']['proximityNearCm'], 100);
    await session.close();
  });

  test('ranging close delivers the reason before completing its stream', () async {
    final id = 'ranging-lifecycle-${host.sequence++}';
    host.override = (call) async => switch (call.method) {
          'ranging.create' => id,
          'ranging.close' => true,
          _ => null,
        };
    final session = await RangingManager.shared.createRangingSession();
    await session.start(rangingPreference());
    final finished = session.onClosed.toList();
    await session.close();
    await session.close();
    await emit({'owner': id, 'type': 'onClosed', 'reason': 3});
    expect((await finished).single.reason, 3);
    expect(await session.events.toList(), isEmpty);
    expect(host.calls.where((call) => call.method == 'ranging.close'), hasLength(1));
  });

  test('ranging stopped callbacks expose the peer technology without inventing a reason', () async {
    final id = 'ranging-stopped-${host.sequence++}';
    host.override = (call) async => switch (call.method) {
          'ranging.create' => id,
          'ranging.close' => false,
          _ => null,
        };
    final session = await RangingManager.shared.createRangingSession();
    final stopped = session.onStopped.first;
    await emit({
      'owner': id,
      'type': 'onStopped',
      'peerUuid': '12345678-1234-5678-1234-567812345678',
      'technology': RangingManager.bleRssi,
    });
    final event = await stopped;
    final int technology = event.technology;
    expect(technology, RangingManager.bleRssi);
    expect(event.peerUuid, '12345678-1234-5678-1234-567812345678');
    expect(event.reason, isNull);
    await session.close();
  });

  test('closing an unused ranging session finishes without a fabricated callback', () async {
    final id = 'ranging-unused-${host.sequence++}';
    host.override = (call) async => switch (call.method) {
          'ranging.create' => id,
          'ranging.close' => false,
          _ => null,
        };
    final session = await RangingManager.shared.createRangingSession();
    final received = <RangingSessionCallback>[];
    var done = false;
    final sub = session.events.listen(received.add, onDone: () => done = true);
    try {
      await Future.wait([session.close(), session.close()]);
      await tick();
      expect(done, isTrue);
      expect(received, isEmpty);
      expect(host.calls.where((call) => call.method == 'ranging.close'), hasLength(1));
      await expectLater(session.start(rangingPreference()), throwsStateError);
    } finally {
      await sub.cancel();
    }
  });

  test('a failed ranging open can retry and closes without waiting for onClosed', () async {
    final id = 'ranging-failed-open-${host.sequence++}';
    host.override = (call) async => switch (call.method) {
          'ranging.create' => id,
          'ranging.close' => false,
          _ => null,
        };
    final session = await RangingManager.shared.createRangingSession();
    final order = <String>[];
    final sub = session.events.listen((event) => order.add(event.type), onDone: () => order.add('done'));
    try {
      for (var i = 0; i < 2; i++) {
        await session.start(rangingPreference());
        await emit({'owner': id, 'type': 'onOpenFailed', 'reason': 3});
      }
      expect(order, ['onOpenFailed', 'onOpenFailed']);
      await session.close();
      await tick();
      expect(order, ['onOpenFailed', 'onOpenFailed', 'done']);
      expect(host.calls.where((call) => call.method == 'ranging.start'), hasLength(2));
    } finally {
      await sub.cancel();
    }
  });

  for (final early in [false, true]) {
    test('closing a pending ranging start delivers its final open failure (early: $early)', () async {
      final id = 'ranging-closing-open-${host.sequence++}';
      final failure = {'owner': id, 'type': 'onOpenFailed', 'reason': 1, 'isComplete': true};
      host.override = (call) async {
        if (call.method == 'ranging.create') return id;
        if (call.method == 'ranging.close') {
          if (early) await emit(failure);
          return true;
        }
        return null;
      };
      final session = await RangingManager.shared.createRangingSession();
      await session.start(rangingPreference());
      final order = <String>[];
      final sub = session.events.listen((event) => order.add(event.type), onDone: () => order.add('done'));
      try {
        await session.close();
        if (!early) {
          expect(order, isEmpty);
          await emit(failure);
        }
        await tick();
        expect(order, ['onOpenFailed', 'done']);
        expect(await session.events.toList(), isEmpty);
        await session.close();
        expect(host.calls.where((call) => call.method == 'ranging.close'), hasLength(1));
      } finally {
        await sub.cancel();
      }
    });
  }

  test('an operation failure while closing an open ranging session preserves its final onClosed', () async {
    final id = 'ranging-closing-active-${host.sequence++}';
    host.override = (call) async => switch (call.method) {
          'ranging.create' => id,
          'ranging.close' => true,
          _ => null,
        };
    final session = await RangingManager.shared.createRangingSession();
    final order = <String>[];
    final sub = session.events.listen((event) => order.add(event.type), onDone: () => order.add('done'));
    try {
      await session.start(rangingPreference());
      await emit({'owner': id, 'type': 'onOpened'});
      await session.close();
      await emit({'owner': id, 'type': 'onOpenFailed', 'reason': 3, 'isComplete': false});
      expect(order, ['onOpened', 'onOpenFailed']);
      await emit({'owner': id, 'type': 'onClosed', 'reason': 1});
      expect(order, ['onOpened', 'onOpenFailed', 'onClosed', 'done']);
    } finally {
      await sub.cancel();
    }
  });
}
