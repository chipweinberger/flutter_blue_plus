import 'dart:typed_data';

import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('an early connection callback survives until the returned client is subscribed', () async {
    host.override = (call) async {
      if (call.method == 'gatt.open') {
        await emit({
          'owner': 'early-gatt',
          'type': 'onConnectionStateChange',
          'status': 0,
          'newState': BluetoothProfile.stateConnected,
          'device': {'address': address}
        });
        return 'early-gatt';
      }
      return null;
    };
    final gatt = await BluetoothDevice(address).connectGatt();
    final event = await gatt.onConnectionStateChange.first;
    expect(event.newState, BluetoothProfile.stateConnected);
    expect(event.device.address, address);
    await gatt.close();
  });

  test('callbacks route by registration and preserve error status and value snapshots', () async {
    final a = await BluetoothDevice(address).connectGatt(), b = await BluetoothDevice(address).connectGatt();
    final seenA = <BluetoothGattCallback>[], seenB = <BluetoothGattCallback>[];
    final subA = a.onCharacteristicRead.listen(seenA.add), subB = b.onCharacteristicRead.listen(seenB.add);
    final ownerA = (host.calls.first.arguments as Map?)?['id'];
    expect(ownerA, isNull); // open chooses a native registration, never an address-based shared client.
    final idA = a.id;
    await emit({
      'owner': idA,
      'type': 'onCharacteristicRead',
      'status': 5,
      'characteristic': characteristic('c1'),
      'value': Uint8List.fromList([128, 255])
    });
    expect(seenA.single.status, 5);
    expect(seenA.single.value, [128, 255]);
    expect(seenB, isEmpty);
    await subA.cancel();
    await subB.cancel();
    await a.close();
    await b.close();
  });

  test('background payload errors reach listeners without ending their streams', () async {
    final globalErrors = <Object>[], ownerErrors = <Object>[];
    final globalEvents = <BluetoothEvent>[], ownerEvents = <CompanionDeviceCallback>[];
    final global = AndroidBluetooth.events.listen(globalEvents.add, onError: globalErrors.add);
    final owner = CompanionDeviceManager.shared.events.listen(ownerEvents.add, onError: ownerErrors.add);
    final details = {
      'owner': 'companion',
      'type': 'onDeviceAppeared',
      'operation': 'receive',
      'exception': 'android.os.BadParcelableException',
      'apiLevel': 36,
    };
    // ignore: deprecated_member_use
    await host.messenger.handlePlatformMessage(eventsChannel.name,
        codec.encodeErrorEnvelope(code: 'background_error', message: 'malformed payload', details: details), (_) {});
    await tick();
    for (final error in [globalErrors.single, ownerErrors.single]) {
      expect(
          error,
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'background_error')
              .having((e) => e.details, 'details', details));
    }
    await emit({'owner': 'companion', 'type': 'onDeviceAppeared', 'address': address});
    expect(globalEvents.single.type, 'onDeviceAppeared');
    expect(ownerEvents.single.address, address);
    await global.cancel();
    await owner.cancel();
  });

  test('global observers preserve callbacks received before the client is returned', () async {
    final id = 'gatt-global-startup-${host.sequence++}';
    final globalEvents = <BluetoothEvent>[];
    final global = AndroidBluetooth.events.listen(globalEvents.add);
    host.override = (call) async {
      if (call.method == 'gatt.open') {
        await emit(connected(id, 2));
        return id;
      }
      return null;
    };
    final gatt = await BluetoothDevice(address).connectGatt();
    final connections = <int>[];
    final local = gatt.onConnectionStateChange.listen((event) => connections.add(event.newState));
    try {
      await tick();
      expect(globalEvents.map((event) => event.data['newState']), [2]);
      expect(connections, [2]);
      await emit(connected(id, 0));
      expect(globalEvents.map((event) => event.data['newState']), [2, 0]);
      expect(connections, [2, 0]);
    } finally {
      await local.cancel();
      await global.cancel();
      await gatt.close();
    }
  });

  test('global observers preserve callbacks across a gap in registration listeners', () async {
    final globalEvents = <BluetoothEvent>[];
    final global = AndroidBluetooth.events.listen(globalEvents.add);
    final gatt = await BluetoothDevice(address).connectGatt();
    final first = <int>[];
    final initial = gatt.onConnectionStateChange.listen((event) => first.add(event.newState));
    await emit(connected(gatt.id, 1));
    await initial.cancel();
    await emit(connected(gatt.id, 2));
    await emit(connected(gatt.id, 0));
    final replayed = <int>[];
    final local = gatt.onConnectionStateChange.listen((event) => replayed.add(event.newState));
    try {
      await tick();
      expect(first, [1]);
      expect(globalEvents.map((event) => event.data['newState']), [1, 2, 0]);
      expect(replayed, [2, 0]);
      await tick();
      expect(globalEvents, hasLength(3));
    } finally {
      await local.cancel();
      await global.cancel();
      await gatt.close();
    }
  });

  test('startup replay reaches typed listeners installed in the same synchronous block', () async {
    final id = 'gatt-listeners-${host.sequence++}';
    host.override = (call) async {
      if (call.method == 'gatt.open') {
        await emit(connected(id, 2));
        return id;
      }
      return null;
    };
    final gatt = await BluetoothDevice(address).connectGatt();
    final connections = <int>[];
    final ignored = gatt.onServicesDiscovered.listen((_) {});
    final expected = gatt.onConnectionStateChange.listen((event) => connections.add(event.newState));
    await tick();
    expect(connections, [2]);
    await ignored.cancel();
    await expected.cancel();
    await gatt.close();
  });

  test('canceling the first listener before replay retains the startup backlog', () async {
    final id = 'gatt-cancel-replay-${host.sequence++}';
    host.override = (call) async {
      if (call.method == 'gatt.open') {
        await emit(connected(id, 2));
        return id;
      }
      return null;
    };
    final gatt = await BluetoothDevice(address).connectGatt();
    final first = gatt.events.listen((_) => fail('canceled listener received replay'));
    await first.cancel();
    expect((await gatt.onConnectionStateChange.first).newState, 2);
    await gatt.close();
  });

  test('startup buffering retains hundreds of callbacks without an event-count limit', () async {
    final id = 'gatt-burst-${host.sequence++}';
    host.override = (call) async {
      if (call.method == 'gatt.open') {
        for (var i = 0; i < 400; i++) {
          await emit(connected(id, i));
        }
        return id;
      }
      return null;
    };
    final gatt = await BluetoothDevice(address).connectGatt();
    final events = await gatt.onConnectionStateChange.take(400).toList();
    expect(events.map((event) => event.newState), List.generate(400, (i) => i));
    await gatt.close();
  });

  test('more than 128 unobserved registrations retain their startup callbacks', () async {
    final clients = <BluetoothGatt>[];
    host.override = (call) async {
      if (call.method == 'gatt.open') {
        final id = 'gatt-many-${host.sequence++}';
        await emit(connected(id, 2));
        return id;
      }
      return null;
    };
    for (var i = 0; i < 160; i++) {
      clients.add(await BluetoothDevice(address).connectGatt());
    }
    for (final gatt in clients) {
      expect((await gatt.onConnectionStateChange.first).newState, 2);
      await gatt.close();
    }
  });

  test('callbacks are retained across a gap with no listeners', () async {
    final gatt = await BluetoothDevice(address).connectGatt();
    final seen = <int>[];
    final sub = gatt.onConnectionStateChange.listen((event) => seen.add(event.newState));
    await emit(connected(gatt.id, 1));
    await sub.cancel();
    await emit(connected(gatt.id, 2));
    await emit(connected(gatt.id, 0));
    expect((await gatt.onConnectionStateChange.take(2).toList()).map((e) => e.newState), [2, 0]);
    expect(seen, [1]);
    await gatt.close();
  });

  test('engine detach retires sessions and the next engine can reconnect the event channel', () async {
    var listens = 0;
    host.messenger.setMockMethodCallHandler(eventsChannel, (call) async {
      if (call.method == 'listen') listens++;
      return null;
    });
    final old = await BluetoothDevice(address).connectGatt();
    var done = false;
    final oldEvents = old.events.listen((_) {}, onDone: () => done = true);
    final detached = AndroidBluetooth.onDetachedFromEngine.first;
    final global = <BluetoothEvent>[];
    final allEvents = AndroidBluetooth.events.listen(global.add);
    try {
      await emit({'owner': 'engine', 'type': 'onDetachedFromEngine'});
      // EventChannel's native endOfStream is a null binary message.
      // ignore: deprecated_member_use
      await host.messenger.handlePlatformMessage(eventsChannel.name, null, (_) {});
      await tick();
      expect(await detached, isA<BluetoothEngineEvent>());
      expect(done, isTrue);
      expect(global.single, isA<BluetoothEngineEvent>());
      await expectLater(old.discoverServices(), throwsStateError);
      final fresh = await BluetoothDevice(address).connectGatt();
      final next = fresh.onConnectionStateChange.first;
      await emit(connected(fresh.id, 2));
      expect((await next).newState, 2);
      expect(listens, 1);
      await fresh.close();
    } finally {
      await oldEvents.cancel();
      await allEvents.cancel();
    }
  });
}
