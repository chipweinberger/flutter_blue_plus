import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'adapter/models/bm_bluetooth_adapter_state.dart';
import 'characteristic/models/bm_read_characteristic_request.dart';
import 'characteristic/models/bm_set_notify_value_request.dart';
import 'characteristic/models/bm_write_characteristic_request.dart';
import 'common/enums/log_level.dart';
import 'common/models/device_identifier.dart';
import 'common/models/options.dart';
import 'common/models/phy_support.dart';
import 'descriptor/models/bm_read_descriptor_request.dart';
import 'descriptor/models/bm_write_descriptor_request.dart';
import 'device/models/bm_bond_state_response.dart';
import 'device/models/bm_connect_request.dart';
import 'device/models/bm_connection_priority_request.dart';
import 'device/models/bm_devices_list.dart';
import 'device/models/bm_mtu_change_request.dart';
import 'device/models/bm_preferred_phy.dart';
import 'method_channel_flutter_blue_plus.dart';
import 'scan/models/bm_scan_settings.dart';

/// The interface that implementations of flutter_blue_plus must implement.
abstract class FlutterBluePlusPlatform extends PlatformInterface {
  FlutterBluePlusPlatform() : super(token: _token);

  static final _token = Object();

  static FlutterBluePlusPlatform _instance = MethodChannelFlutterBluePlus();

  /// The default instance of [FlutterBluePlusPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBluePlus].
  static FlutterBluePlusPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [FlutterBluePlusPlatform] when they register themselves.
  static set instance(FlutterBluePlusPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Clears the GATT cache for a [device].
  Future<void> clearGattCache(
    DeviceIdentifier device,
  ) {
    throw UnimplementedError();
  }

  /// Connects to the device for a [request].
  ///
  /// Returns [true] if the connection state is changed.
  ///
  /// Implementations should call [OnConnectionStateChanged] with the changed connection state.
  Future<bool> connect(
    BmConnectRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Returns the number of connected devices.
  Future<int> connectedCount() {
    throw UnimplementedError();
  }

  /// Creates a bond to a [device].
  ///
  /// Returns [true] if the bond state is changed.
  ///
  /// Implementations should call [OnBondStateChanged] with the changed bond state.
  Future<bool> createBond(
    DeviceIdentifier device,
  ) {
    throw UnimplementedError();
  }

  /// Disconnects from a [device].
  ///
  /// Returns [true] if the connection state is changed.
  ///
  /// Implementations should call [OnConnectionStateChanged] with the changed connection state.
  Future<bool> disconnect(
    DeviceIdentifier device,
  ) {
    throw UnimplementedError();
  }

  /// Discovers the services for a [device].
  ///
  /// Implementations should call [OnDiscoveredServices] with the discovered services.
  Future<void> discoverServices(
    DeviceIdentifier device,
  ) {
    throw UnimplementedError();
  }

  /// Returns the number of remaining connected devices after restarting Flutter.
  Future<int> flutterRestart() {
    throw UnimplementedError();
  }

  /// Returns the adapter name.
  Future<String> getAdapterName() {
    throw UnimplementedError();
  }

  /// Returns the adapter state.
  Future<BmBluetoothAdapterState> getAdapterState() {
    throw UnimplementedError();
  }

  /// Returns the bond state for a [device].
  Future<BmBondStateResponse> getBondState(
    DeviceIdentifier device,
  ) {
    throw UnimplementedError();
  }

  /// Returns the bonded devices.
  Future<BmDevicesList> getBondedDevices() {
    throw UnimplementedError();
  }

  /// Returns the Physical Layer (PHY) support.
  Future<PhySupport> getPhySupport() {
    throw UnimplementedError();
  }

  /// Returns the system devices.
  Future<BmDevicesList> getSystemDevices() {
    throw UnimplementedError();
  }

  /// Returns [true] if Bluetooth is supported on the hardware.
  Future<bool> isSupported() {
    throw UnimplementedError();
  }

  /// Reads the characteristic for a [request].
  ///
  /// Implementations should call [OnCharacteristicReceived] with the read characteristic.
  Future<void> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Reads the descriptor for a [request].
  ///
  /// Implementations should call [OnDescriptorRead] with the read descriptor.
  Future<void> readDescriptor(
    BmReadDescriptorRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Reads the Received Signal Strength Indicator (RSSI) for a [device].
  ///
  /// Implementations should call [OnReadRssi] with the read RSSI.
  Future<void> readRssi(
    DeviceIdentifier device,
  ) {
    throw UnimplementedError();
  }

  /// Removes the bond to a [device].
  ///
  /// Returns [true] if the bond state is changed.
  ///
  /// Implementations should call [OnBondStateChanged] with the changed bond state.
  Future<bool> removeBond(
    DeviceIdentifier device,
  ) {
    throw UnimplementedError();
  }

  /// Requests a change to the connection priority for a [request].
  Future<void> requestConnectionPriority(
    BmConnectionPriorityRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Requests a change to the Maximum Transmission Unit (MTU) for a [request].
  ///
  /// Implementations should call [OnMtuChanged] with the changed MTU.
  Future<void> requestMtu(
    BmMtuChangeRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Sets the log level.
  Future<void> setLogLevel(
    LogLevel level,
  ) {
    throw UnimplementedError();
  }

  /// Sets the notify value for a [request].
  ///
  /// Returns [true] if the characteristic has a Client Characteristic Configuration Descriptor (CCCD).
  ///
  /// Implementations should call [OnDescriptorWritten] with the written CCCD.
  Future<bool> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Sets the options.
  Future<void> setOptions(
    Options options,
  ) {
    throw UnimplementedError();
  }

  /// Sets the preferred Physical Layer (PHY).
  Future<void> setPreferredPhy(
    BmPreferredPhy preferredPhy,
  ) {
    throw UnimplementedError();
  }

  /// Starts scanning for devices.
  ///
  /// Implementations should call [OnScanResponse] for each scanned device.
  Future<void> startScan(
    BmScanSettings settings,
  ) {
    throw UnimplementedError();
  }

  /// Stops scanning for devices.
  Future<void> stopScan() {
    throw UnimplementedError();
  }

  /// Turns off the adapter.
  Future<void> turnOff() {
    throw UnimplementedError();
  }

  /// Turns on the adapter.
  ///
  /// Returns [true] if the power state is changed.
  ///
  /// Implementations should call [OnTurnOnResponse] with the power state.
  Future<bool> turnOn() {
    throw UnimplementedError();
  }

  /// Writes the characteristic for a [request].
  ///
  /// Implementations should call [OnCharacteristicWritten] with the written characteristic.
  Future<void> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Writes the descriptor for a [request].
  ///
  /// Implementations should call [OnDescriptorWritten] with the written descriptor.
  Future<void> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) {
    throw UnimplementedError();
  }
}