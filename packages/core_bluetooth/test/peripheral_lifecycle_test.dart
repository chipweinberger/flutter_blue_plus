import 'dart:async';
import 'dart:typed_data';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

const _identifier = '12345678-1234-1234-1234-123456789abc';

Map<String, Future<void> Function()> _operations(cb.CBPeripheral peripheral, cb.CBService service) {
  final characteristic = service.characteristics!.single;
  final descriptor = characteristic.descriptors!.single;
  return {
    'discoverServices': () => peripheral.discoverServices([cb.CBUUID('180f')]),
    'discoverIncludedServices': () => peripheral.discoverIncludedServices(null, forService: service),
    'discoverCharacteristics': () => peripheral.discoverCharacteristics(forService: service),
    'discoverDescriptors': () => peripheral.discoverDescriptors(characteristic),
    'readRSSI': peripheral.readRSSI,
    'openL2CAPChannel': () => peripheral.openL2CAPChannel(25),
    'readValueForCharacteristic': () => peripheral.readValue(characteristic),
    'readValueForDescriptor': () => peripheral.readValue(descriptor),
    'setNotifyValue': () => peripheral.setNotifyValue(true, characteristic),
    'writeValueForCharacteristic': () => peripheral.writeValue(Uint8List.fromList([7]),
        forAttribute: characteristic, type: cb.CBCharacteristicWriteType.withResponse),
    'writeValueForDescriptor': () => peripheral.writeValue(Uint8List.fromList([1, 0]), forAttribute: descriptor),
    'maximumWriteValueLength': () async {
      await peripheral.maximumWriteValueLength(cb.CBCharacteristicWriteType.withResponse);
    },
    'canSendWriteWithoutResponse': () async {
      await peripheral.getCanSendWriteWithoutResponse();
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  late cb.CBCentralManager manager;
  late cb.CBPeripheral peripheral;
  late cb.CBService service;
  setUp(() async {
    host = CoreBluetoothTestHost()..setUp();
    host.handle = (call) {
      if (call.method == 'centralManager.retrievePeripherals') {
        return [
          {'identifier': _identifier, 'state': 2, 'canSendWriteWithoutResponse': false}
        ];
      }
      return null;
    };
    manager = host.trackCentral(cb.CBCentralManager.createIsolated());
    peripheral = (await manager.retrievePeripherals([cb.UUID(_identifier)])).single;
    service = cb.CBService.fromMap(peripheral: peripheral, map: {
      'handle': 'service',
      'uuid': '180f',
      'isPrimary': true,
      'characteristics': [
        {
          'handle': 'characteristic',
          'uuid': '2a19',
          'properties': 18,
          'isNotifying': false,
          'descriptors': [
            {
              'handle': 'descriptor',
              'uuid': '2902',
              'value': [0, 0]
            }
          ],
        }
      ],
    });
  });
  tearDown(() => host.tearDown());

  test('GATT snapshots distinguish omitted, null and empty collections', () {
    final characteristic = service.characteristics!.single;
    final descriptor = characteristic.descriptors!.single;
    final identity = {'handle': service.handle, 'uuid': '180f', 'isPrimary': true};
    expect(cb.CBService.fromMap(peripheral: peripheral, map: identity), same(service));
    expect(service.characteristics!.single, same(characteristic));
    final characteristicMap = {'handle': characteristic.handle, 'uuid': '2a19', 'properties': 18};
    expect(cb.CBCharacteristic.fromMap(service: service, map: characteristicMap), same(characteristic));
    expect(characteristic.descriptors!.single, same(descriptor));
    cb.CBCharacteristic.fromMap(service: service, map: {...characteristicMap, 'descriptors': null});
    expect(characteristic.descriptors, isNull);
    cb.CBCharacteristic.fromMap(service: service, map: {...characteristicMap, 'descriptors': []});
    expect(characteristic.descriptors, isEmpty);
    for (final value in [<Object?>[], null]) {
      cb.CBService.fromMap(peripheral: peripheral, map: {
        ...identity,
        'includedServices': value,
        'characteristics': value,
      });
      expect(service.includedServices, value == null ? isNull : isEmpty);
      expect(service.characteristics, value == null ? isNull : isEmpty);
    }
  });

  for (final empty in [false, true]) {
    for (final failed in [false, true]) {
      test('discovery callbacks preserve ${empty ? 'empty' : 'null'} collections (failed: $failed)', () async {
        final peer = {'identifier': _identifier, 'state': 2};
        final collection = empty ? <Object?>[] : null;
        final error = failed ? {'domain': 'CBATTErrorDomain', 'code': 10, 'localizedDescription': 'Not found'} : null;
        final expected = empty ? isEmpty : isNull;
        await host.emitCentral('peripheralDidDiscoverServices', {
          'peripheral': peer,
          'services': [
            {'handle': service.handle, 'uuid': '180f', 'isPrimary': true}
          ],
        });
        final characteristic = service.characteristics!.single;
        final descriptor = characteristic.descriptors!.single;
        final descriptorResult = peripheral.onDidDiscoverDescriptorsForCharacteristic.first;
        await host.emitCentral('peripheralDidDiscoverDescriptorsForCharacteristic', {
          'peripheral': peer,
          'characteristicHandle': characteristic.handle,
          'descriptors': collection,
          'error': error,
        });
        expect((await descriptorResult).descriptors, expected);
        expect(characteristic.descriptors, expected);
        final received = <cb.DidUpdateValueForDescriptorResult>[];
        final subscription = peripheral.onDidUpdateValueForDescriptor.listen(received.add);
        addTearDown(subscription.cancel);
        await host.emitCentral('peripheralDidUpdateValueForDescriptor', {
          'peripheral': peer,
          'descriptorHandle': descriptor.handle,
          'value': [1],
        });
        expect(received, isEmpty);
        final includedResult = peripheral.onDidDiscoverIncludedServicesForService.first;
        await host.emitCentral('peripheralDidDiscoverIncludedServicesForService', {
          'peripheral': peer,
          'serviceHandle': service.handle,
          'includedServices': collection,
          'error': error,
        });
        expect((await includedResult).includedServices, expected);
        expect(service.includedServices, expected);
        final characteristicResult = peripheral.onDidDiscoverCharacteristicsForService.first;
        await host.emitCentral('peripheralDidDiscoverCharacteristicsForService', {
          'peripheral': peer,
          'serviceHandle': service.handle,
          'characteristics': collection,
          'error': error,
        });
        expect((await characteristicResult).characteristics, expected);
        expect(service.characteristics, expected);
        final servicesResult = peripheral.onDidDiscoverServices.first;
        await host.emitCentral('peripheralDidDiscoverServices', {
          'peripheral': peer,
          'services': collection,
          'error': error,
        });
        final result = await servicesResult;
        expect(result.services, expected);
        expect(result.error?.code.rawValue, failed ? 10 : null);
        expect(peripheral.services, expected);
      });
    }
  }

  test('restoration with null services retires an existing discovery graph', () async {
    final peer = {'identifier': _identifier, 'state': 2};
    await host.emitCentral('peripheralDidDiscoverServices', {
      'peripheral': peer,
      'services': [
        {'handle': service.handle, 'uuid': '180f', 'isPrimary': true}
      ],
    });
    expect(peripheral.services!.single, same(service));
    final restoration = manager.onWillRestoreState.first;
    await host.emitCentral('willRestoreState', {
      'peripherals': [
        {...peer, 'services': null}
      ]
    });
    expect((await restoration).peripherals.single, same(peripheral));
    expect(peripheral.services, isNull);
  });

  test('local GATT snapshots preserve null and empty child collections', () {
    for (final value in [null, <Object?>[]]) {
      final local = cb.CBMutableService.fromMap({
        'uuid': '180f',
        'isPrimary': true,
        'includedServices': value,
        'characteristics': value,
      });
      final characteristic = cb.CBMutableCharacteristic.fromMap({
        'uuid': '2a19',
        'properties': 2,
        'permissions': 1,
        'descriptors': value,
      });
      final expected = value == null ? isNull : isEmpty;
      expect(local.includedServices, expected);
      expect(local.characteristics, expected);
      expect(characteristic.descriptors, expected);
    }
  });

  test('discovery refreshes native broadcast state independently of the capability bit', () async {
    await host.emitCentral('peripheralDidDiscoverServices', {
      'peripheral': {'identifier': _identifier},
      'services': [
        {'handle': service.handle, 'uuid': '180f', 'isPrimary': true}
      ],
    });
    final characteristic = service.characteristics!.single;
    for (final broadcasted in [false, true, false]) {
      final callback = peripheral.onDidDiscoverCharacteristicsForService.first;
      await host.emitCentral('peripheralDidDiscoverCharacteristicsForService', {
        'peripheral': {'identifier': _identifier},
        'serviceHandle': service.handle,
        'characteristics': [
          {
            'handle': characteristic.handle,
            'uuid': '2a19',
            'properties': 3,
            'isBroadcasted': broadcasted,
            'isNotifying': false,
          }
        ],
      });
      expect((await callback).characteristics!.single, same(characteristic));
      expect(characteristic.properties.hasBroadcast, isTrue);
      expect(characteristic.isBroadcasted, broadcasted);
    }
    // An older snapshot without the field must not infer activity from capability.
    final refreshed = cb.CBCharacteristic.fromMap(service: service, map: {
      'handle': characteristic.handle,
      'uuid': '2a19',
      'properties': 3,
    });
    expect(refreshed, same(characteristic));
    expect(refreshed.isBroadcasted, isFalse);
  });

  test('live peripheral operations retain native method names, owner and attribute handles', () async {
    host.handle = (call) {
      if (call.method == 'peripheral.maximumWriteValueLength') return 185;
      if (call.method == 'peripheral.canSendWriteWithoutResponse') return true;
      return null;
    };
    for (final operation in _operations(peripheral, service).entries) {
      await operation.value();
      final call = host.calls.last;
      expect(call.method, 'peripheral.${operation.key}');
      final arguments = call.arguments as Map;
      expect(arguments['managerId'], 1);
      expect(arguments['peripheralIdentifier'], _identifier);
      if (arguments.containsKey('serviceHandle')) expect(arguments['serviceHandle'], 'service');
      if (arguments.containsKey('characteristicHandle')) expect(arguments['characteristicHandle'], 'characteristic');
      if (arguments.containsKey('descriptorHandle')) expect(arguments['descriptorHandle'], 'descriptor');
    }
    expect(peripheral.canSendWriteWithoutResponse, isTrue);
  });

  for (final waitForDisposal in [false, true]) {
    test('all peripheral operations reject disposal (completed: $waitForDisposal)', () async {
      final disposal = manager.dispose();
      if (waitForDisposal) await disposal;
      for (final operation in _operations(peripheral, service).entries) {
        await expectLater(Future<void>.sync(operation.value), throwsStateError, reason: operation.key);
      }
      await disposal;
      expect(host.calls.where((call) => call.method.startsWith('peripheral.')), isEmpty);
    });
  }

  for (final method in ['maximumWriteValueLength', 'canSendWriteWithoutResponse']) {
    test('an in-flight $method reply is rejected after disposal without updating cached readiness', () async {
      final reply = Completer<Object?>();
      host.handle = (call) async {
        if (call.method == 'peripheral.$method') return await reply.future;
        return null;
      };
      final operation = expectLater(Future<void>.sync(_operations(peripheral, service)[method]!), throwsStateError);
      await host.pump();
      await manager.dispose();
      reply.complete(method == 'maximumWriteValueLength' ? 185 : true);
      await operation;
      expect(peripheral.canSendWriteWithoutResponse, isFalse);
    });
  }
}
