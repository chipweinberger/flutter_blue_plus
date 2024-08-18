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
    channel.setMethodCallHandler(handleMethodCall);
  }

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged {
    return _calls.stream.where((call) {
      return call.method == 'OnAdapterStateChanged';
    }).map((call) {
      return BmBluetoothAdapterState.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmBondStateResponse> get onBondStateChanged {
    return _calls.stream.where((call) {
      return call.method == 'OnBondStateChanged';
    }).map((call) {
      return BmBondStateResponse.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmCharacteristicData> get onCharacteristicReceived {
    return _calls.stream.where((call) {
      return call.method == 'OnCharacteristicReceived';
    }).map((call) {
      return BmCharacteristicData.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmCharacteristicData> get onCharacteristicWritten {
    return _calls.stream.where((call) {
      return call.method == 'OnCharacteristicWritten';
    }).map((call) {
      return BmCharacteristicData.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged {
    return _calls.stream.where((call) {
      return call.method == 'OnConnectionStateChanged';
    }).map((call) {
      return BmConnectionStateResponse.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmDescriptorData> get onDescriptorRead {
    return _calls.stream.where((call) {
      return call.method == 'OnDescriptorRead';
    }).map((call) {
      return BmDescriptorData.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmDescriptorData> get onDescriptorWritten {
    return _calls.stream.where((call) {
      return call.method == 'OnDescriptorWritten';
    }).map((call) {
      return BmDescriptorData.fromMap(call.arguments);
    });
  }

  @override
  Stream<void> get onDetachedFromEngine {
    return _calls.stream.where((call) {
      return call.method == 'OnDetachedFromEngine';
    });
  }

  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices {
    return _calls.stream.where((call) {
      return call.method == 'OnDiscoveredServices';
    }).map((call) {
      return BmDiscoverServicesResult.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmMtuChangedResponse> get onMtuChanged {
    return _calls.stream.where((call) {
      return call.method == 'OnMtuChanged';
    }).map((call) {
      return BmMtuChangedResponse.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmNameChanged> get onNameChanged {
    return _calls.stream.where((call) {
      return call.method == 'OnNameChanged';
    }).map((call) {
      return BmNameChanged.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmReadRssiResult> get onReadRssi {
    return _calls.stream.where((call) {
      return call.method == 'OnReadRssi';
    }).map((call) {
      return BmReadRssiResult.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmScanResponse> get onScanResponse {
    return _calls.stream.where((call) {
      return call.method == 'OnScanResponse';
    }).map((call) {
      return BmScanResponse.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmBluetoothDevice> get onServicesReset {
    return _calls.stream.where((call) {
      return call.method == 'OnServicesReset';
    }).map((call) {
      return BmBluetoothDevice.fromMap(call.arguments);
    });
  }

  @override
  Stream<BmTurnOnResponse> get onTurnOnResponse {
    return _calls.stream.where((call) {
      return call.method == 'OnTurnOnResponse';
    }).map((call) {
      return BmTurnOnResponse.fromMap(call.arguments);
    });
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

  @visibleForTesting
  Future<void> handleMethodCall(
    MethodCall call,
  ) async {
    _calls.add(call);
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
