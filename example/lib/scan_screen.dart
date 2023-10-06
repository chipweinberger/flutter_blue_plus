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
  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: snackBarKeyB,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Find Devices'),
        ),
        body: RefreshIndicator(
          onRefresh: () {
            setState(() {}); // force refresh of connectedSystemDevices
            if (FlutterBluePlus.isScanningNow == false) {
              FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
            }
            return Future.delayed(Duration(milliseconds: 500)); // show refresh icon breifly
          },
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                StreamBuilder<List<BluetoothDevice>>(
                  stream: Stream.fromFuture(FlutterBluePlus.connectedSystemDevices),
                  initialData: const [],
                  builder: (c, snapshot) => Column(
                    children: (snapshot.data ?? [])
                        .map((d) => ListTile(
                              title: Text(d.platformName),
                              subtitle: Text(d.remoteId.toString()),
                              trailing: StreamBuilder<BluetoothConnectionState>(
                                stream: d.connectionState,
                                initialData: BluetoothConnectionState.disconnected,
                                builder: (c, snapshot) {
                                  if (snapshot.data == BluetoothConnectionState.connected) {
                                    return ElevatedButton(
                                      child: const Text('OPEN'),
                                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                          builder: (context) => DeviceScreen(device: d),
                                          settings: RouteSettings(name: '/DeviceScreen'))),
                                    );
                                  }
                                  if (snapshot.data == BluetoothConnectionState.disconnected) {
                                    return ElevatedButton(
                                        child: const Text('CONNECT'),
                                        onPressed: () {
                                          Navigator.of(context).push(MaterialPageRoute(
                                              builder: (context) {
                                                isConnectingOrDisconnecting[d.remoteId] ??= ValueNotifier(true);
                                                isConnectingOrDisconnecting[d.remoteId]!.value = true;
                                                d.connect(timeout: Duration(seconds: 35)).catchError((e) {
                                                  final snackBar = snackBarFail(prettyException("Connect Error:", e));
                                                  snackBarKeyC.currentState?.removeCurrentSnackBar();
                                                  snackBarKeyC.currentState?.showSnackBar(snackBar);
                                                }).then((v) {
                                                  isConnectingOrDisconnecting[d.remoteId] ??= ValueNotifier(false);
                                                  isConnectingOrDisconnecting[d.remoteId]!.value = false;
                                                });
                                                return DeviceScreen(device: d);
                                              },
                                              settings: RouteSettings(name: '/DeviceScreen')));
                                        });
                                  }
                                  return Text(snapshot.data.toString().toUpperCase().split('.')[1]);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
                StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  initialData: const [],
                  builder: (c, snapshot) => Column(
                    children: (snapshot.data ?? [])
                        .map(
                          (r) => ScanResultTile(
                            result: r,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) {
                                  isConnectingOrDisconnecting[r.device.remoteId] ??= ValueNotifier(true);
                                  isConnectingOrDisconnecting[r.device.remoteId]!.value = true;
                                  r.device.connect(timeout: Duration(seconds: 35)).catchError((e) {
                                    final snackBar = snackBarFail(prettyException("Connect Error:", e));
                                    snackBarKeyC.currentState?.removeCurrentSnackBar();
                                    snackBarKeyC.currentState?.showSnackBar(snackBar);
                                  }).then((v) {
                                    isConnectingOrDisconnecting[r.device.remoteId] ??= ValueNotifier(false);
                                    isConnectingOrDisconnecting[r.device.remoteId]!.value = false;
                                  });
                                  return DeviceScreen(device: r.device);
                                },
                                settings: RouteSettings(name: '/DeviceScreen'))),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: StreamBuilder<bool>(
          stream: FlutterBluePlus.isScanning,
          initialData: false,
          builder: (c, snapshot) {
            if (snapshot.data ?? false) {
              return FloatingActionButton(
                child: const Icon(Icons.stop),
                onPressed: () async {
                  try {
                    FlutterBluePlus.stopScan();
                  } catch (e) {
                    final snackBar = snackBarFail(prettyException("Stop Scan Error:", e));
                    snackBarKeyB.currentState?.removeCurrentSnackBar();
                    snackBarKeyB.currentState?.showSnackBar(snackBar);
                  }
                },
                backgroundColor: Colors.red,
              );
            } else {
              return FloatingActionButton(
                  child: const Text("SCAN"),
                  onPressed: () async {
                    try {
                      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
                    } catch (e) {
                      final snackBar = snackBarFail(prettyException("Start Scan Error:", e));
                      snackBarKeyB.currentState?.removeCurrentSnackBar();
                      snackBarKeyB.currentState?.showSnackBar(snackBar);
                    }
                    setState(() {}); // force refresh of connectedSystemDevices
                  });
            }
          },
        ),
      ),
    );
  }
}
