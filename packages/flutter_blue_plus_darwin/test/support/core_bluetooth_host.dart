import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_darwin/flutter_blue_plus_darwin.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

const deviceId = '12345678-1234-1234-1234-123456789ABC';
const otherId = '87654321-4321-4321-4321-CBA987654321';

Map<String, Object?> peripheral({String id = deviceId, int state = 2}) => {
      'identifier': id.toLowerCase(),
      'state': state,
      'name': 'Device',
      'canSendWriteWithoutResponse': true,
    };
Map<String, Object?> descriptor({String handle = 'd', String uuid = '2902', Object? value}) => {
      'handle': handle,
      'uuid': uuid,
      'value': value,
    };
Map<String, Object?> characteristic(
        {String handle = 'c',
        String uuid = '2a19',
        int properties = 62,
        List<Map<String, Object?>> descriptors = const [],
        bool notifying = false}) =>
    {
      'handle': handle,
      'uuid': uuid,
      'properties': properties,
      'isNotifying': notifying,
      'descriptors': descriptors,
    };
Map<String, Object?> service(
        {String handle = 's',
        String uuid = '180f',
        bool primary = true,
        List<Map<String, Object?>> characteristics = const [],
        List<Map<String, Object?>> included = const []}) =>
    {
      'handle': handle,
      'uuid': uuid,
      'isPrimary': primary,
      'characteristics': characteristics,
      'includedServices': included,
    };

BmScanSettings scanSettings(
        {List<Guid> services = const [],
        List<String> names = const [],
        List<String> ids = const [],
        List<String> keywords = const [],
        List<BmMsdFilter> msd = const [],
        List<BmServiceDataFilter> serviceData = const [],
        bool continuous = false,
        int divisor = 1}) =>
    BmScanSettings(
      withServices: services,
      withNames: names,
      withRemoteIds: ids,
      withKeywords: keywords,
      withMsd: msd,
      withServiceData: serviceData,
      continuousUpdates: continuous,
      continuousDivisor: divisor,
      androidLegacy: false,
      androidScanMode: 0,
      androidUsesFineLocation: false,
      webOptionalServices: [],
    );

class CoreBluetoothHost {
  final backend = FlutterBluePlusDarwin();
  final calls = <MethodCall>[];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  static const methods = MethodChannel('dev.core_bluetooth/methods');
  static const events = EventChannel('dev.core_bluetooth/events');
  final responses = <String, Object?>{};
  FutureOr<Object?> Function(MethodCall)? handle;
  int maxPayload = 20;

  Future<void> setUp({bool initialize = true}) async {
    FlutterBluePlusPlatform.instance = backend;
    messenger.setMockMethodCallHandler(MethodChannel(events.name), (_) async => null);
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (handle != null) {
        final result = await handle!(call);
        if (result != null) return result;
      }
      if (responses.containsKey(call.method)) return responses[call.method];
      return switch (call.method) {
        'centralManager.create' => {'managerId': 1, 'state': 5, 'isScanning': false, 'wasReattached': true},
        'centralManager.scanForPeripherals' => true,
        'centralManager.disconnectAllPeripherals' => <Object?>[],
        'centralManager.retrievePeripherals' => [peripheral(state: 0)],
        'centralManager.retrieveConnectedPeripherals' => [peripheral()],
        'centralManager.adapterName' => 'Adapter',
        'peripheral.maximumWriteValueLength' => maxPayload,
        'peripheral.canSendWriteWithoutResponse' => true,
        _ => null,
      };
    });
    if (!initialize) return;
    await backend.isSupported(BmIsSupportedRequest());
    await emit('didUpdateState', {'state': 5, 'isScanning': false});
    calls.clear();
  }

  Future<void> pump() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> emit(String kind, Map<String, Object?> payload, {int managerId = 1}) async {
    // ignore: deprecated_member_use
    await messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope({'kind': kind, 'managerId': managerId, 'payload': payload}),
        (_) {});
    await pump();
  }

  Future<void> connect({String id = deviceId}) async {
    responses['centralManager.retrievePeripherals'] = [peripheral(id: id, state: 0)];
    await backend.connect(BmConnectRequest(remoteId: DeviceIdentifier(id), autoConnect: false));
    await emit('didConnectPeripheral', {'peripheral': peripheral(id: id)});
  }

  Future<void> gatt({String id = deviceId, List<Map<String, Object?>>? services}) async {
    await emit('peripheralDidDiscoverServices', {
      'peripheral': peripheral(id: id),
      'services': services ??
          [
            service(characteristics: [
              characteristic(descriptors: [descriptor()])
            ])
          ]
    });
  }

  Future<void> tearDown() async {
    await backend.dispose();
    messenger.setMockMethodCallHandler(methods, null);
  }
}
