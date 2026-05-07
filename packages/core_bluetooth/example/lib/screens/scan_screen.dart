import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart';
import 'package:flutter/material.dart';

import '../central_manager_controller.dart';
import '../utils/snackbar.dart';
import '../widgets/scan_result_tile.dart';
import '../widgets/system_device_tile.dart';
import 'device_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _bluetooth = CentralManagerController.instance;

  List<CBPeripheral> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = _bluetooth.scanResults.stream.listen((results) {
      if (mounted) {
        setState(() => _scanResults = results);
      }
    }, onError: (e) {
      Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
    });

    _isScanningSubscription = _bluetooth.isScanning.stream.listen((state) {
      if (mounted) {
        setState(() => _isScanning = state);
      }
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future<void> onScanPressed() async {
    try {
      final withServices = [CBUUID("180f")];
      _systemDevices = await _bluetooth.systemDevices(withServices);
    } catch (e, backtrace) {
      Snackbar.show(ABC.b, prettyException("System Devices Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }

    try {
      await _bluetooth.startScan(
        withServices: [],
        timeout: const Duration(seconds: 15),
      );
    } catch (e, backtrace) {
      Snackbar.show(ABC.b, prettyException("Start Scan Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> onStopPressed() async {
    try {
      await _bluetooth.stopScan();
    } catch (e, backtrace) {
      Snackbar.show(ABC.b, prettyException("Stop Scan Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  void onConnectPressed(CBPeripheral device) {
    device.connectAndUpdateStream().catchError((e) {
      Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
    });
    final route = MaterialPageRoute(
      builder: (context) => DeviceScreen(device: device),
      settings: const RouteSettings(name: '/DeviceScreen'),
    );
    Navigator.of(context).push(route);
  }

  Future<void> onRefresh() async {
    if (_isScanning == false) {
      await _bluetooth.startScan(
        withServices: [CBUUID("180f")],
        timeout: const Duration(seconds: 15),
      );
    }
    if (mounted) {
      setState(() {});
    }
    return Future.delayed(const Duration(milliseconds: 500));
  }

  Widget buildScanButton() {
    final button = _isScanning
        ? ElevatedButton(
            onPressed: onStopPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text("STOP"),
          )
        : ElevatedButton(
            onPressed: onScanPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("SCAN"),
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isScanning) buildSpinner(),
        button,
      ],
    );
  }

  Widget buildSpinner() {
    return const Padding(
      padding: EdgeInsets.only(right: 20.0),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }

  List<Widget> _buildSystemDeviceTiles() {
    return _systemDevices
        .map(
          (d) => SystemDeviceTile(
            device: d,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DeviceScreen(device: d),
                settings: const RouteSettings(name: '/DeviceScreen'),
              ),
            ),
            onConnect: () => onConnectPressed(d),
          ),
        )
        .toList();
  }

  Iterable<Widget> _buildScanResultTiles() {
    return _scanResults.map((r) => ScanResultTile(result: r, onTap: () => onConnectPressed(r.peripheral)));
  }

  @override
  Widget build(BuildContext context) {
    final systemDeviceTiles = _buildSystemDeviceTiles();
    final scanResultTiles = _buildScanResultTiles().toList();
    final showSectionHeaders = systemDeviceTiles.isNotEmpty;

    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyB,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Find Devices'),
          actions: [buildScanButton(), const SizedBox(width: 15)],
        ),
        body: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            children: <Widget>[
              if (showSectionHeaders) _buildSectionHeader('SYSTEM CONNECTED'),
              ...systemDeviceTiles,
              if (showSectionHeaders) _buildSectionHeader('SCANNED DEVICES'),
              ...scanResultTiles,
            ],
          ),
        ),
      ),
    );
  }
}
