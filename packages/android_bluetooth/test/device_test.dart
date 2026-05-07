import 'dart:typed_data';

import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  for (final accepted in [true, false]) {
    test('PIN result callbacks expose empty extras and absent optional fields (accepted: $accepted)', () async {
      final next = BluetoothDevice(address).events.first;
      await emit({
        'owner': 'device',
        'type': 'onPairingPinSet',
        'device': {'address': address},
        'accepted': accepted,
        if (!accepted) 'message': 'PIN rejected',
      });
      final event = await next;
      expect(event.type, 'onPairingPinSet');
      expect(event.data['accepted'], accepted);
      expect(event.message, accepted ? null : 'PIN rejected');
      expect(event.extras, isEmpty);
      expect(() => event.extras['unexpected'] = true, throwsUnsupportedError);
      expect([
        event.transport,
        event.bondState,
        event.previousBondState,
        event.pairingVariant,
        event.pairingKey,
        event.encryptionStatus,
        event.encryptionEnabled,
        event.encryptionAlgorithm,
        event.keySize,
      ], everyElement(isNull));
    });
  }

  test('device broadcasts retain their supplied extras and typed fields', () async {
    final extras = {
      'android.bluetooth.device.extra.TRANSPORT': 2,
      'android.bluetooth.device.extra.BOND_STATE': 12,
      'android.bluetooth.device.extra.PREVIOUS_BOND_STATE': 11,
      'android.bluetooth.device.extra.PAIRING_VARIANT': 0,
      'android.bluetooth.device.extra.PAIRING_KEY': 123456,
      'android.bluetooth.device.extra.ENCRYPTION_STATUS': 0,
      'android.bluetooth.device.extra.ENCRYPTION_ENABLED': true,
      'android.bluetooth.device.extra.EXTRA_ENCRYPTION_ALGORITHM': 2,
      'android.bluetooth.device.extra.KEY_SIZE': 16,
      'vendor.extra': 'retained',
    };
    final next = BluetoothDevice(address).events.first;
    await emit({
      'owner': 'device',
      'type': BluetoothDevice.actionEncryptionChange,
      'device': {'address': address},
      'extras': extras,
    });
    final event = await next;
    expect(event.extras, extras);
    expect(() => event.extras.clear(), throwsUnsupportedError);
    expect([
      event.transport,
      event.bondState,
      event.previousBondState,
      event.pairingVariant,
      event.pairingKey,
      event.encryptionStatus,
      event.encryptionEnabled,
      event.encryptionAlgorithm,
      event.keySize,
    ], [
      2,
      12,
      11,
      0,
      123456,
      0,
      true,
      2,
      16
    ]);
  });

  test('device identities normalize addresses without conflating distinct devices', () {
    expect(BluetoothDevice(address.toLowerCase()), BluetoothDevice(address));
    expect(BluetoothDevice(address).hashCode, BluetoothDevice(address).hashCode);
    expect(BluetoothDevice(address), isNot(BluetoothDevice('00:00:00:00:00:01')));
  });

  test('unknown identity preserves its null address and can be queried again once available', () async {
    final device = BluetoothDevice(address);
    host.override = (_) async => {'address': null, 'addressType': BluetoothDevice.addressTypeUnknown};
    final unknown = await device.identityAddressWithType;
    expect(unknown.address, isNull);
    expect(unknown.addressType, BluetoothDevice.addressTypeUnknown);
    expect(device.address, address);
    expect(host.calls.last.arguments, {'address': address});

    host.override = (_) async => {'address': address, 'addressType': BluetoothDevice.addressTypePublic};
    final known = await device.identityAddressWithType;
    expect(known.address, address);
    expect(known.addressType, BluetoothDevice.addressTypePublic);
    expect(unknown.address, isNull);
    expect(unknown.addressType, BluetoothDevice.addressTypeUnknown);
  });

  for (final type in [BluetoothDevice.addressTypePublic, BluetoothDevice.addressTypeRandom]) {
    test('known identity preserves its address and native address type (type: $type)', () async {
      const identityAddress = '11:22:33:44:55:66';
      host.override = (_) async => {'address': identityAddress, 'addressType': type};
      final device = BluetoothDevice(address);
      final identity = await device.identityAddressWithType;
      expect(identity.address, identityAddress);
      expect(identity.addressType, type);
      expect(device.address, address);
      expect(host.calls.last.method, 'device.identityAddressWithType');
      expect(host.calls.last.arguments, {'address': address});
    });
  }

  test('identity queries propagate permission and unsupported errors instead of returning an unknown identity',
      () async {
    for (final code in ['permission_denied', 'unsupported']) {
      host.override = (_) async => throw PlatformException(code: code, message: 'unavailable');
      await expectLater(BluetoothDevice(address).identityAddressWithType,
          throwsA(isA<PlatformException>().having((error) => error.code, 'code', code)));
    }
  });

  test('device client lookup shares objects, distinguishes registrations and retires closed clients', () async {
    final device = BluetoothDevice(address);
    final first = await device.connectGatt();
    final second = await device.connectGatt(autoConnect: true);
    final other = await BluetoothDevice('00:00:00:00:00:01').connectGatt();
    expect(BluetoothDevice(address.toLowerCase()).gattClients, [first, second]);
    expect(() => device.gattClients.clear(), throwsUnsupportedError);
    await first.disconnect();
    expect(device.gattClients, [first, second]);
    await first.close();
    expect(device.gattClients, [second]);
    await second.close();
    await other.close();
    expect(device.gattClients, isEmpty);
  });

  test('engine detach clears direct client lookup', () async {
    await BluetoothDevice(address).connectGatt();
    expect(BluetoothDevice(address).gattClients, isNotEmpty);
    await emit({'owner': 'engine', 'type': 'onDetachedFromEngine'});
    expect(BluetoothDevice(address).gattClients, isEmpty);
  });

  test('explicit random LE address type reaches device and connection requests', () async {
    host.override = (call) async => switch (call.method) {
          'adapter.remoteLeDevice' || 'device.get' || 'device.identityAddressWithType' => {
              'address': address,
              'addressType': BluetoothDevice.addressTypeRandom
            },
          'gatt.open' => 'gatt-typed-address',
          'device.bondState' => BluetoothDevice.bondNone,
          'device.setAlias' => BluetoothStatusCodes.success,
          'device.createBond' || 'device.removeBond' || 'device.setPin' || 'device.setPairingConfirmation' => true,
          _ => null,
        };
    final device = await BluetoothAdapter.shared.getRemoteLeDevice(address, BluetoothDevice.addressTypeRandom);
    final gatt = await device.connectGatt();
    expect(host.calls.last.arguments, containsPair('addressType', BluetoothDevice.addressTypeRandom));
    final refreshed = await device.refresh();
    await refreshed.getBondState();
    await refreshed.createBond();
    await refreshed.setPinForNextPairing(Uint8List.fromList([49, 50]));
    await refreshed.setAlias('Sensor');
    await refreshed.setAlias(null);
    await refreshed.setPairingConfirmation(true);
    await refreshed.setPin(Uint8List.fromList([49, 50]));
    await refreshed.removeBond();
    final identity = await refreshed.identityAddressWithType;
    expect(identity.addressType, BluetoothDevice.addressTypeRandom);
    for (final call in host.calls.where((call) => call.method.startsWith('device.'))) {
      expect(call.arguments, containsPair('address', address));
      expect(call.arguments, containsPair('addressType', BluetoothDevice.addressTypeRandom));
    }
    await gatt.close();
  });

  test('setting and clearing aliases preserve nullable arguments, native status and permission errors', () async {
    final device = BluetoothDevice(address);
    host.override = (_) async => 123;
    for (final alias in ['Sensor', null]) {
      expect(await device.setAlias(alias), 123);
      expect(host.calls.last.method, 'device.setAlias');
      expect(host.calls.last.arguments, {'address': address, 'alias': alias});
    }
    host.override = (_) async => throw PlatformException(code: 'permission_denied', message: 'restricted');
    await expectLater(device.setAlias(null),
        throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'permission_denied')));
  });

  test('permission and unsupported native errors remain structured PlatformExceptions', () async {
    host.override = (_) async =>
        throw PlatformException(code: 'unsupported', message: 'Requires Android API 29', details: {'apiLevel': 26});
    await expectLater(
        BluetoothAdapter.shared.listenUsingL2capChannel(),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'unsupported')
            .having((e) => e.details['apiLevel'], 'apiLevel', 26)));
  });
}
