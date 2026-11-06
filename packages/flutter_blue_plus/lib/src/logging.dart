part of '../flutter_blue_plus.dart';

Map<String, Object?> _logStatus(bool success, int code, String message) =>
    {'success': success ? 1 : 0, 'error_code': code, 'error_string': message};

Map<String, Object?> _logAttribute(
        DeviceIdentifier remoteId, Guid? primary, Guid service, Guid characteristic, int instanceId) =>
    {
      'remote_id': remoteId.str,
      if (primary != null) 'primary_service_uuid': primary.str,
      'service_uuid': service.str,
      'characteristic_uuid': characteristic.str,
      'instance_id': instanceId,
    };

Object? _platformLogValue(Object? value) => switch (value) {
      DeviceIdentifier() => value.str,
      BmIsSupportedRequest() ||
      BmBluetoothAdapterNameRequest() ||
      BmBluetoothAdapterStateRequest() ||
      BmBondedDevicesRequest() ||
      BmTurnOnRequest() ||
      BmTurnOffRequest() ||
      BmStopScanRequest() ||
      PhySupportRequest() =>
        null,
      BmSetLogLevelRequest() => value.logLevel.index,
      BmSetOptionsRequest() => value.toMap(),
      BmScanSettings() => value.toMap(),
      BmSystemDevicesRequest() => value.toMap(),
      BmConnectRequest() => value.toMap(),
      BmDisconnectRequest() => value.remoteId.str,
      BmDiscoverServicesRequest() => value.remoteId.str,
      BmReadRssiRequest() => value.remoteId.str,
      BmBondStateRequest() => value.remoteId.str,
      BmRemoveBondRequest() => value.remoteId.str,
      BmClearGattCacheRequest() => value.remoteId.str,
      BmReadCharacteristicRequest() => value.toMap(),
      BmWriteCharacteristicRequest() => value.toMap(),
      BmReadDescriptorRequest() => value.toMap(),
      BmWriteDescriptorRequest() => value.toMap(),
      BmSetNotifyValueRequest() => value.toMap(),
      BmMtuChangeRequest() => value.toMap(),
      BmConnectionPriorityRequest() => value.toMap(),
      BmPreferredPhy() => value.toMap(),
      BmCreateBondRequest() => value.toMap(),
      BmBluetoothAdapterName() => value.adapterName,
      BmBluetoothAdapterState() => {'adapter_state': value.adapterState.index},
      PhySupport() => {'le_2M': value.le2M, 'le_coded': value.leCoded},
      BmBluetoothDevice() => {'remote_id': value.remoteId.str, 'platform_name': value.platformName},
      BmDevicesList() => {'devices': value.devices.map(_platformLogValue).toList()},
      BmNameChanged() => {'remote_id': value.remoteId.str, 'name': value.name},
      BmBondStateResponse() => {
          'remote_id': value.remoteId.str,
          'bond_state': value.bondState.index,
          'prev_state': value.prevState?.index,
        },
      BmConnectionStateResponse() => {
          'remote_id': value.remoteId.str,
          'connection_state': value.connectionState.index,
          'disconnect_reason_code': value.disconnectReasonCode,
          'disconnect_reason_string': value.disconnectReasonString,
        },
      BmMtuChangedResponse() => {
          'remote_id': value.remoteId.str,
          'mtu': value.mtu,
          ..._logStatus(value.success, value.errorCode, value.errorString),
        },
      BmReadRssiResult() => {
          'remote_id': value.remoteId.str,
          'rssi': value.rssi,
          ..._logStatus(value.success, value.errorCode, value.errorString),
        },
      BmCharacteristicData() => {
          ..._logAttribute(
              value.remoteId, value.primaryServiceUuid, value.serviceUuid, value.characteristicUuid, value.instanceId),
          ..._logStatus(value.success, value.errorCode, value.errorString),
          'value': value.value,
        },
      BmDescriptorData() => {
          ..._logAttribute(
              value.remoteId, value.primaryServiceUuid, value.serviceUuid, value.characteristicUuid, value.instanceId),
          'descriptor_uuid': value.descriptorUuid.str,
          ..._logStatus(value.success, value.errorCode, value.errorString),
          'value': value.value,
        },
      BmBluetoothDescriptor() => {
          ..._logAttribute(
              value.remoteId, value.primaryServiceUuid, value.serviceUuid, value.characteristicUuid, value.instanceId),
          'descriptor_uuid': value.descriptorUuid.str,
        },
      BmCharacteristicProperties() => {
          'broadcast': value.broadcast ? 1 : 0,
          'read': value.read ? 1 : 0,
          'write_without_response': value.writeWithoutResponse ? 1 : 0,
          'write': value.write ? 1 : 0,
          'notify': value.notify ? 1 : 0,
          'indicate': value.indicate ? 1 : 0,
          'authenticated_signed_writes': value.authenticatedSignedWrites ? 1 : 0,
          'extended_properties': value.extendedProperties ? 1 : 0,
          'notify_encryption_required': value.notifyEncryptionRequired ? 1 : 0,
          'indicate_encryption_required': value.indicateEncryptionRequired ? 1 : 0,
        },
      BmBluetoothCharacteristic() => {
          ..._logAttribute(
              value.remoteId, value.primaryServiceUuid, value.serviceUuid, value.characteristicUuid, value.instanceId),
          'properties': _platformLogValue(value.properties),
          'descriptors': value.descriptors.map(_platformLogValue).toList(),
        },
      BmBluetoothService() => {
          'remote_id': value.remoteId.str,
          if (value.primaryServiceUuid != null) 'primary_service_uuid': value.primaryServiceUuid!.str,
          'service_uuid': value.serviceUuid.str,
          'characteristics': value.characteristics.map(_platformLogValue).toList(),
        },
      BmDiscoverServicesResult() => {
          'remote_id': value.remoteId.str,
          'services': value.services.map(_platformLogValue).toList(),
          ..._logStatus(value.success, value.errorCode, value.errorString),
        },
      BmScanAdvertisement() => {
          'remote_id': value.remoteId.str,
          if (value.platformName != null) 'platform_name': value.platformName,
          if (value.advName != null) 'adv_name': value.advName,
          'connectable': value.connectable ? 1 : 0,
          if (value.txPowerLevel != null) 'tx_power_level': value.txPowerLevel,
          if (value.appearance != null) 'appearance': value.appearance,
          'manufacturer_data': value.manufacturerData,
          'service_data': {for (final entry in value.serviceData.entries) entry.key.str: entry.value},
          'service_uuids': value.serviceUuids.map((uuid) => uuid.str).toList(),
          'rssi': value.rssi,
        },
      BmScanResponse() => {
          'advertisements': value.advertisements.map(_platformLogValue).toList(),
          ..._logStatus(value.success, value.errorCode, value.errorString),
        },
      BmTurnOnResponse() => {'user_accepted': value.userAccepted},
      BmDetachedFromEngineResponse() => <String, Object?>{},
      _ => value,
    };

String _formatPlatformLog(Object? value, {required bool pretty}) {
  try {
    final data = _platformLogValue(value);
    return pretty ? const JsonEncoder.withIndent('  ').convert(data) : data.toString();
  } catch (error) {
    // Formatting diagnostics must not change operation or event delivery.
    return '<unable to format: $error>';
  }
}

String _colorizeLog(String text, int color) => FlutterBluePlus._logColor ? '\x1B[1;${color}m$text\x1B[0m' : text;

void _logPlatform(String label, String kind, Object? value, {int valueColor = 33, bool pretty = false}) {
  if (FlutterBluePlus.logLevel != LogLevel.verbose) return;
  final output = _formatPlatformLog(value, pretty: pretty);
  FlutterBluePlusPlatform.log('[FBP] ${_colorizeLog(label, 30)} $kind: ${_colorizeLog(output, valueColor)}');
}

void _listenToPlatformEvent<T>(String name, Stream<T> stream) {
  stream.listen((event) => _logPlatform('[[ $name ]]', 'result', event, pretty: name == 'OnDiscoveredServices'),
      // Existing consumers retain ownership of stream-error handling.
      onError: (Object error, StackTrace stack) {});
}

void _listenToPlatformLogs() {
  final platform = FlutterBluePlusPlatform.instance;
  _listenToPlatformEvent('OnAdapterStateChanged', platform.onAdapterStateChanged);
  _listenToPlatformEvent('OnBondStateChanged', platform.onBondStateChanged);
  _listenToPlatformEvent('OnCharacteristicReceived', platform.onCharacteristicReceived);
  _listenToPlatformEvent('OnCharacteristicWritten', platform.onCharacteristicWritten);
  _listenToPlatformEvent('OnConnectionStateChanged', platform.onConnectionStateChanged);
  _listenToPlatformEvent('OnDescriptorRead', platform.onDescriptorRead);
  _listenToPlatformEvent('OnDescriptorWritten', platform.onDescriptorWritten);
  _listenToPlatformEvent('OnDetachedFromEngine', platform.onDetachedFromEngine);
  _listenToPlatformEvent('OnDiscoveredServices', platform.onDiscoveredServices);
  _listenToPlatformEvent('OnMtuChanged', platform.onMtuChanged);
  _listenToPlatformEvent('OnNameChanged', platform.onNameChanged);
  _listenToPlatformEvent('OnReadRssi', platform.onReadRssi);
  _listenToPlatformEvent('OnScanResponse', platform.onScanResponse);
  _listenToPlatformEvent('OnServicesReset', platform.onServicesReset);
  _listenToPlatformEvent('OnTurnOnResponse', platform.onTurnOnResponse);
}
