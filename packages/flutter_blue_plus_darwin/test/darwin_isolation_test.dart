import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('an isolated manager keeps its own peripheral object, calls and callbacks', () async {
    final host = CoreBluetoothHost();
    await host.setUp();
    await host.connect();
    await host.gatt();
    host.handle = (call) {
      if (call.method == 'centralManager.create') return {'managerId': 2, 'state': 5};
      return null;
    };
    final manager = cb.CBCentralManager.createIsolated();
    final fbpValues = <BmCharacteristicData>[];
    final subscription = host.backend.onCharacteristicReceived.listen(fbpValues.add);
    try {
      await manager.ready;
      final native = (await manager.retrievePeripherals([cb.UUID(deviceId)])).single;
      final shared = cb.CBCentralManager.shared.connectedPeripherals.single;
      expect(native, same((await manager.retrievePeripherals([cb.UUID(deviceId)])).single));
      expect(identical(native, shared), isFalse);
      await manager.connect(native);
      expect((host.calls.last.arguments as Map)['managerId'], 2);
      await host.emit('didConnectPeripheral', {'peripheral': peripheral()}, managerId: 2);
      await host.emit(
          'peripheralDidDiscoverServices',
          {
            'peripheral': peripheral(),
            'services': [
              service(characteristics: [characteristic()])
            ]
          },
          managerId: 2);
      final value = native.onDidUpdateValueForCharacteristic.first;
      await native.readValue(native.services!.single.characteristics!.single);
      expect((host.calls.last.arguments as Map)['managerId'], 2);
      await host.emit(
          'peripheralDidUpdateValueForCharacteristic',
          {
            'peripheral': peripheral(),
            'characteristicHandle': 'c',
            'value': Uint8List.fromList([7])
          },
          managerId: 2);
      expect((await value).value, [7]);
      expect(fbpValues, isEmpty);
    } finally {
      await subscription.cancel();
      await manager.dispose();
      await host.tearDown();
    }
  });
}
