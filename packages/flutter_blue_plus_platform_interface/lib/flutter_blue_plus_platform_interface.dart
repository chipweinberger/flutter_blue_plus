import 'src/bluetooth_msgs.dart';

export 'src/bluetooth_msgs.dart';
export 'src/device_identifier.dart';
export 'src/guid.dart';
export 'src/log_level.dart';

/// The interface that implementations of flutter_blue_plus must implement.
abstract base class FlutterBluePlusPlatform {
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
    _instance = instance;
  }

  Stream<BmBluetoothAdapterState> get onAdapterStateChanged {
    return Stream.empty();
  }

  Stream<BmBondStateResponse> get onBondStateChanged {
    return Stream.empty();
  }

  Stream<BmCharacteristicData> get onCharacteristicReceived {
    return Stream.empty();
  }

  Stream<BmCharacteristicData> get onCharacteristicWritten {
    return Stream.empty();
  }

  Stream<BmConnectionStateResponse> get onConnectionStateChanged {
    return Stream.empty();
  }

  Stream<BmDescriptorData> get onDescriptorRead {
    return Stream.empty();
  }

  Stream<BmDescriptorData> get onDescriptorWritten {
    return Stream.empty();
  }

  Stream<BmDetachedFromEngineResponse> get onDetachedFromEngine {
    return Stream.empty();
  }

  Stream<BmDiscoverServicesResult> get onDiscoveredServices {
    return Stream.empty();
  }

  Stream<BmMtuChangedResponse> get onMtuChanged {
    return Stream.empty();
  }

  Stream<BmNameChanged> get onNameChanged {
    return Stream.empty();
  }

  Stream<BmReadRssiResult> get onReadRssi {
    return Stream.empty();
  }

  Stream<BmScanResponse> get onScanResponse {
    return Stream.empty();
  }

  Stream<BmBluetoothDevice> get onServicesReset {
    return Stream.empty();
  }

  Stream<BmTurnOnResponse> get onTurnOnResponse {
    return Stream.empty();
  }

  Future<bool> clearGattCache(
    BmClearGattCacheRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> connect(
    BmConnectRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> createBond(
    BmCreateBondRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> disconnect(
    BmDisconnectRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> discoverServices(
    BmDiscoverServicesRequest request,
  ) {
    return Future.value(false);
  }

  Future<BmBluetoothAdapterName> getAdapterName(
    BmBluetoothAdapterNameRequest request,
  ) {
    return Future.value(
      BmBluetoothAdapterName(
        adapterName: '',
      ),
    );
  }

  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) {
    return Future.value(
      BmBluetoothAdapterState(
        adapterState: BmAdapterStateEnum.unknown,
      ),
    );
  }

  Future<BmBondStateResponse> getBondState(
    BmBondStateRequest request,
  ) {
    return Future.value(
      BmBondStateResponse(
        remoteId: request.remoteId,
        bondState: BmBondStateEnum.none,
        prevState: null,
      ),
    );
  }

  Future<BmDevicesList> getBondedDevices(
    BmBondedDevicesRequest request,
  ) {
    return Future.value(
      BmDevicesList(
        devices: const [],
      ),
    );
  }

  Future<PhySupport> getPhySupport(
    PhySupportRequest request,
  ) {
    return Future.value(
      PhySupport(
        le2M: false,
        leCoded: false,
      ),
    );
  }

  Future<BmDevicesList> getSystemDevices(
    BmSystemDevicesRequest request,
  ) {
    return Future.value(
      BmDevicesList(
        devices: const [],
      ),
    );
  }

  Future<bool> isSupported(
    BmIsSupportedRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> readDescriptor(
    BmReadDescriptorRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> readRssi(
    BmReadRssiRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> removeBond(
    BmRemoveBondRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> requestConnectionPriority(
    BmConnectionPriorityRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> requestMtu(
    BmMtuChangeRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> setLogLevel(
    BmSetLogLevelRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> setOptions(
    BmSetOptionsRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> setPreferredPhy(
    BmPreferredPhy request,
  ) {
    return Future.value(false);
  }

  Future<bool> startScan(
    BmScanSettings request,
  ) {
    return Future.value(false);
  }

  Future<bool> stopScan(
    BmStopScanRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> turnOff(
    BmTurnOffRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> turnOn(
    BmTurnOnRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) {
    return Future.value(false);
  }

  Future<bool> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) {
    return Future.value(false);
  }
}
