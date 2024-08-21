import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'PhySupport',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the le 2m property',
            () {
              final le2M = false;

              expect(
                PhySupport.fromMap({
                  'le_2M': le2M,
                  'le_coded': false,
                }).le2M,
                equals(le2M),
              );
            },
          );

          test(
            'deserializes the le coded property',
            () {
              final leCoded = false;

              expect(
                PhySupport.fromMap({
                  'le_2M': false,
                  'le_coded': leCoded,
                }).leCoded,
                equals(leCoded),
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
              final le2M = false;
              final leCoded = false;

              expect(
                PhySupport(
                  le2M: le2M,
                  leCoded: leCoded,
                ).hashCode,
                equals(le2M.hashCode ^ leCoded.hashCode),
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
                PhySupport(
                      le2M: false,
                      leCoded: false,
                    ) ==
                    PhySupport(
                      le2M: true,
                      leCoded: false,
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                PhySupport(
                      le2M: false,
                      leCoded: false,
                    ) ==
                    PhySupport(
                      le2M: false,
                      leCoded: false,
                    ),
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
            'serializes the le 2m property',
            () {
              final le2M = false;

              expect(
                PhySupport(
                  le2M: le2M,
                  leCoded: false,
                ).toMap(),
                containsPair(
                  'le_2M',
                  equals(le2M),
                ),
              );
            },
          );

          test(
            'serializes the le coded property',
            () {
              final leCoded = false;

              expect(
                PhySupport(
                  le2M: false,
                  leCoded: leCoded,
                ).toMap(),
                containsPair(
                  'le_coded',
                  equals(leCoded),
                ),
              );
            },
          );
        },
      );
    },
  );
}
