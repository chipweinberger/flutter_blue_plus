part of '../core_bluetooth.dart';

var _nextCoreBluetoothLocalReferenceValue = 0;

String _nextCoreBluetoothLocalReference() {
  _nextCoreBluetoothLocalReferenceValue += 1;
  return 'local_$_nextCoreBluetoothLocalReferenceValue';
}
