import '../device/device.dart';
import 'scan_record.dart';

final class BluetoothScanResult {
  const BluetoothScanResult({
    required this.advertisingSid,
    required this.callbackType,
    required this.connectable,
    required this.device,
    required this.legacy,
    required this.localName,
    required this.periodicAdvertisingInterval,
    required this.primaryPhy,
    required this.rssi,
    required this.scanRecord,
    required this.secondaryPhy,
    required this.timestampNanos,
    required this.txPower,
  });

  factory BluetoothScanResult.fromMap(Map<Object?, Object?> map) {
    return BluetoothScanResult(
      advertisingSid: map['advertisingSid'] as int?,
      callbackType: map['callbackType'] as int?,
      connectable: map['isConnectable'] as bool?,
      device: BluetoothDevice.fromMap(map['device'] as Map<Object?, Object?>),
      legacy: map['isLegacy'] as bool?,
      localName: map['localName'] as String?,
      periodicAdvertisingInterval: map['periodicAdvertisingInterval'] as int?,
      primaryPhy: map['primaryPhy'] as int?,
      rssi: map['rssi'] as int?,
      scanRecord: BluetoothScanRecord.fromMap(map['scanRecord'] as Map<Object?, Object?>? ?? const {}),
      secondaryPhy: map['secondaryPhy'] as int?,
      timestampNanos: map['timestampNanos'] as int?,
      txPower: map['txPower'] as int?,
    );
  }

  final int? advertisingSid;
  final int? callbackType;
  final bool? connectable;
  final BluetoothDevice device;
  final bool? legacy;
  final String? localName;
  final int? periodicAdvertisingInterval;
  final int? primaryPhy;
  final int? rssi;
  final BluetoothScanRecord scanRecord;
  final int? secondaryPhy;
  final int? timestampNanos;
  final int? txPower;

  BluetoothDevice getDevice() {
    return device;
  }

  int? getRssi() {
    return rssi;
  }

  BluetoothScanRecord getScanRecord() {
    return scanRecord;
  }

  int? getTimestampNanos() {
    return timestampNanos;
  }

  int? getPrimaryPhy() {
    return primaryPhy;
  }

  int? getSecondaryPhy() {
    return secondaryPhy;
  }

  int? getAdvertisingSid() {
    return advertisingSid;
  }

  int? getCallbackType() {
    return callbackType;
  }

  int? getTxPower() {
    return txPower;
  }

  int? getPeriodicAdvertisingInterval() {
    return periodicAdvertisingInterval;
  }

  bool? isConnectable() {
    return connectable;
  }

  bool? isLegacy() {
    return legacy;
  }
}
