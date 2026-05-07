import 'dart:typed_data';

import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('scan records preserve repeated AD structures and stop on truncated input', () async {
    final next = BluetoothLeScanner.shared.onScanResult.first;
    await emit({
      'owner': 'scanner',
      'type': 'onScanResult',
      'callbackType': 1,
      'results': [
        {
          'device': {'address': address},
          'rssi': -42,
          'timestampNanos': 1234567890123,
          'isConnectable': true,
          'scanRecord': {
            'bytes': Uint8List.fromList([2, 255, 1, 2, 255, 2, 9, 1, 7]),
            'deviceName': 'sensor',
            'advertiseFlags': 6,
            'txPowerLevel': -7,
            'serviceUuids': [],
            'manufacturerSpecificData': {
              '65535': Uint8List.fromList([255])
            },
            'serviceData': {}
          }
        }
      ]
    });
    final result = (await next).results.single;
    expect(result.timestampNanos, 1234567890123);
    expect(result.scanRecord?.advertisingData[255], [
      [1],
      [2]
    ]);
    expect(result.scanRecord?.manufacturerSpecificData[65535], [255]);
  });

  test('advanced scan settings and filter masks survive transport unchanged', () async {
    host.override = (call) async => switch (call.method) {
          'scan.startSession' => 'scan-arguments-${host.sequence++}',
          'scan.backgroundStart' => 0,
          _ => null,
        };
    final scanner = BluetoothLeScanner.shared;
    final filters = [
      ScanFilter(
          serviceUuid: '180D',
          manufacturerId: 7,
          manufacturerData: Uint8List.fromList([128]),
          manufacturerDataMask: Uint8List.fromList([255]))
    ];
    const settings = ScanSettings(legacy: false, phy: ScanSettings.phyLeAllSupported, scanType: 1, rssiThreshold: -80);
    await scanner.startScan(filters: filters, settings: settings);
    final args = host.calls.last.arguments as Map;
    expect((args['filters'] as List).single['serviceUuid'], '0000180d-0000-1000-8000-00805f9b34fb');
    expect(args['settings']['rssiThreshold'], -80);
    expect(args['settings']['legacy'], false);
    final session = await scanner.startScanSession(filters: filters, settings: settings);
    try {
      expect(host.calls.last.arguments, args);
      expect(await scanner.startBackgroundScan(id: 7, filters: filters, settings: settings), 0);
      expect(host.calls.last.arguments, {'id': 7, ...args});
    } finally {
      await session.stop();
      await scanner.stopScan();
      await scanner.stopBackgroundScan(7);
    }
  });

  test('background scan callbacks retain typed results and raw bytes in memory', () async {
    await emit({
      'owner': 'scanner',
      'type': 'onScanResult',
      'scanId': 7,
      'callbackType': 1,
      'results': [
        {
          'device': {'address': address},
          'rssi': -42,
          'timestampNanos': 1,
          'scanRecord': {
            'bytes': Uint8List.fromList([2, 255, 255]),
            'deviceName': null,
            'advertiseFlags': -1,
            'txPowerLevel': -7,
            'serviceUuids': [],
            'manufacturerSpecificData': {},
            'serviceData': {},
          },
        }
      ],
    });
    final scan = await BluetoothLeScanner.shared.onScanResult.first;
    expect(scan.data['scanId'], 7);
    expect(scan.results.single.device.address, address);
    expect(scan.results.single.scanRecord?.bytes, [2, 255, 255]);
  });

  test('callback scan delivery controls and live updates reach native with raw defaults intact', () async {
    host.override = (call) async => call.method == 'scan.startSession' ? 'scan-delivery-${host.sequence++}' : null;
    final scanner = BluetoothLeScanner.shared;
    await scanner.startScan();
    expect((host.calls.last.arguments as Map).containsKey('deliveryOptions'), isFalse);
    await scanner.stopScan();
    final scan = await scanner.startScanSession(
        deliveryOptions: const ScanDeliveryOptions(
      advertisementDivisor: 3,
      suppressDuplicates: true,
      includeBatchResults: false,
    ));
    expect((host.calls.last.arguments as Map)['deliveryOptions'], {
      'advertisementDivisor': 3,
      'suppressDuplicates': true,
      'includeBatchResults': false,
    });
    await scan.setDeliveryOptions(const ScanDeliveryOptions());
    expect(host.calls.last.method, 'scan.setDeliveryOptions');
    expect(host.calls.last.arguments, {
      'id': scan.id,
      'deliveryOptions': {
        'advertisementDivisor': 1,
        'suppressDuplicates': false,
        'includeBatchResults': true,
      },
    });
    await scan.stop();
  });

  test('invalid advertisement divisors fail before channel invocation', () async {
    final scanner = BluetoothLeScanner.shared;
    final before = host.calls.length;
    for (final divisor in [0, -1, 2147483648]) {
      expect(() => scanner.startScan(deliveryOptions: ScanDeliveryOptions(advertisementDivisor: divisor)),
          throwsRangeError);
      await expectLater(scanner.startScanSession(deliveryOptions: ScanDeliveryOptions(advertisementDivisor: divisor)),
          throwsRangeError);
    }
    expect(host.calls, hasLength(before));
  });

  test('independent callback scans route and stop by their own registration', () async {
    var scans = 0;
    host.override = (call) async => call.method == 'scan.startSession' ? 'scan-test-${scans++}' : null;
    final scanner = BluetoothLeScanner.shared;
    final a = await scanner.startScanSession(), b = await scanner.startScanSession();
    final seenA = <ScanCallback>[], seenB = <ScanCallback>[];
    final subA = a.events.listen(seenA.add), subB = b.events.listen(seenB.add);
    await emit({'owner': a.id, 'type': 'onScanFailed', 'errorCode': 6});
    expect(seenA.single.errorCode, 6);
    expect(seenB, isEmpty);
    final beforeStop = host.calls.length;
    await a.stop();
    expect(host.calls.length, beforeStop); // onScanFailed already retired this native registration.
    await subA.cancel();
    await subB.cancel();
    await b.stop();
  });
}
