import 'dart:collection';

import '../utils/utils.dart';
import 'device_identifier.dart';
import 'guid.dart';

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

  BmBluetoothAdapterState({
    required this.adapterState,
  });

  factory BmBluetoothAdapterState.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBluetoothAdapterState(
      adapterState: BmAdapterStateEnum.values[json['adapter_state'] as int],
    );
  }

  @override
  int get hashCode {
    return adapterState.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmBluetoothAdapterState && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'adapter_state': adapterState.index,
    };
  }
}

class BmBluetoothCharacteristic {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  List<BmBluetoothDescriptor> descriptors;
  BmCharacteristicProperties properties;

  BmBluetoothCharacteristic({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptors,
    required this.properties,
  });

  factory BmBluetoothCharacteristic.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBluetoothCharacteristic(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptors: (json['descriptors'] as List<dynamic>?)
              ?.map((descriptor) => BmBluetoothDescriptor.fromMap(descriptor))
              .toList() ??
          [],
      properties: json['properties'] != null
          ? BmCharacteristicProperties.fromMap(json['properties'])
          : BmCharacteristicProperties(
              broadcast: false,
              read: false,
              writeWithoutResponse: false,
              write: false,
              notify: false,
              indicate: false,
              authenticatedSignedWrites: false,
              extendedProperties: false,
              notifyEncryptionRequired: false,
              indicateEncryptionRequired: false,
            ),
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        const ListEquality<BmBluetoothDescriptor>().hash(descriptors) ^
        properties.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmBluetoothCharacteristic && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'descriptors':
          descriptors.map((descriptor) => descriptor.toMap()).toList(),
      'properties': properties.toMap(),
    };
  }
}

class BmBluetoothDescriptor {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;

  BmBluetoothDescriptor({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
  });

  factory BmBluetoothDescriptor.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBluetoothDescriptor(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        characteristicUuid.hashCode ^
        descriptorUuid.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmBluetoothDescriptor && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'characteristic_uuid': characteristicUuid.str,
      'descriptor_uuid': descriptorUuid.str,
    };
  }
}

class BmBluetoothDevice {
  DeviceIdentifier remoteId;
  String? platformName;

  BmBluetoothDevice({
    required this.remoteId,
    this.platformName,
  });

  factory BmBluetoothDevice.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBluetoothDevice(
      remoteId: DeviceIdentifier(json['remote_id']),
      platformName: json['platform_name'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'platform_name': platformName,
    };
  }
}

class BmBluetoothService {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  bool isPrimary;
  List<BmBluetoothCharacteristic> characteristics;
  List<BmBluetoothService> includedServices;

  BmBluetoothService({
    required this.remoteId,
    required this.serviceUuid,
    required this.isPrimary,
    required this.characteristics,
    required this.includedServices,
  });

  factory BmBluetoothService.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBluetoothService(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      isPrimary: json['is_primary'] == 1,
      characteristics: (json['characteristics'] as List<dynamic>?)
              ?.map((characteristic) =>
                  BmBluetoothCharacteristic.fromMap(characteristic))
              .toList() ??
          [],
      includedServices: (json['included_services'] as List<dynamic>?)
              ?.map((includedService) =>
                  BmBluetoothService.fromMap(includedService))
              .toList() ??
          [],
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        isPrimary.hashCode ^
        const ListEquality<BmBluetoothCharacteristic>().hash(characteristics) ^
        const ListEquality<BmBluetoothService>().hash(includedServices);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmBluetoothService && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'is_primary': isPrimary ? 1 : 0,
      'characteristics': characteristics
          .map((characteristic) => characteristic.toMap())
          .toList(),
      'included_services': includedServices
          .map((includedService) => includedService.toMap())
          .toList(),
    };
  }
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
    this.prevState,
  });

  factory BmBondStateResponse.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmBondStateResponse(
      remoteId: DeviceIdentifier(json['remote_id']),
      bondState: BmBondStateEnum.values[json['bond_state'] as int],
      prevState: json['prev_state'] != null
          ? BmBondStateEnum.values[json['prev_state'] as int]
          : null,
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'bond_state': bondState.index,
      'prev_state': prevState?.index,
    };
  }
}

class BmCharacteristicData {
  final DeviceIdentifier remoteId;
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
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmCharacteristicData.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmCharacteristicData(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      value: json['value'] != null ? hex.decode(json['value']) : [],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        const ListEquality<int>().hash(value) ^
        success.hashCode ^
        errorCode.hashCode ^
        errorString.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmCharacteristicData && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'value': hex.encode(value),
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
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

  factory BmCharacteristicProperties.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmCharacteristicProperties(
      broadcast: json['broadcast'] == 1,
      read: json['read'] == 1,
      writeWithoutResponse: json['write_without_response'] == 1,
      write: json['write'] == 1,
      notify: json['notify'] == 1,
      indicate: json['indicate'] == 1,
      authenticatedSignedWrites: json['authenticated_signed_writes'] == 1,
      extendedProperties: json['extended_properties'] == 1,
      notifyEncryptionRequired: json['notify_encryption_required'] == 1,
      indicateEncryptionRequired: json['indicate_encryption_required'] == 1,
    );
  }

  @override
  int get hashCode {
    return broadcast.hashCode ^
        read.hashCode ^
        writeWithoutResponse.hashCode ^
        write.hashCode ^
        notify.hashCode ^
        indicate.hashCode ^
        authenticatedSignedWrites.hashCode ^
        extendedProperties.hashCode ^
        notifyEncryptionRequired.hashCode ^
        indicateEncryptionRequired.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmCharacteristicProperties && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'broadcast': broadcast ? 1 : 0,
      'read': read ? 1 : 0,
      'write_without_response': writeWithoutResponse ? 1 : 0,
      'write': write ? 1 : 0,
      'notify': notify ? 1 : 0,
      'indicate': indicate ? 1 : 0,
      'authenticated_signed_writes': authenticatedSignedWrites ? 1 : 0,
      'extended_properties': extendedProperties ? 1 : 0,
      'notify_encryption_required': notifyEncryptionRequired ? 1 : 0,
      'indicate_encryption_required': indicateEncryptionRequired ? 1 : 0,
    };
  }
}

class BmConnectRequest {
  DeviceIdentifier remoteId;
  bool autoConnect;

  BmConnectRequest({
    required this.remoteId,
    required this.autoConnect,
  });

  factory BmConnectRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmConnectRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      autoConnect: json['auto_connect'] == 1,
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'auto_connect': autoConnect ? 1 : 0,
    };
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

  factory BmConnectionPriorityRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmConnectionPriorityRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      connectionPriority:
          BmConnectionPriorityEnum.values[json['connection_priority'] as int],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'connection_priority': connectionPriority.index,
    };
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
    this.disconnectReasonCode,
    this.disconnectReasonString,
  });

  factory BmConnectionStateResponse.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmConnectionStateResponse(
      remoteId: DeviceIdentifier(json['remote_id']),
      connectionState:
          BmConnectionStateEnum.values[json['connection_state'] as int],
      disconnectReasonCode: json['disconnect_reason_code'],
      disconnectReasonString: json['disconnect_reason_string'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'connection_state': connectionState.index,
      'disconnectReasonCode': disconnectReasonCode,
      'disconnectReasonString': disconnectReasonString,
    };
  }
}

class BmDescriptorData {
  final DeviceIdentifier remoteId;
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
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.value,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  factory BmDescriptorData.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmDescriptorData(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
      value: json['value'] != null ? hex.decode(json['value']) : [],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        descriptorUuid.hashCode ^
        const ListEquality<int>().hash(value) ^
        success.hashCode ^
        errorCode.hashCode ^
        errorString.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmDescriptorData && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'descriptor_uuid': descriptorUuid.str,
      'value': hex.encode(value),
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
  }
}

class BmDevicesList extends ListBase<BmBluetoothDevice> {
  final List<BmBluetoothDevice> devices;

  BmDevicesList({
    required this.devices,
  });

  factory BmDevicesList.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmDevicesList(
      devices: (json['devices'] as List<dynamic>?)
              ?.map((device) => BmBluetoothDevice.fromMap(device))
              .toList() ??
          [],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'devices': devices.map((device) => device.toMap()).toList(),
    };
  }

  @override
  int get length {
    return devices.length;
  }

  @override
  set length(int newLength) {
    devices.length = newLength;
  }

  @override
  BmBluetoothDevice operator [](int index) {
    return devices[index];
  }

  @override
  void operator []=(int index, BmBluetoothDevice value) {
    devices[index] = value;
  }
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

  factory BmDiscoverServicesResult.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmDiscoverServicesResult(
      remoteId: DeviceIdentifier(json['remote_id']),
      services: (json['services'] as List<dynamic>?)
              ?.map((service) =>
                  BmBluetoothService.fromMap(service as Map<dynamic, dynamic>))
              .toList() ??
          [],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        const ListEquality<BmBluetoothService>().hash(services) ^
        success.hashCode ^
        errorCode.hashCode ^
        errorString.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmDiscoverServicesResult && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'services': services.map((service) => service.toMap()).toList(),
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
  }
}

class BmMsdFilter {
  int manufacturerId;
  List<int>? data;
  List<int>? mask;

  BmMsdFilter(
    this.manufacturerId,
    this.data,
    this.mask,
  );

  factory BmMsdFilter.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmMsdFilter(
      json['manufacturer_id'],
      json['data'] != null ? hex.decode(json['data']) : null,
      json['mask'] != null ? hex.decode(json['mask']) : null,
    );
  }

  @override
  int get hashCode {
    return manufacturerId.hashCode ^
        const ListEquality<int>().hash(data) ^
        const ListEquality<int>().hash(mask);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmMsdFilter && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'manufacturer_id': manufacturerId,
      'data': data != null ? hex.encode(data!) : null,
      'mask': mask != null ? hex.encode(mask!) : null,
    };
  }
}

class BmMtuChangeRequest {
  final DeviceIdentifier remoteId;
  final int mtu;

  BmMtuChangeRequest({
    required this.remoteId,
    required this.mtu,
  });

  factory BmMtuChangeRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmMtuChangeRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      mtu: json['mtu'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'mtu': mtu,
    };
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
    this.errorString = '',
  });

  factory BmMtuChangedResponse.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmMtuChangedResponse(
      remoteId: DeviceIdentifier(json['remote_id']),
      mtu: json['mtu'],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'mtu': mtu,
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
  }
}

class BmNameChanged {
  DeviceIdentifier remoteId;
  String name;

  BmNameChanged({
    required this.remoteId,
    required this.name,
  });

  factory BmNameChanged.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmNameChanged(
      remoteId: DeviceIdentifier(json['remote_id']),
      name: json['name'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'name': name,
    };
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

  factory BmPreferredPhy.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmPreferredPhy(
      remoteId: DeviceIdentifier(json['remote_id']),
      txPhy: json['tx_phy'],
      rxPhy: json['rx_phy'],
      phyOptions: json['phy_options'],
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'tx_phy': txPhy,
      'rx_phy': rxPhy,
      'phy_options': phyOptions,
    };
  }
}

class BmReadCharacteristicRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;

  BmReadCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
  });

  factory BmReadCharacteristicRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmReadCharacteristicRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmReadCharacteristicRequest && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
    };
  }
}

class BmReadDescriptorRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;

  BmReadDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
  });

  factory BmReadDescriptorRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmReadDescriptorRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        descriptorUuid.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmReadDescriptorRequest && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'descriptor_uuid': descriptorUuid.str,
    };
  }
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

  factory BmReadRssiResult.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmReadRssiResult(
      remoteId: DeviceIdentifier(json['remote_id']),
      rssi: json['rssi'],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'rssi': rssi,
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
  }
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
    this.platformName,
    this.advName,
    required this.connectable,
    this.txPowerLevel,
    this.appearance,
    required this.manufacturerData,
    required this.serviceData,
    required this.serviceUuids,
    required this.rssi,
  });

  factory BmScanAdvertisement.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmScanAdvertisement(
      remoteId: DeviceIdentifier(json['remote_id']),
      platformName: json['platform_name'],
      advName: json['adv_name'],
      connectable: json['connectable'] == 1,
      txPowerLevel: json['tx_power_level'],
      appearance: json['appearance'],
      manufacturerData: (json['manufacturer_data'] as Map<dynamic, dynamic>?)
              ?.map((key, value) => MapEntry(key, hex.decode(value))) ??
          {},
      serviceData: (json['service_data'] as Map<dynamic, dynamic>?)
              ?.map((key, value) => MapEntry(Guid(key), hex.decode(value))) ??
          {},
      serviceUuids: (json['service_uuids'] as List<dynamic>?)
              ?.map((str) => Guid(str))
              .toList() ??
          [],
      rssi: json['rssi'] ?? 0,
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        platformName.hashCode ^
        advName.hashCode ^
        connectable.hashCode ^
        txPowerLevel.hashCode ^
        appearance.hashCode ^
        const MapEquality<int, List<int>>().hash(manufacturerData) ^
        const MapEquality<Guid, List<int>>().hash(serviceData) ^
        const ListEquality<Guid>().hash(serviceUuids) ^
        rssi.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmScanAdvertisement && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'platform_name': platformName,
      'adv_name': advName,
      'connectable': connectable ? 1 : 0,
      'tx_power_level': txPowerLevel,
      'appearance': appearance,
      'manufacturer_data': manufacturerData
          .map((key, value) => MapEntry(key, hex.encode(value))),
      'service_data':
          serviceData.map((key, value) => MapEntry(key.str, hex.encode(value))),
      'service_uuids': serviceUuids.map((uuid) => uuid.str).toList(),
      'rssi': rssi,
    };
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

  factory BmScanResponse.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    final success = json['success'] == null || json['success'] != 0;

    return BmScanResponse(
      advertisements: (json['advertisements'] as List<dynamic>?)
              ?.map(
                  (advertisement) => BmScanAdvertisement.fromMap(advertisement))
              .toList() ??
          [],
      success: success,
      errorCode: !success ? json['error_code'] : 0,
      errorString: !success ? json['error_string'] : '',
    );
  }

  @override
  int get hashCode {
    return const ListEquality<BmScanAdvertisement>().hash(advertisements) ^
        success.hashCode ^
        errorCode.hashCode ^
        errorString.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmScanResponse && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'advertisements':
          advertisements.map((advertisement) => advertisement.toMap()).toList(),
      'success': success ? 1 : 0,
      'error_code': errorCode,
      'error_string': errorString,
    };
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

  factory BmScanSettings.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmScanSettings(
      withServices: (json['with_services'] as List<dynamic>?)
              ?.map((str) => Guid(str))
              .toList() ??
          [],
      withRemoteIds:
          (json['with_remote_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      withNames: (json['with_names'] as List<dynamic>?)?.cast<String>() ?? [],
      withKeywords:
          (json['with_keywords'] as List<dynamic>?)?.cast<String>() ?? [],
      withMsd: (json['with_msd'] as List<dynamic>?)
              ?.map((manufacturerData) => BmMsdFilter.fromMap(manufacturerData))
              .toList() ??
          [],
      withServiceData: (json['with_service_data'] as List<dynamic>?)
              ?.map((serviceData) => BmServiceDataFilter.fromMap(serviceData))
              .toList() ??
          [],
      continuousUpdates: json['continuous_updates'],
      continuousDivisor: json['continuous_divisor'],
      androidLegacy: json['android_legacy'],
      androidScanMode: json['android_scan_mode'],
      androidUsesFineLocation: json['android_uses_fine_location'],
    );
  }

  @override
  int get hashCode {
    return const ListEquality<Guid>().hash(withServices) ^
        const ListEquality<String>().hash(withRemoteIds) ^
        const ListEquality<String>().hash(withNames) ^
        const ListEquality<String>().hash(withKeywords) ^
        const ListEquality<BmMsdFilter>().hash(withMsd) ^
        const ListEquality<BmServiceDataFilter>().hash(withServiceData) ^
        continuousUpdates.hashCode ^
        continuousDivisor.hashCode ^
        androidLegacy.hashCode ^
        androidScanMode.hashCode ^
        androidUsesFineLocation.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmScanSettings && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'with_services': withServices.map((uuid) => uuid.str).toList(),
      'with_remote_ids': withRemoteIds,
      'with_names': withNames,
      'with_keywords': withKeywords,
      'with_msd':
          withMsd.map((manufacturerData) => manufacturerData.toMap()).toList(),
      'with_service_data':
          withServiceData.map((serviceData) => serviceData.toMap()).toList(),
      'continuous_updates': continuousUpdates,
      'continuous_divisor': continuousDivisor,
      'android_legacy': androidLegacy,
      'android_scan_mode': androidScanMode,
      'android_uses_fine_location': androidUsesFineLocation,
    };
  }
}

class BmServiceDataFilter {
  Guid service;
  List<int> data;
  List<int> mask;

  BmServiceDataFilter(
    this.service,
    this.data,
    this.mask,
  );

  factory BmServiceDataFilter.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmServiceDataFilter(
      Guid(json['service']),
      json['data'] != null ? hex.decode(json['data']) : [],
      json['mask'] != null ? hex.decode(json['mask']) : [],
    );
  }

  @override
  int get hashCode {
    return service.hashCode ^
        const ListEquality<int>().hash(data) ^
        const ListEquality<int>().hash(mask);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmServiceDataFilter && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'service': service.str,
      'data': hex.encode(data),
      'mask': hex.encode(mask),
    };
  }
}

class BmSetNotifyValueRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final bool forceIndications;
  final bool enable;

  BmSetNotifyValueRequest({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.forceIndications,
    required this.enable,
  });

  factory BmSetNotifyValueRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmSetNotifyValueRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      forceIndications: json['force_indications'],
      enable: json['enable'],
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        forceIndications.hashCode ^
        enable.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmSetNotifyValueRequest && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'force_indications': forceIndications,
      'enable': enable,
    };
  }
}

class BmTurnOnResponse {
  bool userAccepted;

  BmTurnOnResponse({
    required this.userAccepted,
  });

  factory BmTurnOnResponse.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmTurnOnResponse(
      userAccepted: json['user_accepted'] ?? false,
    );
  }

  @override
  int get hashCode {
    return userAccepted.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmTurnOnResponse && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'user_accepted': userAccepted,
    };
  }
}

class BmWriteCharacteristicRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final BmWriteType writeType;
  final bool allowLongWrite;
  final List<int> value;

  BmWriteCharacteristicRequest({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.writeType,
    required this.allowLongWrite,
    required this.value,
  });

  factory BmWriteCharacteristicRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmWriteCharacteristicRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      writeType: BmWriteType.values[json['write_type'] as int],
      allowLongWrite: json['allow_long_write'] != 0,
      value: json['value'] != null ? hex.decode(json['value']) : [],
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        writeType.hashCode ^
        allowLongWrite.hashCode ^
        const ListEquality<int>().hash(value);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmWriteCharacteristicRequest && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'write_type': writeType.index,
      'allow_long_write': allowLongWrite ? 1 : 0,
      'value': hex.encode(value),
    };
  }
}

class BmWriteDescriptorRequest {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;
  final List<int> value;

  BmWriteDescriptorRequest({
    required this.remoteId,
    required this.serviceUuid,
    this.secondaryServiceUuid,
    required this.characteristicUuid,
    required this.descriptorUuid,
    required this.value,
  });

  factory BmWriteDescriptorRequest.fromMap(
    Map<dynamic, dynamic> json,
  ) {
    return BmWriteDescriptorRequest(
      remoteId: DeviceIdentifier(json['remote_id']),
      serviceUuid: Guid(json['service_uuid']),
      secondaryServiceUuid: json['secondary_service_uuid'] != null
          ? Guid(json['secondary_service_uuid'])
          : null,
      characteristicUuid: Guid(json['characteristic_uuid']),
      descriptorUuid: Guid(json['descriptor_uuid']),
      value: json['value'] != null ? hex.decode(json['value']) : [],
    );
  }

  @override
  int get hashCode {
    return remoteId.hashCode ^
        serviceUuid.hashCode ^
        secondaryServiceUuid.hashCode ^
        characteristicUuid.hashCode ^
        descriptorUuid.hashCode ^
        const ListEquality<int>().hash(value);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BmWriteDescriptorRequest && hashCode == other.hashCode;
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'remote_id': remoteId.str,
      'service_uuid': serviceUuid.str,
      'secondary_service_uuid': secondaryServiceUuid?.str,
      'characteristic_uuid': characteristicUuid.str,
      'descriptor_uuid': descriptorUuid.str,
      'value': hex.encode(value),
    };
  }
}

enum BmWriteType {
  withResponse, // 0
  withoutResponse, // 1
}
