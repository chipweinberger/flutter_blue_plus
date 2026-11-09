import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_host.dart';

BmWriteCharacteristicRequest _characteristicRequest({bool noResponse = false}) => BmWriteCharacteristicRequest(
    remoteId: DeviceIdentifier(deviceId),
    primaryServiceUuid: null,
    serviceUuid: Guid('180f'),
    characteristicUuid: Guid('2a19'),
    instanceId: 0,
    value: [7],
    writeType: noResponse ? BmWriteType.withoutResponse : BmWriteType.withResponse,
    allowLongWrite: false);

BmWriteDescriptorRequest _descriptorRequest() => BmWriteDescriptorRequest(
    remoteId: DeviceIdentifier(deviceId),
    primaryServiceUuid: null,
    serviceUuid: Guid('180f'),
    characteristicUuid: Guid('2a19'),
    instanceId: 0,
    descriptorUuid: Guid('2902'),
    value: [7]);

Matcher _disconnected(String method) => isA<PlatformException>()
    .having((error) => error.code, 'code', method)
    .having((error) => error.message, 'message', 'device is disconnected');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothHost host;
  setUp(() async {
    host = CoreBluetoothHost();
    await host.setUp();
  });
  tearDown(() => host.tearDown());

  test('disposing during peripheral retrieval prevents a native connect', () async {
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
        throwsStateError);
    await started.future;
    await host.backend.dispose();
    reply.complete([peripheral(state: 0)]);
    await result;
    expect(host.calls.where((call) => call.method == 'centralManager.connect'), isEmpty);
  });

  for (final descriptor in [false, true]) {
    for (final adapterRestart in [false, true]) {
      final method = descriptor ? 'writeDescriptor' : 'writeCharacteristic';
      test('$method cannot cross ${adapterRestart ? 'an adapter restart' : 'a reconnection'} during a payload query',
          () async {
        await host.connect();
        await host.gatt();
        final started = Completer<void>();
        final reply = Completer<int>();
        host.handle = (call) async {
          if (call.method == 'peripheral.maximumWriteValueLength') {
            started.complete();
            return await reply.future;
          }
          return null;
        };
        final result = expectLater(
            descriptor
                ? host.backend.writeDescriptor(_descriptorRequest())
                : host.backend.writeCharacteristic(_characteristicRequest()),
            throwsA(_disconnected(method)));
        await started.future;
        host.handle = null;
        if (adapterRestart) {
          await host.emit('didUpdateState', {'state': 4});
          await host.emit('didUpdateState', {'state': 5});
        } else {
          await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
        }
        await host.connect();
        await host.gatt();
        reply.complete(20);
        await result;
        expect(host.calls.where((call) => call.method.startsWith('peripheral.writeValue')), isEmpty);

        // The replacement connection must still accept new writes.
        expect(
            await (descriptor
                ? host.backend.writeDescriptor(_descriptorRequest())
                : host.backend.writeCharacteristic(_characteristicRequest())),
            isTrue);
        expect(host.calls.where((call) => call.method.startsWith('peripheral.writeValue')), hasLength(1));
      });
    }
  }

  for (final ready in [false, true]) {
    test('a pending readiness result ($ready) cannot resume a write on a replacement connection', () async {
      await host.connect();
      await host.gatt();
      final started = Completer<void>();
      final reply = Completer<bool>();
      host.handle = (call) async {
        if (call.method == 'peripheral.canSendWriteWithoutResponse') {
          started.complete();
          return await reply.future;
        }
        return null;
      };
      final result = expectLater(host.backend.writeCharacteristic(_characteristicRequest(noResponse: true)),
          throwsA(_disconnected('writeCharacteristic')));
      await started.future;
      host.handle = null;
      await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
      await host.connect();
      await host.gatt();
      reply.complete(ready);
      await result;
      expect(host.calls.where((call) => call.method.startsWith('peripheral.writeValue')), isEmpty);
    });
  }
}
