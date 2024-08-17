import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'DeviceIdentifier',
    () {
      group(
        'hashCode',
        () {
          test(
            'returns the hash code of a lower case identifier',
            () {
              expect(
                DeviceIdentifier('str').hashCode,
                equals('str'.hashCode),
              );
            },
          );

          test(
            'returns the hash code of a mixed case identifier',
            () {
              expect(
                DeviceIdentifier('sTr').hashCode,
                equals('str'.hashCode),
              );
            },
          );

          test(
            'returns the hash code of an upper case identifier',
            () {
              expect(
                DeviceIdentifier('STR').hashCode,
                equals('str'.hashCode),
              );
            },
          );
        },
      );

      group(
        '==',
        () {
          test(
            'returns false if the identifiers are not equal',
            () {
              expect(
                DeviceIdentifier('str1') == DeviceIdentifier('str2'),
                isFalse,
              );
            },
          );

          test(
            'returns true if the identifiers are equal',
            () {
              expect(
                DeviceIdentifier('str') == DeviceIdentifier('str'),
                isTrue,
              );
            },
          );

          test(
            'returns true if the identifiers are equal ignoring case',
            () {
              expect(
                DeviceIdentifier('str') == DeviceIdentifier('STR'),
                isTrue,
              );
            },
          );
        },
      );
    },
  );
}
