// coverage:ignore-file

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../method_channel/method_channel_flutter_blue_plus.dart';
import '../types/types.dart';

/// The interface that implementations of flutter_blue_plus must implement.
abstract class FlutterBluePlusPlatform extends PlatformInterface {
  static final _token = Object();

  static FlutterBluePlusPlatform _instance = MethodChannelFlutterBluePlus();

  FlutterBluePlusPlatform() : super(token: _token);

  /// The default instance of [FlutterBluePlusPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBluePlus].
  static FlutterBluePlusPlatform get instance {
    return _instance;
  }

  /// Platform-specific plugins should set this with their own platform-specific class that extends [FlutterBluePlusPlatform] when they register themselves.
  static set instance(
    FlutterBluePlusPlatform instance,
  ) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Returns a stream of adapter state changed events.
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged {
    throw UnimplementedError();
  }

  /// Returns a stream of bond state changed events.
  Stream<BmBondStateResponse> get onBondStateChanged {
    throw UnimplementedError();
  }

  /// Returns a stream of characteristic received (notified or read) events.
  Stream<BmCharacteristicData> get onCharacteristicReceived {
    throw UnimplementedError();
  }

  /// Returns a stream of characteristic written events.
  Stream<BmCharacteristicData> get onCharacteristicWritten {
    throw UnimplementedError();
  }

  /// Returns a stream of connection state changed events.
  Stream<BmConnectionStateResponse> get onConnectionStateChanged {
    throw UnimplementedError();
  }

  /// Returns a stream of descriptor read events.
  Stream<BmDescriptorData> get onDescriptorRead {
    throw UnimplementedError();
  }

  /// Returns a stream of descriptor written events.
  Stream<BmDescriptorData> get onDescriptorWritten {
    throw UnimplementedError();
  }

  /// Returns a stream of detached from engine events.
  Stream<void> get onDetachedFromEngine {
    throw UnimplementedError();
  }

  /// Returns a stream of discovered services events.
  Stream<BmDiscoverServicesResult> get onDiscoveredServices {
    throw UnimplementedError();
  }

  /// Returns a stream of Maximum Transmission Unit (MTU) changed events.
  Stream<BmMtuChangedResponse> get onMtuChanged {
    throw UnimplementedError();
  }

  /// Returns a stream of name changed events.
  Stream<BmNameChanged> get onNameChanged {
    throw UnimplementedError();
  }

  /// Returns a stream of Received Signal Strength Indicator (RSSI) read events.
  Stream<BmReadRssiResult> get onReadRssi {
    throw UnimplementedError();
  }

  /// Returns a stream of scan response events.
  Stream<BmScanResponse> get onScanResponse {
    throw UnimplementedError();
  }

  /// Returns a stream of services reset events.
  Stream<BmBluetoothDevice> get onServicesReset {
    throw UnimplementedError();
  }

  /// Returns a stream of turn on response events.
  Stream<BmTurnOnResponse> get onTurnOnResponse {
    throw UnimplementedError();
  }

  /// Clears the Generic Attribute Profile (GATT) cache for a [remoteId].
  Future<void> clearGattCache(
    DeviceIdentifier remoteId,
  ) {
    throw UnimplementedError();
  }

  /// Connects to the device for a [request].
  ///
  /// Returns [true] if the connection state is changed.
  ///
  /// Implementations should add an event to the [onConnectionStateChanged] stream with the changed connection state.
  Future<bool> connect(
    BmConnectRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Returns the number of connected devices.
  Future<int> connectedCount() {
    throw UnimplementedError();
  }

  /// Creates a bond to a [remoteId].
  ///
  /// Returns [true] if the bond state is changed.
  ///
  /// Implementations should add an event to the [onBondStateChanged] stream with the changed bond state.
  Future<bool> createBond(
    DeviceIdentifier remoteId,
  ) {
    throw UnimplementedError();
  }

  /// Disconnects from a [remoteId].
  ///
  /// Returns [true] if the connection state is changed.
  ///
  /// Implementations should add an event to the [onConnectionStateChanged] stream with the changed connection state.
  Future<bool> disconnect(
    DeviceIdentifier remoteId,
  ) {
    throw UnimplementedError();
  }

  /// Discovers the services for a [remoteId].
  ///
  /// Implementations should add an event to the [onDiscoveredServices] stream with the discovered services.
  Future<void> discoverServices(
    DeviceIdentifier remoteId,
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

  /// Returns the bond state for a [remoteId].
  Future<BmBondStateResponse> getBondState(
    DeviceIdentifier remoteId,
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
  /// Implementations should add an event to the [onCharacteristicReceived] stream with the read characteristic.
  Future<void> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Reads the descriptor for a [request].
  ///
  /// Implementations should add an event to the [onDescriptorRead] stream with the read descriptor.
  Future<void> readDescriptor(
    BmReadDescriptorRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Reads the Received Signal Strength Indicator (RSSI) for a [remoteId].
  ///
  /// Implementations should add an event to the [onReadRssi] stream with the read RSSI.
  Future<void> readRssi(
    DeviceIdentifier remoteId,
  ) {
    throw UnimplementedError();
  }

  /// Removes the bond to a [remoteId].
  ///
  /// Returns [true] if the bond state is changed.
  ///
  /// Implementations should add an event to the [onBondStateChanged] stream with the changed bond state.
  Future<bool> removeBond(
    DeviceIdentifier remoteId,
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
  /// Implementations should add an event to the [onMtuChanged] stream with the changed MTU.
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
  /// Implementations should add an event to the [onDescriptorWritten] stream with the written CCCD.
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
  /// Implementations should add an event to the [onScanResponse] stream for each scanned device.
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
  /// Implementations should add an event to the [onTurnOnResponse] stream with the power state.
  Future<bool> turnOn() {
    throw UnimplementedError();
  }

  /// Writes the characteristic for a [request].
  ///
  /// Implementations should add an event to the [onCharacteristicWritten] stream with the written characteristic.
  Future<void> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) {
    throw UnimplementedError();
  }

  /// Writes the descriptor for a [request].
  ///
  /// Implementations should add an event to the [onDescriptorWritten] stream with the written descriptor.
  Future<void> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) {
    throw UnimplementedError();
  }
}
