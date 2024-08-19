import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmTurnOnResponse',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the user accepted property',
            () {
              expect(
                BmTurnOnResponse.fromMap({
                  'user_accepted': true,
                }).userAccepted,
                isTrue,
              );
            },
          );

          test(
            'deserializes the user accepted property as false if it is null',
            () {
              expect(
                BmTurnOnResponse.fromMap({
                  'user_accepted': null,
                }).userAccepted,
                isFalse,
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
              final userAccepted = true;

              expect(
                BmTurnOnResponse(
                  userAccepted: userAccepted,
                ).hashCode,
                equals(userAccepted.hashCode),
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
                BmTurnOnResponse(
                      userAccepted: true,
                    ) ==
                    BmTurnOnResponse(
                      userAccepted: false,
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmTurnOnResponse(
                      userAccepted: true,
                    ) ==
                    BmTurnOnResponse(
                      userAccepted: true,
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
            'serializes the user accepted property',
            () {
              expect(
                BmTurnOnResponse(
                  userAccepted: true,
                ).toMap(),
                containsPair(
                  'user_accepted',
                  isTrue,
                ),
              );
            },
          );
        },
      );
    },
  );
}
