import 'dart:typed_data';

import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('discovered GATT lists preserve order, immutable nesting and omitted collections', () async {
    final gatt = await BluetoothDevice(address).connectGatt();
    final graph = [
      service('s1', [characteristic('c1', descriptorHandle: 'd1')]),
      {...service('s2', []), 'characteristics': null, 'includedServices': null},
    ];
    host.override = (call) async => call.method == 'gatt.getServices' ? graph : null;
    try {
      final snapshot = await gatt.services;
      graph.clear();
      expect(snapshot.map((service) => service.handle), ['s1', 's2']);
      expect(snapshot.first.characteristics.single.descriptors.single.handle, 'd1');
      expect(snapshot.last.characteristics, isEmpty);
      expect(snapshot.last.includedServices, isEmpty);
      expect(() => snapshot.clear(), throwsUnsupportedError);
      for (final service in snapshot) {
        expect(() => service.characteristics.clear(), throwsUnsupportedError);
        expect(() => service.includedServices.clear(), throwsUnsupportedError);
      }
      expect(() => snapshot.first.characteristics.single.descriptors.clear(), throwsUnsupportedError);
    } finally {
      await gatt.close();
    }
  });

  test('device and companion collection queries preserve order and immutable snapshots', () async {
    const secondAddress = '11:22:33:44:55:66';
    final devices = [
      {'address': address},
      {'address': secondAddress},
    ];
    final associations = [
      {'id': 7},
      {'id': 8},
    ];
    host.override = (call) async => switch (call.method) {
          'manager.connectedDevices' || 'manager.matchingDevices' || 'adapter.bondedDevices' => devices,
          'companion.associations' => associations,
          _ => null,
        };
    final snapshots = [
      await BluetoothManager.shared.getConnectedDevices(),
      await BluetoothManager.shared.getDevicesMatchingConnectionStates([BluetoothProfile.stateConnected]),
      await BluetoothAdapter.shared.bondedDevices,
    ];
    final companions = await CompanionDeviceManager.shared.myAssociations;
    devices.clear();
    associations.clear();
    for (final snapshot in snapshots) {
      expect(snapshot.map((device) => device.address), [address, secondAddress]);
      expect(() => snapshot.clear(), throwsUnsupportedError);
    }
    expect(companions.map((association) => association.id), [7, 8]);
    expect(() => companions.clear(), throwsUnsupportedError);
    expect(() => companions.first.data.clear(), throwsUnsupportedError);
  });

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
    expect(() => event.results.single.data.clear(), throwsUnsupportedError);
    expect(() => record.data.clear(), throwsUnsupportedError);
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

  test('ranging capability and result maps retain immutable nested snapshots', () async {
    final capabilities = RangingManager.shared.onRangingCapabilities.first;
    await emit({
      'owner': 'ranging',
      'type': 'onRangingCapabilities',
      'capabilities': {
        'technologyAvailability': {'3': 1},
        'csSupportedSecurityLevels': [0, 1],
      },
    });
    final supported = await capabilities;
    expect(supported.technologyAvailability, {3: 1});
    expect(() => supported.data.clear(), throwsUnsupportedError);
    expect(() => supported.technologyAvailability.clear(), throwsUnsupportedError);
    expect(() => supported.csSupportedSecurityLevels.clear(), throwsUnsupportedError);
    host.override = (call) async => switch (call.method) {
          'ranging.create' => 'ranging-snapshots-${host.sequence++}',
          'ranging.close' => true,
          _ => null,
        };
    final session = await RangingManager.shared.createRangingSession();
    try {
      await session.start(rangingPreference());
      final next = session.onResults.first;
      await emit({
        'owner': session.id,
        'type': 'onResults',
        'peerUuid': '12345678-1234-5678-1234-567812345678',
        'result': {
          'rangingTechnology': RangingManager.bleRssi,
          'timestampMillis': 12,
          'distance': {'measurement': 42.5, 'confidence': 3},
        },
      });
      final result = (await next).result;
      expect(result.distance!.measurement, 42.5);
      expect(() => result.data.clear(), throwsUnsupportedError);
      expect(() => (result.data['distance'] as Map).clear(), throwsUnsupportedError);
    } finally {
      final closed = session.onClosed.first;
      await session.close();
      await emit({'owner': session.id, 'type': 'onClosed', 'reason': 0});
      await closed;
    }
  });
}
