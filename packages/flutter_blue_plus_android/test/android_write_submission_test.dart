import 'dart:typed_data';

import 'package:android_bluetooth/android_bluetooth.dart' as ab;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/android_host.dart';

Future<bool> _write(AndroidHost host, bool descriptor, List<int> value, {DeviceIdentifier remoteId = remote}) =>
    descriptor
        ? host.backend.writeDescriptor(BmWriteDescriptorRequest(
            remoteId: remoteId,
            primaryServiceUuid: null,
            serviceUuid: Guid('180d'),
            characteristicUuid: Guid('2a37'),
            instanceId: 0,
            descriptorUuid: Guid('2902'),
            value: value))
        : host.backend.writeCharacteristic(BmWriteCharacteristicRequest(
            remoteId: remoteId,
            primaryServiceUuid: null,
            serviceUuid: Guid('180d'),
            characteristicUuid: Guid('2a37'),
            instanceId: 0,
            writeType: BmWriteType.withResponse,
            allowLongWrite: false,
            value: value));

List<List<int>> _writtenValues(AndroidHost host, bool descriptor) => host.collect(descriptor
    ? host.backend.onDescriptorWritten.map((event) => event.value)
    : host.backend.onCharacteristicWritten.map((event) => event.value));

Future<void> _callback(AndroidHost host, bool descriptor,
    {int status = 0, String serviceHandle = 's', String remoteAddress = address}) {
  final parent = characteristic('c-$serviceHandle', parent: service(serviceHandle, characteristics: []));
  return host.callback(descriptor ? 'onDescriptorWrite' : 'onCharacteristicWrite', status: status, extra: {
    'device': {'address': remoteAddress},
    if (descriptor)
      'descriptor': {'handle': 'd-c-$serviceHandle', 'uuid': uuid('2902'), 'permissions': 17, 'characteristic': parent}
    else ...{
      'characteristic': parent,
      'value': Uint8List.fromList([9, 8]),
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AndroidHost host;
  setUp(() async {
    host = AndroidHost();
    await host.setUp();
  });
  tearDown(() => host.tearDown());

  for (final descriptor in [false, true]) {
    final method = descriptor ? 'writeDescriptor' : 'writeCharacteristic';
    for (final autoConnect in [false, true]) {
      test('$method discards pending bytes across ${autoConnect ? 'auto-connect' : 'fresh client'} reconnect',
          () async {
        await host.connect(autoConnect: autoConnect);
        final firstClient = ab.BluetoothDevice(address).gattClients.single;
        final written = _writtenValues(host, descriptor);
        await _write(host, descriptor, [1, 2]);
        // Android can disconnect without completing an accepted write.
        await host.connection(ab.BluetoothProfile.stateDisconnected, status: 8);
        host.services = [service('new')];
        if (autoConnect) {
          await host.connection(ab.BluetoothProfile.stateConnected);
          await host.discovery();
        } else {
          await host.connect();
        }
        final client = ab.BluetoothDevice(address).gattClients.single;
        expect(identical(client, firstClient), autoConnect);
        final attribute = (await client.services).single.characteristics.single;
        final value = Uint8List.fromList([9, 8]);
        expect(
            await (descriptor
                ? client.writeDescriptor(attribute.descriptors.single, value)
                : client.writeCharacteristic(attribute, value)),
            ab.BluetoothStatusCodes.success);
        await _callback(host, descriptor, serviceHandle: 'new');
        expect(written.single, isEmpty);
        await _write(host, descriptor, [3, 4]);
        await _callback(host, descriptor, serviceHandle: 'new');
        expect(written.last, [3, 4]);
      });
    }

    test('$method preserves another device\'s pending bytes when one device disconnects', () async {
      await host.connect();
      final firstOwner = host.gatt;
      const other = DeviceIdentifier('11:22:33:44:55:66');
      await host.backend.connect(BmConnectRequest(remoteId: other, autoConnect: false));
      await emit({
        'owner': host.gatt,
        'type': 'onConnectionStateChange',
        'status': 0,
        'newState': ab.BluetoothProfile.stateConnected,
        'device': {'address': other.str},
      });
      await host.discovery();
      final written = _writtenValues(host, descriptor);
      await _write(host, descriptor, [1, 2]);
      await _write(host, descriptor, [7, 6], remoteId: other);
      await host.connection(ab.BluetoothProfile.stateDisconnected, owner: firstOwner);
      await _callback(host, descriptor, remoteAddress: other.str);
      expect(written.single, [7, 6]);
    });

    for (final failure in ['status', 'legacy', 'exception']) {
      test('$method discards $failure submission bytes before a later native write', () async {
        host.api = failure == 'legacy' ? 30 : 33;
        await host.connect();
        final written = _writtenValues(host, descriptor);
        host.override = (call) async {
          if (call.method != 'gatt.$method') return null;
          if (failure == 'exception') {
            throw PlatformException(
                code: 'permission_denied', message: 'permission revoked', details: {'stackTrace': 'native stack'});
          }
          return failure == 'legacy'
              ? ab.BluetoothStatusCodes.errorUnknown
              : ab.BluetoothStatusCodes.errorGattWriteRequestBusy;
        };
        final Matcher expectedError = failure == 'exception'
            ? platformError('androidException', 'permission revoked')
            : platformError(method,
                'gatt.$method() returned ${failure == 'legacy' ? 'false' : '201 : ERROR_GATT_WRITE_REQUEST_BUSY'}');
        await expectLater(_write(host, descriptor, [1, 2]), throwsA(expectedError));
        expect(written, isEmpty);
        host.override = null;
        // Native operations are serialized after FBP's rejected submission.
        final client = ab.BluetoothDevice(address).gattClients.single;
        final attribute = (await client.services).single.characteristics.single;
        final value = Uint8List.fromList([9, 8]);
        expect(
            await (descriptor
                ? client.writeDescriptor(attribute.descriptors.single, value)
                : client.writeCharacteristic(attribute, value)),
            ab.BluetoothStatusCodes.success);
        await _callback(host, descriptor);
        expect(written.single, isEmpty); // Retain FBP's unmatched native-write behavior.

        expect(await _write(host, descriptor, [3, 4]), isTrue);
        // An accepted write's asynchronous GATT error still reports its submitted bytes.
        await _callback(host, descriptor, status: ab.BluetoothGatt.gattWriteNotPermitted);
        expect(written.last, [3, 4]);
        await _callback(host, descriptor);
        expect(written.last, isEmpty);
      });
    }

    test('$method rejection preserves an earlier accepted write awaiting its callback', () async {
      await host.connect();
      final written = _writtenValues(host, descriptor);
      await _write(host, descriptor, [7, 6]);
      // An earlier FBP wait can time out while Android's request is still pending.
      host.override =
          (call) async => call.method == 'gatt.$method' ? ab.BluetoothStatusCodes.errorGattWriteRequestBusy : null;
      await expectLater(_write(host, descriptor, [1, 2]), throwsA(isA<PlatformException>()));
      expect(written, isEmpty);
      await _callback(host, descriptor);
      expect(written.single, [7, 6]);
      await _callback(host, descriptor);
      expect(written.last, isEmpty);
    });
  }

  test('rejected notification CCCD bytes do not leak into a later native descriptor write', () async {
    await host.connect();
    final written = _writtenValues(host, true);
    host.override = (call) async =>
        call.method == 'gatt.writeDescriptor' ? ab.BluetoothStatusCodes.errorGattWriteRequestBusy : null;
    await expectLater(
        host.backend.setNotifyValue(notifyRequest()),
        throwsA(
            platformError('setNotifyValue', 'gatt.writeDescriptor() returned 201 : ERROR_GATT_WRITE_REQUEST_BUSY')));
    expect(host.calls.where((call) => call.method == 'gatt.setCharacteristicNotification'), hasLength(1));
    host.override = null;
    final client = ab.BluetoothDevice(address).gattClients.single;
    final descriptor = (await client.services).single.characteristics.single.descriptors.single;
    expect(await client.writeDescriptor(descriptor, Uint8List.fromList([0, 0])), ab.BluetoothStatusCodes.success);
    await _callback(host, true);
    expect(written.single, isEmpty);
    await host.backend.setNotifyValue(notifyRequest(force: true));
    await _callback(host, true);
    expect(written.last, [2, 0]);
  });
}
