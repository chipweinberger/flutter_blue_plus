import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_host.dart';

Future<void> _characteristics(CoreBluetoothHost host,
        {String handle = 's', List<Map<String, Object?>> values = const []}) =>
    host.emit('peripheralDidDiscoverCharacteristicsForService', {
      'peripheral': peripheral(),
      'serviceHandle': handle,
      'characteristics': values,
    });

Future<void> _included(CoreBluetoothHost host,
        {String handle = 's', List<Map<String, Object?>> values = const [], Map<String, Object?>? error}) =>
    host.emit('peripheralDidDiscoverIncludedServicesForService', {
      'peripheral': peripheral(),
      'serviceHandle': handle,
      'includedServices': values,
      'error': error,
    });

Future<void> _descriptors(CoreBluetoothHost host, {String handle = 'c'}) =>
    host.emit('peripheralDidDiscoverDescriptorsForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': handle,
      'descriptors': [descriptor()],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothHost host;
  late List<BmDiscoverServicesResult> results;
  setUp(() async {
    host = CoreBluetoothHost();
    await host.setUp();
    await host.connect();
    results = [];
    final subscription = host.backend.onDiscoveredServices.listen(results.add);
    addTearDown(subscription.cancel);
  });
  tearDown(() => host.tearDown());

  for (final failureStage in ['services', 'characteristics', 'includedServices', 'descriptors']) {
    test('null $failureStage discovery retains the native FBP error', () async {
      final error = {'domain': 'CBATTErrorDomain', 'code': 14, 'localizedDescription': 'discovery failed'};
      await host.backend.discoverServices(BmDiscoverServicesRequest(remoteId: DeviceIdentifier(deviceId)));
      await host.emit('peripheralDidDiscoverServices', {
        'peripheral': peripheral(),
        'services': failureStage == 'services'
            ? null
            : [
                {...service(), 'characteristics': null, 'includedServices': null}
              ],
        'error': failureStage == 'services' ? error : null,
      });
      if (failureStage != 'services') {
        await host.emit('peripheralDidDiscoverCharacteristicsForService', {
          'peripheral': peripheral(),
          'serviceHandle': 's',
          'characteristics': failureStage == 'characteristics'
              ? null
              : [
                  {...characteristic(), 'descriptors': null}
                ],
          'error': failureStage == 'characteristics' ? error : null,
        });
        await host.emit('peripheralDidDiscoverIncludedServicesForService', {
          'peripheral': peripheral(),
          'serviceHandle': 's',
          'includedServices': null,
          'error': failureStage == 'includedServices' ? error : null,
        });
        if (failureStage != 'characteristics') {
          await host.emit('peripheralDidDiscoverDescriptorsForCharacteristic', {
            'peripheral': peripheral(),
            'characteristicHandle': 'c',
            'descriptors': null,
            'error': failureStage == 'descriptors' ? error : null,
          });
        }
      }
      expect(results, hasLength(1));
      expect(results.single.success, isFalse);
      expect(results.single.errorCode, 14);
      expect(results.single.errorString, 'discovery failed');
    });
  }

  for (final includedFirst in [false, true]) {
    for (final failure in ['none', 'att', 'restricted']) {
      test('empty characteristics wait for included services (included first: $includedFirst, error: $failure)',
          () async {
        final error = switch (failure) {
          'att' => {'domain': 'CBATTErrorDomain', 'code': 14, 'localizedDescription': 'included discovery failed'},
          'restricted' => {'domain': 'CBErrorDomain', 'code': 8, 'localizedDescription': 'restricted'},
          _ => null,
        };
        await host.backend.discoverServices(BmDiscoverServicesRequest(remoteId: DeviceIdentifier(deviceId)));
        await host.gatt(services: [service()]);
        if (includedFirst) {
          await _included(host, error: error);
        } else {
          await _characteristics(host);
        }
        expect(results, isEmpty);
        if (includedFirst) {
          await _characteristics(host);
        } else {
          await _included(host, error: error);
        }
        expect(results, hasLength(1));
        expect(results.single.success, failure != 'att');
        expect(results.single.errorCode, failure == 'att' ? 14 : 0);
        expect(results.single.services.single.serviceUuid, Guid('180f'));
        expect(results.single.services.single.characteristics, isEmpty);
        // Completed subrequests must not begin another aggregate discovery.
        await _characteristics(host);
        await _included(host, error: error);
        expect(results, hasLength(1));
      });
    }
  }

  test('nested service discovery waits for every included-service and descriptor callback', () async {
    await host.gatt(services: [service()]);
    await _characteristics(host);
    expect(results, isEmpty);
    await _included(host, values: [service(handle: 'secondary', uuid: '1810', primary: false)]);
    expect(results, isEmpty);
    await _characteristics(host, handle: 'secondary', values: [characteristic()]);
    await _descriptors(host);
    expect(results, isEmpty);
    await _included(host, handle: 'secondary');
    expect(results.single.success, isTrue);
    // Retain the existing top-level FBP service layout and native attribute access.
    expect(results.single.services.single.serviceUuid, Guid('180f'));
    await host.backend.readCharacteristic(BmReadCharacteristicRequest(
        remoteId: DeviceIdentifier(deviceId),
        primaryServiceUuid: Guid('180f'),
        serviceUuid: Guid('1810'),
        characteristicUuid: Guid('2a19'),
        instanceId: 0));
    expect((host.calls.last.arguments as Map)['characteristicHandle'], 'c');
    await _descriptors(host);
    expect(results, hasLength(1));
  });

  test('shared included services are queried once and still delay completion', () async {
    await host.gatt(services: [service(), service(handle: 'other', uuid: '180a')]);
    await _characteristics(host);
    await _characteristics(host, handle: 'other');
    final shared = service(handle: 'shared', uuid: '1810', primary: false);
    await _included(host, values: [shared]);
    await _included(host, handle: 'other', values: [shared]);
    for (final method in ['discoverCharacteristics', 'discoverIncludedServices']) {
      expect(
          host.calls.where(
              (call) => call.method == 'peripheral.$method' && (call.arguments as Map)['serviceHandle'] == 'shared'),
          hasLength(1));
    }
    await _included(host, handle: 'shared');
    expect(results, isEmpty);
    await _characteristics(host, handle: 'shared');
    expect(results.single.success, isTrue);
    expect(results.single.services, hasLength(2));
  });

  test('included-service submission failure completes once and permits a fresh discovery', () async {
    host.handle = (call) {
      if (call.method == 'peripheral.discoverIncludedServices') {
        throw PlatformException(code: 'invalid_args', message: 'included request failed');
      }
      return null;
    };
    await host.gatt();
    expect(results.single.success, isFalse);
    expect(results.single.errorString, contains('included request failed'));
    await _characteristics(host, values: [characteristic()]);
    await _included(host);
    await _descriptors(host);
    expect(results, hasLength(1));
    host.handle = null;
    await host.backend.discoverServices(BmDiscoverServicesRequest(remoteId: DeviceIdentifier(deviceId)));
    await host.gatt(services: [service()]);
    await _characteristics(host);
    expect(results, hasLength(1));
    await _included(host);
    expect(results, hasLength(2));
    expect(results.last.success, isTrue);
  });

  test('restoration retains cached notifications and waits for actual discovery callbacks', () async {
    final notifications = <BmDescriptorData>[];
    final subscription = host.backend.onDescriptorWritten.listen(notifications.add);
    addTearDown(subscription.cancel);
    await host.emit('willRestoreState', {
      'peripherals': [
        {
          ...peripheral(),
          'services': [
            service(characteristics: [
              characteristic(notifying: true, descriptors: [descriptor()])
            ])
          ]
        }
      ]
    });
    expect(notifications.single.value, [1, 0, 0, 0]);
    expect(results, isEmpty);
    expect(host.calls.where((call) => call.method == 'peripheral.discoverDescriptors'), isEmpty);
    await _included(host);
    expect(results, isEmpty);
    await _characteristics(host, values: [characteristic(notifying: true)]);
    expect(results, isEmpty);
    expect(host.calls.where((call) => call.method == 'peripheral.discoverDescriptors'), hasLength(1));
    await _descriptors(host);
    expect(results.single.success, isTrue);
    expect(results.single.services.single.characteristics.single.descriptors.single.descriptorUuid, Guid('2902'));
    await _characteristics(host, values: [characteristic(notifying: true)]);
    await _included(host);
    await _descriptors(host);
    expect(results, hasLength(1));
  });
}
