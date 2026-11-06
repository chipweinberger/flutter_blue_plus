import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_android/flutter_blue_plus_android.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

const address = 'AA:BB:CC:DD:EE:FF';
const remote = DeviceIdentifier(address);
const methods = MethodChannel('dev.android_bluetooth/methods');
const events = MethodChannel('dev.android_bluetooth/events');
const codec = StandardMethodCodec();
const connectPermission = 'android.permission.BLUETOOTH_CONNECT';
const scanPermission = 'android.permission.BLUETOOTH_SCAN';
const fineLocation = 'android.permission.ACCESS_FINE_LOCATION';

String uuid(String short) => Guid(short).str128;
Future<void> tick() => Future<void>.delayed(Duration.zero);
Future<void> emit(Map<String, Object?> event) async {
  // ignore: deprecated_member_use
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(events.name, codec.encodeSuccessEnvelope(event), (_) {});
  await tick();
  await tick();
}

Map<String, Object?> service(String handle,
        {String id = '180d',
        int type = 0,
        List<Map<String, Object?>>? characteristics,
        List<Map<String, Object?>> included = const []}) =>
    {
      'handle': handle,
      'uuid': uuid(id),
      'instanceId': 11,
      'serviceType': type,
      'characteristics': characteristics ?? [characteristic('c-$handle')],
      'includedServices': included,
    };
Map<String, Object?> characteristic(String handle,
        {String id = '2a37',
        int instanceId = 77,
        int properties = 62,
        bool cccd = true,
        Map<String, Object?>? parent}) =>
    {
      'handle': handle,
      'uuid': uuid(id),
      'instanceId': instanceId,
      'properties': properties,
      'permissions': 17,
      if (parent != null) 'service': parent,
      'descriptors': [
        if (cccd) {'handle': 'd-$handle', 'uuid': uuid('2902'), 'permissions': 17}
      ],
    };

TypeMatcher<PlatformException> platformError(String code, String message) =>
    isA<PlatformException>().having((e) => e.code, 'code', code).having((e) => e.message, 'message', message);

int _hostSequence = 0;

final class AndroidHost {
  final backend = FlutterBluePlusAndroid();
  final calls = <MethodCall>[];
  final subscriptions = <StreamSubscription<dynamic>>[];
  final prefix = _hostSequence++;
  int api = 36, state = 12, bondState = 10, sequence = 0;
  bool adapterPresent = true, locationEnabled = true;
  List<Map<String, Object?>> services = [service('s')];
  final granted = <String, bool>{};
  final denied = <String>{};
  Future<Object?> Function(MethodCall)? override;
  String? gatt, scan;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    if (override != null) {
      final result = await override!(call);
      if (result != null) return result;
    }
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    switch (call.method) {
      case 'adapter.capabilities':
        return {
          'apiLevel': api,
          'hasAdapter': adapterPresent,
          'isSupported': adapterPresent,
          'isEnabled': state == 12,
          'isLe2MPhySupported': true,
          'isLeCodedPhySupported': false
        };
      case 'permissions.check':
        return {for (final p in args['permissions'] as List) p: granted[p] ?? true};
      case 'permissions.request':
        return {for (final p in args['permissions'] as List) p: !denied.contains(p)};
      case 'adapter.state':
        return state;
      case 'adapter.isEnabled':
        return state == 12;
      case 'adapter.isLe2MPhySupported':
        return true;
      case 'adapter.isLeCodedPhySupported':
        return false;
      case 'adapter.name':
        return 'Adapter';
      case 'adapter.bondedDevices':
      case 'manager.connectedDevices':
        return [
          {'address': address, 'name': 'Device'}
        ];
      case 'environment.isLocationEnabled':
        return locationEnabled;
      case 'adapter.requestEnable':
      case 'adapter.disable':
        return true;
      case 'device.get':
        return {'address': address, 'name': 'Device', 'bondState': bondState};
      case 'device.bondState':
        return bondState;
      case 'device.createBond':
      case 'device.removeBond':
        return true;
      case 'gatt.open':
        return gatt = 'gatt-$prefix-${sequence++}';
      case 'scan.startSession':
        return scan = 'scan-$prefix-${sequence++}';
      case 'gatt.getServices':
        return services;
      case 'gatt.writeCharacteristic':
      case 'gatt.writeDescriptor':
        return 0;
      case 'gatt.refresh':
        return false;
      case 'gatt.discoverServices':
      case 'gatt.readCharacteristic':
      case 'gatt.readDescriptor':
      case 'gatt.readRemoteRssi':
      case 'gatt.requestMtu':
      case 'gatt.requestConnectionPriority':
      case 'gatt.setCharacteristicNotification':
        return true;
      default:
        return null;
    }
  }

  Future<void> setUp() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methods, handle);
    messenger.setMockMethodCallHandler(events, (_) async => null);
    FlutterBluePlusPlatform.instance = backend;
  }

  Future<void> tearDown() async {
    await emit({'owner': 'engine', 'type': 'onDetachedFromEngine'});
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }

  List<T> collect<T>(Stream<T> stream) {
    final values = <T>[];
    subscriptions.add(stream.listen(values.add));
    return values;
  }

  Future<void> connection(int state, {int status = 0, String? owner}) => emit({
        'owner': owner ?? gatt,
        'type': 'onConnectionStateChange',
        'status': status,
        'newState': state,
        'device': {'address': address, 'name': 'Device'}
      });
  Future<void> connect({bool autoConnect = false, bool discover = true}) async {
    await backend.connect(BmConnectRequest(remoteId: remote, autoConnect: autoConnect));
    await connection(2);
    if (discover) await discovery();
  }

  Future<void> discovery({int status = 0}) =>
      emit({'owner': gatt, 'type': 'onServicesDiscovered', 'status': status, 'services': services});
  Future<void> callback(String type, {int status = 0, Map<String, Object?> extra = const {}}) => emit({
        'owner': gatt,
        'type': type,
        'status': status,
        'device': {'address': address, 'name': 'Device'},
        ...extra
      });
  Future<void> adapter(int state) async {
    this.state = state;
    await emit({
      'owner': 'adapter',
      'type': 'android.bluetooth.adapter.action.STATE_CHANGED',
      'state': state,
      'previousState': 12
    });
  }

  Future<void> advertisement(List<int> bytes, {String? name = 'Heart', int rssi = -40, String type = 'onScanResult'}) =>
      emit({
        'owner': scan,
        'type': type,
        'callbackType': 1,
        'results': [
          {
            'device': {'address': address, 'name': 'Device'},
            'rssi': rssi,
            'timestampNanos': 1,
            'isConnectable': true,
            'scanRecord': {
              'bytes': Uint8List.fromList(bytes),
              'deviceName': name,
              'advertiseFlags': 6,
              'txPowerLevel': -2147483648,
              'serviceUuids': [uuid('180d')],
              'serviceSolicitationUuids': [],
              'manufacturerSpecificData': {},
              'serviceData': {}
            },
          }
        ],
      });
}

BmScanSettings scanSettings(
        {bool continuous = false,
        int divisor = 1,
        List<String> keywords = const [],
        bool fine = false,
        bool location = true}) =>
    BmScanSettings(
        withServices: [],
        withRemoteIds: [],
        withNames: [],
        withKeywords: keywords,
        withMsd: [],
        withServiceData: [],
        continuousUpdates: continuous,
        continuousDivisor: divisor,
        androidLegacy: false,
        androidScanMode: 2,
        androidUsesFineLocation: fine,
        androidCheckLocationServices: location,
        webOptionalServices: []);
BmReadCharacteristicRequest readRequest(
        {int instance = 0, String service = '180d', String characteristic = '2a37', String? primary}) =>
    BmReadCharacteristicRequest(
        remoteId: remote,
        primaryServiceUuid: primary == null ? null : Guid(primary),
        serviceUuid: Guid(service),
        characteristicUuid: Guid(characteristic),
        instanceId: instance);
BmWriteCharacteristicRequest writeRequest(List<int> value, {bool noResponse = false, bool long = false}) =>
    BmWriteCharacteristicRequest(
        remoteId: remote,
        primaryServiceUuid: null,
        serviceUuid: Guid('180d'),
        characteristicUuid: Guid('2a37'),
        instanceId: 0,
        writeType: noResponse ? BmWriteType.withoutResponse : BmWriteType.withResponse,
        allowLongWrite: long,
        value: value);
BmSetNotifyValueRequest notifyRequest({bool enable = true, bool force = false}) => BmSetNotifyValueRequest(
    remoteId: remote,
    primaryServiceUuid: null,
    serviceUuid: Guid('180d'),
    characteristicUuid: Guid('2a37'),
    instanceId: 0,
    enable: enable,
    forceIndications: force);
