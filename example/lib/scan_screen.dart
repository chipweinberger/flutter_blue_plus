import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'global.dart';
import 'widgets.dart';
import 'device_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _connectedDevices = [];
  List<ScanResult> _scanResults = [];

  late StreamSubscription<List<BluetoothDevice>> _connectedDevicesSubscription;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();

    // Initial data fetch
    FlutterBluePlus.connectedSystemDevices.then((devices) {
      _connectedDevices = devices;
      setState(() {});
    });

    _connectedDevicesSubscription = Stream.fromFuture(FlutterBluePlus.connectedSystemDevices).listen((devices) {
      _connectedDevices = devices;
      setState(() {});
    });

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      setState(() {});
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _connectedDevicesSubscription.cancel();
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future onStartScanPressed() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      Global.showSnackbar(ABC.b, prettyException("Start Scan Error:", e), success: false);
    }
    setState(() {}); // force refresh of connectedSystemDevices
  }

  Future onStopScanPressed() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      Global.showSnackbar(ABC.b, prettyException("Stop Scan Error:", e), success: false);
    }
  }

  void onConnectPressed(BluetoothDevice device) {
    MaterialPageRoute route = MaterialPageRoute(
        builder: (context) {
          Global.setIsConnectingOrDisconnecting(device.remoteId, true);
          device.connect(timeout: Duration(seconds: 35)).catchError((e) {
            Global.showSnackbar(ABC.c, prettyException("Connect Error:", e), success: false);
          }).then((v) {
            Global.setIsConnectingOrDisconnecting(device.remoteId, false);
          });
          return DeviceScreen(device: device);
        },
        settings: RouteSettings(name: '/DeviceScreen'));
    Navigator.of(context).push(route);
  }

  Future onRefresh() {
    if (FlutterBluePlus.isScanningNow == false) {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    }
    setState(() {});
    return Future.delayed(Duration(milliseconds: 500));
  }

  Widget buildScanButton(BuildContext context) {
    if (FlutterBluePlus.isScanningNow) {
      return FloatingActionButton(
        child: const Icon(Icons.stop),
        onPressed: onStopScanPressed,
        backgroundColor: Colors.red,
      );
    } else {
      return FloatingActionButton(child: const Text("SCAN"), onPressed: onStartScanPressed);
    }
  }

  List<Widget> _buildConnectedDeviceTiles(BuildContext context) {
    return _connectedDevices
        .map(
          (d) => ConnectedDeviceTile(
            device: d,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DeviceScreen(device: d),
                settings: RouteSettings(name: '/DeviceScreen'),
              ),
            ),
            onConnect: onConnectPressed,
          ),
        )
        .toList();
  }

  List<Widget> _buildScanResultTiles(BuildContext context) {
    return _scanResults
        .map(
          (r) => ScanResultTile(
            result: r,
            onTap: () => onConnectPressed(r.device),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Global.snackBarKeyB,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Find Devices'),
        ),
        body: RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ..._buildConnectedDeviceTiles(context),
                ..._buildScanResultTiles(context),
              ],
            ),
          ),
        ),
        floatingActionButton: buildScanButton(context),
      ),
    );
  }
}
