import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'Options',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the show power alert property',
            () {
              final showPowerAlert = false;

              expect(
                Options.fromMap({
                  'show_power_alert': showPowerAlert,
                }).showPowerAlert,
                equals(showPowerAlert),
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
              final showPowerAlert = false;

              expect(
                Options(
                  showPowerAlert: showPowerAlert,
                ).hashCode,
                equals(showPowerAlert.hashCode),
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
                Options(
                      showPowerAlert: false,
                    ) ==
                    Options(
                      showPowerAlert: true,
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                Options(
                      showPowerAlert: false,
                    ) ==
                    Options(
                      showPowerAlert: false,
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
            'serializes the show power alert property',
            () {
              final showPowerAlert = false;

              expect(
                Options(
                  showPowerAlert: showPowerAlert,
                ).toMap(),
                containsPair(
                  'show_power_alert',
                  equals(showPowerAlert),
                ),
              );
            },
          );
        },
      );
    },
  );
}
