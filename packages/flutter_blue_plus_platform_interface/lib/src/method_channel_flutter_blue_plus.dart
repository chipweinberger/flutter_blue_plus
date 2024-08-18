import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'adapter/models/bm_bluetooth_adapter_state.dart';
import 'adapter/models/bm_turn_on_response.dart';
import 'characteristic/models/bm_characteristic_data.dart';
import 'characteristic/models/bm_read_characteristic_request.dart';
import 'characteristic/models/bm_set_notify_value_request.dart';
import 'characteristic/models/bm_write_characteristic_request.dart';
import 'common/enums/log_level.dart';
import 'common/models/device_identifier.dart';
import 'common/models/options.dart';
import 'common/models/phy_support.dart';
import 'descriptor/models/bm_descriptor_data.dart';
import 'descriptor/models/bm_read_descriptor_request.dart';
import 'descriptor/models/bm_write_descriptor_request.dart';
import 'device/models/bm_bluetooth_device.dart';
import 'device/models/bm_bond_state_response.dart';
import 'device/models/bm_connect_request.dart';
import 'device/models/bm_connection_priority_request.dart';
import 'device/models/bm_connection_state_response.dart';
import 'device/models/bm_devices_list.dart';
import 'device/models/bm_mtu_change_request.dart';
import 'device/models/bm_mtu_changed_response.dart';
import 'device/models/bm_name_changed.dart';
import 'device/models/bm_preferred_phy.dart';
import 'device/models/bm_read_rssi_result.dart';
import 'flutter_blue_plus_platform.dart';
import 'scan/models/bm_scan_response.dart';
import 'scan/models/bm_scan_settings.dart';
import 'service/models/bm_discover_services_result.dart';

/// An implementation of [FlutterBluePlusPlatform] that uses method channels.
class MethodChannelFlutterBluePlus extends FlutterBluePlusPlatform {
  @visibleForTesting
  final channel = const MethodChannel('flutter_blue_plus/methods');

  final _calls = StreamController<MethodCall>.broadcast();

  MethodChannelFlutterBluePlus() {
    channel.setMethodCallHandler(
      (call) async {
        _calls.add(call);
      },
    );
  }

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnAdapterStateChanged') {
        yield BmBluetoothAdapterState.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmBondStateResponse> get onBondStateChanged async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnBondStateChanged') {
        yield BmBondStateResponse.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmCharacteristicData> get onCharacteristicReceived async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnCharacteristicReceived') {
        yield BmCharacteristicData.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmCharacteristicData> get onCharacteristicWritten async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnCharacteristicWritten') {
        yield BmCharacteristicData.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnConnectionStateChanged') {
        yield BmConnectionStateResponse.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmDescriptorData> get onDescriptorRead async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnDescriptorRead') {
        yield BmDescriptorData.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmDescriptorData> get onDescriptorWritten async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnDescriptorWritten') {
        yield BmDescriptorData.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<void> get onDetachedFromEngine async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnDetachedFromEngine') {
        yield null;
      }
    }
  }

  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnDiscoveredServices') {
        yield BmDiscoverServicesResult.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmMtuChangedResponse> get onMtuChanged async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnMtuChanged') {
        yield BmMtuChangedResponse.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmNameChanged> get onNameChanged async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnNameChanged') {
        yield BmNameChanged.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmReadRssiResult> get onReadRssi async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnReadRssi') {
        yield BmReadRssiResult.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmScanResponse> get onScanResponse async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnScanResponse') {
        yield BmScanResponse.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmBluetoothDevice> get onServicesReset async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnServicesReset') {
        yield BmBluetoothDevice.fromMap(call.arguments);
      }
    }
  }

  @override
  Stream<BmTurnOnResponse> get onTurnOnResponse async* {
    await for (final call in _calls.stream) {
      if (call.method == 'OnTurnOnResponse') {
        yield BmTurnOnResponse.fromMap(call.arguments);
      }
    }
  }

  @override
  Future<void> clearGattCache(
    DeviceIdentifier remoteId,
  ) async {
    await channel.invokeMethod<void>(
      'clearGattCache',
      remoteId.str,
    );
  }

  @override
  Future<bool> connect(
    BmConnectRequest request,
  ) async {
    final result = await channel.invokeMethod<bool>(
      'connect',
      request.toMap(),
    );

    return result!;
  }

  @override
  Future<int> connectedCount() async {
    final result = await channel.invokeMethod<int>(
      'connectedCount',
    );

    return result!;
  }

  @override
  Future<bool> createBond(
    DeviceIdentifier remoteId,
  ) async {
    final result = await channel.invokeMethod<bool>(
      'createBond',
      remoteId.str,
    );

    return result!;
  }

  @override
  Future<bool> disconnect(
    DeviceIdentifier remoteId,
  ) async {
    final result = await channel.invokeMethod<bool>(
      'disconnect',
      remoteId.str,
    );

    return result!;
  }

  @override
  Future<void> discoverServices(
    DeviceIdentifier remoteId,
  ) async {
    await channel.invokeMethod<void>(
      'discoverServices',
      remoteId.str,
    );
  }

  @override
  Future<int> flutterRestart() async {
    final result = await channel.invokeMethod<int>(
      'flutterRestart',
    );

    return result!;
  }

  @override
  Future<String> getAdapterName() async {
    final result = await channel.invokeMethod<String>(
      'getAdapterName',
    );

    return result!;
  }

  @override
  Future<BmBluetoothAdapterState> getAdapterState() async {
    final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
      'getAdapterState',
    );

    return BmBluetoothAdapterState.fromMap(result!);
  }

  @override
  Future<BmBondStateResponse> getBondState(
    DeviceIdentifier remoteId,
  ) async {
    final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
      'getBondState',
      remoteId.str,
    );

    return BmBondStateResponse.fromMap(result!);
  }

  @override
  Future<BmDevicesList> getBondedDevices() async {
    final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
      'getBondedDevices',
    );

    return BmDevicesList.fromMap(result!);
  }

  @override
  Future<PhySupport> getPhySupport() async {
    final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
      'getPhySupport',
    );

    return PhySupport.fromMap(result!);
  }

  @override
  Future<BmDevicesList> getSystemDevices() async {
    final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
      'getSystemDevices',
    );

    return BmDevicesList.fromMap(result!);
  }

  @override
  Future<bool> isSupported() async {
    final result = await channel.invokeMethod<bool>(
      'isSupported',
    );

    return result!;
  }

  @override
  Future<void> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) async {
    await channel.invokeMethod<void>(
      'readCharacteristic',
      request.toMap(),
    );
  }

  @override
  Future<void> readDescriptor(
    BmReadDescriptorRequest request,
  ) async {
    await channel.invokeMethod<void>(
      'readDescriptor',
      request.toMap(),
    );
  }

  @override
  Future<void> readRssi(
    DeviceIdentifier remoteId,
  ) async {
    await channel.invokeMethod<void>(
      'readRssi',
      remoteId.str,
    );
  }

  @override
  Future<bool> removeBond(
    DeviceIdentifier remoteId,
  ) async {
    final result = await channel.invokeMethod<bool>(
      'removeBond',
      remoteId.str,
    );

    return result!;
  }

  @override
  Future<void> requestConnectionPriority(
    BmConnectionPriorityRequest request,
  ) async {
    await channel.invokeMethod<void>(
      'requestConnectionPriority',
      request.toMap(),
    );
  }

  @override
  Future<void> requestMtu(
    BmMtuChangeRequest request,
  ) async {
    await channel.invokeMethod<void>(
      'requestMtu',
      request.toMap(),
    );
  }

  @override
  Future<void> setLogLevel(
    LogLevel level,
  ) async {
    await channel.invokeMethod<void>(
      'setLogLevel',
      level.index,
    );
  }

  @override
  Future<bool> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) async {
    final result = await channel.invokeMethod<bool>(
      'setNotifyValue',
      request.toMap(),
    );

    return result!;
  }

  @override
  Future<void> setOptions(
    Options options,
  ) async {
    await channel.invokeMethod<void>(
      'setOptions',
      options.toMap(),
    );
  }

  @override
  Future<void> setPreferredPhy(
    BmPreferredPhy preferredPhy,
  ) async {
    await channel.invokeMethod<void>(
      'setPreferredPhy',
      preferredPhy.toMap(),
    );
  }

  @override
  Future<void> startScan(
    BmScanSettings settings,
  ) async {
    await channel.invokeMethod<void>(
      'startScan',
      settings.toMap(),
    );
  }

  @override
  Future<void> stopScan() async {
    await channel.invokeMethod<void>(
      'stopScan',
    );
  }

  @override
  Future<void> turnOff() async {
    await channel.invokeMethod<void>(
      'turnOff',
    );
  }

  @override
  Future<bool> turnOn() async {
    final result = await channel.invokeMethod<bool>(
      'turnOn',
    );

    return result!;
  }

  @override
  Future<void> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) async {
    await channel.invokeMethod<void>(
      'writeCharacteristic',
      request.toMap(),
    );
  }

  @override
  Future<void> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) async {
    await channel.invokeMethod<void>(
      'writeDescriptor',
      request.toMap(),
    );
  }
}
