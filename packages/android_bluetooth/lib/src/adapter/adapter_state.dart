enum BluetoothAdapterState {
  off(10),
  turningOn(11),
  on(12),
  turningOff(13),
  unknown(-1);

  const BluetoothAdapterState(this.value);

  factory BluetoothAdapterState.fromValue(int value) {
    for (final state in BluetoothAdapterState.values) {
      if (state.value == value) {
        return state;
      }
    }

    return BluetoothAdapterState.unknown;
  }

  final int value;
}
