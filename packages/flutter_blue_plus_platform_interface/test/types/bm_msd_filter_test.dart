import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmMsdFilter',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the data property',
            () {
              expect(
                BmMsdFilter.fromMap({
                  'manufacturer_id': 0,
                  'data': '010203',
                  'mask': null,
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
            'deserializes the data property as null if it is null',
            () {
              expect(
                BmMsdFilter.fromMap({
                  'manufacturer_id': 0,
                  'data': null,
                  'mask': null,
                }).data,
                isNull,
              );
            },
          );

          test(
            'deserializes the mask property',
            () {
              expect(
                BmMsdFilter.fromMap({
                  'manufacturer_id': 0,
                  'data': null,
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
            'deserializes the mask property as null if it is null',
            () {
              expect(
                BmMsdFilter.fromMap({
                  'manufacturer_id': 0,
                  'data': null,
                  'mask': null,
                }).mask,
                isNull,
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
              final manufacturerId = 0;
              final data = <int>[];
              final mask = <int>[];

              expect(
                BmMsdFilter(
                  manufacturerId,
                  data,
                  mask,
                ).hashCode,
                equals(
                  manufacturerId.hashCode ^
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
                BmMsdFilter(0, [], []) == BmMsdFilter(1, [], []),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmMsdFilter(0, [], []) == BmMsdFilter(0, [], []),
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
                BmMsdFilter(
                  0,
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
            'serializes the data property as null if it is null',
            () {
              expect(
                BmMsdFilter(
                  0,
                  null,
                  [],
                ).toMap(),
                containsPair(
                  'data',
                  isNull,
                ),
              );
            },
          );

          test(
            'serializes the mask property',
            () {
              final mask = [0x01, 0x02, 0x03];

              expect(
                BmMsdFilter(
                  0,
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
            'serializes the mask property as null if it is null',
            () {
              expect(
                BmMsdFilter(
                  0,
                  [],
                  null,
                ).toMap(),
                containsPair(
                  'mask',
                  isNull,
                ),
              );
            },
          );
        },
      );
    },
  );
}
