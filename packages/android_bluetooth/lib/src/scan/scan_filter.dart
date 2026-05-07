import 'dart:typed_data';

final class BluetoothScanFilter {
  const BluetoothScanFilter({
    this.advertisingData,
    this.advertisingDataMask,
    this.advertisingDataType,
    this.deviceAddress,
    this.deviceName,
    this.manufacturerData,
    this.manufacturerDataMask,
    this.manufacturerId,
    this.serviceData,
    this.serviceDataMask,
    this.serviceDataUuid,
    this.serviceSolicitationUuid,
    this.serviceSolicitationUuidMask,
    this.serviceUuid,
    this.serviceUuidMask,
  });

  final Uint8List? advertisingData;
  final Uint8List? advertisingDataMask;
  final int? advertisingDataType;
  final String? deviceAddress;
  final String? deviceName;
  final Uint8List? manufacturerData;
  final Uint8List? manufacturerDataMask;
  final int? manufacturerId;
  final Uint8List? serviceData;
  final Uint8List? serviceDataMask;
  final String? serviceDataUuid;
  final String? serviceSolicitationUuid;
  final String? serviceSolicitationUuidMask;
  final String? serviceUuid;
  final String? serviceUuidMask;

  Map<String, Object?> toMap() {
    return {
      'advertisingData': advertisingData,
      'advertisingDataMask': advertisingDataMask,
      'advertisingDataType': advertisingDataType,
      'deviceAddress': deviceAddress,
      'deviceName': deviceName,
      'manufacturerData': manufacturerData,
      'manufacturerDataMask': manufacturerDataMask,
      'manufacturerId': manufacturerId,
      'serviceData': serviceData,
      'serviceDataMask': serviceDataMask,
      'serviceDataUuid': serviceDataUuid,
      'serviceSolicitationUuid': serviceSolicitationUuid,
      'serviceSolicitationUuidMask': serviceSolicitationUuidMask,
      'serviceUuid': serviceUuid,
      'serviceUuidMask': serviceUuidMask,
    };
  }
}

final class BluetoothScanFilterBuilder {
  Uint8List? _advertisingData;
  Uint8List? _advertisingDataMask;
  int? _advertisingDataType;
  String? _deviceAddress;
  String? _deviceName;
  Uint8List? _manufacturerData;
  Uint8List? _manufacturerDataMask;
  int? _manufacturerId;
  Uint8List? _serviceData;
  Uint8List? _serviceDataMask;
  String? _serviceDataUuid;
  String? _serviceSolicitationUuid;
  String? _serviceSolicitationUuidMask;
  String? _serviceUuid;
  String? _serviceUuidMask;

  BluetoothScanFilterBuilder setAdvertisingDataType(int dataType) {
    _advertisingDataType = dataType;
    _advertisingData = null;
    _advertisingDataMask = null;
    return this;
  }

  BluetoothScanFilterBuilder setAdvertisingDataTypeWithData(
    int dataType,
    Uint8List advertisingData,
    Uint8List advertisingDataMask,
  ) {
    _advertisingDataType = dataType;
    _advertisingData = advertisingData;
    _advertisingDataMask = advertisingDataMask;
    return this;
  }

  BluetoothScanFilterBuilder setDeviceAddress(String deviceAddress) {
    _deviceAddress = deviceAddress;
    return this;
  }

  BluetoothScanFilterBuilder setDeviceName(String deviceName) {
    _deviceName = deviceName;
    return this;
  }

  BluetoothScanFilterBuilder setManufacturerData(int manufacturerId, Uint8List manufacturerData) {
    _manufacturerId = manufacturerId;
    _manufacturerData = manufacturerData;
    _manufacturerDataMask = null;
    return this;
  }

  BluetoothScanFilterBuilder setManufacturerDataWithMask(
    int manufacturerId,
    Uint8List manufacturerData,
    Uint8List manufacturerDataMask,
  ) {
    _manufacturerId = manufacturerId;
    _manufacturerData = manufacturerData;
    _manufacturerDataMask = manufacturerDataMask;
    return this;
  }

  BluetoothScanFilterBuilder setServiceData(String serviceDataUuid, Uint8List serviceData) {
    _serviceDataUuid = serviceDataUuid;
    _serviceData = serviceData;
    _serviceDataMask = null;
    return this;
  }

  BluetoothScanFilterBuilder setServiceDataWithMask(
    String serviceDataUuid,
    Uint8List serviceData,
    Uint8List serviceDataMask,
  ) {
    _serviceDataUuid = serviceDataUuid;
    _serviceData = serviceData;
    _serviceDataMask = serviceDataMask;
    return this;
  }

  BluetoothScanFilterBuilder setServiceSolicitationUuid(String serviceSolicitationUuid) {
    _serviceSolicitationUuid = serviceSolicitationUuid;
    _serviceSolicitationUuidMask = null;
    return this;
  }

  BluetoothScanFilterBuilder setServiceSolicitationUuidWithMask(
    String serviceSolicitationUuid,
    String solicitationUuidMask,
  ) {
    _serviceSolicitationUuid = serviceSolicitationUuid;
    _serviceSolicitationUuidMask = solicitationUuidMask;
    return this;
  }

  BluetoothScanFilterBuilder setServiceUuid(String serviceUuid) {
    _serviceUuid = serviceUuid;
    _serviceUuidMask = null;
    return this;
  }

  BluetoothScanFilterBuilder setServiceUuidWithMask(String serviceUuid, String uuidMask) {
    _serviceUuid = serviceUuid;
    _serviceUuidMask = uuidMask;
    return this;
  }

  BluetoothScanFilter build() {
    return BluetoothScanFilter(
      advertisingData: _advertisingData,
      advertisingDataMask: _advertisingDataMask,
      advertisingDataType: _advertisingDataType,
      deviceAddress: _deviceAddress,
      deviceName: _deviceName,
      manufacturerData: _manufacturerData,
      manufacturerDataMask: _manufacturerDataMask,
      manufacturerId: _manufacturerId,
      serviceData: _serviceData,
      serviceDataMask: _serviceDataMask,
      serviceDataUuid: _serviceDataUuid,
      serviceSolicitationUuid: _serviceSolicitationUuid,
      serviceSolicitationUuidMask: _serviceSolicitationUuidMask,
      serviceUuid: _serviceUuid,
      serviceUuidMask: _serviceUuidMask,
    );
  }
}
