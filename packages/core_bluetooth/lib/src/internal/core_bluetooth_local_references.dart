part of '../core_bluetooth.dart';

String _localReferenceSession() {
  final random = math.Random.secure();
  return List.generate(4, (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0')).join();
}

final _coreBluetoothLocalReferenceSession = _localReferenceSession();
var _nextCoreBluetoothLocalReferenceValue = 0;

String _nextCoreBluetoothLocalReference() {
  _nextCoreBluetoothLocalReferenceValue += 1;
  return 'local_${_coreBluetoothLocalReferenceSession}_$_nextCoreBluetoothLocalReferenceValue';
}
