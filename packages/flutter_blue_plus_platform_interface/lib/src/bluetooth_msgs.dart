import 'dart:typed_data';

import 'device_identifier.dart';
import 'guid.dart';
import 'log_level.dart';

class BmBluetoothAdapterStateRequest {
  BmBluetoothAdapterStateRequest();
}

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

  factory BmBluetoothAdapterState.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothAdapterState(
      adapterState: BmAdapterStateEnum.values[json['adapter_state']],
    );
  }
}

class BmBluetoothAdapterNameRequest {
  BmBluetoothAdapterNameRequest();
}

class BmBluetoothAdapterName {
  String adapterName;

  BmBluetoothAdapterName({required this.adapterName});
}

class BmMsdFilter {
  int manufacturerId;
  List<int>? data;
  List<int>? mask;
  BmMsdFilter(this.manufacturerId, this.data, this.mask);
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> map = {};
    map['manufacturer_id'] = manufacturerId;
    map['data'] = Uint8List.fromList(data ?? []);
    map['mask'] = Uint8List.fromList(mask ?? []);
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
    map['data'] = Uint8List.fromList(data);
    map['mask'] = Uint8List.fromList(mask);
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
  final bool androidLegacy;
  final int androidScanMode;
  final bool androidUsesFineLocation;
  final List<Guid> webOptionalServices;

  BmScanSettings({
    required this.withServices,
    required this.withRemoteIds,
    required this.withNames,
    required this.withKeywords,
    required this.withMsd,
    required this.withServiceData,
    required this.continuousUpdates,
    required this.continuousDivisor,
    required this.androidLegacy,
    required this.androidScanMode,
    required this.androidUsesFineLocation,
    required this.webOptionalServices,
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
    data['android_legacy'] = androidLegacy;
    data['android_scan_mode'] = androidScanMode;
    data['android_uses_fine_location'] = androidUsesFineLocation;
    data['web_optional_services'] = webOptionalServices.map((s) => s.str).toList();;
    return data;
  }
}

class BmStopScanRequest {
  BmStopScanRequest();
}

class BmScanAdvertisement {
  final DeviceIdentifier remoteId;
  final String? platformName;
  final String? advName;
  final bool connectable;
  final int? txPowerLevel;
  final int? appearance; // not supported on iOS / macOS
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
    required this.appearance,
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
    rawManufacturerData.forEach((k, v) {
      manufacturerData[k] = v;
    });
    // Cast the data to the right type
    Map<Guid, List<int>> serviceData = {};
    rawServiceData.forEach((k, v) {
      serviceData[Guid(k)] = v;
    });
    // Cast the data to the right type
    List<Guid> serviceUuids = [];
    rawServiceUuids.forEach((e) => serviceUuids.add(Guid(e)));

    return BmScanAdvertisement(
      remoteId: DeviceIdentifier(json['remote_id']),
      platformName: json['platform_name'],
      advName: json['adv_name'],
      connectable: json['connectable'] != null ? json['connectable'] != 0 : false,
      txPowerLevel: json['tx_power_level'],
      appearance: json['appearance'],
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

    bool success = json['success'] == null || json['success'] != 0;

    return BmScanResponse(
      advertisements: advertisements,
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : "",
    );
  }
}

class BmConnectRequest {
  DeviceIdentifier remoteId;
  bool autoConnect;

  BmConnectRequest({
    required this.remoteId,
    required this.autoConnect,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId.str;
    data['auto_connect'] = autoConnect ? 1 : 0;
    return data;
  }
}

class BmDisconnectRequest {
  DeviceIdentifier remoteId;

  BmDisconnectRequest({
    required this.remoteId,
  });
}

class BmBluetoothDevice {
  DeviceIdentifier remoteId;
  String? platformName;

  BmBluetoothDevice({
    required this.remoteId,
    required this.platformName,
  });

  factory BmBluetoothDevice.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothDevice(
      remoteId: DeviceIdentifier(json['remote_id']),
      platformName: json['platform_name'],
    );
  }
}

class BmNameChanged {
  DeviceIdentifier remoteId;
  String name;

  BmNameChanged({
    required this.remoteId,
    required this.name,
  });

  factory BmNameChanged.fromMap(Map<dynamic, dynamic> json) {
    return BmNameChanged(
      remoteId: DeviceIdentifier(json['remote_id']),
      name: json['name'],
    );
  }
}

class BmBluetoothService {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? primaryServiceUuid;
  List<BmBluetoothCharacteristic> characteristics;

  BmBluetoothService({
    required this.serviceUuid,
    required this.remoteId,
    required this.characteristics,
    required this.primaryServiceUuid,
  });

  factory BmBluetoothService.fromMap(Map<dynamic, dynamic> json) {
    // convert characteristics
    List<BmBluetoothCharacteristic> chrs = [];
    for (var v in json['characteristics']) {
      chrs.add(BmBluetoothCharacteristic.fromMap(v));
    }

    return BmBluetoothService(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      primaryServiceUuid: Guid.parse(json['primary_service_uuid']),
      characteristics: chrs,
    );
  }
}

class BmBluetoothCharacteristic {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;
  List<BmBluetoothDescriptor> descriptors;
  BmCharacteristicProperties properties;


  BmBluetoothCharacteristic({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
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
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      characteristicUuid: Guid(json['characteristic_uuid']),
      primaryServiceUuid: Guid.parse(json['primary_service_uuid']),
      descriptors: descs,
      properties: BmCharacteristicProperties.fromMap(json['properties']),
    );
  }
}

class BmBluetoothDescriptor {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final Guid? primaryServiceUuid;

  BmBluetoothDescriptor({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.primaryServiceUuid,
  });

  factory BmBluetoothDescriptor.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothDescriptor(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
      primaryServiceUuid: Guid.parse(json['primary_service_uuid']),
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

class BmDiscoverServicesRequest {
  DeviceIdentifier remoteId;

  BmDiscoverServicesRequest({
    required this.remoteId,
  });
}

class BmDiscoverServicesResult {
  final DeviceIdentifier remoteId;
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
      remoteId: DeviceIdentifier(json['remote_id']),
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
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;

  BmReadCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    this.primaryServiceUuid,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId.str;
    data['service_uuid'] = serviceUuid.str;
    data['characteristic_uuid'] = characteristicUuid.str;
    data['primary_service_uuid'] = primaryServiceUuid?.str;
    data.removeWhere((key, value) => value == null);
    return data;
  }
}

class BmCharacteristicData {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;
  final List<int> value;
  final bool success;
  final int errorCode;
  final String errorString;


  BmCharacteristicData({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmCharacteristicData.fromMap(Map<dynamic, dynamic> json) {
    return BmCharacteristicData(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      characteristicUuid: Guid(json['characteristic_uuid']),
      primaryServiceUuid: Guid.parse(json['primary_service_uuid']),
      value: json['value'] as Uint8List,
      success: json['success'] != 0,
      errorCode: json['error_code'],
      errorString: json['error_string'],
    );
  }
}

class BmReadDescriptorRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final Guid? primaryServiceUuid;

  BmReadDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.primaryServiceUuid,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId.str;
    data['service_uuid'] = serviceUuid.str;
    data['characteristic_uuid'] = characteristicUuid.str;
    data['descriptor_uuid'] = descriptorUuid.str;
    data['primary_service_uuid'] = primaryServiceUuid?.str;
    data.removeWhere((key, value) => value == null);
    return data;
  }
}

enum BmWriteType {
  withResponse,
  withoutResponse,
}

class BmWriteCharacteristicRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;
  final BmWriteType writeType;
  final bool allowLongWrite;
  final List<int> value;


  BmWriteCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    required this.writeType,
    required this.allowLongWrite,
    required this.value,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId.str;
    data['service_uuid'] = serviceUuid.str;
    data['characteristic_uuid'] = characteristicUuid.str;
    data['primary_service_uuid'] = primaryServiceUuid?.str;
    data['write_type'] = writeType.index;
    data['allow_long_write'] = allowLongWrite ? 1 : 0;
    data['value'] = Uint8List.fromList(value);
    data.removeWhere((key, value) => value == null);
    return data;
  }
}

class BmWriteDescriptorRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;
  final Guid descriptorUuid;
  final List<int> value;

  BmWriteDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    required this.descriptorUuid,
    required this.value,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId.str;
    data['service_uuid'] = serviceUuid.str;
    data['characteristic_uuid'] = characteristicUuid.str;
    data['descriptor_uuid'] = descriptorUuid.str;
    data['primary_service_uuid'] = primaryServiceUuid?.str;
    data['value'] = Uint8List.fromList(value);
    data.removeWhere((key, value) => value == null);
    return data;
  }
}

class BmDescriptorData {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final Guid? primaryServiceUuid;
  final List<int> value;
  final bool success;
  final int errorCode;
  final String errorString;

  BmDescriptorData({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.primaryServiceUuid,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmDescriptorData.fromMap(Map<dynamic, dynamic> json) {
    return BmDescriptorData(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
      primaryServiceUuid: Guid.parse(json['primary_service_uuid']),
      value: json['value'] as Uint8List,
      success: json['success'] != 0,
      errorCode: json['error_code'],
      errorString: json['error_string'],
    );
  }
}

class BmSetNotifyValueRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid? primaryServiceUuid;
  final bool forceIndications;
  final bool enable;


  BmSetNotifyValueRequest({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.primaryServiceUuid,
    required this.forceIndications,
    required this.enable,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId.str;
    data['service_uuid'] = serviceUuid.str;
    data['characteristic_uuid'] = characteristicUuid.str;
    data['primary_service_uuid'] = primaryServiceUuid?.str;
    data['force_indications'] = forceIndications;
    data['enable'] = enable;
    data.removeWhere((key, value) => value == null);
    return data;
  }
}

enum BmConnectionStateEnum {
  disconnected, // 0
  connected, // 1
}

class BmConnectionStateResponse {
  final DeviceIdentifier remoteId;
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
      remoteId: DeviceIdentifier(json['remote_id']),
      connectionState: BmConnectionStateEnum.values[json['connection_state'] as int],
      disconnectReasonCode: json['disconnect_reason_code'],
      disconnectReasonString: json['disconnect_reason_string'],
    );
  }
}

class BmBondedDevicesRequest {
  BmBondedDevicesRequest();
}

class BmSystemDevicesRequest {
  final List<Guid> withServices;

  BmSystemDevicesRequest({
    required this.withServices,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['with_services'] = withServices.map((s) => s.str).toList();
    return data;
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
  final DeviceIdentifier remoteId;
  final int mtu;

  BmMtuChangeRequest({required this.remoteId, required this.mtu});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId.str;
    data['mtu'] = mtu;
    return data;
  }
}

class BmMtuChangedResponse {
  final DeviceIdentifier remoteId;
  final int mtu;
  final bool success;
  final int errorCode;
  final String errorString;

  BmMtuChangedResponse({
    required this.remoteId,
    required this.mtu,
    this.success = true,
    this.errorCode = 0,
    this.errorString = "",
  });

  factory BmMtuChangedResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmMtuChangedResponse(
      remoteId: DeviceIdentifier(json['remote_id']),
      mtu: json['mtu'],
      success: json['success'] != 0,
      errorCode: json['error_code'],
      errorString: json['error_string'],
    );
  }
}

class BmReadRssiRequest {
  DeviceIdentifier remoteId;

  BmReadRssiRequest({
    required this.remoteId,
  });
}

class BmReadRssiResult {
  final DeviceIdentifier remoteId;
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
      remoteId: DeviceIdentifier(json['remote_id']),
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
  final DeviceIdentifier remoteId;
  final BmConnectionPriorityEnum connectionPriority;

  BmConnectionPriorityRequest({
    required this.remoteId,
    required this.connectionPriority,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId.str;
    data['connection_priority'] = connectionPriority.index;
    return data;
  }
}

class BmPreferredPhy {
  final DeviceIdentifier remoteId;
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
    data['remote_id'] = remoteId.str;
    data['tx_phy'] = txPhy;
    data['rx_phy'] = rxPhy;
    data['phy_options'] = phyOptions;
    return data;
  }
}

class BmBondStateRequest {
  DeviceIdentifier remoteId;

  BmBondStateRequest({
    required this.remoteId,
  });
}

enum BmBondStateEnum {
  none, // 0
  bonding, // 1
  bonded, // 2
}

class BmBondStateResponse {
  final DeviceIdentifier remoteId;
  final BmBondStateEnum bondState;
  final BmBondStateEnum? prevState;

  BmBondStateResponse({
    required this.remoteId,
    required this.bondState,
    required this.prevState,
  });

  factory BmBondStateResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmBondStateResponse(
      remoteId: DeviceIdentifier(json['remote_id']),
      bondState: BmBondStateEnum.values[json['bond_state']],
      prevState: json['prev_state'] != null ? BmBondStateEnum.values[json['prev_state']] : null,
    );
  }
}

class BmCreateBondRequest {
  DeviceIdentifier remoteId;
  Uint8List? pin;

  BmCreateBondRequest({
    required this.remoteId,
    required this.pin,
  });
  
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId.str;
    data['pin'] = pin;
    return data;
  }
}

class BmRemoveBondRequest {
  DeviceIdentifier remoteId;

  BmRemoveBondRequest({
    required this.remoteId,
  });
}

class BmClearGattCacheRequest {
  DeviceIdentifier remoteId;

  BmClearGattCacheRequest({
    required this.remoteId,
  });
}

class BmDetachedFromEngineResponse {
  BmDetachedFromEngineResponse();
}

class BmTurnOffRequest {
  BmTurnOffRequest();
}

class BmTurnOnRequest {
  BmTurnOnRequest();
}

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

class BmSetLogLevelRequest {
  LogLevel logLevel;
  bool logColor;

  BmSetLogLevelRequest({
    this.logLevel = LogLevel.none,
    this.logColor = true,
  });
}

class BmSetOptionsRequest {
  bool showPowerAlert;
  bool restoreState;

  BmSetOptionsRequest({
    required this.showPowerAlert,
    required this.restoreState,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['show_power_alert'] = showPowerAlert;
    data['restore_state'] = restoreState;
    return data;
  }
}

class BmIsSupportedRequest {
  BmIsSupportedRequest();
}

class PhySupportRequest {
  PhySupportRequest();
}

class PhySupport {
  /// High speed (PHY 2M)
  final bool le2M;

  /// Long range (PHY codec)
  final bool leCoded;

  PhySupport({
    required this.le2M,
    required this.leCoded,
  });

  factory PhySupport.fromMap(Map<dynamic, dynamic> json) {
    return PhySupport(
      le2M: json['le_2M'],
      leCoded: json['le_coded'],
    );
  }
}

// random number defined by flutter blue plus.
// Ideally it should not conflict with iOS or Android error codes.
int bmUserCanceledErrorCode = 23789258;
