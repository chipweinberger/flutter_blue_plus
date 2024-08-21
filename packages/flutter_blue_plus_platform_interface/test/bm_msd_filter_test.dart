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
            'deserializes the data property',
            () {
              expect(
                BmMsdFilter.fromMap({
                  'manufacturer_id': 0,
                  'data': '010203',
                  'mask': null,
                }).data,
                orderedEquals([
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

          test(
            'deserializes the mask property',
            () {
              expect(
                BmMsdFilter.fromMap({
                  'manufacturer_id': 0,
                  'data': null,
                  'mask': '010203',
                }).mask,
                orderedEquals([
                  0x01,
                  0x02,
                  0x03,
                ]),
              );
            },
          );
        },
      );
    },
  );
}
