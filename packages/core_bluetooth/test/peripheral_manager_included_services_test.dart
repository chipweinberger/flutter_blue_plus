import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

Map<String, Object?> _characteristic(String handle) => {
      'handle': handle,
      'uuid': '2a19',
      'properties': 18,
      'permissions': 1,
      'descriptors': [],
    };

Map<String, Object?> _central() => {
      'identifier': '12345678-1234-1234-1234-123456789abc',
      'maximumUpdateValueLength': 20,
    };

Map<String, Object?> _request(String handle) => {
      'requestHandle': handle,
      'characteristicHandle': 'included-c',
      'offset': 0,
      'central': _central(),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  late cb.CBPeripheralManager manager;
  late cb.CBMutableCharacteristic included;
  setUp(() async {
    host = CoreBluetoothTestHost()..setUp();
    manager = host.track(cb.CBPeripheralManager.createIsolated());
    await manager.ready;
    await host.emit('peripheralManagerWillRestoreState', {
      'services': [
        {
          'handle': 'root',
          'uuid': '180f',
          'isPrimary': true,
          'characteristics': [_characteristic('root-c')],
          'includedServices': [
            {
              'handle': 'middle',
              'uuid': '180f',
              'isPrimary': false,
              'characteristics': [],
              'includedServices': [
                {
                  'handle': 'leaf',
                  'uuid': '180f',
                  'isPrimary': false,
                  'characteristics': [_characteristic('included-c')],
                  'includedServices': [],
                }
              ],
            }
          ],
        }
      ],
    });
    included = manager.services.single.includedServices!.single.includedServices!.single.characteristics!.single
        as cb.CBMutableCharacteristic;
  });
  tearDown(() => host.tearDown());

  test('nested ATT reads retain the tracked characteristic and can be answered', () async {
    final response = manager.onDidReceiveReadRequest.first;
    await host.emit('peripheralManagerDidReceiveRead', _request('read'));
    final request = (await response).request;
    expect(request.characteristic, same(included));
    await manager.respond(to: request, withResult: cb.CBATTErrorCode.success);
    expect(host.calls.last.method, 'peripheralManager.respondToRequest');
    expect((host.calls.last.arguments as Map)['requestHandle'], 'read');
  });

  test('nested ATT writes retain every batch member and characteristic identity', () async {
    final response = manager.onDidReceiveWriteRequests.first;
    await host.emit('peripheralManagerDidReceiveWrite', {
      'requests': [_request('write-1'), _request('write-2')]
    });
    final requests = (await response).requests;
    expect(requests, hasLength(2));
    expect(requests.every((request) => identical(request.characteristic, included)), isTrue);
    await manager.respond(to: requests.first, withResult: cb.CBATTErrorCode.success);
    expect((host.calls.last.arguments as Map)['requestHandle'], 'write-1');
  });

  test('nested subscribe and unsubscribe events update the same tracked characteristic', () async {
    final subscribed = manager.onDidSubscribeToCharacteristic.first;
    await host.emit('peripheralManagerDidSubscribeToCharacteristic', {
      'characteristicHandle': 'included-c',
      'central': _central(),
    });
    expect((await subscribed).characteristic, same(included));
    expect(included.subscribedCentrals, hasLength(1));
    final unsubscribed = manager.onDidUnsubscribeFromCharacteristic.first;
    await host.emit('peripheralManagerDidUnsubscribeFromCharacteristic', {
      'characteristicHandle': 'included-c',
      'central': _central(),
    });
    expect((await unsubscribed).characteristic, same(included));
    expect(included.subscribedCentrals, isEmpty);
  });

  test('cyclic included-service references terminate and unknown handles remain ignored', () async {
    final root = manager.services.single;
    final leaf = root.includedServices!.single.includedServices!.single;
    leaf.includedServices!.add(root);
    final requests = <cb.DidReceiveReadRequestResult>[];
    final subscription = manager.onDidReceiveReadRequest.listen(requests.add);
    await host.emit('peripheralManagerDidReceiveRead', {..._request('unknown'), 'characteristicHandle': 'missing'});
    expect(requests, isEmpty);
    await host.emit('peripheralManagerDidReceiveRead', _request('known'));
    expect(requests.single.request.characteristic, same(included));
    leaf.includedServices!.clear();
    await subscription.cancel();
  });
}
