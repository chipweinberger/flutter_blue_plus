import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('modern presence callbacks retain association, event type and optional UUID', () async {
    final received = <CompanionDeviceCallback>[];
    final global = <BluetoothEvent>[];
    final subscription = CompanionDeviceManager.shared.events.listen(received.add);
    final globalSubscription = AndroidBluetooth.events.listen(global.add);
    try {
      for (final uuid in [null, '0000180f-0000-1000-8000-00805f9b34fb']) {
        for (var event = 0; event <= 5; event++) {
          await emit({
            'owner': 'companion',
            'type': 'onDevicePresenceEvent',
            'associationId': uuid == null ? 7 : -1,
            'presenceEvent': event,
            'uuid': uuid,
          });
          final callback = received.last;
          expect(callback.type, 'onDevicePresenceEvent');
          expect(callback.associationId, uuid == null ? 7 : -1);
          expect(callback.presenceEvent, event);
          expect(callback.uuid, uuid);
          expect(callback.association, isNull);
          expect(callback.address, isNull);
          expect(callback.isComplete, isFalse);
          expect(global.last, isA<CompanionDeviceCallback>());
        }
      }
      expect(received, hasLength(12));
      expect(global, hasLength(12));
    } finally {
      await subscription.cancel();
      await globalSubscription.cancel();
    }
  });

  for (final type in ['onFailure', 'onAssociationCancelled']) {
    for (final early in [false, true]) {
      test('$type completes and retires a companion request (early: $early)', () async {
        final id = 'association-lifecycle-${host.sequence++}';
        final event = <String, Object?>{
          'owner': id,
          'type': type,
          if (type == 'onFailure') ...{'status': 17, 'message': 'association failed'},
          if (type == 'onAssociationCancelled') 'resultCode': 0,
        };
        host.override = (call) async {
          if (call.method == 'companion.associate') {
            if (early) await emit(event);
            return id;
          }
          return null;
        };
        final request = await CompanionDeviceManager.shared.associate(const AssociationRequest());
        final received = <CompanionDeviceCallback>[];
        final order = <String>[];
        final subscription = request.events.listen((event) {
          received.add(event);
          order.add(event.type);
        }, onDone: () => order.add('done'));
        try {
          if (!early) await emit(event);
          await tick();
          expect(request.id, id);
          expect(order, [type, 'done']);
          if (type == 'onFailure') {
            expect(received.single.status, 17);
            expect(received.single.message, 'association failed');
          } else {
            expect(received.single.resultCode, 0);
          }
          // The request keeps its completed stream instead of opening a new owner hub.
          expect(await request.events.toList(), isEmpty);
          final late = <BluetoothEvent>[];
          final global = AndroidBluetooth.events.listen(late.add);
          try {
            await emit(event);
            expect(late, isEmpty); // A retired request cannot be routed again.
            await emit({'owner': 'companion', 'type': 'onDeviceAppeared', 'address': address});
            expect(late.single.type, 'onDeviceAppeared'); // Manager-wide presence remains live.
          } finally {
            await global.cancel();
          }
        } finally {
          await subscription.cancel();
        }
      });
    }
  }

  test('a pending companion request stays open until its terminal callback', () async {
    final id = 'association-pending-${host.sequence++}';
    host.override = (call) async => call.method == 'companion.associate' ? id : null;
    final request = await CompanionDeviceManager.shared.associate(const AssociationRequest());
    final seen = <String>[];
    var done = false;
    final sub = request.events.listen((event) => seen.add(event.type), onDone: () => done = true);
    try {
      await emit({'owner': id, 'type': 'onAssociationPending'});
      expect(seen, ['onAssociationPending']);
      expect(done, isFalse);
      await emit({'owner': id, 'type': 'onAssociationCancelled', 'resultCode': 0});
      expect(seen, ['onAssociationPending', 'onAssociationCancelled']);
      expect(done, isTrue);
    } finally {
      await sub.cancel();
    }
  });

  for (final early in [false, true]) {
    for (final types in [
      ['onAssociationCreated'],
      ['onAssociationResult'],
      ['onAssociationCreated', 'onAssociationResult'],
      ['onAssociationResult', 'onAssociationCreated'],
    ]) {
      test('companion success $types completes and retires the request (early: $early)', () async {
        final id = 'association-success-${host.sequence++}';
        final callbacks = [
          for (var i = 0; i < types.length; i++)
            <String, Object?>{'owner': id, 'type': types[i], 'isComplete': i == types.length - 1},
        ];
        host.override = (call) async {
          if (call.method == 'companion.associate') {
            if (early) {
              for (final callback in callbacks) {
                await emit(callback);
              }
            }
            return id;
          }
          return null;
        };
        final request = await CompanionDeviceManager.shared.associate(const AssociationRequest());
        final order = <String>[];
        final received = <CompanionDeviceCallback>[];
        final subscription = request.events.listen((event) {
          received.add(event);
          order.add(event.type);
        }, onDone: () => order.add('done'));
        try {
          if (!early) {
            for (final callback in callbacks) {
              await emit(callback);
            }
          }
          await tick();
          expect(order, [...types, 'done']);
          expect(received.last.isComplete, isTrue);
          if (received.length > 1) expect(received.first.isComplete, isFalse);
          expect(await request.events.toList(), isEmpty);
          final late = <BluetoothEvent>[];
          final global = AndroidBluetooth.events.listen(late.add);
          try {
            await emit(callbacks.last);
            expect(late, isEmpty);
            await emit({'owner': 'companion', 'type': 'onDeviceAppeared', 'address': address});
            expect(late.single.type, 'onDeviceAppeared');
          } finally {
            await global.cancel();
          }
        } finally {
          await subscription.cancel();
        }
      });
    }
  }
}
