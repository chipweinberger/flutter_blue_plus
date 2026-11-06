import 'package:android_bluetooth/android_bluetooth.dart';
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
    host.override = (call) async => call.method == 'advertise.startSet' ? id : null;
    final set = await BluetoothLeAdvertiser.shared.startAdvertisingSet(parameters: const AdvertisingSetParameters());
    final received = <AdvertisingSetCallback>[];
    final finished = set.events.toList().then(received.addAll);
    await set.stop();
    await set.stop();
    await emit({'owner': id, 'type': 'onAdvertisingSetStopped'});
    await finished;
    expect(received.single, isA<AdvertisingSetStoppedResult>());
    expect(host.calls.where((call) => call.method == 'advertise.stopSet'), hasLength(1));
    await expectLater(set.enableAdvertising(true), throwsStateError);
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
