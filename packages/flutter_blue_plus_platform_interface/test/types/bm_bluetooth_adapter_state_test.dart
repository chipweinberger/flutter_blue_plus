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
              final adapterState = BmAdapterStateEnum.unknown;

              expect(
                BmBluetoothAdapterState.fromMap({
                  'adapter_state': adapterState.index,
                }).adapterState,
                equals(adapterState),
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
        'hashCode',
        () {
          test(
            'returns the hash code',
            () {
              final adapterState = BmAdapterStateEnum.unknown;

              expect(
                BmBluetoothAdapterState(
                  adapterState: adapterState,
                ).hashCode,
                equals(adapterState.hashCode),
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
                BmBluetoothAdapterState(
                      adapterState: BmAdapterStateEnum.unknown,
                    ) ==
                    BmBluetoothAdapterState(
                      adapterState: BmAdapterStateEnum.unavailable,
                    ),
                isFalse,
              );
            },
          );

          test(
            'returns true if they are equal',
            () {
              expect(
                BmBluetoothAdapterState(
                      adapterState: BmAdapterStateEnum.unknown,
                    ) ==
                    BmBluetoothAdapterState(
                      adapterState: BmAdapterStateEnum.unknown,
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
            'serializes the adapter state property',
            () {
              final adapterState = BmAdapterStateEnum.unknown;

              expect(
                BmBluetoothAdapterState(
                  adapterState: adapterState,
                ).toMap(),
                containsPair(
                  'adapter_state',
                  equals(adapterState.index),
                ),
              );
            },
          );
        },
      );
    },
  );
}
