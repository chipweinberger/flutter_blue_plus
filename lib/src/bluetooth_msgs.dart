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

class BmMsdFilter {
  int manufacturerId;
  List<int>? data;
  List<int>? mask;
  BmMsdFilter(this.manufacturerId, this.data, this.mask);
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> map = {};
    map['manufacturer_id'] = manufacturerId;
    map['data'] = _hexEncode(data ?? []);
    map['mask'] = _hexEncode(mask ?? []);
    return map;
  }
}

class BmServiceDataFilter {
  Guid service;
  List<int> data;
  List<int> mask;
  BmServiceDataFilter(this.service, this.data, this.mask);
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> map = {};
    map['service'] = service.str;
    map['data'] = _hexEncode(data);
    map['mask'] = _hexEncode(mask);
    return map;
  }
}

class BmScanSettings {
  final List<Guid> withServices;
  final List<String> withRemoteIds;
  final List<String> withNames;
  final List<String> withKeywords;
  final List<BmMsdFilter> withMsd;
  final List<BmServiceDataFilter> withServiceData;
  final bool continuousUpdates;
  final int continuousDivisor;
  final int androidScanMode;
  final bool androidUsesFineLocation;

  BmScanSettings({
    required this.withServices,
    required this.withRemoteIds,
    required this.withNames,
    required this.withKeywords,
    required this.withMsd,
    required this.withServiceData,
    required this.continuousUpdates,
    required this.continuousDivisor,
    required this.androidScanMode,
    required this.androidUsesFineLocation,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['with_services'] = withServices.map((s) => s.str).toList();
    data['with_remote_ids'] = withRemoteIds;
    data['with_names'] = withNames;
    data['with_keywords'] = withKeywords;
    data['with_msd'] = withMsd.map((d) => d.toMap()).toList();
    data['with_service_data'] = withServiceData.map((d) => d.toMap()).toList();
    data['continuous_updates'] = continuousUpdates;
    data['continuous_divisor'] = continuousDivisor;
    data['android_scan_mode'] = androidScanMode;
    data['android_uses_fine_location'] = androidUsesFineLocation;
    return data;
  }
}

class BmScanAdvertisement {
  final String remoteId;
  final String? platformName;
  final String? advName;
  final bool connectable;
  final int? txPowerLevel;
  final Map<int, List<int>> manufacturerData;
  final Map<Guid, List<int>> serviceData;
  final List<Guid> serviceUuids;
  final int rssi;

  BmScanAdvertisement({
    required this.remoteId,
    required this.platformName,
    required this.advName,
    required this.connectable,
    required this.txPowerLevel,
    required this.manufacturerData,
    required this.serviceData,
    required this.serviceUuids,
    required this.rssi,
  });

  factory BmScanAdvertisement.fromMap(Map<dynamic, dynamic> json) {
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
    Map<Guid, List<int>> serviceData = {};
    for (var key in rawServiceData.keys) {
      serviceData[Guid(key)] = _hexDecode(rawServiceData[key]);
    }

    // Cast the data to the right type
    List<Guid> serviceUuids = [];
    for (var val in rawServiceUuids) {
      serviceUuids.add(Guid(val));
    }

    return BmScanAdvertisement(
      remoteId: json['remote_id'],
      platformName: json['platform_name'],
      advName: json['adv_name'],
      connectable: json['connectable'] != null ? json['connectable'] != 0 : false,
      txPowerLevel: json['tx_power_level'],
      manufacturerData: manufacturerData,
      serviceData: serviceData,
      serviceUuids: serviceUuids,
      rssi: json['rssi'] != null ? json['rssi'] : 0,
    );
  }
}

class BmScanResponse {
  final List<BmScanAdvertisement> advertisements;
  final bool success;
  final int errorCode;
  final String errorString;

  BmScanResponse({
    required this.advertisements,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmScanResponse.fromMap(Map<dynamic, dynamic> json) {
    List<BmScanAdvertisement> advertisements = [];
    for (var item in json['advertisements']) {
      advertisements.add(BmScanAdvertisement.fromMap(item));
    }

    bool success = json['success'] == null || json['success'] == 0;

    return BmScanResponse(
      advertisements: advertisements,
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : "",
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

class BmBluetoothDevice {
  String remoteId;
  String? platformName;

  BmBluetoothDevice({
    required this.remoteId,
    required this.platformName,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['platform_name'] = platformName;
    return data;
  }

  factory BmBluetoothDevice.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothDevice(
      remoteId: json['remote_id'],
      platformName: json['platform_name'],
    );
  }
}

class BmNameChanged {
  String remoteId;
  String name;

  BmNameChanged({
    required this.remoteId,
    required this.name,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['name'] = name;
    return data;
  }

  factory BmNameChanged.fromMap(Map<dynamic, dynamic> json) {
    return BmNameChanged(
      remoteId: json['remote_id'],
      name: json['name'],
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

  BmBluetoothCharacteristic({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptors,
    required this.properties,
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
    );
  }
}

class BmBluetoothDescriptor {
  final String remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;

  BmBluetoothDescriptor({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
  });

  factory BmBluetoothDescriptor.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothDescriptor(
      remoteId: json['remote_id'],
      serviceUuid: Guid(json['service_uuid']),
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
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
  final int errorCode;
  final String errorString;

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
    data['service_uuid'] = serviceUuid.str;
    data['secondary_service_uuid'] = secondaryServiceUuid?.str;
    data['characteristic_uuid'] = characteristicUuid.str;
    return data;
  }
}

class BmCharacteristicData {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final List<int> value;
  final bool success;
  final int errorCode;
  final String errorString;

  BmCharacteristicData({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmCharacteristicData.fromMap(Map<dynamic, dynamic> json) {
    return BmCharacteristicData(
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
    data['service_uuid'] = serviceUuid.str;
    data['secondary_service_uuid'] = secondaryServiceUuid?.str;
    data['characteristic_uuid'] = characteristicUuid.str;
    data['descriptor_uuid'] = descriptorUuid.str;
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
  final bool allowLongWrite;
  final List<int> value;

  BmWriteCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.writeType,
    required this.allowLongWrite,
    required this.value,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['service_uuid'] = serviceUuid.str;
    data['secondary_service_uuid'] = secondaryServiceUuid?.str;
    data['characteristic_uuid'] = characteristicUuid.str;
    data['write_type'] = writeType.index;
    data['allow_long_write'] = allowLongWrite ? 1 : 0;
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
    data['service_uuid'] = serviceUuid.str;
    data['secondary_service_uuid'] = secondaryServiceUuid?.str;
    data['characteristic_uuid'] = characteristicUuid.str;
    data['descriptor_uuid'] = descriptorUuid.str;
    data['value'] = _hexEncode(value);
    return data;
  }
}

class BmDescriptorData {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final List<int> value;
  final bool success;
  final int errorCode;
  final String errorString;

  BmDescriptorData({
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

  factory BmDescriptorData.fromMap(Map<dynamic, dynamic> json) {
    return BmDescriptorData(
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

class BmSetNotifyValueRequest {
  final String remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final bool forceIndications;
  final bool enable;

  BmSetNotifyValueRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.forceIndications,
    required this.enable,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['service_uuid'] = serviceUuid.str;
    data['secondary_service_uuid'] = secondaryServiceUuid?.str;
    data['characteristic_uuid'] = characteristicUuid.str;
    data['force_indications'] = forceIndications;
    data['enable'] = enable;
    return data;
  }
}

enum BmConnectionStateEnum {
  disconnected, // 0
  connected, // 1
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

class BmDevicesList {
  final List<BmBluetoothDevice> devices;

  BmDevicesList({required this.devices});

  factory BmDevicesList.fromMap(Map<dynamic, dynamic> json) {
    // convert to BmBluetoothDevice
    List<BmBluetoothDevice> devices = [];
    for (var i = 0; i < json['devices'].length; i++) {
      devices.add(BmBluetoothDevice.fromMap(json['devices'][i]));
    }
    return BmDevicesList(devices: devices);
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
  final int errorCode;
  final String errorString;

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
  final int errorCode;
  final String errorString;

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

enum BmConnectionPriorityEnum {
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
}

class BmBondStateResponse {
  final String remoteId;
  final BmBondStateEnum bondState;
  final BmBondStateEnum? prevState;

  BmBondStateResponse({
    required this.remoteId,
    required this.bondState,
    required this.prevState,
  });

  factory BmBondStateResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmBondStateResponse(
      remoteId: json['remote_id'],
      bondState: BmBondStateEnum.values[json['bond_state']],
      prevState: json['prev_state'] != null ? BmBondStateEnum.values[json['prev_state']] : null,
    );
  }
}

// BmTurnOnResponse
class BmTurnOnResponse {
  bool userAccepted;

  BmTurnOnResponse({
    required this.userAccepted,
  });

  factory BmTurnOnResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmTurnOnResponse(
      userAccepted: json['user_accepted'],
    );
  }
}
