import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_blue_plus_darwin/flutter_blue_plus_darwin.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothHost host;
  setUp(() async {
    host = CoreBluetoothHost();
    host.responses['centralManager.create'] = {'managerId': 1, 'state': 5, 'isScanning': false, 'wasReattached': false};
    await host.setUp(initialize: false);
  });
  tearDown(() => host.tearDown());

  test('fresh startup preserves connections restored before manager creation completes', () async {
    final connections = <BmConnectionStateResponse>[];
    final subscription = host.backend.onConnectionStateChanged.listen(connections.add);
    host.handle = (call) async {
      if (call.method == 'centralManager.create') {
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
      }
      return null;
    };
    expect(await host.backend.isSupported(BmIsSupportedRequest()), isTrue);
    await host.pump();
    expect(connections, hasLength(1));
    expect(connections.single.connectionState, BmConnectionStateEnum.connected);
    expect(host.calls.where((call) => call.method == 'centralManager.disconnectAllPeripherals'), isEmpty);
    expect(FlutterBluePlusDarwin.getPeripheral(deviceId)!.services!.single.characteristics!.single.isNotifying, isTrue);
    await subscription.cancel();
  });

  test('FBP adopts shared connections made through CoreBluetooth in the current Dart session', () async {
    await host.emit('didConnectPeripheral', {'peripheral': peripheral()});
    final connections = <BmConnectionStateResponse>[];
    final subscription = host.backend.onConnectionStateChanged.listen(connections.add);
    await host.backend.isSupported(BmIsSupportedRequest());
    await host.pump();
    expect(connections, hasLength(1));
    expect(await host.backend.connect(BmConnectRequest(remoteId: DeviceIdentifier(deviceId), autoConnect: false)),
        isFalse);
    expect(FlutterBluePlusDarwin.getPeripheral(deviceId), same(cb.CBCentralManager.shared.connectedPeripherals.single));
    expect(host.calls.where((call) => call.method == 'centralManager.disconnectAllPeripherals'), isEmpty);
    await subscription.cancel();
  });
}
