import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_bluetooth_test_host.dart';

const _id = '12345678-1234-1234-1234-123456789abc';

cb.CBL2CAPChannel _channel() => cb.CBL2CAPChannel.fromMap(map: {
      'handle': 'channel',
      'psm': 129,
      'peerKind': 'central',
      'peerIdentifier': _id,
      'peerMaximumUpdateValueLength': 20,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreBluetoothTestHost host;
  setUp(() => host = CoreBluetoothTestHost()..setUp());
  tearDown(() => host.tearDown());

  for (final typed in [true, false]) {
    test('L2CAP reads decode ${typed ? 'typed' : 'legacy'} bytes into independent zero-offset buffers', () async {
      final payload = List<int>.generate(4096, (index) => index % 256);
      host.handle = (call) {
        if (call.method != 'l2capChannel.readInputStream') return null;
        expect(call.arguments, {'channelHandle': 'channel', 'maxLength': 4096});
        return typed ? Uint8List.fromList(payload) : payload;
      };
      final result = await _channel().inputStream.read();
      expect(result, payload);
      expect(result.offsetInBytes, 0);
      expect(result.buffer.lengthInBytes, result.length);
      result[0] = 99;
      expect(payload[0], 0);
    });
  }

  test('empty typed reads remain empty Uint8Lists', () async {
    host.handle = (call) => call.method == 'l2capChannel.readInputStream' ? Uint8List(0) : null;
    final result = await _channel().inputStream.read();
    expect(result, isEmpty);
    expect(result.offsetInBytes, 0);
    expect(result.buffer.lengthInBytes, 0);
  });

  test('large read upper bounds preserve partial native replies without padding or extra reads', () async {
    for (final length in [65537, 2147483648, 0x7fffffffffffffff]) {
      host.handle = (call) {
        if (call.method != 'l2capChannel.readInputStream') return null;
        expect(call.arguments, {'channelHandle': 'channel', 'maxLength': length});
        return Uint8List.fromList([42, 255]);
      };
      final before = host.calls.length;
      final bytes = await _channel().inputStream.read(maxLength: length);
      expect(bytes, [42, 255]);
      expect(bytes.offsetInBytes, 0);
      expect(bytes.buffer.lengthInBytes, 2);
      expect(host.calls.length, before + 1);
    }
  });

  test('native read errors retain their code and details', () async {
    host.handle = (call) {
      if (call.method == 'l2capChannel.readInputStream') {
        throw PlatformException(
            code: 'stream_error', message: 'Read failed', details: {'domain': 'NSPOSIXErrorDomain', 'code': 2});
      }
      return null;
    };
    await expectLater(
        _channel().inputStream.read(),
        throwsA(isA<PlatformException>()
            .having((error) => error.code, 'code', 'stream_error')
            .having((error) => error.details, 'details', {'domain': 'NSPOSIXErrorDomain', 'code': 2})));
  });

  for (final open in [true, false]) {
    test('invalid PSM errors propagate through ${open ? 'open' : 'unpublish'} and allow a valid retry', () async {
      final method = open ? 'peripheral.openL2CAPChannel' : 'peripheralManager.unpublishL2CAPChannel';
      host.handle = (call) {
        if (call.method == 'centralManager.retrievePeripherals') {
          return [
            {'identifier': _id, 'state': 2}
          ];
        }
        if (call.method == method && (call.arguments as Map)['psm'] == -1) {
          throw PlatformException(code: 'invalid_args', message: 'Invalid PSM');
        }
        return null;
      };
      if (open) {
        final manager = host.trackCentral(cb.CBCentralManager.createIsolated());
        final peripheral = (await manager.retrievePeripherals([cb.UUID(_id)])).single;
        await expectLater(peripheral.openL2CAPChannel(-1),
            throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'invalid_args')));
        await peripheral.openL2CAPChannel(129);
      } else {
        final manager = host.track(cb.CBPeripheralManager.createIsolated());
        await expectLater(manager.unpublishL2CAPChannel(-1),
            throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'invalid_args')));
        await manager.unpublishL2CAPChannel(129);
      }
      expect(host.calls.last.method, method);
      expect((host.calls.last.arguments as Map)['psm'], 129);
    });
  }
}
