import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'Guid',
    () {
      group(
        'empty',
        () {
          test(
            'constructs an instance',
            () {
              expect(
                Guid.empty().bytes,
                equals([
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                  0x00,
                ]),
              );
            },
          );
        },
      );

      group(
        'fromBytes',
        () {
          test(
            'constructs an instance from a list of 2 bytes',
            () {
              expect(
                Guid.fromBytes([
                  0x01,
                  0x02,
                ]).bytes,
                equals([
                  0x01,
                  0x02,
                ]),
              );
            },
          );

          test(
            'constructs an instance from a list of 4 bytes',
            () {
              expect(
                Guid.fromBytes([
                  0x01,
                  0x02,
                  0x03,
                  0x04,
                ]).bytes,
                equals([
                  0x01,
                  0x02,
                  0x03,
                  0x04,
                ]),
              );
            },
          );

          test(
            'constructs an instance from a list of 16 bytes',
            () {
              expect(
                Guid.fromBytes([
                  0x01,
                  0x02,
                  0x03,
                  0x04,
                  0x00,
                  0x00,
                  0x10,
                  0x00,
                  0x80,
                  0x00,
                  0x00,
                  0x80,
                  0x5F,
                  0x9B,
                  0x34,
                  0xFB,
                ]).bytes,
                equals([
                  0x01,
                  0x02,
                  0x03,
                  0x04,
                  0x00,
                  0x00,
                  0x10,
                  0x00,
                  0x80,
                  0x00,
                  0x00,
                  0x80,
                  0x5F,
                  0x9B,
                  0x34,
                  0xFB,
                ]),
              );
            },
          );

          test(
            'throws a format exception if the list is not 2 nor 4 nor 16 bytes in length',
            () {
              expect(
                () {
                  Guid.fromBytes([
                    0x01,
                    0x02,
                    0x03,
                  ]);
                },
                throwsFormatException,
              );
            },
          );
        },
      );

      group(
        'fromString',
        () {
          test(
            'constructs an instance from a string of 2 bytes',
            () {
              expect(
                Guid.fromString('0102').bytes,
                equals([
                  0x01,
                  0x02,
                ]),
              );
            },
          );

          test(
            'constructs an instance from a string of 4 bytes',
            () {
              expect(
                Guid.fromString('01020304').bytes,
                equals([
                  0x01,
                  0x02,
                  0x03,
                  0x04,
                ]),
              );
            },
          );

          test(
            'constructs an instance from a string of 16 bytes',
            () {
              expect(
                Guid.fromString('0102030400001000800000805f9b34fb').bytes,
                equals([
                  0x01,
                  0x02,
                  0x03,
                  0x04,
                  0x00,
                  0x00,
                  0x10,
                  0x00,
                  0x80,
                  0x00,
                  0x00,
                  0x80,
                  0x5F,
                  0x9B,
                  0x34,
                  0xFB,
                ]),
              );
            },
          );

          test(
            'constructs an instance from a uuid formatted string',
            () {
              expect(
                Guid.fromString('01020304-0000-1000-8000-00805f9b34fb').bytes,
                equals([
                  0x01,
                  0x02,
                  0x03,
                  0x04,
                  0x00,
                  0x00,
                  0x10,
                  0x00,
                  0x80,
                  0x00,
                  0x00,
                  0x80,
                  0x5F,
                  0x9B,
                  0x34,
                  0xFB,
                ]),
              );
            },
          );

          test(
            'throws a format exception if the string is not 2 nor 4 nor 16 bytes in length',
            () {
              expect(
                () {
                  Guid.fromString('010203');
                },
                throwsFormatException,
              );
            },
          );
        },
      );
    },
  );

  group(
    'str',
    () {
      test(
        'returns a string of 2 bytes if the list of bytes is 2 bytes in length',
        () {
          expect(
            Guid('0102').str,
            equals('0102'),
          );
        },
      );

      test(
        'returns a string of 4 bytes if the list of bytes is 4 bytes in length',
        () {
          expect(
            Guid('01020304').str,
            equals('01020304'),
          );
        },
      );

      test(
        'returns a string of 16 bytes if the list of bytes is 16 bytes in length and does not end with the suffix',
        () {
          expect(
            Guid('01020304-0000-0000-0000-000000000000').str,
            equals('01020304-0000-0000-0000-000000000000'),
          );
        },
      );

      test(
        'returns a string of 4 bytes if the list of bytes is 16 bytes in length and ends with the suffix',
        () {
          expect(
            Guid('01020304-0000-1000-8000-00805f9b34fb').str,
            equals('01020304'),
          );
        },
      );
    },
  );

  group(
    'str128',
    () {
      test(
        'returns a string of 16 bytes if the list of bytes is 2 bytes in length',
        () {
          expect(
            Guid('0102').str128,
            equals('00000102-0000-1000-8000-00805f9b34fb'),
          );
        },
      );

      test(
        'returns a string of 16 bytes if the list of bytes is 4 bytes in length',
        () {
          expect(
            Guid('01020304').str128,
            equals('01020304-0000-1000-8000-00805f9b34fb'),
          );
        },
      );

      test(
        'returns a string of 16 bytes if the list of bytes is 16 bytes in length',
        () {
          expect(
            Guid('01020304-0000-1000-8000-00805f9b34fb').str128,
            equals('01020304-0000-1000-8000-00805f9b34fb'),
          );
        },
      );
    },
  );

  group(
    'uuid',
    () {
      test(
        'returns the str property',
        () {
          expect(
            Guid('0102').uuid,
            equals('0102'),
          );
        },
      );
    },
  );

  group(
    'uuid128',
    () {
      test(
        'returns the str128 property',
        () {
          expect(
            Guid('0102').uuid128,
            equals('00000102-0000-1000-8000-00805f9b34fb'),
          );
        },
      );
    },
  );

  group(
    'toString',
    () {
      test(
        'returns the str property',
        () {
          expect(
            Guid('0102').toString(),
            equals('0102'),
          );
        },
      );
    },
  );
}
