part of flutter_blue_plus;

enum BmAdapterStateEnum {
  unknown, // 0
  unavailable, // 1
  unauthorized, // 2
  turningOn, // 3
  on, // 4
  turningOff, // 5
  off, // 6
}

class BmBluetoothAdapterState {
  BmAdapterStateEnum adapterState;

  BmBluetoothAdapterState({required this.adapterState});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['adapter_state'] = adapterState.index;
    return data;
  }

  factory BmBluetoothAdapterState.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothAdapterState(
      adapterState: BmAdapterStateEnum.values[json['adapter_state']],
    );
  }
}

class BmAdvertisementData {
  final String? localName;
  final int? txPowerLevel;
  final bool connectable;
  final Map<int, List<int>> manufacturerData;
  final Map<String, List<int>> serviceData;

  // We use strings and not Guid because advertisement UUIDs can
  // be 32-bit UUIDs, 64-bit, etc i.e. "FE56"
  List<String> serviceUuids;

  BmAdvertisementData({
    required this.localName,
    required this.txPowerLevel,
    required this.connectable,
    required this.manufacturerData,
    required this.serviceData,
    required this.serviceUuids,
  });

  factory BmAdvertisementData.fromMap(Map<dynamic, dynamic> json) {
    // Get raw data
    var rawManufacturerData = json['manufacturer_data'] ?? {};
    var rawServiceData = json['service_data'] ?? {};
    var rawServiceUuids = json['service_uuids'] ?? [];

    // Cast the data to the right type
    Map<int, List<int>> manufacturerData = {};
    for (var key in rawManufacturerData.keys) {
      manufacturerData[key] = _hexDecode(rawManufacturerData[key]);
    }

    // Cast the data to the right type
    Map<String, List<int>> serviceData = {};
    for (var key in rawServiceData.keys) {
      serviceData[key] = _hexDecode(rawServiceData[key]);
    }

    // Cast the data to the right type
    // Note: we use strings and not Guid because advertisement UUIDs can
    // be 32-bit UUIDs, 64-bit, etc i.e. "FE56"
    List<String> serviceUuids = [];
    for (var val in rawServiceUuids) {
      serviceUuids.add(val);
    }

    // Construct the BmAdvertisementData
    return BmAdvertisementData(
      localName: json['local_name'],
      txPowerLevel: json['tx_power_level'],
      connectable: json['connectable'] != 0,
      manufacturerData: manufacturerData,
      serviceData: serviceData,
      serviceUuids: serviceUuids,
    );
  }
}

class BmScanSettings {
  final List<Guid> serviceUuids;
  final List<String> macAddresses;
  final bool allowDuplicates;
  final int androidScanMode;
  final bool androidUsesFineLocation;

  BmScanSettings({
    required this.serviceUuids,
    required this.macAddresses,
    required this.allowDuplicates,
    required this.androidScanMode,
    required this.androidUsesFineLocation,
  });

  Map<dynamic, dynamic> toMap() {
    // Cast serviceUuid to strings
    List<String> s = [];
    for (var val in serviceUuids) {
      s.add(val.toString());
    }

    final Map<dynamic, dynamic> data = {};
    data['service_uuids'] = s;
    data['mac_addresses'] = macAddresses;
    data['allow_duplicates'] = allowDuplicates;
    data['android_scan_mode'] = androidScanMode;
    data['android_uses_fine_location'] = androidUsesFineLocation;
    return data;
  }
}

class BmScanFailed {
  final bool success;
  final int? errorCode;
  final String? errorString;

  BmScanFailed({
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmScanFailed.fromMap(Map<dynamic, dynamic> json) {
    return BmScanFailed(
      success: json['success'] != 0,
      errorCode: json['error_code'],
      errorString: json['error_string'],
    );
  }
}

class BmScanResult {
  final BmBluetoothDevice device;
  final BmAdvertisementData advertisementData;
  final int rssi;

  BmScanResult({
    required this.device,
    required this.advertisementData,
    required this.rssi,
  });

  factory BmScanResult.fromMap(Map<dynamic, dynamic> json) {
    return BmScanResult(
      device: BmBluetoothDevice.fromMap(json['device']),
      advertisementData: BmAdvertisementData.fromMap(json['advertisement_data']),
      rssi: json['rssi'],
    );
  }
}

class BmScanResponse {
  final BmScanResult? result;
  final BmScanFailed? failed;

  BmScanResponse({
    required this.result,
    required this.failed,
  });

  factory BmScanResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmScanResponse(
      result: json['result'] != null ? BmScanResult.fromMap(json['result']) : null,
      failed: json['failed'] != null ? BmScanFailed.fromMap(json['failed']) : null,
    );
  }
}

class BmConnectRequest {
  String remoteId;
  bool autoConnect;

  BmConnectRequest({
    required this.remoteId,
    required this.autoConnect,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['auto_connect'] = autoConnect ? 1 : 0;
    return data;
  }
}

enum BmBluetoothSpecEnum {
  unknown,
  classic,
  le,
  dual,
}

class BmBluetoothDevice {
  String remoteId;
  String? localName;
  BmBluetoothSpecEnum type;

  BmBluetoothDevice({
    required this.remoteId,
    required this.localName,
    required this.type,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['local_name'] = localName;
    data['type'] = type.index;
    return data;
  }

  factory BmBluetoothDevice.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothDevice(
      remoteId: json['remote_id'],
      localName: json['local_name'],
      type: BmBluetoothSpecEnum.values[json['type']],
    );
  }
}

class BmBluetoothService {
  final String remoteId;
  final Guid serviceUuid;
  bool isPrimary;
  List<BmBluetoothCharacteristic> characteristics;
  List<BmBluetoothService> includedServices;

  BmBluetoothService({
    required this.serviceUuid,
    required this.remoteId,
    required this.isPrimary,
    required this.characteristics,
    required this.includedServices,
  });

  factory BmBluetoothService.fromMap(Map<dynamic, dynamic> json) {
    // convert characteristics
    List<BmBluetoothCharacteristic> chrs = [];
    for (var v in json['characteristics']) {
      chrs.add(BmBluetoothCharacteristic.fromMap(v));
    }

    // convert services
    List<BmBluetoothService> svcs = [];
    for (var v in json['included_services']) {
      svcs.add(BmBluetoothService.fromMap(v));
    }

    return BmBluetoothService(
      serviceUuid: Guid(json['service_uuid']),
      remoteId: json['remote_id'],
      isPrimary: json['is_primary'] != 0,
      characteristics: chrs,
      includedServices: svcs,
    );
  }
}

class BmBluetoothCharacteristic {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  List<BmBluetoothDescriptor> descriptors;
  BmCharacteristicProperties properties;
  List<int> value;

  BmBluetoothCharacteristic({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptors,
    required this.properties,
    required this.value,
  });

  factory BmBluetoothCharacteristic.fromMap(Map<dynamic, dynamic> json) {
    // convert descriptors
    List<BmBluetoothDescriptor> descs = [];
    for (var v in json['descriptors']) {
      descs.add(BmBluetoothDescriptor.fromMap(v));
    }

    return BmBluetoothCharacteristic(
      remoteId: json['remote_id'],
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null ? Guid(json['secondary_service_uuid']) : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptors: descs,
      properties: BmCharacteristicProperties.fromMap(json['properties']),
      value: _hexDecode(json['value']),
    );
  }
}

class BmBluetoothDescriptor {
  final String remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final List<int> value;

  BmBluetoothDescriptor({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.value,
  });

  factory BmBluetoothDescriptor.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothDescriptor(
      remoteId: json['remote_id'],
      serviceUuid: Guid(json['service_uuid']),
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
      value: _hexDecode(json['value']),
    );
  }
}

class BmCharacteristicProperties {
  bool broadcast;
  bool read;
  bool writeWithoutResponse;
  bool write;
  bool notify;
  bool indicate;
  bool authenticatedSignedWrites;
  bool extendedProperties;
  bool notifyEncryptionRequired;
  bool indicateEncryptionRequired;

  BmCharacteristicProperties({
    required this.broadcast,
    required this.read,
    required this.writeWithoutResponse,
    required this.write,
    required this.notify,
    required this.indicate,
    required this.authenticatedSignedWrites,
    required this.extendedProperties,
    required this.notifyEncryptionRequired,
    required this.indicateEncryptionRequired,
  });

  factory BmCharacteristicProperties.fromMap(Map<dynamic, dynamic> json) {
    return BmCharacteristicProperties(
      broadcast: json['broadcast'] != 0,
      read: json['read'] != 0,
      writeWithoutResponse: json['write_without_response'] != 0,
      write: json['write'] != 0,
      notify: json['notify'] != 0,
      indicate: json['indicate'] != 0,
      authenticatedSignedWrites: json['authenticated_signed_writes'] != 0,
      extendedProperties: json['extended_properties'] != 0,
      notifyEncryptionRequired: json['notify_encryption_required'] != 0,
      indicateEncryptionRequired: json['indicate_encryption_required'] != 0,
    );
  }
}

class BmDiscoverServicesResult {
  final String remoteId;
  final List<BmBluetoothService> services;
  final bool success;
  final int? errorCode;
  final String? errorString;

  BmDiscoverServicesResult({
    required this.remoteId,
    required this.services,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmDiscoverServicesResult.fromMap(Map<dynamic, dynamic> json) {
    return BmDiscoverServicesResult(
      remoteId: json['remote_id'],
      services: (json['services'] as List<dynamic>)
          .map((e) => BmBluetoothService.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      success: json['success'] != 0,
      errorCode: json['error_code'],
      errorString: json['error_string'],
    );
  }
}

class BmReadCharacteristicRequest {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;

  BmReadCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['service_uuid'] = serviceUuid.toString();
    data['secondary_service_uuid'] = secondaryServiceUuid?.toString();
    data['characteristic_uuid'] = characteristicUuid.toString();
    return data;
  }
}

class BmOnCharacteristicReceived {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final List<int> value;
  final bool success;
  final int? errorCode;
  final String? errorString;

  BmOnCharacteristicReceived({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmOnCharacteristicReceived.fromMap(Map<dynamic, dynamic> json) {
    return BmOnCharacteristicReceived(
      remoteId: json['remote_id'],
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null ? Guid(json['secondary_service_uuid']) : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      value: _hexDecode(json['value']),
      success: json['success'] != 0,
      errorCode: json['error_code'],
      errorString: json['error_string'],
    );
  }
}

class BmOnCharacteristicWritten {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final bool success;
  final int? errorCode;
  final String? errorString;

  BmOnCharacteristicWritten({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmOnCharacteristicWritten.fromMap(Map<dynamic, dynamic> json) {
    return BmOnCharacteristicWritten(
      remoteId: json['remote_id'],
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null ? Guid(json['secondary_service_uuid']) : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      success: json['success'] != 0,
      errorCode: json['error_code'],
      errorString: json['error_string'],
    );
  }
}

class BmReadDescriptorRequest {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;

  BmReadDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['service_uuid'] = serviceUuid.toString();
    data['secondary_service_uuid'] = secondaryServiceUuid?.toString();
    data['characteristic_uuid'] = characteristicUuid.toString();
    data['descriptor_uuid'] = descriptorUuid.toString();
    return data;
  }
}

enum BmWriteType {
  withResponse,
  withoutResponse,
}

class BmWriteCharacteristicRequest {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final BmWriteType writeType;
  final List<int> value;

  BmWriteCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.writeType,
    required this.value,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['service_uuid'] = serviceUuid.toString();
    data['secondary_service_uuid'] = secondaryServiceUuid?.toString();
    data['characteristic_uuid'] = characteristicUuid.toString();
    data['write_type'] = writeType.index;
    data['value'] = _hexEncode(value);
    return data;
  }
}

class BmWriteDescriptorRequest {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final List<int> value;

  BmWriteDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.value,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['service_uuid'] = serviceUuid.toString();
    data['secondary_service_uuid'] = secondaryServiceUuid?.toString();
    data['characteristic_uuid'] = characteristicUuid.toString();
    data['descriptor_uuid'] = descriptorUuid.toString();
    data['value'] = _hexEncode(value);
    return data;
  }
}

enum BmOnDescriptorResponseType {
  read, // 0
  write, // 1
}

BmOnDescriptorResponseType bmOnDescriptorResponseParse(int i) {
  switch (i) {
    case 0:
      return BmOnDescriptorResponseType.read;
    case 1:
      return BmOnDescriptorResponseType.write;
  }
  throw ("invalid BmOnDescriptorResponseType type: $i");
}

class BmOnDescriptorResponse {
  final BmOnDescriptorResponseType type;
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final List<int> value;
  final bool success;
  final int? errorCode;
  final String? errorString;

  BmOnDescriptorResponse({
    required this.type,
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmOnDescriptorResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmOnDescriptorResponse(
      type: bmOnDescriptorResponseParse(json['type']),
      remoteId: json['remote_id'],
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null ? Guid(json['secondary_service_uuid']) : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
      value: _hexDecode(json['value']),
      success: json['success'] != 0,
      errorCode: json['error_code'],
      errorString: json['error_string'],
    );
  }
}

class BmSetNotificationRequest {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final bool enable;

  BmSetNotificationRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.enable,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['service_uuid'] = serviceUuid.toString();
    data['secondary_service_uuid'] = secondaryServiceUuid?.toString();
    data['characteristic_uuid'] = characteristicUuid.toString();
    data['enable'] = enable;
    return data;
  }
}

enum BmConnectionStateEnum {
  disconnected, // 0
  connecting, // 1
  connected, // 2
  disconnecting, // 3
}

class BmConnectionStateResponse {
  final String remoteId;
  final BmConnectionStateEnum connectionState;
  final int? disconnectReasonCode;
  final String? disconnectReasonString;

  BmConnectionStateResponse({
    required this.remoteId,
    required this.connectionState,
    required this.disconnectReasonCode,
    required this.disconnectReasonString,
  });

  factory BmConnectionStateResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmConnectionStateResponse(
      remoteId: json['remote_id'],
      connectionState: BmConnectionStateEnum.values[json['connection_state'] as int],
      disconnectReasonCode: json['disconnect_reason_code'],
      disconnectReasonString: json['disconnect_reason_string'],
    );
  }
}

class BmConnectedDevicesResponse {
  final List<BmBluetoothDevice> devices;

  BmConnectedDevicesResponse({required this.devices});

  factory BmConnectedDevicesResponse.fromMap(Map<dynamic, dynamic> json) {
    // convert to BmBluetoothDevice
    List<BmBluetoothDevice> devices = [];
    for (var i = 0; i < json['devices'].length; i++) {
      devices.add(BmBluetoothDevice.fromMap(json['devices'][i]));
    }
    return BmConnectedDevicesResponse(devices: devices);
  }
}

class BmMtuChangeRequest {
  final String remoteId;
  final int mtu;

  BmMtuChangeRequest({required this.remoteId, required this.mtu});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['mtu'] = mtu;
    return data;
  }
}

class BmMtuChangedResponse {
  final String remoteId;
  final int mtu;
  final bool success;
  final int? errorCode;
  final String? errorString;

  BmMtuChangedResponse({
    required this.remoteId,
    required this.mtu,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmMtuChangedResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmMtuChangedResponse(
      remoteId: json['remote_id'],
      mtu: json['mtu'],
      success: json['success'] != 0,
      errorCode: json['error_code'],
      errorString: json['error_string'],
    );
  }
}

class BmReadRssiResult {
  final String remoteId;
  final int rssi;
  final bool success;
  final int? errorCode;
  final String? errorString;

  BmReadRssiResult({
    required this.remoteId,
    required this.rssi,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmReadRssiResult.fromMap(Map<dynamic, dynamic> json) {
    return BmReadRssiResult(
      remoteId: json['remote_id'],
      rssi: json['rssi'],
      success: json['success'] != 0,
      errorCode: json['error_code'],
      errorString: json['error_string'],
    );
  }
}

enum BmConnectionPriorityEnum{
  balanced, // 0 
  high, // 1
  lowPower, // 2
}

class BmConnectionPriorityRequest {
  final String remoteId;
  final BmConnectionPriorityEnum connectionPriority;

  BmConnectionPriorityRequest({
    required this.remoteId,
    required this.connectionPriority,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['connection_priority'] = connectionPriority.index;
    return data;
  }
}

class BmPreferredPhy {
  final String remoteId;
  final int txPhy;
  final int rxPhy;
  final int phyOptions;

  BmPreferredPhy({
    required this.remoteId,
    required this.txPhy,
    required this.rxPhy,
    required this.phyOptions,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['tx_phy'] = txPhy;
    data['rx_phy'] = rxPhy;
    data['phy_options'] = phyOptions;
    return data;
  }

  factory BmPreferredPhy.fromMap(Map<dynamic, dynamic> json) {
    return BmPreferredPhy(
      remoteId: json['remote_id'],
      txPhy: json['tx_phy'],
      rxPhy: json['rx_phy'],
      phyOptions: json['phy_options'],
    );
  }
}


enum BmBondStateEnum {
  none, // 0
  bonding, // 1
  bonded, // 2
  failed, // 3
  lost, // 4
}

class BmBondStateResponse {
  final String remoteId;
  final BmBondStateEnum bondState;

  BmBondStateResponse({
    required this.remoteId,
    required this.bondState,
  });

  factory BmBondStateResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmBondStateResponse(
      remoteId: json['remote_id'],
      bondState: BmBondStateEnum.values[json['bond_state']],
    );
  }
}