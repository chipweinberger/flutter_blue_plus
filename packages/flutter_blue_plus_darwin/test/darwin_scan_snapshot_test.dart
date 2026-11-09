import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_host.dart';

BmScanSettings _settings(String filter, List<String> values) => switch (filter) {
      'names' => scanSettings(names: values),
      'ids' => scanSettings(ids: values),
      _ => scanSettings(keywords: values),
    };

Future<void> _advertise(CoreBluetoothHost host, {String id = deviceId, String name = 'Original'}) =>
    host.emit('didDiscoverPeripheral', {
      'peripheral': peripheral(id: id),
      'advertisementData': {'localName': name},
      'rssi': -40,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothHost host;
  setUp(() async {
    host = CoreBluetoothHost();
    await host.setUp(initialize: false);
  });
  tearDown(() async {
    await host.backend.dispose();
    await cb.CBCentralManager.shared.dispose();
    await host.tearDown();
  });

  for (final initialized in [true, false]) {
    for (final filter in ['names', 'ids', 'keywords']) {
      test('$filter filters are captured at startScan submission (initialized: $initialized)', () async {
        final creation = Completer<Object?>();
        if (initialized) {
          await host.backend.isSupported(BmIsSupportedRequest());
        } else {
          host.handle = (call) => call.method == 'centralManager.create' ? creation.future : null;
        }
        final values = [filter == 'ids' ? deviceId : 'Original'];
        final results = <BmScanResponse>[];
        final subscription = host.backend.onScanResponse.listen(results.add);
        addTearDown(subscription.cancel);
        final starting = host.backend.startScan(_settings(filter, values));
        values[0] = filter == 'ids' ? otherId : 'Changed';
        if (!initialized) {
          await host.pump();
          expect(host.calls.where((call) => call.method == 'centralManager.scanForPeripherals'), isEmpty);
          creation.complete({'managerId': 1, 'state': 5, 'isScanning': false});
        }
        await starting;
        await _advertise(host, name: filter == 'keywords' ? 'prefix Original suffix' : 'Original');
        expect(results, hasLength(1));
        await _advertise(host,
            id: filter == 'ids' ? otherId : deviceId, name: filter == 'keywords' ? 'prefix Changed suffix' : 'Changed');
        expect(results, hasLength(1));
        values.clear();
        await _advertise(host, id: otherId, name: 'Unrelated');
        expect(results, hasLength(1), reason: 'Later mutations must not change the active filters either');
      });
    }
  }

  test('mutating an empty custom filter cannot change native service filtering', () async {
    final names = <String>[];
    final services = [Guid('180f')];
    final results = <BmScanResponse>[];
    final subscription = host.backend.onScanResponse.listen(results.add);
    addTearDown(subscription.cancel);
    final starting = host.backend.startScan(scanSettings(names: names, services: services));
    names.add('Changed');
    services[0] = Guid('180a');
    await starting;
    final submitted = host.calls.last;
    expect(submitted.method, 'centralManager.scanForPeripherals');
    expect((submitted.arguments as Map)['serviceUUIDs'], ['180f']);
    await _advertise(host, name: 'Changed');
    expect(results, isEmpty);
    await host.emit('didDiscoverPeripheral', {
      'peripheral': peripheral(),
      'advertisementData': {
        'serviceUUIDs': ['180f']
      },
      'rssi': -40,
    });
    expect(results, hasLength(1));
  });
}
