import 'dart:typed_data';

import 'package:core_bluetooth/core_bluetooth.dart' as cb;
import 'package:flutter_test/flutter_test.dart';

const _full = '0000180f-0000-1000-8000-00805f9b34fb';

cb.UUIDBytes _bytes(List<int> values) => (
      values[0],
      values[1],
      values[2],
      values[3],
      values[4],
      values[5],
      values[6],
      values[7],
      values[8],
      values[9],
      values[10],
      values[11],
      values[12],
      values[13],
      values[14],
      values[15],
    );

void main() {
  test('Foundation UUID bytes reject out-of-range values in every position', () {
    for (var index = 0; index < 16; index++) {
      for (final value in [-9223372036854775808, -1, 256, 9223372036854775807]) {
        final values = List.filled(16, 0)..[index] = value;
        expect(
          () => cb.UUID.fromBytes(_bytes(values)),
          throwsA(isA<RangeError>()
              .having((error) => error.invalidValue, 'value', value)
              .having((error) => error.name, 'name', 'bytes[$index]')),
        );
      }
    }
  });

  test('Foundation UUID byte boundaries round-trip without shifting or truncation', () {
    for (var index = 0; index < 16; index++) {
      for (final value in [0, 1, 127, 128, 254, 255]) {
        final values = List.filled(16, 0)..[index] = value;
        final bytes = _bytes(values);
        final uuid = cb.UUID.fromBytes(bytes);
        final parsed = cb.UUID(uuid.uuidString);
        expect(uuid.uuid, bytes);
        expect(parsed.uuid, bytes);
        expect(parsed, uuid);
        expect(parsed.hashCode, uuid.hashCode);
        expect(cb.CBUUID.fromNSUUID(uuid).data, values);
      }
    }
  });

  test('Bluetooth UUID strings preserve 16-bit, 32-bit and 128-bit normalization', () {
    for (final input in ['180F', '0000180F', _full.toUpperCase(), _full.replaceAll('-', '').toUpperCase()]) {
      final uuid = cb.CBUUID(input);
      expect(uuid, cb.CBUUID(_full));
      expect(uuid.hashCode, cb.CBUUID(_full).hashCode);
      expect(uuid.uuidString, input.length < 32 ? input.toLowerCase() : _full);
      expect(cb.CBUUID.string(input), uuid);
      expect(cb.CBUUID.fromData(uuid.data), uuid);
      expect(cb.CBUUID.data(uuid.data), uuid);
    }
    expect(cb.CBUUID('180F').data, [0x18, 0x0f]);
    expect(cb.CBUUID('0000180F').data, [0, 0, 0x18, 0x0f]);
    expect(cb.CBUUID(_full).data, [0, 0, 0x18, 0x0f, 0, 0, 0x10, 0, 0x80, 0, 0, 0x80, 0x5f, 0x9b, 0x34, 0xfb]);
  });

  test('Foundation UUID strings preserve normalization, bytes and Bluetooth conversion', () {
    final canonical = cb.UUID(_full);
    for (final input in [_full, _full.toUpperCase(), _full.replaceAll('-', '')]) {
      final uuid = cb.UUID(input);
      expect(uuid.uuidString, _full);
      expect(uuid, canonical);
      expect(uuid.hashCode, canonical.hashCode);
      expect(cb.UUID.fromBytes(uuid.uuid), uuid);
      expect(cb.CBUUID.fromNSUUID(uuid), cb.CBUUID(_full));
      expect(cb.CBUUID.nsuuid(uuid), cb.CBUUID(_full));
    }
  });

  test('Bluetooth UUID byte constructors still own an independent byte copy', () {
    final bytes = Uint8List.fromList([0x18, 0x0f]);
    final uuid = cb.CBUUID.fromData(bytes);
    bytes[0] = 0;
    expect(uuid.data, [0x18, 0x0f]);
    expect(uuid.uuidString, '180f');
    expect(uuid, cb.CBUUID('180f'));
  });

  for (final input in ['180f', '0000180f', _full]) {
    test('Bluetooth UUID data can be edited without changing its identity ($input)', () {
      final expected = cb.CBUUID(input).data;
      final constructors = <cb.CBUUID Function()>[
        () => cb.CBUUID(input),
        () => cb.CBUUID.string(input),
        () => cb.CBUUID.fromData(expected),
        () => cb.CBUUID.data(expected),
        if (input == _full) ...[
          () => cb.CBUUID.fromNSUUID(cb.UUID(input)),
          () => cb.CBUUID.nsuuid(cb.UUID(input)),
        ],
      ];
      for (final create in constructors) {
        final uuid = create();
        final equivalent = cb.CBUUID(input);
        final hash = uuid.hashCode;
        final lookup = {uuid: 'registered'};
        final first = uuid.data;
        final second = uuid.data;
        first[0] ^= 255;
        first.buffer.asUint8List()[first.length - 1] ^= 255;
        expect(first, isNot(expected));
        expect(second, expected);
        expect(uuid.data, expected);
        expect(uuid.uuidString, input);
        expect(uuid, equivalent);
        expect(uuid.hashCode, hash);
        expect(lookup[equivalent], 'registered');
        expect(cb.CBUUID.fromData(uuid.data), uuid);
      }
    });
  }

  test('Bluetooth UUIDs reject signed pairs and whitespace accepted by integer parsing', () {
    for (final pair in ['+1', ' 1', '1 ', '\t1', '\n1', '\r1']) {
      for (final length in [4, 8, 32]) {
        final padding = '0' * (length - pair.length);
        for (final input in ['$pair$padding', '$padding$pair']) {
          expect(() => cb.CBUUID(input), throwsFormatException, reason: 'input: ${input.codeUnits}');
          expect(() => cb.CBUUID.string(input), throwsFormatException, reason: 'input: ${input.codeUnits}');
        }
      }
    }
    expect(() => cb.CBUUID('+1ff'), throwsFormatException);
    expect(() => cb.CBUUID('0000+1ff-0000-1000-8000-00805f9b34fb'), throwsFormatException);
  });

  test('Foundation UUIDs reject signed pairs and whitespace throughout full UUIDs', () {
    for (final pair in ['+1', ' 1', '1 ', '\t1', '\n1', '\r1']) {
      for (final offset in [0, 14, 30]) {
        final hex = '${'0' * offset}$pair${'0' * (30 - offset)}';
        final dashed = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
            '${hex.substring(16, 20)}-${hex.substring(20)}';
        expect(() => cb.UUID(hex), throwsFormatException, reason: 'input: ${hex.codeUnits}');
        expect(() => cb.UUID(dashed), throwsFormatException, reason: 'input: ${dashed.codeUnits}');
      }
    }
  });

  test('UUID constructors reject other non-hex characters and invalid lengths', () {
    for (final input in ['180g', '0x0f', '１８０f', '180\u0000', '', '1', '180', '180f00', '0' * 31, '0' * 33]) {
      expect(() => cb.CBUUID(input), throwsFormatException, reason: 'input: ${input.codeUnits}');
    }
    for (final input in [
      '0000180g-0000-1000-8000-00805f9b34fb',
      '0000180f-0000-1000-8000-00805f9b34f\u0000',
      '0000180f-0000-1000-8000-00805f9b34f１',
      '',
      '180f',
      '0' * 31,
      '0' * 33,
    ]) {
      expect(() => cb.UUID(input), throwsFormatException, reason: 'input: ${input.codeUnits}');
    }
  });
}
