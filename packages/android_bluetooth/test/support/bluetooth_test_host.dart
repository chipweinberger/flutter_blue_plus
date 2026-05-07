import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel, StandardMethodCodec;
import 'package:flutter_test/flutter_test.dart';

const methods = MethodChannel('dev.android_bluetooth/methods');
const eventsChannel = MethodChannel('dev.android_bluetooth/events');
const codec = StandardMethodCodec();
const address = 'AA:BB:CC:DD:EE:FF';

Map<String, Object?> descriptor(String handle) => {
      'uuid': '00002902-0000-1000-8000-00805f9b34fb',
      'handle': handle,
      'permissions': 17,
    };
Map<String, Object?> characteristic(String handle, {String? descriptorHandle}) => {
      'uuid': '00002a37-0000-1000-8000-00805f9b34fb',
      'handle': handle,
      'instanceId': 7,
      'properties': 18,
      'permissions': 1,
      'descriptors': [if (descriptorHandle != null) descriptor(descriptorHandle)],
    };
Map<String, Object?> service(String handle, List<Map<String, Object?>> characteristics) => {
      'uuid': '0000180d-0000-1000-8000-00805f9b34fb',
      'handle': handle,
      'instanceId': 4,
      'serviceType': 0,
      'characteristics': characteristics,
      'includedServices': [],
    };

Future<void> tick() => Future<void>.delayed(Duration.zero);
Future<void> emit(Map<String, Object?> event) async {
  // ignore: deprecated_member_use
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(eventsChannel.name, codec.encodeSuccessEnvelope(event), (_) {});
  await tick();
}

Map<String, Object?> connected(String owner, int state) => {
      'owner': owner,
      'type': 'onConnectionStateChange',
      'status': 0,
      'newState': state,
      'device': {'address': address}
    };
Map<String, Object?> callbackCharacteristic() => {
      'handle': 'char',
      'uuid': '00002a37-0000-1000-8000-00805f9b34fb',
      'instanceId': 1,
      'properties': 18,
      'permissions': 1,
      'descriptors': []
    };

RangingPreference rangingPreference() => RangingPreference(
      deviceRole: RangingPreference.deviceRoleInitiator,
      devices: [
        RawRangingDevice(
            uuid: '12345678-1234-5678-1234-567812345678',
            bleRssiRangingParams: const BleRssiRangingParams(peerBluetoothAddress: address))
      ],
    );

int _hostSequence = 0;

/// A fresh method handler per test, with unique registrations across combined suites.
final class BluetoothTestHost {
  BluetoothTestHost() {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  final String ownerPrefix = 'test-host-${_hostSequence++}';
  final calls = <MethodCall>[];
  var sequence = 0;
  Future<Object?> Function(MethodCall)? override;
  TestDefaultBinaryMessenger get messenger => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    if (call.method == 'adapter.capabilities') {
      return {'apiLevel': 36, 'isSupported': true, 'hasAdapter': true, 'isEnabled': true};
    }
    if (override != null) return override!(call);
    switch (call.method) {
      case 'gatt.open':
        return 'gatt-$ownerPrefix-${sequence++}';
      case 'server.open':
        return 'server-$ownerPrefix-${sequence++}';
      case 'gatt.discoverServices':
        return true;
      case 'gatt.getServices':
        return [
          service('s1', [characteristic('c1', descriptorHandle: 'd1')]),
          service('s2', [characteristic('c2')])
        ];
      case 'gatt.writeCharacteristic':
        return BluetoothStatusCodes.success;
      case 'gatt.readCharacteristic':
        return false;
      case 'server.addService':
        return true;
      default:
        return null;
    }
  }

  Future<void> setUp() async {
    calls.clear();
    override = null;
    messenger.setMockMethodCallHandler(eventsChannel, (_) async => null);
    messenger.setMockMethodCallHandler(methods, handle);
    await AndroidBluetooth.capabilities;
    calls.clear();
  }
}
