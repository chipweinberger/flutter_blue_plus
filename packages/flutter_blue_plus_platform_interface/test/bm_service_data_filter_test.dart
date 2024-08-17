import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmServiceDataFilter',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the data property as [] if it is null',
            () {
              expect(
                BmServiceDataFilter.fromMap({
                  'service': '0102',
                  'data': null,
                  'mask': null,
                }).data,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the data property',
            () {
              expect(
                BmServiceDataFilter.fromMap({
                  'service': '0102',
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
            'deserializes the mask property as [] if it is null',
            () {
              expect(
                BmServiceDataFilter.fromMap({
                  'service': '0102',
                  'data': null,
                  'mask': null,
                }).mask,
                isEmpty,
              );
            },
          );

          test(
            'deserializes the mask property',
            () {
              expect(
                BmServiceDataFilter.fromMap({
                  'service': '0102',
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
