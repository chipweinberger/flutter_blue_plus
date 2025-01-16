import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/bluetooth_msgs.dart';

export 'src/bluetooth_msgs.dart';
export 'src/device_identifier.dart';
export 'src/guid.dart';
export 'src/log_level.dart';

/// The interface that implementations of flutter_blue_plus must implement.
abstract class FlutterBluePlusPlatform extends PlatformInterface {
  static final _token = Object();

  FlutterBluePlusPlatform() : super(token: _token);

  static FlutterBluePlusPlatform? _instance;

  /// The default instance of [FlutterBluePlusPlatform] to use. Throws an [UnsupportedError] if flutter_blue_plus is unsupported on this platform.
  static FlutterBluePlusPlatform get instance {
    final instance = _instance;

    if (instance != null) {
      return instance;
    } else {
      throw UnsupportedError(
        'flutter_blue_plus is unsupported on this platform',
      );
    }
  }

  /// Platform-specific plugins should set this with their own platform-specific class that extends [FlutterBluePlusPlatform] when they register themselves.
  static set instance(
    FlutterBluePlusPlatform instance,
  ) {
    PlatformInterface.verify(instance, _token);

    _instance = instance;
  }

  Stream<BmBluetoothAdapterState> get onAdapterStateChanged {
    throw UnimplementedError();
  }

  Stream<BmBondStateResponse> get onBondStateChanged {
    throw UnimplementedError();
  }

  Stream<BmCharacteristicData> get onCharacteristicReceived {
    throw UnimplementedError();
  }

  Stream<BmCharacteristicData> get onCharacteristicWritten {
    throw UnimplementedError();
  }

  Stream<BmConnectionStateResponse> get onConnectionStateChanged {
    throw UnimplementedError();
  }

  Stream<BmDescriptorData> get onDescriptorRead {
    throw UnimplementedError();
  }

  Stream<BmDescriptorData> get onDescriptorWritten {
    throw UnimplementedError();
  }

  Stream<BmDetachedFromEngineResponse> get onDetachedFromEngine {
    throw UnimplementedError();
  }

  Stream<BmDiscoverServicesResult> get onDiscoveredServices {
    throw UnimplementedError();
  }

  Stream<BmMtuChangedResponse> get onMtuChanged {
    throw UnimplementedError();
  }

  Stream<BmNameChanged> get onNameChanged {
    throw UnimplementedError();
  }

  Stream<BmReadRssiResult> get onReadRssi {
    throw UnimplementedError();
  }

  Stream<BmScanResponse> get onScanResponse {
    throw UnimplementedError();
  }

  Stream<BmBluetoothDevice> get onServicesReset {
    throw UnimplementedError();
  }

  Future<void> clearGattCache(
    BmClearGattCacheRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> connect(
    BmConnectRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> createBond(
    BmCreateBondRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> disconnect(
    BmDisconnectRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> discoverServices(
    BmDiscoverServicesRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<BmBluetoothAdapterName> getAdapterName(
    BmBluetoothAdapterNameRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<BmBondStateResponse> getBondState(
    BmBondStateRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<BmDevicesList> getBondedDevices(
    BmBondedDevicesRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<PhySupport> getPhySupport(
    PhySupportRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<BmDevicesList> getSystemDevices(
    BmSystemDevicesRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<bool> isSupported(
    BmIsSupportedRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> readDescriptor(
    BmReadDescriptorRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> readRssi(
    BmReadRssiRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> removeBond(
    BmRemoveBondRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> requestConnectionPriority(
    BmConnectionPriorityRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> requestMtu(
    BmMtuChangeRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> setLogLevel(
    BmSetLogLevelRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<bool> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> setOptions(
    BmSetOptionsRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> setPreferredPhy(
    BmPreferredPhy request,
  ) {
    throw UnimplementedError();
  }

  Future<void> startScan(
    BmScanSettings request,
  ) {
    throw UnimplementedError();
  }

  Future<void> stopScan(
    BmStopScanRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> turnOff(
    BmTurnOffRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> turnOn(
    BmTurnOnRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) {
    throw UnimplementedError();
  }

  Future<void> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) {
    throw UnimplementedError();
  }
}
