import 'dart:async';

import 'package:android_bluetooth/android_bluetooth.dart' as ab;
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_android/flutter_blue_plus_android.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/android_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AndroidHost host;
  setUp(() async {
    host = AndroidHost();
    await host.setUp();
  });
  tearDown(() => host.tearDown());

  test('adapter presence, name, state, PHY and system devices retain the public contract', () async {
    expect(await host.backend.isSupported(BmIsSupportedRequest()), true);
    expect((await host.backend.getAdapterName(BmBluetoothAdapterNameRequest())).adapterName, 'Adapter');
    expect((await host.backend.getAdapterState(BmBluetoothAdapterStateRequest())).adapterState, BmAdapterStateEnum.on);
    expect((await host.backend.getPhySupport(PhySupportRequest())).le2M, true);
    expect((await host.backend.getSystemDevices(BmSystemDevicesRequest(withServices: []))).devices.single.remoteId,
        remote);
    expect((await host.backend.getBondedDevices(BmBondedDevicesRequest())).devices.single.platformName, 'Device');
    expect(await host.backend.setOptions(BmSetOptionsRequest()), true);
    expect(await host.backend.turnOn(BmTurnOnRequest()), false);
    expect(await host.backend.turnOff(BmTurnOffRequest()), true);
  });

  test('no adapter reports unsupported, unknown and N/A with the legacy unavailable error', () async {
    host.adapterPresent = false;
    host.override = (call) async {
      if (call.method == 'adapter.state') throw PlatformException(code: 'unsupported');
      return null;
    };
    expect(await host.backend.isSupported(BmIsSupportedRequest()), false);
    expect((await host.backend.getAdapterState(BmBluetoothAdapterStateRequest())).adapterState,
        BmAdapterStateEnum.unknown);
    expect((await host.backend.getAdapterName(BmBluetoothAdapterNameRequest())).adapterName, 'N/A');
    await expectLater(host.backend.stopScan(BmStopScanRequest()),
        throwsA(platformError('bluetoothUnavailable', 'the device does not support bluetooth')));
  });

  test('name permission denial returns empty and scan denial uses its original error', () async {
    host.granted[connectPermission] = false;
    host.denied.add(connectPermission);
    expect((await host.backend.getAdapterName(BmBluetoothAdapterNameRequest())).adapterName, '');
    await expectLater(host.backend.startScan(scanSettings()),
        throwsA(platformError('startScan', 'Permission $connectPermission required to scan devices')));
    expect(host.calls.where((c) => c.method == 'permissions.check').last.arguments['permissions'],
        [scanPermission, connectPermission]);
  });

  test('pre-31 location preflight precedes permission prompts and PHY requires 26', () async {
    host.api = 25;
    host.locationEnabled = false;
    await expectLater(host.backend.startScan(scanSettings()),
        throwsA(platformError('startScan', 'Location services are required for Bluetooth scan')));
    expect(host.calls.where((c) => c.method.startsWith('permissions.')), isEmpty);
    await expectLater(host.backend.getPhySupport(PhySupportRequest()),
        throwsA(platformError('getPhySupport', 'Only supported on devices >= API 26. This device == 25')));
    await host.backend.startScan(scanSettings(location: false));
    expect(host.calls.where((c) => c.method == 'permissions.check').last.arguments['permissions'], [fineLocation]);
  });

  test('turnOn reports launch immediately and forwards the later activity result', () async {
    host.state = 10;
    final responses = host.collect(host.backend.onTurnOnResponse);
    expect(await host.backend.turnOn(BmTurnOnRequest()), true);
    expect(responses, isEmpty);
    await emit({'owner': 'adapter', 'type': 'onEnableResponse', 'userAccepted': false});
    expect(responses.single.userAccepted, false);
    expect(await host.backend.turnOff(BmTurnOffRequest()), true);
  });

  test('scan defaults, repeated MSD, appearance and A/B/A dedup match legacy', () async {
    final responses = host.collect(host.backend.onScanResponse);
    await host.backend.startScan(scanSettings());
    final settings = host.calls.last.arguments['settings'];
    expect(settings['scanMode'], 2);
    expect(settings['legacy'], false);
    expect(settings['phy'], 255);
    final a = [4, 255, 0x4c, 0, 1, 4, 255, 0x4c, 0, 2, 3, 0x19, 0x40, 3, 0];
    await host.advertisement(a);
    await host.advertisement(a, rssi: -80);
    await host.advertisement([2, 1, 6, 0]);
    await host.advertisement(a);
    expect(responses.length, 3);
    final adv = responses.first.advertisements.single;
    expect(adv.manufacturerData, {
      0x4c: [1, 0x4c, 0, 2]
    });
    expect(adv.appearance, 832);
    expect(adv.txPowerLevel, null);
    expect(adv.serviceUuids, [Guid('180d')]);
    await host.advertisement([0], type: 'onBatchScanResults');
    expect(responses.length, 3);
    await host.backend.stopScan(BmStopScanRequest());
    expect(host.calls.last.method, 'scan.stopSession');
  });

  for (final api in [30, 33]) {
    test('API $api retains appearance selection and advertising field boundaries', () async {
      host.api = api;
      final responses = host.collect(host.backend.onScanResponse);
      await host.backend.startScan(scanSettings(continuous: true));
      await host.advertisement([3, 0x19, 1, 0, 3, 0x19, 2, 0, 0]);
      // A type-zero field ends the legacy appearance search, but not MSD parsing.
      await host.advertisement([1, 0, 3, 0x19, 3, 0, 4, 0xff, 0x4c, 0, 9, 0]);
      await host.advertisement([3, 0x19, 0, 0, 3, 0x19, 4, 0, 0]);
      // A truncated field leaves the preceding complete fields intact.
      await host.advertisement([4, 0xff, 0x4c, 0, 7, 3, 0x19, 5]);
      await host.advertisement([0, 3, 0x19, 6, 0]);
      final advertisements = responses.map((response) => response.advertisements.single).toList();
      expect(advertisements.map((advertisement) => advertisement.appearance),
          api < 33 ? [1, null, null, null, null] : [2, 3, 4, null, null]);
      expect(advertisements[1].manufacturerData, {
        0x4c: [9]
      });
      expect(advertisements[3].manufacturerData, {
        0x4c: [7]
      });
    });
  }

  test('keyword matching is case sensitive and divisor counts only matching names', () async {
    final responses = host.collect(host.backend.onScanResponse);
    await host.backend.startScan(scanSettings(continuous: true, divisor: 2, keywords: ['Heart']));
    final filters = host.calls.last.arguments['filters'] as List;
    expect(filters.map((f) => f['advertisingDataType']), [8, 9]);
    await host.advertisement([0], name: 'heart');
    await host.advertisement([0], name: 'Heart');
    await host.advertisement([0], name: 'Heart');
    await host.advertisement([0], name: 'Heart');
    expect(responses.length, 2);
  });

  test('failed scan can restart and old session callbacks cannot enter the next scan', () async {
    final responses = host.collect(host.backend.onScanResponse);
    await host.backend.startScan(scanSettings());
    final old = host.scan;
    await emit({'owner': old, 'type': 'onScanFailed', 'errorCode': 6});
    expect(responses.single.errorString, 'SCAN_FAILED_SCANNING_TOO_FREQUENTLY');
    await host.backend.startScan(scanSettings());
    await emit({'owner': old, 'type': 'onScanFailed', 'errorCode': 3});
    expect(responses.length, 1);
    await host.advertisement([0]);
    expect(responses.length, 2);
  });

  test('connect booleans, duplicate callbacks and pending cancellation match legacy', () async {
    final states = host.collect(host.backend.onConnectionStateChanged);
    expect(await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false)), true);
    expect(await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false)), true);
    expect(host.calls.where((c) => c.method == 'gatt.open').length, 1);
    final old = host.gatt;
    expect(await host.backend.disconnect(BmDisconnectRequest(remoteId: remote)), true);
    await tick();
    expect(states.single.disconnectReasonCode, 23789258);
    expect(states.single.disconnectReasonString, 'connection canceled');
    await host.connect();
    expect(await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false)), false);
    await host.connection(2);
    await host.connection(2, owner: old);
    expect(states.length, 2);
    expect(await host.backend.disconnect(BmDisconnectRequest(remoteId: remote)), true);
    await host.connection(0, status: 0x13);
    expect(states.last.disconnectReasonString, 'REMOTE_USER_TERMINATED_CONNECTION');
    expect(await host.backend.disconnect(BmDisconnectRequest(remoteId: remote)), false);
  });

  test('auto-connect keeps the same client until explicit disconnect', () async {
    final states = host.collect(host.backend.onConnectionStateChanged);
    await host.connect(autoConnect: true);
    final client = FlutterBluePlusAndroid.getGatt(address);
    await host.connection(0, status: 8);
    expect(FlutterBluePlusAndroid.getGatt(address), same(client));
    expect(host.calls.where((c) => c.method == 'gatt.close'), isEmpty);
    await host.connection(2);
    expect(states.length, 3);
    await host.connection(0);
    expect(await host.backend.disconnect(BmDisconnectRequest(remoteId: remote)), false);
    expect(FlutterBluePlusAndroid.getGatt(address), null);
    expect(ab.BluetoothDevice(address).gattClients, isEmpty);
  });

  test('adapter shutdown emits state before synthetic disconnect and closes all clients', () async {
    final order = <String>[];
    host.subscriptions.add(host.backend.onAdapterStateChanged.listen((_) => order.add('adapter')));
    host.subscriptions.add(host.backend.onConnectionStateChanged.listen((e) => order.add(e.connectionState.name)));
    await host.connect();
    order.clear();
    await host.adapter(13);
    await host.adapter(10);
    expect(order, ['adapter', 'disconnected', 'adapter']);
    expect(FlutterBluePlusAndroid.getGatt(address), null);
  });

  test('direct package lookup returns FBP client and additional listeners receive its callbacks', () async {
    await host.connect();
    final client = ab.BluetoothDevice(address.toLowerCase()).gattClients.single;
    expect(client, same(FlutterBluePlusAndroid.getGatt(address)));
    final native = host.collect(client.onMtuChanged);
    final fbp = host.collect(host.backend.onMtuChanged);
    await host.callback('onMtuChanged', extra: {'mtu': 247});
    expect(native.single.mtu, 247);
    expect(fbp.single.mtu, 247);
    expect(host.calls.where((c) => c.method == 'gatt.open').length, 1);
  });

  test('discovery translates unique IDs, duplicate service ordinals and included services', () async {
    final discovered = host.collect(host.backend.onDiscoveredServices);
    host.services = [
      service('s1', characteristics: [characteristic('a'), characteristic('b', id: '2a38')]),
      service('s2', characteristics: [characteristic('c')])
    ];
    await host.connect();
    expect(discovered.single.services.expand((s) => s.characteristics).map((c) => c.instanceId), [0, 1, 2]);
    await host.backend.readCharacteristic(readRequest(instance: 2));
    expect(host.calls.last.arguments['handle'], 'c');
    host.services = [
      service('primary', id: '1800', included: [service('secondary', type: 1)])
    ];
    await host.discovery();
    final secondary = discovered.last.services.last;
    expect(secondary.primaryServiceUuid, Guid('1800'));
    expect(secondary.characteristics.single.instanceId, 0);
    await host.backend.readCharacteristic(readRequest(primary: '1800'));
    expect(host.calls.last.arguments['handle'], 'c-secondary');
  });

  test('duplicate characteristics in one service keep Android instance IDs', () async {
    host.services = [
      service('s', characteristics: [characteristic('a', instanceId: 4), characteristic('b', instanceId: 9)])
    ];
    final discovered = host.collect(host.backend.onDiscoveredServices);
    await host.connect();
    expect(discovered.single.services.single.characteristics.map((c) => c.instanceId), [4, 9]);
    await host.backend.readCharacteristic(readRequest(instance: 9));
    expect(host.calls.last.arguments['handle'], 'b');
    await expectLater(host.backend.readCharacteristic(readRequest()),
        throwsA(platformError('readCharacteristic', "characteristic not found in service (chr: '2a37' svc: '180d')")));
  });

  test('write size limits, cached callback bytes and MTU updates match legacy', () async {
    await host.connect();
    await expectLater(
        host.backend.writeCharacteristic(writeRequest(List.filled(21, 1))),
        throwsA(platformError(
            'writeCharacteristic', 'data longer than allowed. dataLen: 21 > max: 20 (withResponse, noLongWrite)')));
    await host.backend.writeCharacteristic(writeRequest(List.filled(512, 1), long: true));
    await host.callback('onMtuChanged', status: 133, extra: {'mtu': 100});
    await host.connection(2); // Duplicate must not reset negotiated MTU.
    final written = host.collect(host.backend.onCharacteristicWritten);
    await host.backend.writeCharacteristic(writeRequest(List.filled(97, 42), noResponse: true));
    final chr = characteristic('c-s', parent: service('s', characteristics: []));
    await host.callback('onCharacteristicWrite', status: 3, extra: {'characteristic': chr});
    expect(written.single.value, List.filled(97, 42));
    expect(written.single.instanceId, 0);
    expect(written.single.success, false);
    expect(written.single.errorString, 'GATT_WRITE_NOT_PERMITTED');
    await host.callback('onCharacteristicWrite', extra: {'characteristic': chr});
    expect(written.last.value, isEmpty);
  });

  test('notification registration, CCCD preference and missing CCCD retain return values', () async {
    await host.connect();
    await host.backend.setNotifyValue(notifyRequest());
    expect(host.calls.last.arguments['value'], [1, 0]);
    await host.backend.setNotifyValue(notifyRequest(force: true));
    expect(host.calls.last.arguments['value'], [2, 0]);
    await host.backend.setNotifyValue(notifyRequest(enable: false));
    expect(host.calls.last.arguments['value'], [0, 0]);
    host.services = [
      service('s', characteristics: [characteristic('c', cccd: false)])
    ];
    await host.discovery();
    expect(await host.backend.setNotifyValue(notifyRequest()), false);
    expect(host.calls.last.method, 'gatt.setCharacteristicNotification');
  });

  test('descriptor callbacks return cached bytes and missing read descriptor keeps legacy error code', () async {
    await host.connect();
    final written = host.collect(host.backend.onDescriptorWritten);
    await host.backend.writeDescriptor(BmWriteDescriptorRequest(
        remoteId: remote,
        primaryServiceUuid: null,
        serviceUuid: Guid('180d'),
        characteristicUuid: Guid('2a37'),
        instanceId: 0,
        descriptorUuid: Guid('2902'),
        value: [1, 0]));
    await host.callback('onDescriptorWrite', extra: {
      'descriptor': {
        'handle': 'd-c-s',
        'uuid': uuid('2902'),
        'permissions': 17,
        'characteristic': characteristic('c-s', parent: service('s', characteristics: []))
      }
    });
    expect(written.single.value, [1, 0]);
    await expectLater(
        host.backend.readDescriptor(BmReadDescriptorRequest(
            remoteId: remote,
            primaryServiceUuid: null,
            serviceUuid: Guid('180d'),
            characteristicUuid: Guid('2a37'),
            instanceId: 0,
            descriptorUuid: Guid('2903'))),
        throwsA(platformError('writeDescriptor', 'descriptor not found on characteristic. (desc: 2903 chr: 2a37)')));
  });

  test('discovery failure, refresh and Android service-change do not discard valid handles', () async {
    await host.connect();
    expect(await host.backend.clearGattCache(BmClearGattCacheRequest(remoteId: remote)), true);
    await host.callback('onServiceChanged');
    await host.discovery(status: 133);
    await host.backend.readCharacteristic(readRequest());
    expect(host.calls.last.arguments['handle'], 'c-s');
  });

  test('only 1801/2a05 reads and notifications generate services reset', () async {
    host.services = [
      service('s', id: '1801', characteristics: [characteristic('c', id: '2a05')])
    ];
    final reset = host.collect(host.backend.onServicesReset);
    final received = host.collect(host.backend.onCharacteristicReceived);
    await host.connect();
    await host.callback('onServiceChanged');
    expect(reset, isEmpty);
    await host.callback('onCharacteristicChanged', extra: {
      'characteristic': characteristic('c', id: '2a05', parent: service('s', id: '1801', characteristics: [])),
      'value': Uint8List.fromList([1, 0, 255, 255])
    });
    expect(reset.single.remoteId, remote);
    expect(received.single.success, true);
  });

  test('bonding booleans and broadcasts match legacy including already bonding', () async {
    await host.connect();
    host.bondState = 12;
    expect(await host.backend.createBond(BmCreateBondRequest(remoteId: remote, pin: null)), false);
    host.bondState = 11;
    expect(await host.backend.createBond(BmCreateBondRequest(remoteId: remote, pin: null)), true);
    host.bondState = 10;
    expect(
        await host.backend.createBond(BmCreateBondRequest(remoteId: remote, pin: Uint8List.fromList([49, 50]))), true);
    expect(host.calls.last.arguments['pin'], [49, 50]);
    expect(await host.backend.removeBond(BmRemoveBondRequest(remoteId: remote)), false);
    host.bondState = 12;
    expect(await host.backend.removeBond(BmRemoveBondRequest(remoteId: remote)), true);
    final bonds = host.collect(host.backend.onBondStateChanged);
    await emit({
      'owner': 'device',
      'type': 'android.bluetooth.device.action.BOND_STATE_CHANGED',
      'device': {'address': address},
      'extras': {
        'android.bluetooth.device.extra.BOND_STATE': 12,
        'android.bluetooth.device.extra.PREVIOUS_BOND_STATE': 11
      }
    });
    expect(bonds.single.bondState, BmBondStateEnum.bonded);
    expect(bonds.single.prevState, BmBondStateEnum.bonding);
  });

  test('remaining GATT operations dispatch unchanged parameters and rejection messages', () async {
    await host.connect();
    expect(await host.backend.discoverServices(BmDiscoverServicesRequest(remoteId: remote)), true);
    expect(await host.backend.readRssi(BmReadRssiRequest(remoteId: remote)), true);
    expect(await host.backend.requestMtu(BmMtuChangeRequest(remoteId: remote, mtu: 247)), true);
    expect(host.calls.last.arguments['mtu'], 247);
    expect(
        await host.backend.requestConnectionPriority(
            BmConnectionPriorityRequest(remoteId: remote, connectionPriority: BmConnectionPriorityEnum.high)),
        true);
    expect(host.calls.last.arguments['priority'], 1);
    expect(
        await host.backend.setPreferredPhy(BmPreferredPhy(remoteId: remote, txPhy: 2, rxPhy: 2, phyOptions: 1)), true);
    expect(host.calls.last.arguments['txPhy'], 2);
    host.override = (call) async => call.method == 'gatt.readRemoteRssi' ? false : null;
    await expectLater(host.backend.readRssi(BmReadRssiRequest(remoteId: remote)),
        throwsA(platformError('readRssi', 'gatt.readRemoteRssi() returned false')));
  });

  test('native exceptions retain androidException, the native message and string stack details', () async {
    host.override = (call) async {
      if (call.method == 'adapter.bondedDevices') {
        throw PlatformException(
            code: 'permission_denied',
            message: 'java.lang.SecurityException: denied',
            details: {'exception': 'java.lang.SecurityException', 'stackTrace': 'native stack'});
      }
      return null;
    };
    await expectLater(
        host.backend.getBondedDevices(BmBondedDevicesRequest()),
        throwsA(platformError('androidException', 'java.lang.SecurityException: denied')
            .having((e) => e.details, 'details', 'native stack')));
  });

  test('scan filters remain separate OR entries and empty masks remain absent', () async {
    final settings = scanSettings();
    settings.withServices.add(Guid('180d'));
    settings.withRemoteIds.add(address);
    settings.withNames.add('Heart');
    settings.withMsd.add(BmMsdFilter(76, [1], []));
    settings.withServiceData.add(BmServiceDataFilter(Guid('180f'), [2], []));
    await host.backend.startScan(settings);
    final filters = host.calls.last.arguments['filters'] as List;
    expect(filters.length, 5);
    expect(filters[0]['serviceUuid'], uuid('180d'));
    expect(filters[1]['deviceAddress'], address);
    expect(filters[2]['deviceName'], 'Heart');
    expect(filters[3]['manufacturerDataMask'], null);
    expect(filters[4]['serviceDataMask'], null);
    expect(filters[3]['serviceDataUuid'], null);
  });

  test('concurrent permission operations are serialized without losing callers', () async {
    host.granted[connectPermission] = false;
    final grant = Completer<Object?>();
    var pending = 0;
    host.override = (call) async {
      if (call.method == 'permissions.request') {
        pending++;
        if (pending == 1) return grant.future;
        return {connectPermission: true};
      }
      return null;
    };
    final first = host.backend.getAdapterName(BmBluetoothAdapterNameRequest());
    final second = host.backend.getSystemDevices(BmSystemDevicesRequest(withServices: []));
    await tick();
    await tick();
    expect(pending, 1);
    grant.complete({connectPermission: true});
    expect((await first).adapterName, 'Adapter');
    expect((await second).devices.length, 1);
    expect(pending, 2);
  });

  test('already granted operations proceed while an unrelated permission dialog is open', () async {
    host.granted[scanPermission] = false;
    final opened = Completer<void>();
    final grant = Completer<Object?>();
    host.override = (call) async {
      if (call.method == 'permissions.request') {
        opened.complete();
        return grant.future;
      }
      return null;
    };
    final scan = host.backend.startScan(scanSettings());
    await opened.future;
    String? adapterName;
    final name = host.backend.getAdapterName(BmBluetoothAdapterNameRequest()).then((result) {
      adapterName = result.adapterName;
    });
    try {
      await tick();
      await tick();
      expect(adapterName, 'Adapter');
      expect(host.calls.where((call) => call.method == 'permissions.request').length, 1);
    } finally {
      grant.complete({scanPermission: true});
      await scan;
      await name;
    }
  });

  test('queued operations recheck permissions granted by the preceding dialog', () async {
    host.granted[connectPermission] = false;
    final opened = Completer<void>();
    final grant = Completer<Object?>();
    host.override = (call) async {
      if (call.method == 'permissions.request') {
        opened.complete();
        return grant.future;
      }
      return null;
    };
    final name = host.backend.getAdapterName(BmBluetoothAdapterNameRequest());
    await opened.future;
    final devices = host.backend.getSystemDevices(BmSystemDevicesRequest(withServices: []));
    await tick();
    host.granted[connectPermission] = true;
    grant.complete({connectPermission: true});
    expect((await name).adapterName, 'Adapter');
    expect((await devices).devices.single.remoteId, remote);
    expect(host.calls.where((call) => call.method == 'permissions.request').length, 1);
  });

  test('strict bond and PHY reads do not turn permission errors into false state', () async {
    host.override = (call) async {
      if (call.method == 'device.bondState' || call.method == 'adapter.isLe2MPhySupported') {
        throw PlatformException(
            code: 'permission_denied',
            message: 'java.lang.SecurityException: denied',
            details: {'stackTrace': 'stack'});
      }
      return null;
    };
    await expectLater(host.backend.getBondState(BmBondStateRequest(remoteId: remote)),
        throwsA(platformError('androidException', 'java.lang.SecurityException: denied')));
    await expectLater(host.backend.getPhySupport(PhySupportRequest()),
        throwsA(platformError('androidException', 'java.lang.SecurityException: denied')));
  });

  test('write rejections preserve API 33 status and pre-33 boolean errors', () async {
    await host.connect();
    host.override = (call) async => call.method == 'gatt.writeCharacteristic' ? 201 : null;
    await expectLater(
        host.backend.writeCharacteristic(writeRequest([1])),
        throwsA(platformError(
            'writeCharacteristic', 'gatt.writeCharacteristic() returned 201 : ERROR_GATT_WRITE_REQUEST_BUSY')));
  });

  test('pre-33 write failures retain the boolean rejection message', () async {
    host.api = 30;
    await host.connect();
    host.override = (call) async => call.method == 'gatt.writeCharacteristic' ? 2147483647 : null;
    await expectLater(host.backend.writeCharacteristic(writeRequest([1])),
        throwsA(platformError('writeCharacteristic', 'gatt.writeCharacteristic() returned false')));
  });

  test('characteristic and notification properties retain immediate validation errors', () async {
    host.services = [
      service('s', characteristics: [characteristic('c', properties: 0)])
    ];
    await host.connect();
    await expectLater(host.backend.readCharacteristic(readRequest()),
        throwsA(platformError('readCharacteristic', 'The READ property is not supported by this BLE characteristic')));
    await expectLater(
        host.backend.writeCharacteristic(writeRequest([1])),
        throwsA(
            platformError('writeCharacteristic', 'The WRITE property is not supported by this BLE characteristic')));
    await expectLater(
        host.backend.setNotifyValue(notifyRequest()),
        throwsA(platformError(
            'setNotifyValue', 'neither NOTIFY nor INDICATE properties are supported by this BLE characteristic')));
    expect(host.calls.last.method, 'gatt.setCharacteristicNotification');
    host.services = [
      service('s', characteristics: [characteristic('c', properties: 16)])
    ];
    await host.discovery();
    await expectLater(host.backend.setNotifyValue(notifyRequest(force: true)),
        throwsA(platformError('setNotifyValue', 'INDICATE not supported by this BLE characteristic')));
  });

  test('verbose logs retain method, event and scan output and color preference', () async {
    final logs = host.collect(FlutterBluePlusPlatform.logs);
    await host.backend.setLogLevel(BmSetLogLevelRequest(logLevel: LogLevel.verbose, logColor: false));
    await host.backend.startScan(scanSettings());
    await host.advertisement([0]);
    expect(logs.any((s) => s.contains('<startScan> args:')), true);
    expect(logs.any((s) => s.contains('[[ OnScanResponse ]] result:')), true);
    expect(logs.every((s) => !s.contains('\x1b')), true);
  });

  test('detach forwards one event, retires direct lookup and permits backend reinitialization', () async {
    final detached = host.collect(host.backend.onDetachedFromEngine);
    await host.connect();
    await emit({'owner': 'engine', 'type': 'onDetachedFromEngine'});
    expect(detached.length, 1);
    expect(FlutterBluePlusAndroid.getGatt(address), null);
    expect(ab.BluetoothDevice(address).gattClients, isEmpty);
    expect(await host.backend.isSupported(BmIsSupportedRequest()), true);
  });

  test('FBP callback values remain mutable without changing AndroidBluetooth snapshots', () async {
    await host.connect();
    final fbp = host.collect(host.backend.onCharacteristicReceived);
    final native = host.collect(ab.BluetoothDevice(address).gattClients.single.onCharacteristicRead);
    await host.callback('onCharacteristicRead', extra: {
      'characteristic': characteristic('c-s', parent: service('s', characteristics: [])),
      'value': Uint8List.fromList([1, 2]),
    });
    fbp.single.value[0] = 9;
    expect(fbp.single.value, [9, 2]);
    expect(native.single.value, [1, 2]);
  });

  test('writes own a payload snapshot independent of callers and native transport data', () async {
    await host.connect();
    final values = <int>[1, 2];
    final written = host.collect(host.backend.onCharacteristicWritten);
    final submitted = host.backend.writeCharacteristic(writeRequest(values));
    values[0] = 9;
    await submitted;
    final nativeWrite = host.calls.last;
    expect(nativeWrite.method, 'gatt.writeCharacteristic');
    expect(nativeWrite.arguments['value'], [1, 2]);
    await host.callback('onCharacteristicWrite', extra: {
      'characteristic': characteristic('c-s', parent: service('s', characteristics: [])),
    });
    expect(written.single.value, [1, 2]);
    written.single.value[1] = 7;
    expect(values, [9, 2]);
    expect(nativeWrite.arguments['value'], [1, 2]);
  });

  test('late callbacks after rediscovery preserve original duplicate-characteristic identity', () async {
    host.services = [
      service('old-s',
          characteristics: [characteristic('old-a', instanceId: 4), characteristic('old-b', instanceId: 9)])
    ];
    await host.connect();
    host.services = [service('new-s')];
    await host.discovery();
    final received = host.collect(host.backend.onCharacteristicReceived);
    await host.callback('onCharacteristicRead', extra: {
      'characteristic': characteristic('old-b', instanceId: 9, parent: service('old-s', characteristics: [])),
      'value': Uint8List.fromList([7]),
    });
    expect(received.single.instanceId, 9);
    expect(received.single.value, [7]);
    await host.backend.readCharacteristic(readRequest());
    expect(host.calls.last.arguments['handle'], 'c-new-s');
  });

  test('adapter-on waits for scan cleanup before notifying listeners', () async {
    final stopped = Completer<Object?>();
    final states = host.collect(host.backend.onAdapterStateChanged);
    await host.backend.startScan(scanSettings());
    host.override = (call) async => call.method == 'scan.stopSession' ? stopped.future : null;
    await host.adapter(12);
    expect(states, isEmpty);
    stopped.complete();
    await tick();
    await tick();
    expect(states.single.adapterState, BmAdapterStateEnum.on);
    host.override = null;
    await host.backend.startScan(scanSettings());
    expect(host.calls.last.method, 'scan.startSession');
  });

  test('adapter state bursts stay ordered while scan cleanup is pending', () async {
    final stopped = Completer<Object?>();
    final states = host.collect(host.backend.onAdapterStateChanged);
    await host.backend.startScan(scanSettings());
    host.override = (call) async => call.method == 'scan.stopSession' ? stopped.future : null;
    try {
      await host.adapter(12);
      await host.adapter(13);
      await host.adapter(10);
      expect(states, isEmpty);
    } finally {
      stopped.complete();
    }
    await tick();
    await tick();
    expect(states.map((event) => event.adapterState),
        [BmAdapterStateEnum.on, BmAdapterStateEnum.turningOff, BmAdapterStateEnum.off]);
    expect(host.calls.where((call) => call.method == 'scan.stopSession'), hasLength(1));
  });

  test('adapter cleanup errors are forwarded and later state events still run', () async {
    final errors = <Object>[];
    final states = host.collect(host.backend.onAdapterStateChanged);
    await runZonedGuarded<Future<void>>(() async {
      await host.backend.startScan(scanSettings());
      var rejectStop = true;
      host.override = (call) async {
        if (call.method == 'scan.stopSession' && rejectStop) {
          rejectStop = false;
          throw PlatformException(code: 'io_error', message: 'stop failed');
        }
        return null;
      };
      await host.adapter(12);
      await host.adapter(13);
      await host.adapter(12);
    }, (error, stack) => errors.add(error));
    expect(errors, hasLength(1));
    expect(errors.single, platformError('io_error', 'stop failed'));
    expect(states.map((event) => event.adapterState), [BmAdapterStateEnum.turningOff, BmAdapterStateEnum.on]);
    expect(host.calls.where((call) => call.method == 'scan.stopSession'), hasLength(2));
  });

  test('late adapter cleanup from a detached engine cannot clear a replacement scan', () async {
    final stopped = Completer<Object?>();
    final states = host.collect(host.backend.onAdapterStateChanged);
    await host.backend.startScan(scanSettings());
    host.override = (call) async => call.method == 'scan.stopSession' ? stopped.future : null;
    await host.adapter(12);
    await host.adapter(13); // This queued event belongs to the old engine too.
    await emit({'owner': 'engine', 'type': 'onDetachedFromEngine'});
    host.state = 12;
    host.override = null;
    await host.backend.startScan(scanSettings());
    stopped.complete();
    await tick();
    await tick();
    expect(states, isEmpty);
    await host.backend.stopScan(BmStopScanRequest());
    expect(host.calls.last.method, 'scan.stopSession');
    expect(host.calls.last.arguments['id'], host.scan);
  });

  test('adapter cleanup failures from a detached engine are ignored', () async {
    final errors = <Object>[];
    final states = host.collect(host.backend.onAdapterStateChanged);
    await runZonedGuarded<Future<void>>(() async {
      final stopped = Completer<Object?>();
      await host.backend.startScan(scanSettings());
      host.override = (call) async => call.method == 'scan.stopSession' ? stopped.future : null;
      await host.adapter(12);
      await emit({'owner': 'engine', 'type': 'onDetachedFromEngine'});
      host.override = null;
      await host.backend.startScan(scanSettings());
      stopped.completeError(PlatformException(code: 'io_error', message: 'old engine stop failed'));
      await tick();
      await tick();
      await host.adapter(11);
      await host.backend.stopScan(BmStopScanRequest());
    }, (error, stack) => errors.add(error));
    expect(errors, isEmpty);
    expect(states.map((event) => event.adapterState), [BmAdapterStateEnum.turningOn]);
  });

  test('legacy callback decoding failures do not become uncaught Dart errors', () async {
    await host.connect();
    final received = host.collect(host.backend.onCharacteristicReceived);
    final chr = characteristic('c-s', parent: service('s', characteristics: []));
    await host.callback('onCharacteristicRead', status: 2, extra: {'characteristic': chr, 'value': null});
    expect(received, isEmpty); // The original Bm decoder rejects null typed bytes.
    await host.callback('onCharacteristicRead', status: 2, extra: {'characteristic': chr, 'value': Uint8List(0)});
    expect(received.single.success, false);
    expect(received.single.errorString, 'GATT_READ_NOT_PERMITTED');
  });

  test('typed scanning retains filter snapshots across permission awaits', () async {
    final grant = Completer<Object?>();
    host.granted[scanPermission] = false;
    host.override = (call) async => call.method == 'permissions.request' ? grant.future : null;
    final settings = scanSettings();
    final bytes = <int>[1];
    settings.withServices.add(Guid('180d'));
    settings.withMsd.add(BmMsdFilter(76, bytes, []));
    settings.withServiceData.add(BmServiceDataFilter(Guid('180f'), [2], []));
    final started = host.backend.startScan(settings);
    await tick();
    await tick();
    settings.withServices.clear();
    settings.withMsd.clear();
    settings.withServiceData.clear();
    bytes[0] = 9;
    grant.complete({scanPermission: true});
    await started;
    final filters = host.calls.last.arguments['filters'] as List;
    expect(filters.length, 3);
    expect(filters[0]['serviceUuid'], uuid('180d'));
    expect(filters[1]['manufacturerData'], [1]);
    expect(filters[2]['serviceData'], [2]);
  });
}
