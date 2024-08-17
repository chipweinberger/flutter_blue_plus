import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmConnectionPriorityRequest',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the connection priority property',
            () {
              expect(
                BmConnectionPriorityRequest.fromMap({
                  'remote_id': '',
                  'connection_priority': 0,
                }).connectionPriority,
                equals(BmConnectionPriorityEnum.balanced),
              );
            },
          );

          test(
            'throws a range error if the connection priority property index is out of range',
            () {
              expect(
                () {
                  BmConnectionPriorityRequest.fromMap({
                    'remote_id': '',
                    'connection_priority': 3,
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
            'serializes the connection priority property',
            () {
              expect(
                BmConnectionPriorityRequest(
                  remoteId: DeviceIdentifier(''),
                  connectionPriority: BmConnectionPriorityEnum.balanced,
                ).toMap(),
                containsPair('connection_priority', 0),
              );
            },
          );
        },
      );
    },
  );
}
