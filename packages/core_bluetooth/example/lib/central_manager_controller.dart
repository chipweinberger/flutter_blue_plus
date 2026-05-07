import 'package:core_bluetooth/core_bluetooth.dart';

import 'utils/utils.dart';

final class ScanResult {
  const ScanResult({
    required this.peripheral,
    required this.advertisementData,
    required this.rssi,
  });

  final AdvertisementData advertisementData;
  final CBPeripheral peripheral;
  final int? rssi;
}

final class CentralManagerController extends CBCentralManagerDelegate {
  CentralManagerController._() {
    centralManager = CBCentralManager.shared;
    centralManager.delegate = this;
  }

  static final CentralManagerController instance = CentralManagerController._();

  late final CBCentralManager centralManager;

  final adapterState = StreamControllerReemit(initialValue: CBManagerState.unknown);
  final isScanning = StreamControllerReemit(initialValue: false);
  final scanResults = StreamControllerReemit<List<ScanResult>>(initialValue: const []);

  final _connectionStates = <String, StreamControllerReemit<CBPeripheralState>>{};
  final _isConnecting = <String, StreamControllerReemit<bool>>{};
  final _isDisconnecting = <String, StreamControllerReemit<bool>>{};

  Stream<CBPeripheralState> connectionState(CBPeripheral peripheral) {
    return _connectionStateController(peripheral).stream;
  }

  Stream<bool> isConnectingStream(CBPeripheral peripheral) {
    return _connectingController(peripheral).stream;
  }

  Stream<bool> isDisconnectingStream(CBPeripheral peripheral) {
    return _disconnectingController(peripheral).stream;
  }

  Future<List<CBPeripheral>> systemDevices(List<CBUUID> withServices) {
    return centralManager.retrieveConnectedPeripherals(withServices);
  }

  Future<void> startScan({
    List<CBUUID>? withServices,
    Duration? timeout,
  }) async {
    scanResults.add(const []);
    isScanning.add(true);
    try {
      await centralManager.scanForPeripherals(
        withServices: withServices,
        options: const CentralManagerScanOptions(
          allowDuplicates: true,
        ),
      );
      if (timeout != null) {
        Future<void>.delayed(timeout).then((_) {
          if (isScanning.value == true) {
            stopScan();
          }
        });
      }
    } catch (_) {
      isScanning.add(false);
      rethrow;
    }
  }

  Future<void> stopScan() async {
    await centralManager.stopScan();
    isScanning.add(false);
  }

  Future<void> connect(CBPeripheral peripheral) async {
    _connectingController(peripheral).add(true);
    _connectionStateController(peripheral).add(CBPeripheralState.connecting);
    try {
      await centralManager.connect(peripheral);
    } catch (_) {
      _connectingController(peripheral).add(false);
      _connectionStateController(peripheral).add(CBPeripheralState.disconnected);
      rethrow;
    }
  }

  Future<void> disconnect(CBPeripheral peripheral) async {
    _disconnectingController(peripheral).add(true);
    _connectionStateController(peripheral).add(CBPeripheralState.disconnecting);
    try {
      await centralManager.cancelPeripheralConnection(peripheral);
    } catch (_) {
      _disconnectingController(peripheral).add(false);
      _connectionStateController(peripheral).add(peripheral.state);
      rethrow;
    }
  }

  @override
  void centralManagerDidConnect(CBCentralManager central, CBPeripheral peripheral) {
    _connectingController(peripheral).add(false);
    _disconnectingController(peripheral).add(false);
    _connectionStateController(peripheral).add(CBPeripheralState.connected);
  }

  @override
  void centralManagerDidDisconnectPeripheral(
    CBCentralManager central,
    CBPeripheral peripheral,
    CBError? error, {
    double? timestamp,
    bool? isReconnecting,
  }) {
    _connectingController(peripheral).add(false);
    _disconnectingController(peripheral).add(false);
    _connectionStateController(peripheral).add(CBPeripheralState.disconnected);
  }

  @override
  void centralManagerDidDiscover(
    CBCentralManager central,
    CBPeripheral peripheral,
    AdvertisementData advertisementData,
    int? rssi,
  ) {
    final results = [...scanResults.value ?? const <ScanResult>[]];
    final next = ScanResult(
      peripheral: peripheral,
      advertisementData: advertisementData,
      rssi: rssi,
    );
    final existingIndex = results.indexWhere((result) => result.peripheral.identifier == peripheral.identifier);
    if (existingIndex >= 0) {
      results[existingIndex] = next;
    } else {
      results.add(next);
    }
    _connectionStateController(peripheral).add(peripheral.state);
    scanResults.add(results);
  }

  @override
  void centralManagerDidFailToConnect(
    CBCentralManager central,
    CBPeripheral peripheral,
    CBError? error,
  ) {
    _connectingController(peripheral).add(false);
    _disconnectingController(peripheral).add(false);
    _connectionStateController(peripheral).add(CBPeripheralState.disconnected);
  }

  @override
  void centralManagerDidUpdateState(CBCentralManager central) {
    adapterState.add(central.state);
    if (central.state != CBManagerState.poweredOn) {
      isScanning.add(false);
    }
  }

  StreamControllerReemit<CBPeripheralState> _connectionStateController(CBPeripheral peripheral) {
    return _connectionStates[peripheral.identifier.uuidString] ??=
        StreamControllerReemit(initialValue: peripheral.state);
  }

  StreamControllerReemit<bool> _connectingController(CBPeripheral peripheral) {
    return _isConnecting[peripheral.identifier.uuidString] ??= StreamControllerReemit(initialValue: false);
  }

  StreamControllerReemit<bool> _disconnectingController(CBPeripheral peripheral) {
    return _isDisconnecting[peripheral.identifier.uuidString] ??= StreamControllerReemit(initialValue: false);
  }
}

extension PeripheralConnectionX on CBPeripheral {
  Stream<CBPeripheralState> get connectionState {
    return CentralManagerController.instance.connectionState(this);
  }

  Stream<bool> get isConnecting {
    return CentralManagerController.instance.isConnectingStream(this);
  }

  Stream<bool> get isDisconnecting {
    return CentralManagerController.instance.isDisconnectingStream(this);
  }

  Future<void> connectAndUpdateStream() {
    return CentralManagerController.instance.connect(this);
  }

  Future<void> disconnectAndUpdateStream() {
    return CentralManagerController.instance.disconnect(this);
  }
}
