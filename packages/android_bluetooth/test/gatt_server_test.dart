import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bluetooth_test_host.dart';

void main() {
  final host = BluetoothTestHost();
  setUp(host.setUp);
  tearDown(tick);

  test('GATT server retains prepared-write/offset/response metadata', () async {
    final server = await BluetoothManager.shared.openGattServer();
    final next = server.onCharacteristicWriteRequest.first;
    await emit({
      'owner': server.id,
      'type': 'onCharacteristicWriteRequest',
      'device': {'address': address},
      'requestId': 42,
      'offset': 17,
      'preparedWrite': true,
      'responseNeeded': true,
      'value': [1, 255],
      'characteristic': characteristic('server-c')
    });
    final event = await next;
    expect(event.preparedWrite, true);
    expect(event.responseNeeded, true);
    expect(event.offset, 17);
    expect(event.requestId, 42);
    expect(event.value, [1, 255]);
    host.override = (_) async => true;
    await server.sendResponse(event.device, event.requestId, BluetoothGatt.gattInvalidOffset, offset: 17);
    expect(host.calls.last.arguments, containsPair('requestId', 42));
    expect(host.calls.last.arguments, containsPair('status', 7));
    host.override = null;
    await server.close();
  });
}
