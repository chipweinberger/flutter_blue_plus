import 'dart:typed_data';

final class BluetoothScanRecord {
  const BluetoothScanRecord({
    required this.advertisingDataMap,
    required this.appearance,
    required this.localName,
    required this.manufacturerData,
    required this.rawBytes,
    required this.serviceData,
    required this.serviceSolicitationUuids,
    required this.serviceUuids,
    required this.txPowerLevel,
  });

  factory BluetoothScanRecord.fromMap(Map<Object?, Object?> map) {
    final advertisingDataMap = <int, Uint8List>{};
    final rawAdvertisingDataMap = map['advertisingDataMap'] as Map<Object?, Object?>? ?? const {};
    for (final entry in rawAdvertisingDataMap.entries) {
      advertisingDataMap[entry.key as int] = entry.value as Uint8List;
    }

    final manufacturerData = <int, Uint8List>{};
    final manufacturerDataMap = map['manufacturerData'] as Map<Object?, Object?>? ?? const {};
    for (final entry in manufacturerDataMap.entries) {
      manufacturerData[entry.key as int] = entry.value as Uint8List;
    }

    final serviceData = <String, Uint8List>{};
    final serviceDataMap = map['serviceData'] as Map<Object?, Object?>? ?? const {};
    for (final entry in serviceDataMap.entries) {
      serviceData[entry.key as String] = entry.value as Uint8List;
    }

    return BluetoothScanRecord(
      advertisingDataMap: advertisingDataMap,
      appearance: map['appearance'] as int?,
      localName: map['localName'] as String?,
      manufacturerData: manufacturerData,
      rawBytes: map['rawBytes'] as Uint8List?,
      serviceData: serviceData,
      serviceSolicitationUuids: (map['serviceSolicitationUuids'] as List<Object?>? ?? const []).cast<String>(),
      serviceUuids: (map['serviceUuids'] as List<Object?>? ?? const []).cast<String>(),
      txPowerLevel: map['txPowerLevel'] as int?,
    );
  }

  final Map<int, Uint8List> advertisingDataMap;
  final int? appearance;
  final String? localName;
  final Map<int, Uint8List> manufacturerData;
  final Uint8List? rawBytes;
  final Map<String, Uint8List> serviceData;
  final List<String> serviceSolicitationUuids;
  final List<String> serviceUuids;
  final int? txPowerLevel;

  String? getDeviceName() {
    return localName;
  }

  Map<int, Uint8List> getManufacturerSpecificData() {
    return manufacturerData;
  }

  Map<String, Uint8List> getServiceData() {
    return serviceData;
  }

  List<String> getServiceUuids() {
    return serviceUuids;
  }

  int? getTxPowerLevel() {
    return txPowerLevel;
  }

  Uint8List? getBytes() {
    return rawBytes;
  }

  Map<int, Uint8List> getAdvertisingDataMap() {
    return advertisingDataMap;
  }

  List<String> getServiceSolicitationUuids() {
    return serviceSolicitationUuids;
  }

  int? getAppearance() {
    return appearance;
  }
}
