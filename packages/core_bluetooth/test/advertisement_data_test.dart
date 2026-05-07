import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

final class _DiscoveryDelegate extends cb.CBCentralManagerDelegate {
  cb.AdvertisementData? advertisement;
  @override
  void centralManagerDidDiscover(
      cb.CBCentralManager manager, cb.CBPeripheral peripheral, cb.AdvertisementData advertisementData, int? rssi) {
    advertisement = advertisementData;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  late cb.CBCentralManager manager;
  late _DiscoveryDelegate delegate;
  setUp(() async {
    host = CoreBluetoothTestHost()..setUp();
    delegate = _DiscoveryDelegate();
    manager = host.trackCentral(cb.CBCentralManager.createIsolated(delegate: delegate));
    await manager.ready;
  });
  tearDown(() => host.tearDown());

  test('discovery exposes ordinary, overflow and solicited service UUIDs independently', () async {
    final discovering = manager.onDidDiscoverPeripheral.first;
    await host.emitCentral('didDiscoverPeripheral', {
      'peripheral': {'identifier': '12345678-1234-1234-1234-123456789abc', 'state': 0},
      'advertisementData': {
        'serviceUUIDs': ['180f'],
        'overflowServiceUUIDs': ['1810', '12345678-1234-1234-1234-123456789ABC'],
        'solicitedServiceUUIDs': ['180d'],
      },
      'rssi': -40,
    });
    final event = await discovering;
    final data = event.advertisementData;
    expect(data, same(delegate.advertisement));
    expect(data.serviceUUIDs, [cb.CBUUID('180f')]);
    expect(data.overflowServiceUUIDs, [cb.CBUUID('1810'), cb.CBUUID('12345678-1234-1234-1234-123456789abc')]);
    expect(data.solicitedServiceUUIDs, [cb.CBUUID('180d')]);
    expect(event.rssi, -40);
  });

  for (final empty in [false, true]) {
    test('optional advertisement UUID lists preserve absence and empty lists (empty: $empty)', () async {
      final discovering = manager.onDidDiscoverPeripheral.first;
      await host.emitCentral('didDiscoverPeripheral', {
        'peripheral': {'identifier': '12345678-1234-1234-1234-123456789abc', 'state': 0},
        'advertisementData': {
          if (empty) ...{'overflowServiceUUIDs': [], 'solicitedServiceUUIDs': []},
        },
      });
      final data = (await discovering).advertisementData;
      expect(data.serviceUUIDs, isNull);
      expect(data.overflowServiceUUIDs, empty ? isEmpty : isNull);
      expect(data.solicitedServiceUUIDs, empty ? isEmpty : isNull);
    });
  }
}
