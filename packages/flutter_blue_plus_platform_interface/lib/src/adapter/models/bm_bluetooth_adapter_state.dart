import '../enums/bm_adapter_state_enum.dart';

class BmBluetoothAdapterState {
  BmAdapterStateEnum adapterState;

  BmBluetoothAdapterState({
    required this.adapterState,
  });

  factory BmBluetoothAdapterState.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBluetoothAdapterState(
      adapterState: BmAdapterStateEnum.values[json['adapter_state'] as int],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'adapter_state': adapterState.index,
    };
  }
}
