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
            'deserializes the user accepted property as false if the user accepted property is null',
            () {
              expect(
                BmTurnOnResponse.fromMap({
                  'user_accepted': null,
                }).userAccepted,
                isFalse,
              );
            },
          );

          test(
            'deserializes the user accepted property as true if the user accepted property is true',
            () {
              expect(
                BmTurnOnResponse.fromMap({
                  'user_accepted': true,
                }).userAccepted,
                isTrue,
              );
            },
          );
        },
      );
    },
  );
}
