import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmBondStateResponse',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the bond state property',
            () {
              expect(
                BmBondStateResponse.fromMap({
                  'remote_id': '',
                  'bond_state': 0,
                }).bondState,
                equals(BmBondStateEnum.none),
              );
            },
          );

          test(
            'deserializes the prev state property',
            () {
              expect(
                BmBondStateResponse.fromMap({
                  'remote_id': '',
                  'bond_state': 0,
                  'prev_state': 0,
                }).prevState,
                equals(BmBondStateEnum.none),
              );
            },
          );

          test(
            'throws a range error if the bond state property index is out of range',
            () {
              expect(
                () {
                  BmBondStateResponse.fromMap({
                    'remote_id': '',
                    'bond_state': 3,
                  });
                },
                throwsRangeError,
              );
            },
          );

          test(
            'throws a range error if the prev state property index is out of range',
            () {
              expect(
                () {
                  BmBondStateResponse.fromMap({
                    'remote_id': '',
                    'bond_state': 0,
                    'prev_state': 3,
                  });
                },
                throwsRangeError,
              );
            },
          );
        },
      );

      group(
        'toMap',
        () {
          test(
            'serializes the bond state property',
            () {
              expect(
                BmBondStateResponse(
                  remoteId: DeviceIdentifier(''),
                  bondState: BmBondStateEnum.none,
                ).toMap(),
                containsPair('bond_state', 0),
              );
            },
          );

          test(
            'serializes the prev state property',
            () {
              expect(
                BmBondStateResponse(
                  remoteId: DeviceIdentifier(''),
                  bondState: BmBondStateEnum.none,
                  prevState: BmBondStateEnum.none,
                ).toMap(),
                containsPair('prev_state', 0),
              );
            },
          );
        },
      );
    },
  );
}
