part of flutter_blue_plus;

void _printDbg(String s) {
  // ignore: avoid_print
  //print(s);
}

enum BmPowerEnum {
  unknown,
  unavailable,
  unauthorized,
  turningOn,
  on,
  turningOff,
  off,
}

class BmBluetoothPowerState {
  BmPowerEnum state;

  BmBluetoothPowerState({required this.state});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['state'] = state.index;
    _printDbg("\nBmBluetoothPowerState $data");
    return data;
  }

  factory BmBluetoothPowerState.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmBluetoothPowerState $json");
    return BmBluetoothPowerState(
      state: BmPowerEnum.values[json['state']],
    );
  }
}

class BmAdvertisementData {
  String localName;
  int? txPowerLevel;
  bool connectable;
  Map<int, List<int>> manufacturerData;
  Map<String, List<int>> serviceData;
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
    _printDbg("\nBmAdvertisementData $json");
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

    // Construct the BmAdvertisementData
    return BmAdvertisementData(
      localName: json['local_name'] ?? "",
      txPowerLevel: json['tx_power_level'],
      connectable: json['connectable'] != 0,
      manufacturerData: manufacturerData,
      serviceData: serviceData,
      serviceUuids: List<String>.from(rawServiceUuids),
    );
  }
}

class BmScanSettings {
  int androidScanMode;
  List<String> serviceUuids;
  bool allowDuplicates;
  List<String> macAddresses;

  BmScanSettings({
    required this.androidScanMode,
    required this.serviceUuids,
    required this.allowDuplicates,
    required this.macAddresses,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['android_scan_mode'] = androidScanMode;
    data['service_uuids'] = serviceUuids;
    data['allow_duplicates'] = allowDuplicates;
    data['mac_addresses'] = macAddresses;
    _printDbg("\nBmScanSettings $data");
    return data;
  }
}

class BmScanResult {
  BmBluetoothDevice device;
  BmAdvertisementData advertisementData;
  int rssi;

  BmScanResult({
    required this.device,
    required this.advertisementData,
    required this.rssi,
  });

  factory BmScanResult.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmScanResult $json");
    return BmScanResult(
      device: BmBluetoothDevice.fromMap(json['device']),
      advertisementData:
          BmAdvertisementData.fromMap(json['advertisement_data']),
      rssi: json['rssi'],
    );
  }
}

class BmConnectRequest {
  String remoteId;
  bool androidAutoConnect;

  BmConnectRequest({
    required this.remoteId,
    required this.androidAutoConnect,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['android_auto_connect'] = androidAutoConnect;
    _printDbg("\nBmConnectRequest $data");
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
  String? name;
  BmBluetoothSpecEnum type;

  BmBluetoothDevice({
    required this.remoteId,
    required this.name,
    required this.type,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['name'] = name;
    data['type'] = type.index;
    _printDbg("\nBmBluetoothDevice $data");
    return data;
  }

  factory BmBluetoothDevice.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmBluetoothDevice $json");
    return BmBluetoothDevice(
      remoteId: json['remote_id'],
      name: json['name'],
      type: BmBluetoothSpecEnum.values[json['type']],
    );
  }
}

class BmBluetoothService {
  String uuid;
  String remoteId;
  bool isPrimary;
  List<BmBluetoothCharacteristic> characteristics;
  List<BmBluetoothService> includedServices;

  BmBluetoothService({
    required this.uuid,
    required this.remoteId,
    required this.isPrimary,
    required this.characteristics,
    required this.includedServices,
  });

  factory BmBluetoothService.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmBluetoothService $json");
    return BmBluetoothService(
      uuid: json['uuid'],
      remoteId: json['remote_id'],
      isPrimary: json['is_primary'],
      characteristics: (json['characteristics'] as List<dynamic>)
          .map((v) => BmBluetoothCharacteristic.fromMap(v))
          .toList(),
      includedServices: (json['included_services'] as List<dynamic>)
          .map((v) => BmBluetoothService.fromMap(v))
          .toList(),
    );
  }
}

class BmBluetoothCharacteristic {
  String uuid;
  String remoteId;
  String serviceUuid;
  String? secondaryServiceUuid;
  List<BmBluetoothDescriptor> descriptors;
  BmCharacteristicProperties properties;
  List<int> value;

  BmBluetoothCharacteristic({
    required this.uuid,
    required this.remoteId,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.descriptors,
    required this.properties,
    required this.value,
  });

  factory BmBluetoothCharacteristic.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmBluetoothCharacteristic $json");
    return BmBluetoothCharacteristic(
      uuid: json['uuid'],
      remoteId: json['remote_id'],
      serviceUuid: json['service_uuid'],
      secondaryServiceUuid: json['secondary_service_uuid'],
      descriptors: (json['descriptors'] as List<dynamic>)
          .map((v) => BmBluetoothDescriptor.fromMap(v))
          .toList(),
      properties: BmCharacteristicProperties.fromMap(json['properties']),
      value: _hexDecode(json['value'] ?? ""),
    );
  }
}

class BmBluetoothDescriptor {
  final String uuid;
  final String remoteId;
  final String serviceUuid;
  final String characteristicUuid;
  final List<int> value;

  BmBluetoothDescriptor({
    required this.uuid,
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.value,
  });

  factory BmBluetoothDescriptor.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmBluetoothDescriptor $json");
    return BmBluetoothDescriptor(
      uuid: json['uuid'],
      remoteId: json['remote_id'],
      serviceUuid: json['service_uuid'],
      characteristicUuid: json['characteristic_uuid'],
      value: _hexDecode(json['value'] ?? ""),
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
    _printDbg("\nBmCharacteristicProperties $json");
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

  BmDiscoverServicesResult({required this.remoteId, required this.services});

  factory BmDiscoverServicesResult.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmDiscoverServicesResult $json");
    return BmDiscoverServicesResult(
      remoteId: json['remote_id'],
      services: (json['services'] as List<dynamic>)
          .map((e) => BmBluetoothService.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
    );
  }
}

class BmReadCharacteristicRequest {
  final String remoteId;
  final String characteristicUuid;
  final String serviceUuid;
  final String? secondaryServiceUuid;

  BmReadCharacteristicRequest({
    required this.remoteId,
    required this.characteristicUuid,
    required this.serviceUuid,
    this.secondaryServiceUuid,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['characteristic_uuid'] = characteristicUuid;
    data['service_uuid'] = serviceUuid;
    if (secondaryServiceUuid != null) {
      data['secondary_service_uuid'] = secondaryServiceUuid;
    }
    _printDbg("\nBmReadCharacteristicRequest $data");
    return data;
  }
}

class BmReadCharacteristicResponse {
  final String remoteId;
  final BmBluetoothCharacteristic characteristic;

  BmReadCharacteristicResponse(
      {required this.remoteId, required this.characteristic});

  factory BmReadCharacteristicResponse.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmReadCharacteristicResponse $json");
    return BmReadCharacteristicResponse(
        remoteId: json['remote_id'],
        characteristic:
            BmBluetoothCharacteristic.fromMap(json['characteristic']));
  }
}

class BmReadDescriptorRequest {
  final String remoteId;
  final String descriptorUuid;
  final String serviceUuid;
  final String? secondaryServiceUuid;
  final String characteristicUuid;

  BmReadDescriptorRequest({
    required this.remoteId,
    required this.descriptorUuid,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['descriptor_uuid'] = descriptorUuid;
    data['service_uuid'] = serviceUuid;
    if (secondaryServiceUuid != null) {
      data['secondary_service_uuid'] = secondaryServiceUuid;
    }
    data['characteristic_uuid'] = characteristicUuid;
    _printDbg("\nBmReadDescriptorRequest $data");
    return data;
  }

  factory BmReadDescriptorRequest.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmReadDescriptorRequest $json");
    return BmReadDescriptorRequest(
      remoteId: json['remote_id'],
      descriptorUuid: json['descriptor_uuid'],
      serviceUuid: json['service_uuid'],
      secondaryServiceUuid: json['secondary_service_uuid'],
      characteristicUuid: json['characteristic_uuid'],
    );
  }
}

class BmReadDescriptorResponse {
  final BmReadDescriptorRequest request;
  final List<int> value;

  BmReadDescriptorResponse({required this.request, required this.value});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['request'] = request.toMap();
    data['value'] = value;
    _printDbg("\nBmReadDescriptorResponse $data");
    return data;
  }

  factory BmReadDescriptorResponse.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmReadDescriptorResponse $json");
    return BmReadDescriptorResponse(
      request: BmReadDescriptorRequest.fromMap(json['request']),
      value: _hexDecode(json['value'] ?? ""),
    );
  }
}

enum BmWriteType {
  withResponse,
  withoutResponse,
}

class BmWriteCharacteristicRequest {
  final String remoteId;
  final String characteristicUuid;
  final String serviceUuid;
  final String? secondaryServiceUuid;
  final BmWriteType writeType;
  final List<int> value;

  BmWriteCharacteristicRequest({
    required this.remoteId,
    required this.characteristicUuid,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.writeType,
    required this.value,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['characteristic_uuid'] = characteristicUuid;
    data['service_uuid'] = serviceUuid;
    if (secondaryServiceUuid != null) {
      data['secondary_service_uuid'] = secondaryServiceUuid;
    }
    data['write_type'] = writeType.index;
    data['value'] = _hexEncode(value);
    _printDbg("\nBmWriteCharacteristicRequest $data");
    return data;
  }

  factory BmWriteCharacteristicRequest.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmWriteCharacteristicRequest $json");
    return BmWriteCharacteristicRequest(
      remoteId: json['remote_id'],
      characteristicUuid: json['characteristic_uuid'],
      serviceUuid: json['service_uuid'],
      secondaryServiceUuid: json['secondary_service_uuid'],
      writeType: BmWriteType.values[json['write_type'] as int],
      value: _hexDecode(json['value'] ?? ""),
    );
  }
}

class BmWriteCharacteristicResponse {
  final BmWriteCharacteristicRequest request;
  final bool success;

  BmWriteCharacteristicResponse({required this.request, required this.success});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['request'] = request.toMap();
    data['success'] = success;
    _printDbg("\nBmWriteCharacteristicResponse $data");
    return data;
  }

  factory BmWriteCharacteristicResponse.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmWriteCharacteristicResponse $json");
    return BmWriteCharacteristicResponse(
      request: BmWriteCharacteristicRequest.fromMap(json['request']),
      success: json['success'] != 0,
    );
  }
}

class BmWriteDescriptorRequest {
  final String remoteId;
  final String descriptorUuid;
  final String serviceUuid;
  final String? secondaryServiceUuid;
  final String characteristicUuid;
  final List<int> value;

  BmWriteDescriptorRequest({
    required this.remoteId,
    required this.descriptorUuid,
    required this.serviceUuid,
    required this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.value,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['descriptor_uuid'] = descriptorUuid;
    data['service_uuid'] = serviceUuid;
    if (secondaryServiceUuid != null) {
      data['secondary_service_uuid'] = secondaryServiceUuid;
    }
    data['characteristic_uuid'] = characteristicUuid;
    data['value'] = _hexEncode(value);
    _printDbg("\nBmWriteDescriptorRequest $data");
    return data;
  }

  factory BmWriteDescriptorRequest.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmWriteDescriptorRequest $json");
    return BmWriteDescriptorRequest(
      remoteId: json['remote_id'],
      descriptorUuid: json['descriptor_uuid'],
      serviceUuid: json['service_uuid'],
      secondaryServiceUuid: json['secondary_service_uuid'],
      characteristicUuid: json['characteristic_uuid'],
      value: _hexDecode(json['value'] ?? ""),
    );
  }
}

class BmWriteDescriptorResponse {
  final BmWriteDescriptorRequest request;
  final bool success;

  BmWriteDescriptorResponse({required this.request, required this.success});

  factory BmWriteDescriptorResponse.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmWriteDescriptorResponse $json");
    return BmWriteDescriptorResponse(
      request: BmWriteDescriptorRequest.fromMap(json['request']),
      success: json['success'] != 0,
    );
  }
}

class BmSetNotificationRequest {
  final String remoteId;
  final String serviceUuid;
  final String? secondaryServiceUuid;
  final String characteristicUuid;
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
    data['service_uuid'] = serviceUuid;
    if (secondaryServiceUuid != null) {
      data['secondary_service_uuid'] = secondaryServiceUuid;
    }
    data['characteristic_uuid'] = characteristicUuid;
    data['enable'] = enable;
    _printDbg("BmSetNotificationRequest $data");
    return data;
  }
}

class BmSetNotificationResponse {
  final String remoteId;
  final BmBluetoothCharacteristic characteristic;
  final bool success;

  BmSetNotificationResponse({
    required this.remoteId,
    required this.characteristic,
    required this.success,
  });

  factory BmSetNotificationResponse.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmSetNotificationResponse $json");
    return BmSetNotificationResponse(
      remoteId: json['remote_id'],
      characteristic: BmBluetoothCharacteristic.fromMap(json['characteristic']),
      success: json['success'] != 0,
    );
  }
}

class BmOnCharacteristicChanged {
  final String remoteId;
  final BmBluetoothCharacteristic characteristic;

  BmOnCharacteristicChanged(
      {required this.remoteId, required this.characteristic});

  factory BmOnCharacteristicChanged.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmOnCharacteristicChanged $json");
    return BmOnCharacteristicChanged(
      remoteId: json['remote_id'],
      characteristic: BmBluetoothCharacteristic.fromMap(json['characteristic']),
    );
  }
}

enum BmConnectionStateEnum {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

class BmConnectionStateResponse {
  final String remoteId;
  final BmConnectionStateEnum state;

  BmConnectionStateResponse({required this.remoteId, required this.state});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['state'] = state.index;
    _printDbg("\nBmConnectionStateResponse $data");
    return data;
  }

  factory BmConnectionStateResponse.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmConnectionStateResponse $json");
    return BmConnectionStateResponse(
      remoteId: json['remote_id'],
      state: BmConnectionStateEnum.values[json['state'] as int],
    );
  }
}

class BmConnectedDevicesResponse {
  final List<BmBluetoothDevice> devices;

  BmConnectedDevicesResponse({required this.devices});

  factory BmConnectedDevicesResponse.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmConnectedDevicesResponse $json");
    return BmConnectedDevicesResponse(
        devices: (json['devices'] as List)
            .map((i) => BmBluetoothDevice.fromMap(i))
            .toList());
  }
}

class BmMtuSizeRequest {
  final String remoteId;
  final int mtu;

  BmMtuSizeRequest({required this.remoteId, required this.mtu});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['mtu'] = mtu;
    _printDbg("\nBmMtuSizeRequest $data");
    return data;
  }
}

class BmMtuSizeResponse {
  final String remoteId;
  final int mtu;

  BmMtuSizeResponse({required this.remoteId, required this.mtu});

  factory BmMtuSizeResponse.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmMtuSizeResponse $json");
    return BmMtuSizeResponse(
      remoteId: json['remote_id'],
      mtu: json['mtu'],
    );
  }
}

class BmReadRssiResult {
  final String remoteId;
  final int rssi;

  BmReadRssiResult({required this.remoteId, required this.rssi});

  factory BmReadRssiResult.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmReadRssiResult $json");
    return BmReadRssiResult(
      remoteId: json['remote_id'],
      rssi: json['rssi'],
    );
  }
}

class BmConnectionPriorityRequest {
  final String remoteId;
  final int connectionPriority;

  BmConnectionPriorityRequest(
      {required this.remoteId, required this.connectionPriority});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['connectionPriority'] = connectionPriority;
    _printDbg("\nBmConnectionPriorityRequest $data");
    return data;
  }
}

class BmPreferredPhy {
  final String remoteId;
  final int txPhy;
  final int rxPhy;
  final int phyOptions;

  BmPreferredPhy(
      {required this.remoteId,
      required this.txPhy,
      required this.rxPhy,
      required this.phyOptions});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['txPhy'] = txPhy;
    data['rxPhy'] = rxPhy;
    data['phyOptions'] = phyOptions;
    _printDbg("\nBmPreferredPhy $data");
    return data;
  }

  factory BmPreferredPhy.fromMap(Map<dynamic, dynamic> json) {
    _printDbg("\nBmPreferredPhy $json");
    return BmPreferredPhy(
      remoteId: json['remote_id'],
      txPhy: json['txPhy'],
      rxPhy: json['rxPhy'],
      phyOptions: json['phyOptions'],
    );
  }
}
