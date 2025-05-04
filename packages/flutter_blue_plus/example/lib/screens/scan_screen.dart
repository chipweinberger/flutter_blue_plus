import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'device_screen.dart';
import '../utils/snackbar.dart';
import '../widgets/system_device_tile.dart';
import '../widgets/scan_result_tile.dart';
import '../utils/extra.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() => _scanResults = results);
      }
    }, onError: (e) {
      Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
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

  Future onScanPressed() async {
    try {
      // `withServices` is required on iOS for privacy purposes, ignored on android.
      var withServices = [Guid("180f")]; // Battery Level Service
      _systemDevices = await FlutterBluePlus.systemDevices(withServices);
    } catch (e, backtrace) {
      Snackbar.show(ABC.b, prettyException("System Devices Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [
          // Guid("180f"), // battery
          // Guid("180a"), // device info
          // Guid("1800"), // generic access
          // Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e"), // Nordic UART
        ],
        webOptionalServices: [
          Guid("180f"), // battery
          Guid("180a"), // device info
          Guid("1800"), // generic access
          Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e"), // Nordic UART
        ],
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

  Future onStopPressed() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e, backtrace) {
      Snackbar.show(ABC.b, prettyException("Stop Scan Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  void onConnectPressed(BluetoothDevice device) {
    device.connectAndUpdateStream().catchError((e) {
      Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
    });
    MaterialPageRoute route = MaterialPageRoute(
        builder: (context) => DeviceScreen(device: device), settings: RouteSettings(name: '/DeviceScreen'));
    Navigator.of(context).push(route);
  }

  Future onRefresh() {
    if (_isScanning == false) {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    }
    if (mounted) {
      setState(() {});
    }
    return Future.delayed(Duration(milliseconds: 500));
  }

  Widget buildScanButton() {
    return Row(children: [
      if (FlutterBluePlus.isScanningNow)
        buildSpinner()
      else
        ElevatedButton(
            onPressed: onScanPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text("SCAN"))
    ]);
  }

  Widget buildSpinner() {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
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
                settings: RouteSettings(name: '/DeviceScreen'),
              ),
            ),
            onConnect: () => onConnectPressed(d),
          ),
        )
        .toList();
  }

  Iterable<Widget> _buildScanResultTiles() {
    return _scanResults.map((r) => ScanResultTile(result: r, onTap: () => onConnectPressed(r.device)));
  }

  @override
  Widget build(BuildContext context) {
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
              ..._buildSystemDeviceTiles(),
              ..._buildScanResultTiles(),
            ],
          ),
        ),
        // floatingActionButton: buildScanButton(context),
      ),
    );
  }
}
