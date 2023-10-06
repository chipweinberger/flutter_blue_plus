import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'widgets.dart';
import 'device_screen.dart';
import 'main.dart';

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
      final snackBar = snackBarFail(prettyException("Start Scan Error:", e));
      snackBarKeyB.currentState?.removeCurrentSnackBar();
      snackBarKeyB.currentState?.showSnackBar(snackBar);
    }
    setState(() {}); // force refresh of connectedSystemDevices
  }

  Future onStopScanPressed() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      final snackBar = snackBarFail(prettyException("Stop Scan Error:", e));
      snackBarKeyB.currentState?.removeCurrentSnackBar();
      snackBarKeyB.currentState?.showSnackBar(snackBar);
    }
  }

  void onConnectPressed(BluetoothDevice device) {
    MaterialPageRoute route = MaterialPageRoute(
        builder: (context) {
          isConnectingOrDisconnecting[device.remoteId] ??= ValueNotifier(true);
          isConnectingOrDisconnecting[device.remoteId]!.value = true;
          device.connect(timeout: Duration(seconds: 35)).catchError((e) {
            final snackBar = snackBarFail(prettyException("Connect Error:", e));
            snackBarKeyC.currentState?.removeCurrentSnackBar();
            snackBarKeyC.currentState?.showSnackBar(snackBar);
          }).then((v) {
            isConnectingOrDisconnecting[device.remoteId]!.value = false;
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
    return _connectedDevices.map(
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
    ).toList();
  }

  List<Widget> _buildScanResultTiles(BuildContext context) {
    return _scanResults.map(
      (r) => ScanResultTile(
        result: r,
        onTap: () => onConnectPressed(r.device),
      ),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: snackBarKeyB,
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
