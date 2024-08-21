import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmConnectionStateResponse',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the connection state property',
            () {
              expect(
                BmConnectionStateResponse.fromMap({
                  'remote_id': 'str',
                  'connection_state': 0,
                }).connectionState,
                equals(BmConnectionStateEnum.disconnected),
              );
            },
          );

          test(
            'throws a range error if the connection state property index is out of range',
            () {
              expect(
                () {
                  BmConnectionStateResponse.fromMap({
                    'remote_id': 'str',
                    'connection_state': 2,
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
            'serializes the connection state property',
            () {
              expect(
                BmConnectionStateResponse(
                  remoteId: DeviceIdentifier('str'),
                  connectionState: BmConnectionStateEnum.disconnected,
                ).toMap(),
                containsPair('connection_state', 0),
              );
            },
          );
        },
      );
    },
  );
}
