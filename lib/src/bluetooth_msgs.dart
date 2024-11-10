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

  Map<dynamic, dynamic> toMap() => {
        'adapter_state': adapterState.index,
      };

  factory BmBluetoothAdapterState.fromMap(Map<dynamic, dynamic> json) => BmBluetoothAdapterState(
        adapterState: BmAdapterStateEnum.values[json['adapter_state']],
      );
}

class BmMsdFilter {
  int manufacturerId;
  List<int>? data;
  List<int>? mask;
  BmMsdFilter(this.manufacturerId, this.data, this.mask);
  Map<dynamic, dynamic> toMap() => {
        'manufacturer_id': manufacturerId,
        'data': _hexEncode(data ?? []),
        'mask': _hexEncode(mask ?? []),
      };
}

class BmServiceDataFilter {
  Guid service;
  List<int> data;
  List<int> mask;
  BmServiceDataFilter(this.service, this.data, this.mask);
  Map<dynamic, dynamic> toMap() => {
        'service': service.str,
        'data': _hexEncode(data),
        'mask': _hexEncode(mask),
      };
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
  });

  Map<dynamic, dynamic> toMap() => {
        'with_services': withServices.map((s) => s.str).toList(),
        'with_remote_ids': withRemoteIds,
        'with_names': withNames,
        'with_keywords': withKeywords,
        'with_msd': withMsd.map((d) => d.toMap()).toList(),
        'with_service_data': withServiceData.map((d) => d.toMap()).toList(),
        'continuous_updates': continuousUpdates,
        'continuous_divisor': continuousDivisor,
        'android_legacy': androidLegacy,
        'android_scan_mode': androidScanMode,
        'android_uses_fine_location': androidUsesFineLocation,
      };
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

  factory BmScanAdvertisement.fromMap(Map<dynamic, dynamic> json) => BmScanAdvertisement(
        remoteId: DeviceIdentifier(json['remote_id']),
        platformName: json['platform_name'],
        advName: json['adv_name'],
        connectable: json['connectable'] != null ? json['connectable'] != 0 : false,
        txPowerLevel: json['tx_power_level'],
        appearance: json['appearance'],
        manufacturerData:
            json['manufacturer_data']?.map<int, List<int>>((key, value) => MapEntry(key as int, _hexDecode(value))) ??
                {},
        serviceData:
            json['service_data']?.map<Guid, List<int>>((key, value) => MapEntry(Guid(key), _hexDecode(value))) ?? {},
        serviceUuids: json['service_uuids']?.map((v) => Guid(v)).toList() ?? [],
        rssi: json['rssi'] ?? 0,
      );
}

class BmStatus {
  final bool success;
  final int errorCode;
  final String errorString;

  BmStatus({
    this.success = true,
    this.errorCode = 0,
    this.errorString = "",
  });

  BmStatus.fromMap(Map<dynamic, dynamic> json)
      : success = json['success'] != 0,
        errorCode = json['error_code'] ?? 0,
        errorString = json['error_string'] ?? "";
}

class BmScanResponse extends BmStatus {
  final List<BmScanAdvertisement> advertisements;

  BmScanResponse.fromMap(Map<dynamic, dynamic> json)
      : advertisements = json['advertisements']
            .map<BmScanAdvertisement>((v) => BmScanAdvertisement.fromMap(v as Map<dynamic, dynamic>))
            .toList(),
        super.fromMap(json);
}

class BmConnectRequest {
  DeviceIdentifier remoteId;
  bool autoConnect;

  BmConnectRequest({
    required this.remoteId,
    required this.autoConnect,
  });

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'auto_connect': autoConnect ? 1 : 0,
      };
}

class BmBluetoothDevice {
  DeviceIdentifier remoteId;
  String? platformName;

  BmBluetoothDevice({
    required this.remoteId,
    required this.platformName,
  });

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'platform_name': platformName,
      };

  factory BmBluetoothDevice.fromMap(Map<dynamic, dynamic> json) => BmBluetoothDevice(
        remoteId: DeviceIdentifier(json['remote_id']),
        platformName: json['platform_name'],
      );
}

class BmNameChanged {
  DeviceIdentifier remoteId;
  String name;

  BmNameChanged({
    required this.remoteId,
    required this.name,
  });

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'name': name,
      };

  factory BmNameChanged.fromMap(Map<dynamic, dynamic> json) => BmNameChanged(
        remoteId: DeviceIdentifier(json['remote_id']),
        name: json['name'],
      );
}

class BmBluetoothService {
  final Guid uuid;
  final int index;
  final bool isPrimary;
  List<BmBluetoothCharacteristic> characteristics;
  List<String> includedServices;

  BmBluetoothService.fromMap(Map<dynamic, dynamic> json)
      : uuid = Guid(json['uuid']),
        index = json['index'],
        isPrimary = json['primary'] != 0,
        characteristics = (json['characteristics'] as List<dynamic>)
            .map<BmBluetoothCharacteristic>((v) => BmBluetoothCharacteristic.fromMap(v))
            .toList(),
        includedServices = (json['included_services'] as List<dynamic>).map((v) => v as String).toList();
}

class BmBluetoothCharacteristic {
  final Guid uuid;
  final int index;
  List<BmBluetoothDescriptor> descriptors;
  BmCharacteristicProperties properties;

  BmBluetoothCharacteristic.fromMap(Map<dynamic, dynamic> json)
      : uuid = Guid(json['uuid']),
        index = json['index'],
        descriptors = (json['descriptors'] as List<dynamic>).map((v) => BmBluetoothDescriptor.fromMap(v)).toList(),
        properties = BmCharacteristicProperties.fromMap(json['properties']);
}

class BmBluetoothDescriptor {
  final Guid uuid;

  BmBluetoothDescriptor.fromMap(Map<dynamic, dynamic> json) : uuid = Guid(json['uuid']);
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

  BmCharacteristicProperties.fromMap(Map<dynamic, dynamic> json)
      : broadcast = json['broadcast'] != 0,
        read = json['read'] != 0,
        writeWithoutResponse = json['write_without_response'] != 0,
        write = json['write'] != 0,
        notify = json['notify'] != 0,
        indicate = json['indicate'] != 0,
        authenticatedSignedWrites = json['authenticated_signed_writes'] != 0,
        extendedProperties = json['extended_properties'] != 0,
        notifyEncryptionRequired = json['notify_encryption_required'] != 0,
        indicateEncryptionRequired = json['indicate_encryption_required'] != 0;
}

class BmDiscoverServicesResult extends BmStatus {
  final DeviceIdentifier remoteId;
  final List<BmBluetoothService> services;

  BmDiscoverServicesResult.fromMap(Map<dynamic, dynamic> json)
      : remoteId = DeviceIdentifier(json['remote_id']),
        services = (json['services'] as List<dynamic>)
            .map((e) => BmBluetoothService.fromMap(e as Map<dynamic, dynamic>))
            .toList(),
        super.fromMap(json);
}

class BmReadCharacteristicRequest {
  final DeviceIdentifier remoteId;
  final String identifier;

  BmReadCharacteristicRequest({
    required this.remoteId,
    required this.identifier,
  });

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'identifier': identifier,
      };
}

class BmCharacteristicData extends BmStatus {
  final DeviceIdentifier remoteId;
  final String identifier;
  final List<int> value;

  BmCharacteristicData.fromMap(Map<dynamic, dynamic> json)
      : remoteId = DeviceIdentifier(json['remote_id']),
        identifier = json['identifier'],
        value = _hexDecode(json['value']),
        super.fromMap(json);
}

class BmReadDescriptorRequest {
  final DeviceIdentifier remoteId;
  final String identifier;

  BmReadDescriptorRequest({
    required this.remoteId,
    required this.identifier,
  });

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'identifier': identifier,
      };
}

enum BmWriteType {
  withResponse,
  withoutResponse,
}

class BmWriteCharacteristicRequest {
  final DeviceIdentifier remoteId;
  final String identifier;
  final BmWriteType writeType;
  final bool allowLongWrite;
  final List<int> value;

  BmWriteCharacteristicRequest({
    required this.remoteId,
    required this.identifier,
    required this.writeType,
    required this.allowLongWrite,
    required this.value,
  });

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'identifier': identifier,
        'write_type': writeType.index,
        'allow_long_write': allowLongWrite ? 1 : 0,
        'value': _hexEncode(value),
      };
}

class BmWriteDescriptorRequest {
  final DeviceIdentifier remoteId;
  final String identifier;
  final List<int> value;

  BmWriteDescriptorRequest({
    required this.remoteId,
    required this.identifier,
    required this.value,
  });

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'identifier': identifier,
        'value': _hexEncode(value),
      };
}

class BmDescriptorData extends BmStatus {
  final DeviceIdentifier remoteId;
  final String identifier;
  final List<int> value;

  BmDescriptorData.fromMap(Map<dynamic, dynamic> json)
      : remoteId = DeviceIdentifier(json['remote_id']),
        identifier = json['identifier'],
        value = _hexDecode(json['value']),
        super.fromMap(json);
}

class BmSetNotifyValueRequest {
  final DeviceIdentifier remoteId;
  final String identifier;
  final bool forceIndications;
  final bool enable;

  BmSetNotifyValueRequest({
    required this.remoteId,
    required this.identifier,
    required this.forceIndications,
    required this.enable,
  });

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'identifier': identifier,
        'force_indications': forceIndications,
        'enable': enable,
      };
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

  factory BmConnectionStateResponse.fromMap(Map<dynamic, dynamic> json) => BmConnectionStateResponse(
        remoteId: DeviceIdentifier(json['remote_id']),
        connectionState: BmConnectionStateEnum.values[json['connection_state'] as int],
        disconnectReasonCode: json['disconnect_reason_code'],
        disconnectReasonString: json['disconnect_reason_string'],
      );
}

class BmDevicesList {
  final List<BmBluetoothDevice> devices;

  BmDevicesList({required this.devices});

  factory BmDevicesList.fromMap(Map<dynamic, dynamic> json) =>
      BmDevicesList(devices: json['devices'].map(BmBluetoothDevice.fromMap).toList());
}

class BmMtuChangeRequest {
  final DeviceIdentifier remoteId;
  final int mtu;

  BmMtuChangeRequest({required this.remoteId, required this.mtu});

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'mtu': mtu,
      };
}

class BmMtuChangedResponse extends BmStatus {
  final DeviceIdentifier remoteId;
  final int mtu;

  BmMtuChangedResponse({
    required this.remoteId,
    required this.mtu,
  }) : super();

  BmMtuChangedResponse.fromMap(Map<dynamic, dynamic> json)
      : remoteId = DeviceIdentifier(json['remote_id']),
        mtu = json['mtu'],
        super.fromMap(json);

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'mtu': mtu,
        'success': success ? 1 : 0,
        'error_code': errorCode,
        'error_string': errorString,
      };
}

class BmReadRssiResult extends BmStatus {
  final DeviceIdentifier remoteId;
  final int rssi;

  BmReadRssiResult.fromMap(Map<dynamic, dynamic> json)
      : remoteId = DeviceIdentifier(json['remote_id']),
        rssi = json['rssi'],
        super.fromMap(json);
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

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'connection_priority': connectionPriority.index,
      };
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

  Map<dynamic, dynamic> toMap() => {
        'remote_id': remoteId.str,
        'tx_phy': txPhy,
        'rx_phy': rxPhy,
        'phy_options': phyOptions,
      };

  factory BmPreferredPhy.fromMap(Map<dynamic, dynamic> json) => BmPreferredPhy(
        remoteId: DeviceIdentifier(json['remote_id']),
        txPhy: json['tx_phy'],
        rxPhy: json['rx_phy'],
        phyOptions: json['phy_options'],
      );
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

  BmBondStateResponse.fromMap(Map<dynamic, dynamic> json)
      : remoteId = DeviceIdentifier(json['remote_id']),
        bondState = BmBondStateEnum.values[json['bond_state']],
        prevState = json['prev_state'] != null ? BmBondStateEnum.values[json['prev_state']] : null;
}

// BmTurnOnResponse
class BmTurnOnResponse {
  bool userAccepted;

  BmTurnOnResponse.fromMap(Map<dynamic, dynamic> json) : userAccepted = json['user_accepted'] != 0;
}

// random number defined by flutter blue plus.
// Ideally it should not conflict with iOS or Android error codes.
int bmUserCanceledErrorCode = 23789258;
