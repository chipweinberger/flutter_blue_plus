import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  late cb.CBCentralManager manager;
  setUp(() async {
    host = CoreBluetoothTestHost()..setUp();
    manager = host.trackCentral(cb.CBCentralManager.createIsolated());
    await manager.ready;
  });
  tearDown(() => host.tearDown());

  test('advertisement divisor defaults to 1 and leaves native scan options unchanged', () async {
    await manager.scanForPeripherals();
    expect((host.calls.last.arguments as Map)['advertisementDivisor'], 1);
    await manager.scanForPeripherals(
      withServices: [cb.CBUUID('180f')],
      options: cb.CentralManagerScanOptions(allowDuplicates: true, solicitedServiceUUIDs: [cb.CBUUID('180d')]),
      advertisementDivisor: 3,
    );
    expect(host.calls.last.arguments, {
      'managerId': 1,
      'serviceUUIDs': ['180f'],
      'options': {
        'allowDuplicates': true,
        'solicitedServiceUUIDs': ['180d']
      },
      'advertisementDivisor': 3,
    });
  });

  test('invalid divisors fail before submitting a native scan', () async {
    final before = host.calls.length;
    for (final divisor in [0, -1, 2147483648]) {
      await expectLater(manager.scanForPeripherals(advertisementDivisor: divisor), throwsRangeError);
    }
    expect(host.calls, hasLength(before));
  });
}
