/// The interface that implementations of flutter_blue_plus must implement.
abstract base class FlutterBluePlusPlatform {
  static FlutterBluePlusPlatform? _instance;

  /// The default instance of [FlutterBluePlusPlatform] to use. Throws an [UnsupportedError] if flutter_blue_plus is unsupported on this platform.
  static FlutterBluePlusPlatform get instance {
    if (_instance case final instance?) {
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

  /// Returns a stream of adapter state change events.
  Stream<BluetoothAdapterState> get adapterStateChanges {
    throw UnimplementedError();
  }

  /// Returns a stream of bond state change events.
  Stream<OnBondStateChangedEvent> get bondStateChanges {
    throw UnimplementedError();
  }

  /// Returns a stream of characteristic receive events.
  Stream<OnCharacteristicReceivedEvent> get characteristicReceives {
    throw UnimplementedError();
  }

  /// Returns a stream of characteristic write events.
  Stream<OnCharacteristicWrittenEvent> get characteristicWrites {
    throw UnimplementedError();
  }

  /// Returns a stream of connection state change events.
  Stream<OnConnectionStateChangedEvent> get connectionStateChanges {
    throw UnimplementedError();
  }

  /// Returns a stream of descriptor read events.
  Stream<OnDescriptorReadEvent> get descriptorReads {
    throw UnimplementedError();
  }

  /// Returns a stream of descriptor write events.
  Stream<OnDescriptorWrittenEvent> get descriptorWrites {
    throw UnimplementedError();
  }

  /// Returns a stream of Maximum Transmission Unit (MTU) change events.
  Stream<OnMtuChangedEvent> get mtuChanges {
    throw UnimplementedError();
  }

  /// Returns a stream of name change events.
  Stream<OnNameChangedEvent> get nameChanges {
    throw UnimplementedError();
  }

  /// Returns a stream of Physical Layer (PHY) change events.
  Stream<OnPhyChangedEvent> get phyChanges {
    throw UnimplementedError();
  }

  /// Returns a stream of Received Signal Strength Indicator (RSSI) read events.
  Stream<OnReadRssiEvent> get rssiReads {
    throw UnimplementedError();
  }

  /// Returns a stream of scan result events.
  Stream<ScanResult> get scanResults {
    throw UnimplementedError();
  }

  /// Returns a stream of services change events.
  Stream<OnServicesResetEvent> get servicesChanges {
    throw UnimplementedError();
  }

  /// Returns a stream of services discover events.
  Stream<OnDiscoveredServicesEvent> get servicesDiscovers {
    throw UnimplementedError();
  }

  /// Clears the Generic Attribute Profile (GATT) cache for a [remoteId].
  Future<void> clearGattCache(
    DeviceIdentifier remoteId,
  ) {
    throw UnimplementedError();
  }

  /// Connects to a [remoteId].
  Future<void> connect(
    DeviceIdentifier remoteId, {
    bool autoConnect = false,
  }) {
    throw UnimplementedError();
  }

  /// Creates a bond to a [remoteId].
  Future<void> createBond(
    DeviceIdentifier remoteId,
  ) {
    throw UnimplementedError();
  }

  /// Disconnects from a [remoteId].
  Future<void> disconnect(
    DeviceIdentifier remoteId,
  ) {
    throw UnimplementedError();
  }

  /// Discovers the services for a [remoteId].
  Future<List<BluetoothService>> discoverServices(
    DeviceIdentifier remoteId,
  ) {
    throw UnimplementedError();
  }

  /// Returns the adapter name.
  Future<String> getAdapterName() {
    throw UnimplementedError();
  }

  /// Returns the bonded devices.
  Future<List<BluetoothDevice>> getBondedDevices() {
    throw UnimplementedError();
  }

  /// Returns the Physical Layer (PHY) support.
  Future<PhySupport> getPhySupport() {
    throw UnimplementedError();
  }

  /// Returns the system devices.
  Future<List<BluetoothDevice>> getSystemDevices() {
    throw UnimplementedError();
  }

  /// Returns [true] if Bluetooth is supported on the hardware.
  Future<bool> isSupported() {
    throw UnimplementedError();
  }

  /// Reads the value for a [characteristicUuid].
  ///
  /// Returns the value as a list of bytes.
  Future<List<int>> readCharacteristic(
    DeviceIdentifier remoteId,
    Guid serviceUuid,
    Guid characteristicUuid,
  ) {
    throw UnimplementedError();
  }

  /// Reads the value for a [descriptorUuid].
  ///
  /// Returns the value as a list of bytes.
  Future<List<int>> readDescriptor(
    DeviceIdentifier remoteId,
    Guid serviceUuid,
    Guid characteristicUuid,
    Guid descriptorUuid,
  ) {
    throw UnimplementedError();
  }

  /// Reads the Received Signal Strength Indicator (RSSI) for a [remoteId].
  Future<int> readRssi(
    DeviceIdentifier remoteId,
  ) {
    throw UnimplementedError();
  }

  /// Removes the bond to a [remoteId].
  Future<void> removeBond(
    DeviceIdentifier remoteId,
  ) {
    throw UnimplementedError();
  }

  /// Requests a change to the connection priority for a [remoteId].
  Future<void> requestConnectionPriority(
    DeviceIdentifier remoteId,
    ConnectionPriority connectionPriority,
  ) {
    throw UnimplementedError();
  }

  /// Requests a change to the Maximum Transmission Unit (MTU) for a [remoteId].
  Future<int> requestMtu(
    DeviceIdentifier remoteId,
    int mtu,
  ) {
    throw UnimplementedError();
  }

  /// Sets the log level.
  Future<void> setLogLevel(
    LogLevel level,
  ) {
    throw UnimplementedError();
  }

  /// Sets the notify and/or indicate value for a [characteristicUuid].
  Future<void> setNotifyValue(
    DeviceIdentifier remoteId,
    Guid serviceUuid,
    Guid characteristicUuid,
    bool enable, {
    bool androidForceIndications = false,
  }) {
    throw UnimplementedError();
  }

  /// Sets the options.
  Future<void> setOptions({
    bool darwinShowPowerAlert = true,
  }) {
    throw UnimplementedError();
  }

  /// Sets the preferred Physical Layer (PHY).
  Future<void> setPreferredPhy(
    int txPhy,
    int rxPhy,
    PhyCoding phyOptions,
  ) {
    throw UnimplementedError();
  }

  /// Starts scanning for devices.
  Future<void> startScan({
    List<Guid> withServices = const [],
    List<String> withRemoteIds = const [],
    List<String> withNames = const [],
    List<String> withKeywords = const [],
    List<MsdFilter> withMsd = const [],
    List<ServiceDataFilter> withServiceData = const [],
    bool continuousUpdates = false,
    int continuousDivisor = 1,
    bool androidLegacy = false,
    AndroidScanMode androidScanMode = AndroidScanMode.lowLatency,
    bool androidUsesFineLocation = false,
  }) {
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
  Future<void> turnOn() {
    throw UnimplementedError();
  }

  /// Writes a [value] to a [characteristicUuid].
  ///
  /// The [value] must be a list of bytes.
  Future<void> writeCharacteristic(
    DeviceIdentifier remoteId,
    Guid serviceUuid,
    Guid characteristicUuid,
    List<int> value,
    WriteType writeType, {
    bool allowLongWrite = false,
  }) {
    throw UnimplementedError();
  }

  /// Writes a [value] to a [descriptorUuid].
  ///
  /// The [value] must be a list of bytes.
  Future<void> writeDescriptor(
    DeviceIdentifier remoteId,
    Guid serviceUuid,
    Guid characteristicUuid,
    Guid descriptorUuid,
    List<int> value,
  ) {
    throw UnimplementedError();
  }
}
