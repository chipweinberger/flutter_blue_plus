import 'dart:typed_data';

import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('compatibility primitives preserve arguments and parent callback identities', () async {
    host.override = (call) async {
      switch (call.method) {
        case 'environment.isLocationEnabled':
          return false;
        case 'device.createBond':
        case 'adapter.requestEnable':
          return true;
        case 'gatt.open':
          return 'gatt-compatibility-${host.sequence++}';
      }
      return null;
    };
    final device = BluetoothDevice(address);
    final pin = Uint8List.fromList([49, 50, 51, 52]);
    expect((await AndroidBluetooth.capabilities).hasAdapter, isTrue);
    expect(await AndroidBluetooth.isLocationEnabled, isFalse);
    await device.setPinForNextPairing(pin);
    expect(host.calls.last.arguments, {'address': address, 'pin': pin});
    await device.setPinForNextPairing(null);
    expect((host.calls.last.arguments as Map)['pin'], isNull);
    expect(await device.createBond(pin: pin), isTrue);
    expect((host.calls.last.arguments as Map)['pin'], pin);
    final response = BluetoothAdapter.shared.onEnableResponse.first;
    expect(await BluetoothAdapter.shared.requestEnable(waitForResult: false), isTrue);
    expect((host.calls.last.arguments as Map)['waitForResult'], isFalse);
    await emit({'owner': 'adapter', 'type': 'onEnableResponse', 'userAccepted': false});
    expect((await response).userAccepted, isFalse);
    final gatt = await device.connectGatt(preserveAttributeHandles: true);
    expect((host.calls.last.arguments as Map)['preserveAttributeHandles'], isTrue);
    final callback = gatt.onDescriptorRead.first;
    await emit({
      'owner': gatt.id,
      'type': 'onDescriptorRead',
      'status': 0,
      'value': Uint8List(0),
      'descriptor': {
        'handle': 'descriptor-original',
        'uuid': '2902',
        'permissions': 1,
        'characteristic': {
          ...callbackCharacteristic(),
          'service': {'handle': 'service-original', 'uuid': '180D', 'instanceId': 7, 'serviceType': 0},
        },
      },
    });
    final descriptor = (await callback).descriptor;
    expect(descriptor.handle, 'descriptor-original');
    expect(descriptor.characteristic!.handle, 'char');
    expect(descriptor.characteristic!.service!.handle, 'service-original');
    await gatt.close();
  });
}
