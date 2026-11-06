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

  test('scan configures native dedup and preserves repeated MSD and appearance', () async {
    final responses = host.collect(host.backend.onScanResponse);
    await host.backend.startScan(scanSettings());
    final settings = host.calls.last.arguments['settings'];
    expect(settings['scanMode'], 2);
    expect(settings['legacy'], false);
    expect(settings['phy'], 255);
    expect(host.calls.last.arguments['deliveryOptions'], {
      'advertisementDivisor': 1,
      'suppressDuplicates': true,
      'includeBatchResults': false,
    });
    final a = [4, 255, 0x4c, 0, 1, 4, 255, 0x4c, 0, 2, 3, 0x19, 0x40, 3, 0];
    await host.advertisement(a);
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

  test('native delivery samples before Dart keywords without resampling callbacks in Dart', () async {
    final responses = host.collect(host.backend.onScanResponse);
    await host.backend.startScan(scanSettings(continuous: true, divisor: 2, keywords: ['Heart']));
    final filters = host.calls.last.arguments['filters'] as List;
    expect(filters.map((f) => f['advertisingDataType']), [8, 9]);
    expect(host.calls.last.arguments['deliveryOptions'], {
      'advertisementDivisor': 2,
      'suppressDuplicates': false,
      'includeBatchResults': false,
    });
    // Native tests exercise all advertisements. These channel frames already passed sampling.
    await host.advertisement([0], name: 'heart');
    await host.advertisement([0], name: 'Heart');
    await host.advertisement([0], name: 'Heart');
    expect(responses.length, 2);
  });

  test('repeated scan submissions replace native delivery history without restarting the radio', () async {
    final responses = host.collect(host.backend.onScanResponse);
    await host.backend.startScan(scanSettings());
    final id = host.scan;
    await host.backend.startScan(scanSettings(continuous: true, divisor: 3, keywords: ['Changed']));
    expect(host.scan, id);
    expect(host.calls.where((call) => call.method == 'scan.startSession'), hasLength(1));
    expect(host.calls.last.method, 'scan.setDeliveryOptions');
    expect(host.calls.last.arguments, {
      'id': id,
      'deliveryOptions': {
        'advertisementDivisor': 3,
        'suppressDuplicates': false,
        'includeBatchResults': false,
      },
    });
    await tick();
    expect(responses.single.errorCode, 1);
    await host.advertisement([0], name: 'Heart');
    expect(responses, hasLength(1));
    await host.advertisement([0], name: 'Changed');
    expect(responses, hasLength(2));
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

  for (final scenario in ['pending', 'pending-auto', 'disconnected-auto']) {
    test('a failed disconnect preserves the client for retry ($scenario)', () async {
      final states = host.collect(host.backend.onConnectionStateChanged);
      await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: scenario != 'pending'));
      final client = FlutterBluePlusAndroid.getGatt(address)!;
      if (scenario == 'disconnected-auto') {
        await host.connection(2);
        await host.connection(0);
      }
      final before = states.length;
      host.override = (call) async {
        if (call.method == 'gatt.disconnect') {
          throw PlatformException(code: 'permission_denied', message: 'CONNECT denied');
        }
        return null;
      };
      await expectLater(host.backend.disconnect(BmDisconnectRequest(remoteId: remote)),
          throwsA(platformError('androidException', 'CONNECT denied')));
      expect(FlutterBluePlusAndroid.getGatt(address), same(client));
      expect(ab.BluetoothDevice(address).gattClients, [client]);
      expect(host.calls.where((call) => call.method == 'gatt.close'), isEmpty);
      expect(states, hasLength(before));
      host.override = null;
      expect(await host.backend.disconnect(BmDisconnectRequest(remoteId: remote)), scenario != 'disconnected-auto');
      expect(host.calls.where((call) => call.method == 'gatt.disconnect'), hasLength(2));
      expect(host.calls.where((call) => call.method == 'gatt.close').single.arguments['id'], client.id);
      expect(FlutterBluePlusAndroid.getGatt(address), isNull);
      expect(ab.BluetoothDevice(address).gattClients, isEmpty);
      await tick();
      expect(states, hasLength(before + (scenario == 'disconnected-auto' ? 0 : 1)));
    });
  }

  for (final failed in [false, true]) {
    test('pending cancellation ${failed ? 'replays' : 'discards'} callbacks after native submission', () async {
      final states = host.collect(host.backend.onConnectionStateChanged);
      await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false));
      final client = FlutterBluePlusAndroid.getGatt(address)!;
      host.override = (call) async {
        if (call.method == 'gatt.disconnect') {
          await host.connection(2, owner: client.id);
          expect(states, isEmpty);
          if (failed) throw PlatformException(code: 'permission_denied', message: 'CONNECT denied');
        }
        return null;
      };
      final disconnecting = host.backend.disconnect(BmDisconnectRequest(remoteId: remote));
      if (failed) {
        await expectLater(disconnecting, throwsA(platformError('androidException', 'CONNECT denied')));
      } else {
        expect(await disconnecting, isTrue);
      }
      await tick();
      await tick();
      expect(states, hasLength(1));
      expect(
          states.single.connectionState, failed ? BmConnectionStateEnum.connected : BmConnectionStateEnum.disconnected);
      expect(FlutterBluePlusAndroid.getGatt(address), failed ? same(client) : isNull);
      if (failed) {
        host.override = null;
        expect(await host.backend.disconnect(BmDisconnectRequest(remoteId: remote)), isTrue);
        await host.connection(0, owner: client.id);
      } else {
        expect(states.single.disconnectReasonCode, bmUserCanceledErrorCode);
      }
      expect(ab.BluetoothDevice(address).gattClients, isEmpty);
    });
  }

  for (final detach in [false, true]) {
    test('a disconnect failure cannot restore a client after ${detach ? 'engine detach' : 'adapter shutdown'}',
        () async {
      await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false));
      final client = FlutterBluePlusAndroid.getGatt(address)!;
      final started = Completer<void>();
      final reply = Completer<Object?>();
      host.override = (call) async {
        if (call.method == 'gatt.disconnect') {
          started.complete();
          return await reply.future;
        }
        return null;
      };
      final disconnecting = expectLater(host.backend.disconnect(BmDisconnectRequest(remoteId: remote)),
          throwsA(platformError('androidException', 'CONNECT denied')));
      await started.future;
      if (detach) {
        await emit({'owner': 'engine', 'type': 'onDetachedFromEngine'});
      } else {
        await host.adapter(ab.BluetoothAdapter.stateTurningOff);
      }
      reply.completeError(PlatformException(code: 'permission_denied', message: 'CONNECT denied'));
      await disconnecting;
      expect(FlutterBluePlusAndroid.getGatt(address), isNull);
      expect(ab.BluetoothDevice(address).gattClients, isEmpty);
      if (!detach) {
        expect(host.calls.where((call) => call.method == 'gatt.close').single.arguments['id'], client.id);
      } else {
        // Reattach before teardown to avoid buffering a second unobserved detach.
        await host.backend.isSupported(BmIsSupportedRequest());
      }
    });
  }

  test('overlapping pending cancellation does not submit another disconnect or replacement', () async {
    await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false));
    final started = Completer<void>();
    final reply = Completer<Object?>();
    host.override = (call) async {
      if (call.method == 'gatt.disconnect') {
        started.complete();
        return await reply.future;
      }
      return null;
    };
    final first = host.backend.disconnect(BmDisconnectRequest(remoteId: remote));
    await started.future;
    expect(await host.backend.disconnect(BmDisconnectRequest(remoteId: remote)), isFalse);
    expect(await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false)), isTrue);
    expect(host.calls.where((call) => call.method == 'gatt.disconnect'), hasLength(1));
    expect(host.calls.where((call) => call.method == 'gatt.open'), hasLength(1));
    reply.complete(null);
    expect(await first, isTrue);
    expect(FlutterBluePlusAndroid.getGatt(address), isNull);
    expect(ab.BluetoothDevice(address).gattClients, isEmpty);
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

  for (final denied in [false, true]) {
    test('failed replacement retains the original auto-connect client (permission: $denied)', () async {
      final states = host.collect(host.backend.onConnectionStateChanged);
      await host.connect(autoConnect: true);
      final original = FlutterBluePlusAndroid.getGatt(address)!;
      await host.connection(0, status: 8);
      host.override = (call) async {
        if (call.method == 'gatt.open') {
          throw PlatformException(
              code: denied ? 'permission_denied' : 'invalid_state',
              message: denied ? 'CONNECT revoked' : 'Android failed to register GATT client');
        }
        return null;
      };
      await expectLater(
          host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false)),
          throwsA(platformError(denied ? 'androidException' : 'connect',
              denied ? 'CONNECT revoked' : 'device.connectGatt returned null')));
      host.override = null;
      expect(FlutterBluePlusAndroid.getGatt(address), same(original));
      expect(ab.BluetoothDevice(address).gattClients, [original]);
      expect(host.calls.where((call) => call.method == 'gatt.close'), isEmpty);
      await host.connection(2, owner: original.id);
      expect(states, hasLength(3));
      expect(await host.backend.disconnect(BmDisconnectRequest(remoteId: remote)), isTrue);
      expect(host.calls.last.method, 'gatt.disconnect');
      expect(host.calls.last.arguments['id'], original.id);
      await host.connection(0, owner: original.id);
      expect(ab.BluetoothDevice(address).gattClients, isEmpty);
    });
  }

  test('the retained client can reconnect before a replacement submission fails', () async {
    final states = host.collect(host.backend.onConnectionStateChanged);
    await host.connect(autoConnect: true);
    final original = FlutterBluePlusAndroid.getGatt(address)!;
    await host.connection(0);
    host.override = (call) async {
      if (call.method == 'gatt.open') {
        await host.connection(2, owner: original.id);
        throw PlatformException(code: 'invalid_state', message: 'Android failed to register GATT client');
      }
      return null;
    };
    await expectLater(host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false)),
        throwsA(platformError('connect', 'device.connectGatt returned null')));
    host.override = null;
    expect(states, hasLength(3));
    expect(FlutterBluePlusAndroid.getGatt(address), same(original));
    // A connected original must not be replaced again after rollback.
    expect(await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false)), isFalse);
    expect(host.calls.where((call) => call.method == 'gatt.open'), hasLength(2));
  });

  test('a successful replacement retires the original client and ignores its later callbacks', () async {
    final states = host.collect(host.backend.onConnectionStateChanged);
    await host.connect(autoConnect: true);
    final original = FlutterBluePlusAndroid.getGatt(address)!;
    await host.connection(0);
    expect(await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false)), isTrue);
    final replacement = FlutterBluePlusAndroid.getGatt(address)!;
    expect(replacement, isNot(same(original)));
    expect(ab.BluetoothDevice(address).gattClients, [replacement]);
    expect(host.calls.where((call) => call.method == 'gatt.close').single.arguments['id'], original.id);
    await host.connection(2, owner: original.id);
    expect(states, hasLength(2));
    await host.connection(2, owner: replacement.id);
    expect(states, hasLength(3));
  });

  for (final shutdown in [false, true]) {
    for (final failed in [false, true]) {
      test(
          'replacement ${failed ? 'failure' : 'success'} after ${shutdown ? 'shutdown' : 'cancellation'} retires both clients',
          () async {
        final states = host.collect(host.backend.onConnectionStateChanged);
        await host.connect(autoConnect: true);
        final original = FlutterBluePlusAndroid.getGatt(address)!;
        await host.connection(0);
        final started = Completer<void>();
        final reply = Completer<Object?>();
        host.override = (call) async {
          if (call.method == 'gatt.open') {
            started.complete();
            return await reply.future;
          }
          return null;
        };
        final connecting = host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false));
        final outcome = expectLater(connecting,
            failed ? throwsA(platformError('connect', 'device.connectGatt returned null')) : completion(isTrue));
        await started.future;
        final Future<bool>? disconnecting;
        if (shutdown) {
          await host.adapter(ab.BluetoothAdapter.stateTurningOff);
          disconnecting = null;
        } else {
          disconnecting = host.backend.disconnect(BmDisconnectRequest(remoteId: remote));
          await tick();
          await tick();
        }
        expect(FlutterBluePlusAndroid.getGatt(address), isNull);
        if (failed) {
          reply.completeError(
              PlatformException(code: 'invalid_state', message: 'Android failed to register GATT client'));
        } else {
          reply.complete('gatt-replacement-${host.prefix}');
        }
        await outcome;
        if (disconnecting != null) expect(await disconnecting, isTrue);
        await tick();
        await tick();
        expect(FlutterBluePlusAndroid.getGatt(address), isNull);
        expect(ab.BluetoothDevice(address).gattClients, isEmpty);
        final closed = host.calls.where((call) => call.method == 'gatt.close').map((call) => call.arguments['id']);
        expect(closed, contains(original.id));
        if (!failed) expect(closed, contains('gatt-replacement-${host.prefix}'));
        final eventCount = states.length;
        await host.connection(2, owner: original.id);
        expect(states, hasLength(eventCount));
      });
    }
  }

  test('a retained-client close failure cannot skip replacement cleanup during cancellation', () async {
    await host.connect(autoConnect: true);
    final original = FlutterBluePlusAndroid.getGatt(address)!;
    await host.connection(0);
    final started = Completer<void>();
    final reply = Completer<Object?>();
    final replacementId = 'gatt-replacement-close-${host.prefix}';
    host.override = (call) async {
      if (call.method == 'gatt.open') {
        started.complete();
        return await reply.future;
      }
      if (call.method == 'gatt.close' && call.arguments['id'] == original.id) {
        throw PlatformException(code: 'permission_denied', message: 'Original close failed');
      }
      return null;
    };
    final connecting = host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false));
    await started.future;
    final disconnected = expectLater(host.backend.disconnect(BmDisconnectRequest(remoteId: remote)),
        throwsA(platformError('androidException', 'Original close failed')));
    await tick();
    await tick();
    reply.complete(replacementId);
    expect(await connecting, isTrue);
    await disconnected;
    expect(host.calls.where((call) => call.method == 'gatt.close').map((call) => call.arguments['id']),
        [original.id, replacementId]);
    expect(FlutterBluePlusAndroid.getGatt(address), isNull);
    expect(ab.BluetoothDevice(address).gattClients, [original]);
    // The failed native close remains explicitly retryable.
    host.override = null;
    await original.close();
    expect(ab.BluetoothDevice(address).gattClients, isEmpty);
  });

  for (final autoConnect in [false, true]) {
    for (final logErrors in [false, true]) {
      test('automatic close failures stay handled (auto-connect: $autoConnect, logging: $logErrors)', () async {
        final errors = <Object>[];
        final logs = host.collect(FlutterBluePlusPlatform.logs);
        await host.backend
            .setLogLevel(BmSetLogLevelRequest(logLevel: logErrors ? LogLevel.error : LogLevel.none, logColor: false));
        late ab.BluetoothGatt client;
        late List<BmConnectionStateResponse> states;
        await runZonedGuarded<Future<void>>(() async {
          await host.connect(autoConnect: autoConnect);
          client = ab.BluetoothDevice(address).gattClients.single;
          states = host.collect(host.backend.onConnectionStateChanged);
          host.override = (call) async {
            if (call.method == 'gatt.close') {
              throw PlatformException(code: 'permission_denied', message: 'CONNECT revoked');
            }
            return null;
          };
          if (autoConnect) await host.backend.disconnect(BmDisconnectRequest(remoteId: remote));
          await host.connection(ab.BluetoothProfile.stateDisconnected, status: 19);
          await tick();
        }, (error, stack) => errors.add(error));
        expect(errors, isEmpty);
        expect(states, hasLength(1));
        expect(states.single.connectionState, BmConnectionStateEnum.disconnected);
        expect(states.single.disconnectReasonCode, 19);
        expect(states.single.disconnectReasonString, 'REMOTE_USER_TERMINATED_CONNECTION');
        expect(FlutterBluePlusAndroid.getGatt(address), isNull);
        expect(host.calls.where((call) => call.method == 'gatt.close'), hasLength(1));
        expect(logs, hasLength(logErrors ? 1 : 0));
        if (logErrors) {
          expect(logs.single, contains(address));
          expect(logs.single, contains('CONNECT revoked'));
        }
        // Automatic cleanup handling must not swallow errors for explicit native callers.
        await expectLater(client.close(), throwsA(platformError('permission_denied', 'CONNECT revoked')));
        host.override = null;
        await client.close();
        expect(ab.BluetoothDevice(address).gattClients, isEmpty);
      });
    }
  }

  test('an awaited pending-disconnect close failure retains the existing FBP exception', () async {
    await host.backend.connect(BmConnectRequest(remoteId: remote, autoConnect: false));
    host.override = (call) async {
      if (call.method == 'gatt.close') throw PlatformException(code: 'permission_denied', message: 'CONNECT revoked');
      return null;
    };
    await expectLater(host.backend.disconnect(BmDisconnectRequest(remoteId: remote)),
        throwsA(platformError('androidException', 'CONNECT revoked')));
  });

  test('automatic close errors from a detached engine do not produce stale diagnostics', () async {
    final errors = <Object>[];
    final logs = host.collect(FlutterBluePlusPlatform.logs);
    await host.backend.setLogLevel(BmSetLogLevelRequest(logLevel: LogLevel.error, logColor: false));
    await runZonedGuarded<Future<void>>(() async {
      final close = Completer<Object?>();
      await host.connect();
      host.override = (call) async => call.method == 'gatt.close' ? await close.future : null;
      await host.connection(ab.BluetoothProfile.stateDisconnected);
      await emit({'owner': 'engine', 'type': 'onDetachedFromEngine'});
      close.completeError(PlatformException(code: 'engine_detached', message: 'Engine ended'));
      await tick();
      await tick();
    }, (error, stack) => errors.add(error));
    expect(errors, isEmpty);
    expect(logs, isEmpty);
    // Reattach before the host's final detach so it does not buffer another engine event.
    await host.backend.isSupported(BmIsSupportedRequest());
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

  for (final scenario in ['first failure', 'both fail', 'second pending']) {
    test('shutdown attempts every client before reporting cleanup errors ($scenario)', () async {
      const other = DeviceIdentifier('11:22:33:44:55:66');
      final errors = <Object>[];
      final attempted = <String>[];
      final states = host.collect(host.backend.onAdapterStateChanged);
      final disconnected = host.collect(host.backend.onConnectionStateChanged);
      late String first, second;
      late Completer<void> secondClosed;
      await runZonedGuarded<Future<void>>(() async {
        secondClosed = Completer<void>();
        await host.connect();
        first = host.gatt!;
        await host.backend.connect(BmConnectRequest(remoteId: other, autoConnect: false));
        second = host.gatt!;
        await emit({
          'owner': second,
          'type': 'onConnectionStateChange',
          'status': 0,
          'newState': ab.BluetoothProfile.stateConnected,
          'device': {'address': other.str},
        });
        disconnected.clear();
        host.override = (call) async {
          if (call.method == 'gatt.close') {
            final id = call.arguments['id'] as String;
            attempted.add(id);
            if (id == first) throw PlatformException(code: 'permission_denied', message: 'first close failed');
            if (scenario == 'both fail') throw PlatformException(code: 'io_error', message: 'second close failed');
            if (scenario == 'second pending') await secondClosed.future;
          }
          return null;
        };
        await host.adapter(ab.BluetoothAdapter.stateTurningOff);
        await host.adapter(ab.BluetoothAdapter.stateTurningOn);
      }, (error, stack) => errors.add(error));
      final errorsBeforeCompletion = List.of(errors);
      final statesBeforeCompletion = states.map((event) => event.adapterState).toList();
      secondClosed.complete();
      await tick();
      await tick();
      expect(attempted, [first, second]);
      expect(errors, hasLength(1));
      expect(errors.single, platformError('permission_denied', 'first close failed'));
      if (scenario == 'second pending') {
        expect(errorsBeforeCompletion, isEmpty);
        expect(statesBeforeCompletion, [BmAdapterStateEnum.turningOff]);
      }
      expect(states.map((event) => event.adapterState), [BmAdapterStateEnum.turningOff, BmAdapterStateEnum.turningOn]);
      expect(disconnected.map((event) => event.remoteId), [remote, other]);
      expect(disconnected.every((event) => event.connectionState == BmConnectionStateEnum.disconnected), isTrue);
      expect(disconnected.every((event) => event.disconnectReasonCode == 0), isTrue);
      expect(FlutterBluePlusAndroid.getGatt(address), isNull);
      expect(FlutterBluePlusAndroid.getGatt(other.str), isNull);
      expect(ab.BluetoothDevice(other.str).gattClients, scenario == 'both fail' ? hasLength(1) : isEmpty);
    });
  }

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
    await host.callback('onCharacteristicWrite', status: 3, extra: {
      'characteristic': chr,
      'value': Uint8List.fromList([9, 8]),
    });
    expect(written.single.value, List.filled(97, 42));
    expect(written.single.instanceId, 0);
    expect(written.single.success, false);
    expect(written.single.errorString, 'GATT_WRITE_NOT_PERMITTED');
    await host.callback('onCharacteristicWrite', extra: {
      'characteristic': chr,
      'value': Uint8List.fromList([7]),
    });
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

  test('backend leaves standard request and event logging to the main package', () async {
    final logs = host.collect(FlutterBluePlusPlatform.logs);
    await host.backend.setLogLevel(BmSetLogLevelRequest(logLevel: LogLevel.verbose, logColor: false));
    await host.backend.startScan(scanSettings());
    await host.advertisement([0]);
    expect(logs, isEmpty);
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
    final native = host.collect(ab.BluetoothDevice(address).gattClients.single.onCharacteristicWrite);
    final submitted = host.backend.writeCharacteristic(writeRequest(values));
    values[0] = 9;
    await submitted;
    final nativeWrite = host.calls.last;
    expect(nativeWrite.method, 'gatt.writeCharacteristic');
    expect(nativeWrite.arguments['value'], [1, 2]);
    await host.callback('onCharacteristicWrite', extra: {
      'characteristic': characteristic('c-s', parent: service('s', characteristics: [])),
      'value': Uint8List.fromList([9, 8]),
    });
    expect(written.single.value, [1, 2]);
    expect(native.single.value, [9, 8]);
    written.single.value[1] = 7;
    expect(values, [9, 2]);
    expect(nativeWrite.arguments['value'], [1, 2]);
    expect(native.single.value, [9, 8]);
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

  for (final blockedMethod in ['adapter.capabilities', 'permissions.request']) {
    for (final clearLists in [false, true]) {
      test('typed scanning retains filter snapshots across $blockedMethod (clear lists: $clearLists)', () async {
        final waiting = Completer<void>();
        final resume = Completer<void>();
        host.granted[scanPermission] = blockedMethod != 'permissions.request';
        host.override = (call) async {
          if (call.method == blockedMethod) {
            waiting.complete();
            await resume.future;
            if (blockedMethod == 'permissions.request') return {scanPermission: true};
          }
          return null;
        };
        final settings = scanSettings();
        final bytes = <int>[1];
        settings.withServices.add(Guid('180d'));
        settings.withRemoteIds.addAll([address, '11:22:33:44:55:66']);
        settings.withNames.addAll(['Heart', 'Sensor']);
        settings.withMsd.add(BmMsdFilter(76, bytes, []));
        settings.withServiceData.add(BmServiceDataFilter(Guid('180f'), [2], []));
        final started = host.backend.startScan(settings);
        await waiting.future;
        if (clearLists) {
          settings.withRemoteIds.clear();
          settings.withNames.clear();
        } else {
          settings.withRemoteIds[0] = '00:00:00:00:00:01';
          settings.withNames[0] = 'Changed';
        }
        settings.withServices.clear();
        settings.withMsd.clear();
        settings.withServiceData.clear();
        bytes[0] = 9;
        resume.complete();
        await started;
        final filters =
            host.calls.singleWhere((call) => call.method == 'scan.startSession').arguments['filters'] as List;
        expect(filters.length, 7);
        expect(filters[0]['serviceUuid'], uuid('180d'));
        expect(filters[1]['deviceAddress'], address);
        expect(filters[2]['deviceAddress'], '11:22:33:44:55:66');
        expect(filters[3]['deviceName'], 'Heart');
        expect(filters[4]['deviceName'], 'Sensor');
        expect(filters[5]['manufacturerData'], [1]);
        expect(filters[6]['serviceData'], [2]);
      });
    }
  }
}
