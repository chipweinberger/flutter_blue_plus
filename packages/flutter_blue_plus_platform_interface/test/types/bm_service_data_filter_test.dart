import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_blue_plus_platform_interface/src/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmServiceDataFilter',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the data property',
            () {
              expect(
                BmServiceDataFilter.fromMap({
                  'service': '0102',
                  'data': '010203',
                  'mask': '010203',
                }).data,
                equals([
                  0x01,
                  0x02,
                  0x03,
                ]),
              );
            },
          );

          test(
            'deserializes the data property as [] if it is null',
            () {
              expect(
                BmServiceDataFilter.fromMap({
                  'service': '0102',
                  'data': null,
                  'mask': '010203',
                }).data,
                equals([]),
              );
            },
          );

          test(
            'deserializes the mask property',
            () {
              expect(
                BmServiceDataFilter.fromMap({
                  'service': '0102',
                  'data': '010203',
                  'mask': '010203',
                }).mask,
                equals([
                  0x01,
                  0x02,
                  0x03,
                ]),
              );
            },
          );

          test(
            'deserializes the mask property as [] if it is null',
            () {
              expect(
                BmServiceDataFilter.fromMap({
                  'service': '0102',
                  'data': '010203',
                  'mask': null,
                }).mask,
                equals([]),
              );
            },
          );

          test(
            'deserializes the service property',
            () {
              final service = '0102';

              expect(
                BmServiceDataFilter.fromMap({
                  'service': service,
                  'data': '010203',
                  'mask': '010203',
                }).service,
                equals(Guid(service)),
              );
            },
          );
        },
      );

      group(
        'hashCode',
        () {
          test(
            'returns the hash code',
            () {
              final service = Guid('0102');
              final data = <int>[];
              final mask = <int>[];

              expect(
                BmServiceDataFilter(
                  service,
                  data,
                  mask,
                ).hashCode,
                equals(
                  service.hashCode ^
                      const ListEquality<int>().hash(data) ^
                      const ListEquality<int>().hash(mask),
                ),
              );
            },
          );
        },
      );

      group(
        '==',
        () {
          test(
            'returns false if they are not equal',
            () {
              expect(
                BmServiceDataFilter(Guid('0102'), [], []) ==
                    BmServiceDataFilter(Guid('0304'), [], []),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmServiceDataFilter(Guid('0102'), [], []) ==
                    BmServiceDataFilter(Guid('0102'), [], []),
                isTrue,
              );
            },
          );
        },
      );

      group(
        'toMap',
        () {
          test(
            'serializes the data property',
            () {
              final data = [0x01, 0x02, 0x03];

              expect(
                BmServiceDataFilter(
                  Guid('0102'),
                  data,
                  [],
                ).toMap(),
                containsPair(
                  'data',
                  hex.encode(data),
                ),
              );
            },
          );

          test(
            'serializes the mask property',
            () {
              final mask = [0x01, 0x02, 0x03];

              expect(
                BmServiceDataFilter(
                  Guid('0102'),
                  [],
                  mask,
                ).toMap(),
                containsPair(
                  'mask',
                  hex.encode(mask),
                ),
              );
            },
          );

          test(
            'serializes the characteristic uuid property',
            () {
              final service = Guid('0102');

              expect(
                BmServiceDataFilter(
                  service,
                  [],
                  [],
                ).toMap(),
                containsPair(
                  'service',
                  equals(service.str),
                ),
              );
            },
          );
        },
      );
    },
  );
}
