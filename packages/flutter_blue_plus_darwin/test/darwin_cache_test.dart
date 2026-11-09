import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothHost host;
  setUp(() async {
    host = CoreBluetoothHost();
    await host.setUp();
    await host.connect();
  });
  tearDown(() => host.tearDown());

  test('descriptor replacement evicts removed descriptor handles', () async {
    await host.gatt();
    final results = <BmDescriptorData>[];
    final subscription = host.backend.onDescriptorRead.listen(results.add);
    await host.emit('peripheralDidDiscoverDescriptorsForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'c',
      'descriptors': [],
    });
    await host.emit('peripheralDidUpdateValueForDescriptor', {
      'peripheral': peripheral(),
      'descriptorHandle': 'd',
      'value': Uint8List.fromList([9]),
    });
    expect(results, isEmpty);
    await subscription.cancel();
  });

  test('characteristic replacement evicts its old characteristic and descriptor handles', () async {
    await host.gatt();
    final values = <BmCharacteristicData>[];
    final descriptors = <BmDescriptorData>[];
    final characteristicSubscription = host.backend.onCharacteristicReceived.listen(values.add);
    final descriptorSubscription = host.backend.onDescriptorRead.listen(descriptors.add);
    await host.emit('peripheralDidDiscoverCharacteristicsForService', {
      'peripheral': peripheral(),
      'serviceHandle': 's',
      'characteristics': [],
    });
    await host.emit('peripheralDidUpdateValueForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'c',
      'value': Uint8List.fromList([9]),
    });
    await host.emit('peripheralDidUpdateValueForDescriptor', {
      'peripheral': peripheral(),
      'descriptorHandle': 'd',
      'value': Uint8List.fromList([9]),
    });
    expect(values, isEmpty);
    expect(descriptors, isEmpty);
    await characteristicSubscription.cancel();
    await descriptorSubscription.cancel();
  });

  test('included-service replacement evicts attributes in removed services', () async {
    await host.gatt(services: [
      service(included: [
        service(
            handle: 'secondary', uuid: '1810', primary: false, characteristics: [characteristic(handle: 'includedC')])
      ])
    ]);
    final values = <BmCharacteristicData>[];
    final subscription = host.backend.onCharacteristicReceived.listen(values.add);
    await host.emit('peripheralDidDiscoverIncludedServicesForService', {
      'peripheral': peripheral(),
      'serviceHandle': 's',
      'includedServices': [],
    });
    await host.emit('peripheralDidUpdateValueForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'includedC',
      'value': Uint8List.fromList([9]),
    });
    expect(values, isEmpty);
    await subscription.cancel();
  });
}
