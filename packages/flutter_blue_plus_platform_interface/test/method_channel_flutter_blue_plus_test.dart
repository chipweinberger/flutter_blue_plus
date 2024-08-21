import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_blue_plus_platform_interface/src/method_channel_flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'MethodChannelFlutterBluePlus',
    () {
      final flutterBluePlus = MethodChannelFlutterBluePlus();
      final log = <MethodCall>[];

      Future<Object?>? Function(MethodCall methodCall)? handler;

      group(
        'clearGattCache',
        () {
          test(
            'invokes the method',
            () async {
              final device = DeviceIdentifier('');

              await flutterBluePlus.clearGattCache(device);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'clearGattCache',
                    arguments: device.str,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'connect',
        () {
          final result = true;

          setUp(
            () {
              handler = (call) {
                return Future.value(result);
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              final request = BmConnectRequest(
                remoteId: DeviceIdentifier(''),
                autoConnect: false,
              );

              expect(
                await flutterBluePlus.connect(request),
                equals(result),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              final request = BmConnectRequest(
                remoteId: DeviceIdentifier(''),
                autoConnect: false,
              );

              await flutterBluePlus.connect(request);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'connect',
                    arguments: request.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'connectedCount',
        () {
          final result = 0;

          setUp(
            () {
              handler = (call) {
                return Future.value(result);
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              expect(
                await flutterBluePlus.connectedCount(),
                equals(result),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              await flutterBluePlus.connectedCount();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'connectedCount',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'createBond',
        () {
          final result = true;

          setUp(
            () {
              handler = (call) {
                return Future.value(result);
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              final device = DeviceIdentifier('');

              expect(
                await flutterBluePlus.createBond(device),
                equals(result),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              final device = DeviceIdentifier('');

              await flutterBluePlus.createBond(device);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'createBond',
                    arguments: device.str,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'disconnect',
        () {
          final result = true;

          setUp(
            () {
              handler = (call) {
                return Future.value(result);
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              final device = DeviceIdentifier('');

              expect(
                await flutterBluePlus.disconnect(device),
                equals(result),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              final device = DeviceIdentifier('');

              await flutterBluePlus.disconnect(device);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'disconnect',
                    arguments: device.str,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'discoverServices',
        () {
          test(
            'invokes the method',
            () async {
              final device = DeviceIdentifier('');

              await flutterBluePlus.discoverServices(device);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'discoverServices',
                    arguments: device.str,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'flutterRestart',
        () {
          final result = 0;

          setUp(
            () {
              handler = (call) {
                return Future.value(result);
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              expect(
                await flutterBluePlus.flutterRestart(),
                equals(result),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              await flutterBluePlus.flutterRestart();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'flutterRestart',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'getAdapterName',
        () {
          final result = '';

          setUp(
            () {
              handler = (call) {
                return Future.value(result);
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              expect(
                await flutterBluePlus.getAdapterName(),
                equals(result),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              await flutterBluePlus.getAdapterName();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'getAdapterName',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'getAdapterState',
        () {
          final result = BmBluetoothAdapterState(
            adapterState: BmAdapterStateEnum.unknown,
          );

          setUp(
            () {
              handler = (call) {
                return Future.value(result.toMap());
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              expect(
                (await flutterBluePlus.getAdapterState()).toMap(),
                equals(result.toMap()),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              await flutterBluePlus.getAdapterState();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'getAdapterState',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'getBondState',
        () {
          final result = BmBondStateResponse(
            remoteId: DeviceIdentifier(''),
            bondState: BmBondStateEnum.none,
          );

          setUp(
            () {
              handler = (call) {
                return Future.value(result.toMap());
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              final device = DeviceIdentifier('');

              expect(
                (await flutterBluePlus.getBondState(device)).toMap(),
                equals(result.toMap()),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              final device = DeviceIdentifier('');

              await flutterBluePlus.getBondState(device);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'getBondState',
                    arguments: device.str,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'getBondedDevices',
        () {
          final result = BmDevicesList(
            devices: [],
          );

          setUp(
            () {
              handler = (call) {
                return Future.value(result.toMap());
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              expect(
                (await flutterBluePlus.getBondedDevices()).toMap(),
                equals(result.toMap()),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              await flutterBluePlus.getBondedDevices();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'getBondedDevices',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'getPhySupport',
        () {
          final result = PhySupport(
            le2M: false,
            leCoded: false,
          );

          setUp(
            () {
              handler = (call) {
                return Future.value(result.toMap());
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              expect(
                (await flutterBluePlus.getPhySupport()).toMap(),
                equals(result.toMap()),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              await flutterBluePlus.getPhySupport();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'getPhySupport',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'getSystemDevices',
        () {
          final result = BmDevicesList(
            devices: [],
          );

          setUp(
            () {
              handler = (call) {
                return Future.value(result.toMap());
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              expect(
                (await flutterBluePlus.getSystemDevices()).toMap(),
                equals(result.toMap()),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              await flutterBluePlus.getSystemDevices();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'getSystemDevices',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'isSupported',
        () {
          final result = true;

          setUp(
            () {
              handler = (call) {
                return Future.value(result);
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              expect(
                await flutterBluePlus.isSupported(),
                equals(result),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              await flutterBluePlus.isSupported();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'isSupported',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'readCharacteristic',
        () {
          test(
            'invokes the method',
            () async {
              final request = BmReadCharacteristicRequest(
                remoteId: DeviceIdentifier(''),
                serviceUuid: Guid('0102'),
                characteristicUuid: Guid('0102'),
              );

              await flutterBluePlus.readCharacteristic(request);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'readCharacteristic',
                    arguments: request.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'readDescriptor',
        () {
          test(
            'invokes the method',
            () async {
              final request = BmReadDescriptorRequest(
                remoteId: DeviceIdentifier(''),
                serviceUuid: Guid('0102'),
                characteristicUuid: Guid('0102'),
                descriptorUuid: Guid('0102'),
              );

              await flutterBluePlus.readDescriptor(request);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'readDescriptor',
                    arguments: request.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'readRssi',
        () {
          test(
            'invokes the method',
            () async {
              final device = DeviceIdentifier('');

              await flutterBluePlus.readRssi(device);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'readRssi',
                    arguments: device.str,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'removeBond',
        () {
          final result = true;

          setUp(
            () {
              handler = (call) {
                return Future.value(result);
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              final device = DeviceIdentifier('');

              expect(
                await flutterBluePlus.removeBond(device),
                equals(result),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              final device = DeviceIdentifier('');

              await flutterBluePlus.removeBond(device);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'removeBond',
                    arguments: device.str,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'requestConnectionPriority',
        () {
          test(
            'invokes the method',
            () async {
              final request = BmConnectionPriorityRequest(
                remoteId: DeviceIdentifier(''),
                connectionPriority: BmConnectionPriorityEnum.balanced,
              );

              await flutterBluePlus.requestConnectionPriority(request);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'requestConnectionPriority',
                    arguments: request.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'requestMtu',
        () {
          test(
            'invokes the method',
            () async {
              final request = BmMtuChangeRequest(
                remoteId: DeviceIdentifier(''),
                mtu: 0,
              );

              await flutterBluePlus.requestMtu(request);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'requestMtu',
                    arguments: request.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'setLogLevel',
        () {
          test(
            'invokes the method',
            () async {
              final level = LogLevel.none;

              await flutterBluePlus.setLogLevel(level);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'setLogLevel',
                    arguments: level.index,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'setNotifyValue',
        () {
          final result = true;

          setUp(
            () {
              handler = (call) {
                return Future.value(result);
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              final request = BmSetNotifyValueRequest(
                remoteId: DeviceIdentifier(''),
                serviceUuid: Guid('0102'),
                characteristicUuid: Guid('0102'),
                forceIndications: false,
                enable: false,
              );

              expect(
                await flutterBluePlus.setNotifyValue(request),
                equals(result),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              final request = BmSetNotifyValueRequest(
                remoteId: DeviceIdentifier(''),
                serviceUuid: Guid('0102'),
                characteristicUuid: Guid('0102'),
                forceIndications: false,
                enable: false,
              );

              await flutterBluePlus.setNotifyValue(request);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'setNotifyValue',
                    arguments: request.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'setOptions',
        () {
          test(
            'invokes the method',
            () async {
              final options = Options(
                showPowerAlert: false,
              );

              await flutterBluePlus.setOptions(options);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'setOptions',
                    arguments: options.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'setPreferredPhy',
        () {
          test(
            'invokes the method',
            () async {
              final preferredPhy = BmPreferredPhy(
                remoteId: DeviceIdentifier(''),
                txPhy: 0,
                rxPhy: 0,
                phyOptions: 0,
              );

              await flutterBluePlus.setPreferredPhy(preferredPhy);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'setPreferredPhy',
                    arguments: preferredPhy.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'startScan',
        () {
          test(
            'invokes the method',
            () async {
              final settings = BmScanSettings(
                withServices: [],
                withRemoteIds: [],
                withNames: [],
                withKeywords: [],
                withMsd: [],
                withServiceData: [],
                continuousUpdates: false,
                continuousDivisor: 1,
                androidLegacy: false,
                androidScanMode: 0,
                androidUsesFineLocation: false,
              );

              await flutterBluePlus.startScan(settings);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'startScan',
                    arguments: settings.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'stopScan',
        () {
          test(
            'invokes the method',
            () async {
              await flutterBluePlus.stopScan();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'stopScan',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'turnOff',
        () {
          test(
            'invokes the method',
            () async {
              await flutterBluePlus.turnOff();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'turnOff',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'turnOn',
        () {
          final result = true;

          setUp(
            () {
              handler = (call) {
                return Future.value(result);
              };
            },
          );

          tearDown(
            () {
              handler = null;
            },
          );

          test(
            'deserializes the result',
            () async {
              expect(
                await flutterBluePlus.turnOn(),
                equals(result),
              );
            },
          );

          test(
            'invokes the method',
            () async {
              await flutterBluePlus.turnOn();

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'turnOn',
                    arguments: null,
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'writeCharacteristic',
        () {
          test(
            'invokes the method',
            () async {
              final request = BmWriteCharacteristicRequest(
                remoteId: DeviceIdentifier(''),
                serviceUuid: Guid('0102'),
                characteristicUuid: Guid('0102'),
                writeType: BmWriteType.withResponse,
                allowLongWrite: false,
                value: [],
              );

              await flutterBluePlus.writeCharacteristic(request);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'writeCharacteristic',
                    arguments: request.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      group(
        'writeDescriptor',
        () {
          test(
            'invokes the method',
            () async {
              final request = BmWriteDescriptorRequest(
                remoteId: DeviceIdentifier(''),
                serviceUuid: Guid('0102'),
                characteristicUuid: Guid('0102'),
                descriptorUuid: Guid('0102'),
                value: [],
              );

              await flutterBluePlus.writeDescriptor(request);

              expect(
                log,
                orderedEquals([
                  isMethodCall(
                    'writeDescriptor',
                    arguments: request.toMap(),
                  ),
                ]),
              );
            },
          );
        },
      );

      setUp(
        () {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            flutterBluePlus.channel,
            (call) {
              log.add(call);

              return handler?.call(call);
            },
          );
        },
      );

      tearDown(
        () {
          log.clear();
        },
      );
    },
  );
}
