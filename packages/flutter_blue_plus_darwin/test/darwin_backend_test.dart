import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_darwin/flutter_blue_plus_darwin.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_host.dart';

BmReadCharacteristicRequest readRequest({int instance = 0, String? primary, String svc = '180f'}) =>
    BmReadCharacteristicRequest(
        remoteId: DeviceIdentifier(deviceId),
        primaryServiceUuid: primary == null ? null : Guid(primary),
        serviceUuid: Guid(svc),
        characteristicUuid: Guid('2a19'),
        instanceId: instance);
BmWriteCharacteristicRequest writeRequest(List<int> value, {bool noResponse = false, bool longWrite = false}) =>
    BmWriteCharacteristicRequest(
        remoteId: DeviceIdentifier(deviceId),
        primaryServiceUuid: null,
        serviceUuid: Guid('180f'),
        characteristicUuid: Guid('2a19'),
        instanceId: 0,
        value: value,
        writeType: noResponse ? BmWriteType.withoutResponse : BmWriteType.withResponse,
        allowLongWrite: longWrite);
BmReadDescriptorRequest readDescriptorRequest() => BmReadDescriptorRequest(
    remoteId: DeviceIdentifier(deviceId),
    primaryServiceUuid: null,
    serviceUuid: Guid('180f'),
    characteristicUuid: Guid('2a19'),
    instanceId: 0,
    descriptorUuid: Guid('2902'));
Matcher platformError(String code, [String? message]) => isA<PlatformException>()
    .having((e) => e.code, 'code', code)
    .having((e) => e.message, 'message', message == null ? anything : contains(message));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothHost host;
  setUp(() async {
    host = CoreBluetoothHost();
    await host.setUp();
  });
  tearDown(() => host.tearDown());

  test('adapter and system devices use CoreBluetooth with FBP identifiers', () async {
    expect((await host.backend.getAdapterName(BmBluetoothAdapterNameRequest())).adapterName, 'Adapter');
    expect((await host.backend.getAdapterState(BmBluetoothAdapterStateRequest())).adapterState, BmAdapterStateEnum.on);
    final devices = await host.backend.getSystemDevices(BmSystemDevicesRequest(withServices: [Guid('180f')]));
    expect(devices.devices.single.remoteId.str, deviceId);
    expect((host.calls.last.arguments as Map)['serviceUUIDs'], ['180f']);
  });

  test('adapter off stops scanning and synthesizes the original disconnect reason', () async {
    await host.connect();
    final states = <BmConnectionStateResponse>[];
    final subscription = host.backend.onConnectionStateChanged.listen(states.add);
    await host.emit('didUpdateState', {'state': 4});
    expect(states.single.disconnectReasonCode, 1573878);
    expect(states.single.disconnectReasonString, 'Bluetooth turned off');
    expect(host.calls.any((c) => c.method == 'centralManager.stopScan'), isTrue);
    await expectLater(
        host.backend.startScan(scanSettings()), throwsA(platformError('startScan', 'CBManagerStatePoweredOff')));
    await subscription.cancel();
  });

  test('connect and disconnect retain idempotent return values and native access', () async {
    final request = BmConnectRequest(remoteId: DeviceIdentifier(deviceId), autoConnect: true);
    expect(await host.backend.connect(request), isTrue);
    expect(await host.backend.connect(request), isTrue);
    expect(host.calls.where((c) => c.method == 'centralManager.connect'), hasLength(1));
    expect(((host.calls.last.arguments as Map)['options'] as Map)['enableAutoReconnect'], isTrue);
    await host.emit('didConnectPeripheral', {'peripheral': peripheral()});
    expect(await host.backend.connect(request), isFalse);
    expect(FlutterBluePlusDarwin.centralManager, same(cb.CBCentralManager.shared));
    expect(FlutterBluePlusDarwin.getPeripheral(deviceId.toLowerCase())?.identifier.uuidString, deviceId.toLowerCase());
    expect(await host.backend.disconnect(BmDisconnectRequest(remoteId: DeviceIdentifier(deviceId))), isTrue);
    await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
    expect(await host.backend.disconnect(BmDisconnectRequest(remoteId: DeviceIdentifier(deviceId))), isFalse);
  });

  test('invalid and unknown remote ids retain operation-specific errors', () async {
    await expectLater(host.backend.connect(BmConnectRequest(remoteId: DeviceIdentifier('invalid'), autoConnect: false)),
        throwsA(platformError('connect', 'invalid remoteId')));
    host.responses['centralManager.retrievePeripherals'] = [];
    await expectLater(host.backend.connect(BmConnectRequest(remoteId: DeviceIdentifier(deviceId), autoConnect: false)),
        throwsA(platformError('connect', 'Peripheral not found')));
    await expectLater(
        host.backend.readCharacteristic(readRequest()), throwsA(platformError('readCharacteristic', 'disconnected')));
  });

  test('native connection errors retain unknown numeric codes and cancellation semantics', () async {
    await host.connect();
    final events = <BmConnectionStateResponse>[];
    final subscription = host.backend.onConnectionStateChanged.listen(events.add);
    await host.emit('didDisconnectPeripheral', {
      'peripheral': peripheral(state: 0),
      'error': {'domain': 'CBErrorDomain', 'code': 987, 'localizedDescription': 'native failure'}
    });
    expect(events.last.disconnectReasonCode, 987);
    await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
    expect(events.last.disconnectReasonCode, bmUserCanceledErrorCode);
    await host.emit('didFailToConnectPeripheral', {'peripheral': peripheral(state: 0)});
    expect(events.last.disconnectReasonCode, isNull);
    await subscription.cancel();
  });

  test('scan filters are additive and custom filters disable native service filtering', () async {
    final results = <BmScanResponse>[];
    final subscription = host.backend.onScanResponse.listen(results.add);
    await host.backend.startScan(scanSettings(services: [Guid('180f')], names: ['match']));
    expect((host.calls.last.arguments as Map)['serviceUUIDs'], isEmpty);
    await host.emit('didDiscoverPeripheral', {
      'peripheral': peripheral(),
      'advertisementData': {'localName': 'match'},
      'rssi': -40
    });
    await host.emit('didDiscoverPeripheral', {
      'peripheral': peripheral(),
      'advertisementData': {
        'serviceUUIDs': ['180f']
      },
      'rssi': -41
    });
    await host.emit('didDiscoverPeripheral', {
      'peripheral': peripheral(),
      'advertisementData': {'localName': 'other'},
      'rssi': -42
    });
    expect(results, hasLength(2));
    expect(results.first.advertisements.single.remoteId.str, deviceId);
    expect(FlutterBluePlusDarwin.centralManager.isScanning, isTrue);
    await host.backend.stopScan(BmStopScanRequest());
    expect(FlutterBluePlusDarwin.centralManager.isScanning, isFalse);
    await subscription.cancel();
  });

  test('native scan activity does not change FBP scan submission results', () async {
    host.responses['centralManager.scanForPeripherals'] = false;
    expect(await host.backend.startScan(scanSettings()), isTrue);
    expect(FlutterBluePlusDarwin.centralManager.isScanning, isFalse);
    host.responses['centralManager.scanForPeripherals'] = true;
    expect(await host.backend.startScan(scanSettings()), isTrue);
    expect(FlutterBluePlusDarwin.centralManager.isScanning, isTrue);
  });

  test('native sampling precedes Dart filters without resampling delivered callbacks', () async {
    final results = <BmScanResponse>[];
    final subscription = host.backend.onScanResponse.listen(results.add);
    final settings = scanSettings(keywords: ['match'], continuous: true, divisor: 2);
    await host.backend.startScan(settings);
    expect((host.calls.last.arguments as Map)['advertisementDivisor'], 2);
    // For one device with names other/match/match, native divisor 2 sends indices 0 and 2.
    // The first matching advertisement (index 1) consumes a slot and never crosses the channel.
    for (final (name, rssi) in [('other', -40), ('match', -42)]) {
      await host.emit('didDiscoverPeripheral', {
        'peripheral': peripheral(),
        'advertisementData': {'localName': name},
        'rssi': rssi
      });
    }
    expect(results.single.advertisements.single.rssi, -42);
    await host.emit('didDiscoverPeripheral', {
      'peripheral': peripheral(),
      'advertisementData': {'localName': 'match'},
      'rssi': -44
    });
    expect(results, hasLength(2));
    await host.backend.startScan(settings);
    await host.emit('didDiscoverPeripheral', {
      'peripheral': peripheral(),
      'advertisementData': {'localName': 'match'},
      'rssi': -40
    });
    expect(results, hasLength(3));
    await subscription.cancel();
  });

  test('only native scan options and the continuous-update divisor reach CoreBluetooth', () async {
    for (final (continuous, divisor) in [(true, 3), (true, 1), (false, 7), (false, 1)]) {
      await host.backend.startScan(scanSettings(
        services: [Guid('180f')],
        ids: [deviceId],
        names: ['Exact'],
        keywords: ['part'],
        msd: [
          BmMsdFilter(0x1234, [2], [])
        ],
        serviceData: [
          BmServiceDataFilter(Guid('180d'), [2, 3], [])
        ],
        continuous: continuous,
        divisor: divisor,
      ));
      final args = host.calls.last.arguments as Map;
      expect(args, {
        'managerId': 1,
        'serviceUUIDs': [],
        'options': {'allowDuplicates': continuous ? true : null, 'solicitedServiceUUIDs': null},
        'advertisementDivisor': continuous ? divisor : 1,
      });
    }
  });

  test('scan preserves manufacturer bytes and the original default mask behavior', () async {
    final results = <BmScanResponse>[];
    final subscription = host.backend.onScanResponse.listen(results.add);
    final data = [2];
    await host.backend.startScan(scanSettings(msd: [BmMsdFilter(0x1234, data, [])]));
    data[0] = 1;
    await host.emit('didDiscoverPeripheral', {
      'peripheral': peripheral(),
      'advertisementData': {
        'manufacturerData': Uint8List.fromList([0x34, 0x12, 0]),
        'serviceData': {
          '180f': Uint8List.fromList([8])
        },
        'isConnectable': true
      },
      'rssi': -40
    });
    expect(results.single.advertisements.single.manufacturerData[0x1234], [0]);
    expect(results.single.advertisements.single.serviceData[Guid('180f')], [8]);
    await subscription.cancel();
  });

  test('empty discovery completes and restricted UUID errors remain nonfatal', () async {
    await host.connect();
    final results = <BmDiscoverServicesResult>[];
    final subscription = host.backend.onDiscoveredServices.listen(results.add);
    await host.backend.discoverServices(BmDiscoverServicesRequest(remoteId: DeviceIdentifier(deviceId)));
    await host.emit('peripheralDidDiscoverServices', {
      'peripheral': peripheral(),
      'services': [],
      'error': {'domain': 'CBErrorDomain', 'code': 8, 'localizedDescription': 'restricted'}
    });
    expect(results.single.success, isTrue);
    expect(results.single.services, isEmpty);
    await subscription.cancel();
  });

  test('discovery discovers characteristics and descriptors and keeps first native failure', () async {
    await host.connect();
    final results = <BmDiscoverServicesResult>[];
    final subscription = host.backend.onDiscoveredServices.listen(results.add);
    await host.gatt();
    expect(host.calls.any((c) => c.method == 'peripheral.discoverCharacteristics'), isTrue);
    await host.emit('peripheralDidDiscoverCharacteristicsForService', {
      'peripheral': peripheral(),
      'serviceHandle': 's',
      'characteristics': [characteristic()],
      'error': {'domain': 'CBATTErrorDomain', 'code': 13, 'localizedDescription': 'bad length'}
    });
    expect(results, isEmpty);
    await host.emit('peripheralDidDiscoverDescriptorsForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'c',
      'descriptors': [descriptor()],
      'error': {'domain': 'CBATTErrorDomain', 'code': 14, 'localizedDescription': 'later'}
    });
    expect(results, isEmpty);
    await host.emit('peripheralDidDiscoverIncludedServicesForService',
        {'peripheral': peripheral(), 'serviceHandle': 's', 'includedServices': []});
    expect(results.single.errorCode, 13);
    expect(results.single.services.single.characteristics.single.descriptors.single.descriptorUuid, Guid('2902'));
    await subscription.cancel();
  });

  test('duplicate services use flattened characteristic indexes', () async {
    await host.connect();
    await host.gatt(services: [
      service(characteristics: [characteristic(handle: 'c0'), characteristic(handle: 'c1', uuid: '2a00')]),
      service(handle: 's2', characteristics: [characteristic(handle: 'c2')])
    ]);
    await host.backend.readCharacteristic(readRequest(instance: 2));
    expect((host.calls.last.arguments as Map)['characteristicHandle'], 'c2');
    await expectLater(host.backend.readCharacteristic(readRequest(instance: 1)),
        throwsA(platformError('readCharacteristic', 'not found')));
  });

  test('included services retain callback lookup and characteristic identity', () async {
    await host.connect();
    await host.gatt(services: [service()]);
    await host.emit('peripheralDidDiscoverIncludedServicesForService', {
      'peripheral': peripheral(),
      'serviceHandle': 's',
      'includedServices': [service(handle: 'secondary', uuid: '1810', primary: false)]
    });
    await host.emit('peripheralDidDiscoverCharacteristicsForService', {
      'peripheral': peripheral(),
      'serviceHandle': 'secondary',
      'characteristics': [characteristic(handle: 'includedC')]
    });
    await host.backend.readCharacteristic(readRequest(primary: '180f', svc: '1810'));
    expect((host.calls.last.arguments as Map)['characteristicHandle'], 'includedC');
    final response = host.backend.onCharacteristicReceived.first;
    await host.emit('peripheralDidUpdateValueForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'includedC',
      'value': Uint8List.fromList([7])
    });
    expect((await response).primaryServiceUuid, Guid('180f'));
  });

  test('reads and notifications preserve values and native ATT errors', () async {
    await host.connect();
    await host.gatt();
    await host.backend.readCharacteristic(readRequest());
    final response = host.backend.onCharacteristicReceived.first;
    await host.emit('peripheralDidUpdateValueForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'c',
      'value': Uint8List.fromList([1, 2]),
      'error': {'domain': 'CBATTErrorDomain', 'code': 5, 'localizedDescription': 'authentication'}
    });
    final event = await response;
    expect(event.value, [1, 2]);
    expect(event.errorCode, 5);
    expect(event.success, isFalse);
  });

  test('writes retain submitted bytes and enforce payload limits', () async {
    await host.connect();
    await host.gatt();
    await expectLater(host.backend.writeCharacteristic(writeRequest(List.filled(21, 0))),
        throwsA(platformError('writeCharacteristic', 'max: 20')));
    final value = [1, 2];
    await host.backend.writeCharacteristic(writeRequest(value));
    value[0] = 9;
    final response = host.backend.onCharacteristicWritten.first;
    await host
        .emit('peripheralDidWriteValueForCharacteristic', {'peripheral': peripheral(), 'characteristicHandle': 'c'});
    expect((await response).value, [1, 2]);
    host.maxPayload = 600;
    await expectLater(host.backend.writeCharacteristic(writeRequest(List.filled(513, 0), longWrite: true)),
        throwsA(platformError('writeCharacteristic', 'max: 512')));
  });

  test('writes without response complete only on readiness callback', () async {
    await host.connect();
    await host.gatt();
    final events = <BmCharacteristicData>[];
    final subscription = host.backend.onCharacteristicWritten.listen(events.add);
    await host.backend.writeCharacteristic(writeRequest([3], noResponse: true));
    await host.pump();
    expect(events, isEmpty);
    await host.emit('peripheralIsReadyToSendWriteWithoutResponse', {'peripheral': peripheral()});
    expect(events.single.value, [3]);
    await subscription.cancel();
  });

  test('notification callbacks synthesize four-byte CCCD and prefer notify bit', () async {
    await host.connect();
    await host.gatt();
    final response = host.backend.onDescriptorWritten.first;
    await host.backend.setNotifyValue(BmSetNotifyValueRequest(
        remoteId: DeviceIdentifier(deviceId),
        primaryServiceUuid: null,
        serviceUuid: Guid('180f'),
        characteristicUuid: Guid('2a19'),
        instanceId: 0,
        forceIndications: true,
        enable: true));
    await host.emit('peripheralDidUpdateNotificationStateForCharacteristic',
        {'peripheral': peripheral(), 'characteristicHandle': 'c', 'isNotifying': true});
    final event = await response;
    expect(event.value, [1, 0, 0, 0]);
    expect(event.descriptorUuid, Guid('2902'));
  });

  test('descriptor reads convert strings and numbers into the original byte format', () async {
    await host.connect();
    await host.gatt();
    for (final pair in <(Object, List<int>)>[
      ('é', [0xc3, 0xa9]),
      (258, [2, 1, 0, 0])
    ]) {
      await host.backend.readDescriptor(readDescriptorRequest());
      final response = host.backend.onDescriptorRead.first;
      await host.emit('peripheralDidUpdateValueForDescriptor',
          {'peripheral': peripheral(), 'descriptorHandle': 'd', 'value': pair.$1});
      expect((await response).value, pair.$2);
    }
  });

  test('disconnect clears cached writes before reconnecting', () async {
    await host.connect();
    await host.gatt();
    await host.backend.writeCharacteristic(writeRequest([8]));
    await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
    await host.connect();
    await host.gatt();
    final response = host.backend.onCharacteristicWritten.first;
    await host
        .emit('peripheralDidWriteValueForCharacteristic', {'peripheral': peripheral(), 'characteristicHandle': 'c'});
    expect((await response).value, isEmpty);
  });

  test('unimplemented platform methods retain inherited return values', () async {
    expect(await host.backend.turnOn(BmTurnOnRequest()), isFalse);
    expect(await host.backend.turnOff(BmTurnOffRequest()), isFalse);
    expect((await host.backend.getBondedDevices(BmBondedDevicesRequest())).devices, isEmpty);
    expect(await host.backend.requestMtu(BmMtuChangeRequest(remoteId: DeviceIdentifier(deviceId), mtu: 100)), isFalse);
    expect(await host.backend.clearGattCache(BmClearGattCacheRequest(remoteId: DeviceIdentifier(deviceId))), isFalse);
    expect((await host.backend.getPhySupport(PhySupportRequest())).le2M, isFalse);
    expect(host.calls, isEmpty);
  });

  test('hot restart waits for native disconnect callbacks before accepting operations', () async {
    await host.backend.dispose();
    host.responses['centralManager.disconnectAllPeripherals'] = [peripheral()];
    final replacement = FlutterBluePlusDarwin();
    final events = <BmConnectionStateResponse>[];
    final subscription = replacement.onConnectionStateChanged.listen(events.add);
    var completed = false;
    final ready = replacement.isSupported(BmIsSupportedRequest()).then((value) {
      completed = true;
      return value;
    });
    try {
      await host.pump();
      expect(completed, isFalse);
      await host.emit('didConnectPeripheral', {'peripheral': peripheral()});
      expect(events, isEmpty);
      await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
      expect(await ready, isTrue);
      expect(events, isEmpty);
    } finally {
      await subscription.cancel();
      await replacement.dispose();
    }
  });

  test('restoration reuses cached services and notification state', () async {
    final connections = <BmConnectionStateResponse>[];
    final notifications = <BmDescriptorData>[];
    final c = host.backend.onConnectionStateChanged.listen(connections.add);
    final d = host.backend.onDescriptorWritten.listen(notifications.add);
    await host.emit('willRestoreState', {
      'peripherals': [
        {
          ...peripheral(),
          'services': [
            service(characteristics: [
              characteristic(notifying: true, descriptors: [descriptor()])
            ])
          ],
        }
      ]
    });
    expect(connections.single.connectionState, BmConnectionStateEnum.connected);
    expect(notifications.single.value, [1, 0, 0, 0]);
    await host.backend.readCharacteristic(readRequest());
    expect((host.calls.last.arguments as Map)['characteristicHandle'], 'c');
    await c.cancel();
    await d.cancel();
  });

  test('restoration reconnects peripherals whose connection was lost', () async {
    await host.emit('willRestoreState', {
      'peripherals': [peripheral(state: 0)]
    });
    expect(host.calls.where((c) => c.method == 'centralManager.connect'), hasLength(1));
    expect((host.calls.last.arguments as Map)['options'], isNull);
  });

  test('native readiness rejects writes after another caller fills the queue', () async {
    await host.connect();
    await host.gatt();
    host.responses['peripheral.canSendWriteWithoutResponse'] = false;
    await expectLater(host.backend.writeCharacteristic(writeRequest([1], noResponse: true)),
        throwsA(platformError('writeCharacteristic', 'you must slow down')));
    expect(host.calls.where((c) => c.method == 'peripheral.writeValueForCharacteristic'), isEmpty);
  });

  test('descriptor writes enforce MTU and echo submitted bytes', () async {
    await host.connect();
    await host.gatt();
    BmWriteDescriptorRequest request(List<int> value) => BmWriteDescriptorRequest(
        remoteId: DeviceIdentifier(deviceId),
        primaryServiceUuid: null,
        serviceUuid: Guid('180f'),
        characteristicUuid: Guid('2a19'),
        instanceId: 0,
        descriptorUuid: Guid('2902'),
        value: value);
    await expectLater(host.backend.writeDescriptor(request(List.filled(21, 0))),
        throwsA(platformError('writeDescriptor', 'maxDataLen: 20')));
    final value = [4, 5];
    await host.backend.writeDescriptor(request(value));
    value[0] = 9;
    final response = host.backend.onDescriptorWritten.first;
    await host.emit('peripheralDidWriteValueForDescriptor', {'peripheral': peripheral(), 'descriptorHandle': 'd'});
    expect((await response).value, [4, 5]);
  });

  test('single-service duplicate characteristics use UUID-local indexes', () async {
    await host.connect();
    await host.gatt(services: [
      service(characteristics: [
        characteristic(handle: 'first'),
        characteristic(handle: 'other', uuid: '2a00'),
        characteristic(handle: 'second')
      ])
    ]);
    await host.backend.readCharacteristic(readRequest(instance: 1));
    expect((host.calls.last.arguments as Map)['characteristicHandle'], 'second');
  });

  test('property checks retain the historical read error code', () async {
    await host.connect();
    await host.gatt(services: [
      service(characteristics: [characteristic(properties: 0)])
    ]);
    await expectLater(
        host.backend.readCharacteristic(readRequest()), throwsA(platformError('writeCharacteristic', 'READ property')));
    await expectLater(host.backend.writeCharacteristic(writeRequest([1])),
        throwsA(platformError('writeCharacteristic', 'WRITE property')));
  });

  test('GATT objects retain their identity across snapshots', () async {
    await host.connect();
    await host.gatt();
    final before = FlutterBluePlusDarwin.getPeripheral(deviceId)!.services!.single.characteristics!.single;
    final nativeValues = <List<int>>[];
    final subscription = FlutterBluePlusDarwin.getPeripheral(deviceId)!
        .onDidUpdateValueForCharacteristic
        .listen((event) => nativeValues.add(event.value!));
    await host.gatt();
    expect(FlutterBluePlusDarwin.getPeripheral(deviceId)!.services!.single.characteristics!.single, same(before));
    await host.emit('peripheralDidUpdateValueForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'c',
      'value': Uint8List.fromList([1])
    });
    await host.emit('peripheralDidUpdateValueForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'c',
      'value': Uint8List.fromList([2])
    });
    expect(nativeValues, [
      [1],
      [2]
    ]);
    await subscription.cancel();
  });

  test('names and service resets are forwarded only for FBP connections', () async {
    final names = <BmNameChanged>[];
    final resets = <BmBluetoothDevice>[];
    final n = host.backend.onNameChanged.listen(names.add);
    final r = host.backend.onServicesReset.listen(resets.add);
    await host.emit('peripheralDidUpdateName', {'peripheral': peripheral()});
    await host.emit('peripheralDidModifyServices', {'peripheral': peripheral(), 'invalidatedServices': []});
    expect(names, isEmpty);
    expect(resets, isEmpty);
    await host.connect();
    await host.emit('peripheralDidUpdateName', {
      'peripheral': {...peripheral(), 'name': 'New name'}
    });
    await host.emit('peripheralDidModifyServices', {'peripheral': peripheral(), 'invalidatedServices': []});
    expect(names.single.name, 'New name');
    expect(resets.single.remoteId.str, deviceId);
    await n.cancel();
    await r.cancel();
  });

  test('MTU polling emits changes, settles, and restarts for a new connection', () async {
    final values = <int>[];
    final subscription = host.backend.onMtuChanged.listen((event) => values.add(event.mtu));
    await host.connect();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    expect(values, [23]);
    host.maxPayload = 600;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(values, [23, 515]);
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    final calls = host.calls.where((c) => c.method == 'peripheral.maximumWriteValueLength').length;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(host.calls.where((c) => c.method == 'peripheral.maximumWriteValueLength'), hasLength(calls));
    await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
    await host.connect();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    expect(values, [23, 515, 515]);
    await subscription.cancel();
  });

  test('missing characteristic values retain the original rejected-callback behavior', () async {
    await host.connect();
    await host.gatt();
    final events = <BmCharacteristicData>[];
    final subscription = host.backend.onCharacteristicReceived.listen(events.add);
    await host.emit('peripheralDidUpdateValueForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'c',
      'value': null,
      'error': {'domain': 'CBATTErrorDomain', 'code': 5, 'localizedDescription': 'authentication'}
    });
    expect(events, isEmpty);
    await subscription.cancel();
  });

  test('lowercase connection identifiers retain the former lookup behavior', () async {
    await expectLater(
        host.backend.connect(BmConnectRequest(remoteId: DeviceIdentifier(deviceId.toLowerCase()), autoConnect: false)),
        throwsA(platformError('connect', 'Peripheral not found')));
  });

  test('new service snapshots evict attributes that are no longer present', () async {
    await host.connect();
    await host.gatt();
    await host.gatt(services: [
      service(handle: 'newS', characteristics: [characteristic(handle: 'newC')])
    ]);
    final events = <BmCharacteristicData>[];
    final subscription = host.backend.onCharacteristicReceived.listen(events.add);
    await host.emit('peripheralDidUpdateValueForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'c',
      'value': Uint8List.fromList([1])
    });
    await host.emit('peripheralDidUpdateValueForCharacteristic', {
      'peripheral': peripheral(),
      'characteristicHandle': 'newC',
      'value': Uint8List.fromList([2])
    });
    expect(events.single.value, [2]);
    await subscription.cancel();
  });

  test('late write readiness ignores a characteristic removed by discovery', () async {
    await host.connect();
    await host.gatt();
    await host.backend.writeCharacteristic(writeRequest([1], noResponse: true));
    await host.gatt(services: []);
    final events = <BmCharacteristicData>[];
    final subscription = host.backend.onCharacteristicWritten.listen(events.add);
    await host.emit('peripheralIsReadyToSendWriteWithoutResponse', {'peripheral': peripheral()});
    expect(events, isEmpty);
    await subscription.cancel();
  });

  test('native peripheral observers receive names and service resets alongside FBP', () async {
    await host.connect();
    final peripheralObject = FlutterBluePlusDarwin.getPeripheral(deviceId)!;
    final names = <String?>[];
    final resets = <cb.DidModifyServicesResult>[];
    final nameSubscription = peripheralObject.onDidUpdateName.listen((event) => names.add(event.name));
    final resetSubscription = peripheralObject.onDidModifyServices.listen(resets.add);
    final fbpReset = host.backend.onServicesReset.first;
    await host.emit('peripheralDidUpdateName', {
      'peripheral': {...peripheral(), 'name': 'Updated'}
    });
    await host
        .emit('peripheralDidModifyServices', {'peripheral': peripheral(), 'invalidatedServices': [], 'services': []});
    expect(names, ['Updated']);
    expect(resets, hasLength(1));
    expect((await fbpReset).platformName, 'Device');
    await nameSubscription.cancel();
    await resetSubscription.cancel();
  });

  test('service-reset snapshots prevent operations on invalidated attributes', () async {
    await host.connect();
    await host.gatt();
    await host.emit('peripheralDidModifyServices', {
      'peripheral': peripheral(),
      'invalidatedServices': [service()],
      'services': []
    });
    await expectLater(host.backend.readCharacteristic(readRequest()),
        throwsA(platformError('readCharacteristic', 'primary service not found')));
  });

  test('write readiness publishes a fresh value without changing the submitted snapshot', () async {
    await host.connect();
    await host.gatt();
    await host.backend.writeCharacteristic(writeRequest([3], noResponse: true));
    final results = <BmCharacteristicData>[];
    final subscription = host.backend.onCharacteristicWritten.listen(results.add);
    await host.emit('peripheralIsReadyToSendWriteWithoutResponse', {'peripheral': peripheral()});
    results.single.value[0] = 9;
    await host.emit('peripheralIsReadyToSendWriteWithoutResponse', {'peripheral': peripheral()});
    expect(results.last.value, [3]);
    await subscription.cancel();
  });

  for (final adapterOff in [false, true]) {
    test('reconnection requires fresh GATT discovery and preserves identity/events (adapter off: $adapterOff)',
        () async {
      await host.connect();
      await host.gatt();
      final native = FlutterBluePlusDarwin.getPeripheral(deviceId);
      await host.backend.readCharacteristic(readRequest());
      final reads = host.calls.where((call) => call.method == 'peripheral.readValueForCharacteristic').length;
      final connections = <BmConnectionStateResponse>[];
      final subscription = host.backend.onConnectionStateChanged.listen(connections.add);
      addTearDown(subscription.cancel);
      if (adapterOff) {
        await host.emit('didUpdateState', {'state': 4});
        expect(FlutterBluePlusDarwin.centralManager.connectedPeripherals, isEmpty);
        expect(native!.state, cb.CBPeripheralState.disconnected);
      } else {
        await host.emit('didDisconnectPeripheral', {'peripheral': peripheral(state: 0)});
      }
      expect(native!.services, isNull);
      expect(connections.single.connectionState, BmConnectionStateEnum.disconnected);
      expect(connections.single.disconnectReasonCode, adapterOff ? 1573878 : bmUserCanceledErrorCode);
      if (adapterOff) {
        expect(connections.single.disconnectReasonString, 'Bluetooth turned off');
        await host.emit('didUpdateState', {'state': 5});
      }
      await host.connect();
      expect(FlutterBluePlusDarwin.getPeripheral(deviceId), same(native));
      expect(connections.last.connectionState, BmConnectionStateEnum.connected);
      await expectLater(host.backend.readCharacteristic(readRequest()),
          throwsA(platformError('readCharacteristic', 'primary service not found')));
      expect(host.calls.where((call) => call.method == 'peripheral.readValueForCharacteristic'), hasLength(reads));
      await host.gatt(services: [
        service(handle: 'fresh-s', characteristics: [characteristic(handle: 'fresh-c')])
      ]);
      await host.backend.readCharacteristic(readRequest());
      expect((host.calls.last.arguments as Map)['characteristicHandle'], 'fresh-c');
    });
  }

  test('native extra advertisement UUID lists preserve FBP filtering and scan payloads', () async {
    final native = <cb.DidDiscoverPeripheralResult>[];
    final results = <BmScanResponse>[];
    final nativeSubscription = cb.CBCentralManager.shared.onDidDiscoverPeripheral.listen(native.add);
    final subscription = host.backend.onScanResponse.listen(results.add);
    addTearDown(nativeSubscription.cancel);
    addTearDown(subscription.cancel);
    await host.backend.startScan(scanSettings(services: [Guid('180f')]));
    await host.emit('didDiscoverPeripheral', {
      'peripheral': peripheral(),
      'advertisementData': {
        'overflowServiceUUIDs': ['180f'],
        'solicitedServiceUUIDs': ['180f']
      },
      'rssi': -40,
    });
    expect(results, isEmpty);
    expect(native.single.advertisementData.overflowServiceUUIDs, [cb.CBUUID('180f')]);
    expect(native.single.advertisementData.solicitedServiceUUIDs, [cb.CBUUID('180f')]);
    await host.emit('didDiscoverPeripheral', {
      'peripheral': peripheral(),
      'advertisementData': {
        'serviceUUIDs': ['180f'],
        'overflowServiceUUIDs': ['1810'],
        'solicitedServiceUUIDs': ['180d']
      },
      'rssi': -40,
    });
    expect(results.single.advertisements.single.serviceUuids, [Guid('180f')]);
    expect(native.last.advertisementData.overflowServiceUUIDs, [cb.CBUUID('1810')]);
    expect(native.last.advertisementData.solicitedServiceUUIDs, [cb.CBUUID('180d')]);
  });
}
