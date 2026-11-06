import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

const remote = DeviceIdentifier('AA:BB:CC:DD:EE:FF');

Future<void> tick() => Future<void>.delayed(Duration.zero);

final class LoggingBackend extends FlutterBluePlusPlatform {
  final characteristics = StreamController<BmCharacteristicData>.broadcast();
  final scans = StreamController<BmScanResponse>.broadcast();
  final services = StreamController<BmDiscoverServicesResult>.broadcast();
  final rssi = StreamController<BmReadRssiResult>.broadcast();
  final calls = <String>[];
  PlatformException? failure;
  BmSetLogLevelRequest? logSettings;
  BmSetOptionsRequest? options;

  @override
  Stream<BmCharacteristicData> get onCharacteristicReceived => characteristics.stream;
  @override
  Stream<BmScanResponse> get onScanResponse => scans.stream;
  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices => services.stream;
  @override
  Stream<BmReadRssiResult> get onReadRssi => rssi.stream;

  @override
  Future<bool> setLogLevel(BmSetLogLevelRequest request) async {
    logSettings = request;
    return true;
  }

  @override
  Future<bool> setOptions(BmSetOptionsRequest request) async {
    options = request;
    return true;
  }

  @override
  Future<bool> isSupported(BmIsSupportedRequest request) async {
    calls.add('isSupported');
    if (failure != null) throw failure!;
    return true;
  }

  @override
  Future<BmBluetoothAdapterName> getAdapterName(BmBluetoothAdapterNameRequest request) async =>
      BmBluetoothAdapterName(adapterName: 'Test adapter');
}

final class UnformattableScanResponse extends BmScanResponse {
  UnformattableScanResponse() : super(advertisements: [], success: true, errorCode: 0, errorString: '');

  @override
  List<BmScanAdvertisement> get advertisements => throw StateError('invalid advertisements');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = LoggingBackend();
  final logs = <String>[];
  late StreamSubscription<String> subscription;

  setUpAll(() async {
    FlutterBluePlusPlatform.instance = backend;
    subscription = FlutterBluePlus.logs.listen(logs.add);
    await FlutterBluePlus.setLogLevel(LogLevel.none);
  });

  setUp(() async {
    backend.failure = null;
    backend.calls.clear();
    await FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);
    await tick();
    logs.clear();
  });

  tearDownAll(() async {
    await subscription.cancel();
    await backend.characteristics.close();
    await backend.scans.close();
    await backend.services.close();
    await backend.rssi.close();
  });

  test('main package logs typed requests and results once and forwards settings', () async {
    expect(await FlutterBluePlus.isSupported, isTrue);
    expect(await FlutterBluePlus.adapterName, 'Test adapter');
    await FlutterBluePlus.setOptions(showPowerAlert: false, restoreState: true);
    await tick();
    expect(logs.where((line) => line.contains('<isSupported> args:')), hasLength(1));
    expect(logs.where((line) => line.contains('(isSupported) result: true')), hasLength(1));
    expect(logs, contains('[FBP] (getAdapterName) result: Test adapter'));
    expect(logs, contains('[FBP] <setOptions> args: {show_power_alert: false, restore_state: true}'));
    expect(logs.any((line) => line.contains('\x1b')), isFalse);
    expect(backend.options!.restoreState, isTrue);
    expect(backend.logSettings!.logLevel, LogLevel.verbose);
    expect(backend.logSettings!.logColor, isFalse);
  });

  test('logging preserves failures and the invocation mutex remains usable', () async {
    final failure = PlatformException(code: 'test_failure', message: 'query failed');
    backend.failure = failure;
    await expectLater(FlutterBluePlus.isSupported, throwsA(same(failure)));
    backend.failure = null;
    expect(await FlutterBluePlus.isSupported, isTrue);
    await tick();
    expect(backend.calls, ['isSupported', 'isSupported']);
    expect(logs.where((line) => line.contains('<isSupported> args:')), hasLength(2));
    expect(logs.where((line) => line.contains('(isSupported) result:')), hasLength(1));
  });

  test('one incoming event produces one log with multiple public listeners', () async {
    final first = FlutterBluePlus.events.onCharacteristicReceived.first;
    final second = FlutterBluePlus.events.onCharacteristicReceived.first;
    backend.characteristics.add(BmCharacteristicData(
        remoteId: remote,
        primaryServiceUuid: null,
        serviceUuid: Guid('180d'),
        characteristicUuid: Guid('2a37'),
        instanceId: 0,
        value: [1, 2, 255],
        success: true,
        errorCode: 0,
        errorString: 'GATT_SUCCESS'));
    expect((await first).value, [1, 2, 255]);
    expect((await second).value, [1, 2, 255]);
    await tick();
    final events = logs.where((line) => line.contains('[[ OnCharacteristicReceived ]]')).toList();
    expect(events, hasLength(1));
    expect(events.single, contains('characteristic_uuid: 2a37'));
    expect(events.single, contains('value: [1, 2, 255]'));
  });

  test('service graphs are readable and scan data stays in the shared logs', () async {
    backend.services.add(BmDiscoverServicesResult(
        remoteId: remote,
        services: [
          BmBluetoothService(remoteId: remote, primaryServiceUuid: null, serviceUuid: Guid('180d'), characteristics: [
            BmBluetoothCharacteristic(
                remoteId: remote,
                primaryServiceUuid: null,
                serviceUuid: Guid('180d'),
                characteristicUuid: Guid('2a37'),
                instanceId: 7,
                properties: BmCharacteristicProperties(
                    broadcast: false,
                    read: true,
                    writeWithoutResponse: false,
                    write: false,
                    notify: true,
                    indicate: false,
                    authenticatedSignedWrites: false,
                    extendedProperties: false,
                    notifyEncryptionRequired: false,
                    indicateEncryptionRequired: false),
                descriptors: [
                  BmBluetoothDescriptor(
                      remoteId: remote,
                      primaryServiceUuid: null,
                      serviceUuid: Guid('180d'),
                      characteristicUuid: Guid('2a37'),
                      instanceId: 7,
                      descriptorUuid: Guid('2902')),
                ])
          ])
        ],
        success: true,
        errorCode: 0,
        errorString: 'GATT_SUCCESS'));
    backend.scans.add(BmScanResponse(advertisements: [
      BmScanAdvertisement(
          remoteId: remote,
          platformName: 'Sensor',
          advName: 'Heart',
          connectable: true,
          txPowerLevel: null,
          appearance: null,
          manufacturerData: {
            76: [1, 2]
          },
          serviceData: {
            Guid('180d'): [3]
          },
          serviceUuids: [Guid('180d')],
          rssi: -40)
    ], success: true, errorCode: 0, errorString: ''));
    await tick();
    final discovered = logs.singleWhere((line) => line.contains('[[ OnDiscoveredServices ]]'));
    expect(discovered, contains('\n  "remote_id"'));
    expect(discovered, contains('"descriptor_uuid": "2902"'));
    expect(discovered, contains('"instance_id": 7'));
    expect(discovered, contains('"notify": 1'));
    final scan = logs.singleWhere((line) => line.contains('[[ OnScanResponse ]]'));
    expect(scan, contains('adv_name: Heart'));
    expect(scan, contains('manufacturer_data: {76: [1, 2]}'));
    expect(scan, contains('service_data: {180d: [3]}'));
  });

  test('disabled logging skips formatting and formatter failures do not stop events', () async {
    final received = <BmScanResponse>[];
    final listener = backend.scans.stream.listen(received.add);
    try {
      await FlutterBluePlus.setLogLevel(LogLevel.none);
      await tick();
      logs.clear();
      backend.scans.add(UnformattableScanResponse());
      await tick();
      expect(logs, isEmpty);
      expect(received, hasLength(1));
      await FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);
      await tick();
      logs.clear();
      backend.scans.add(UnformattableScanResponse());
      await tick();
      expect(received, hasLength(2));
      expect(logs.single, contains('unable to format'));
    } finally {
      await listener.cancel();
    }
  });

  test('color and level changes take effect without adding event subscriptions', () async {
    await FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
    await tick();
    logs.clear();
    backend.rssi.add(BmReadRssiResult(remoteId: remote, rssi: -42, success: true, errorCode: 0, errorString: ''));
    await tick();
    expect(logs, hasLength(1));
    expect(logs.single, contains('\x1b['));
    await FlutterBluePlus.setLogLevel(LogLevel.debug);
    await tick();
    logs.clear();
    backend.rssi.add(BmReadRssiResult(remoteId: remote, rssi: -41, success: true, errorCode: 0, errorString: ''));
    await tick();
    expect(logs, isEmpty);
  });
}
