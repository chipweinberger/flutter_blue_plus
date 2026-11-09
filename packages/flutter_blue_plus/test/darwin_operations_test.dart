import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../flutter_blue_plus_darwin/test/support/core_bluetooth_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('public FBP operations use CoreBluetooth and retain callback errors', () async {
    final host = CoreBluetoothHost();
    await host.setUp();
    try {
      await FlutterBluePlus.isSupported;
      final device = BluetoothDevice.fromId(deviceId);
      final connection = device.connect(license: License.commercial, mtu: null);
      await host.pump();
      await host.emit('didConnectPeripheral', {'peripheral': peripheral()});
      await connection;
      expect(device.isConnected, isTrue);

      final discovery = device.discoverServices();
      await host.pump();
      await host.gatt();
      await host.emit('peripheralDidDiscoverCharacteristicsForService', {
        'peripheral': peripheral(),
        'serviceHandle': 's',
        'characteristics': [characteristic()]
      });
      await host.emit('peripheralDidDiscoverIncludedServicesForService',
          {'peripheral': peripheral(), 'serviceHandle': 's', 'includedServices': []});
      await host.emit('peripheralDidDiscoverDescriptorsForCharacteristic', {
        'peripheral': peripheral(),
        'characteristicHandle': 'c',
        'descriptors': [descriptor()]
      });
      final services = await discovery;
      final attribute = services.single.characteristics.single;
      expect(attribute.uuid, Guid('2a19'));

      final read = attribute.read();
      await host.pump();
      await host.emit('peripheralDidUpdateValueForCharacteristic', {
        'peripheral': peripheral(),
        'characteristicHandle': 'c',
        'value': Uint8List.fromList([1, 2])
      });
      expect(await read, [1, 2]);

      final write = attribute.write([3, 4]);
      await host.pump();
      await host
          .emit('peripheralDidWriteValueForCharacteristic', {'peripheral': peripheral(), 'characteristicHandle': 'c'});
      await write;
      expect(attribute.lastValue, [3, 4]);

      final notify = attribute.setNotifyValue(true);
      await host.pump();
      await host.emit('peripheralDidUpdateNotificationStateForCharacteristic',
          {'peripheral': peripheral(), 'characteristicHandle': 'c', 'isNotifying': true});
      expect(await notify, isTrue);
      expect(attribute.isNotifying, isTrue);

      final failedRead = expectLater(
          attribute.read(),
          throwsA(isA<FlutterBluePlusException>()
              .having((error) => error.function, 'function', 'readCharacteristic')
              .having((error) => error.code, 'code', 5)
              .having((error) => error.description, 'description', 'authentication required')));
      await host.pump();
      await host.emit('peripheralDidUpdateValueForCharacteristic', {
        'peripheral': peripheral(),
        'characteristicHandle': 'c',
        'value': Uint8List(0),
        'error': {'domain': 'CBATTErrorDomain', 'code': 5, 'localizedDescription': 'authentication required'}
      });
      await failedRead;

      final failedDescriptorRead = expectLater(
          attribute.descriptors.single.read(),
          throwsA(isA<FlutterBluePlusException>()
              .having((error) => error.function, 'function', 'readDescriptor')
              .having((error) => error.code, 'code', 5)
              .having((error) => error.description, 'description', 'authentication required')));
      await host.pump();
      await host.emit('peripheralDidUpdateValueForDescriptor', {
        'peripheral': peripheral(),
        'descriptorHandle': 'd',
        'value': null,
        'error': {'domain': 'CBATTErrorDomain', 'code': 5, 'localizedDescription': 'authentication required'},
      });
      await failedDescriptorRead;

      var discoveryFinished = false;
      final failedDiscovery = expectLater(
          device.discoverServices(),
          throwsA(isA<FlutterBluePlusException>()
              .having((error) => error.function, 'function', 'discoverServices')
              .having((error) => error.code, 'code', 14)
              .having((error) => error.description, 'description', 'included discovery failed')));
      final completion = failedDiscovery.then((_) => discoveryFinished = true);
      await host.pump();
      await host.gatt(services: [service()]);
      await host.emit('peripheralDidDiscoverCharacteristicsForService',
          {'peripheral': peripheral(), 'serviceHandle': 's', 'characteristics': []});
      expect(discoveryFinished, isFalse);
      await host.emit('peripheralDidDiscoverIncludedServicesForService', {
        'peripheral': peripheral(),
        'serviceHandle': 's',
        'includedServices': [],
        'error': {'domain': 'CBATTErrorDomain', 'code': 14, 'localizedDescription': 'included discovery failed'}
      });
      await completion;

      final disconnect = device.disconnect();
      await host.pump();
      await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
      await disconnect;
      expect(device.isDisconnected, isTrue);
    } finally {
      await host.tearDown();
    }
  });
}
