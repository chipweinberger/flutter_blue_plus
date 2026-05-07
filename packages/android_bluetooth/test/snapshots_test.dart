import 'dart:typed_data';

import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('callback result types carry required fields and immutable shared snapshots', () async {
    final gatt = await BluetoothDevice(address).connectGatt();
    final first = gatt.onCharacteristicRead.first, second = gatt.onCharacteristicRead.first;
    final bytes = Uint8List.fromList([1, 255]);
    await emit({
      'owner': gatt.id,
      'type': 'onCharacteristicRead',
      'status': 0,
      'characteristic': callbackCharacteristic(),
      'value': bytes
    });
    bytes[0] = 99;
    final a = await first, b = await second;
    expect(a, isA<GattCharacteristicReadResult>());
    expect(a.status, 0);
    expect(a.characteristic.handle, 'char');
    final value = a.value!;
    if (a.data['value'] is Uint8List) {
      expect(identical(value, a.data['value']), isTrue);
      expect(identical(a.value, value), isTrue);
      expect(() => value[0] = 77, throwsUnsupportedError);
    } else {
      // Dart 3.0–3.2 expose isolated typed copies of the frozen list.
      expect(identical(a.value, value), isFalse);
      value[0] = 77;
      expect(a.value, [1, 255]);
    }
    expect(() => a.data['status'] = 5, throwsUnsupportedError);
    expect(() => (a.data['characteristic'] as Map)['uuid'] = 'changed', throwsUnsupportedError);
    expect(() => a.characteristic.descriptors.clear(), throwsUnsupportedError);
    expect(b.value, [1, 255]);
    final local = BluetoothGattService('180D');
    local.characteristics.add(BluetoothGattCharacteristic('2A37', 2, 1));
    expect(local.characteristics, hasLength(1));
    await gatt.close();
  });

  test('scan-record AD views and lookup collections are immutable', () async {
    final next = BluetoothLeScanner.shared.onScanResult.first;
    await emit({
      'owner': 'scanner',
      'type': 'onScanResult',
      'callbackType': 1,
      'results': [
        {
          'device': {'address': address},
          'rssi': -40,
          'timestampNanos': 1,
          'scanRecord': {
            'bytes': Uint8List.fromList([2, 255, 7]),
            'advertiseFlags': 6,
            'txPowerLevel': -7,
            'serviceUuids': ['180D'],
            'manufacturerSpecificData': {},
            'serviceData': {}
          }
        }
      ]
    });
    final event = await next, record = event.results.single.scanRecord!;
    expect(() => event.results.clear(), throwsUnsupportedError);
    expect(() => record.serviceUuids.add('180F'), throwsUnsupportedError);
    expect(() => record.advertisingData.clear(), throwsUnsupportedError);
    final payload = record.advertisingData[255]!.single;
    if (record.data['bytes'] is Uint8List) {
      expect(() => payload[0] = 0, throwsUnsupportedError);
    } else {
      payload[0] = 0;
      expect(record.advertisingData[255]!.single, [7]);
    }
  });
}
