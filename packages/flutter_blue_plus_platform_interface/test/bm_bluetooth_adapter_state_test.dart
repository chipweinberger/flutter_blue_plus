import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'BmBluetoothAdapterState',
    () {
      group(
        'fromMap',
        () {
          test(
            'deserializes the adapter state property',
            () {
              expect(
                BmBluetoothAdapterState.fromMap({
                  'adapter_state': 0,
                }).adapterState,
                equals(BmAdapterStateEnum.unknown),
              );
            },
          );

          test(
            'throws a range error if the adapter state property index is out of range',
            () {
              expect(
                () {
                  BmBluetoothAdapterState.fromMap({
                    'adapter_state': 7,
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
            'serializes the adapter state property',
            () {
              expect(
                BmBluetoothAdapterState(
                  adapterState: BmAdapterStateEnum.unknown,
                ).toMap(),
                containsPair('adapter_state', 0),
              );
            },
          );
        },
      );
    },
  );
}
