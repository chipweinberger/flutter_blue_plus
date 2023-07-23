// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'widgets.dart';

void main() {
  if (Platform.isAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    [
      Permission.location,
      Permission.storage,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan
    ].request().then((status) {
      runApp(const FlutterBlueApp());
    });
  } else {
    runApp(const FlutterBlueApp());
  }
}

class FlutterBlueApp extends StatelessWidget {
  const FlutterBlueApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothAdapterState>(
          stream: FlutterBluePlus.instance.adapterState,
          initialData: BluetoothAdapterState.unknown,
          builder: (c, snapshot) {
            final adapterState = snapshot.data;
            if (adapterState == BluetoothAdapterState.on) {
              return const FindDevicesScreen();
            }
            return BluetoothOffScreen(adapterState: adapterState);
          }),
    );
  }
}

class BluetoothOffScreen extends StatefulWidget {
  const BluetoothOffScreen({Key? key, this.adapterState}) : super(key: key);

  final BluetoothAdapterState? adapterState;

  @override
  State<BluetoothOffScreen> createState() => _BluetoothOffScreenState();
}

class _BluetoothOffScreenState extends State<BluetoothOffScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${widget.adapterState != null ? widget.adapterState.toString().split(".").last : 'not available'}.',
              style: Theme.of(context).primaryTextTheme.titleSmall?.copyWith(color: Colors.white),
            ),
            ElevatedButton(
              child: const Text('TURN ON'),
              onPressed: () async {
                try {
                  if (Platform.isAndroid) {
                    FlutterBluePlus.instance.turnOn();
                  }
                } catch (e) {
                  if (mounted) {
                    final snackBar = SnackBar(content: Text('Error: [turnOn] ${e.toString()}'));
                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatefulWidget {
  const FindDevicesScreen({Key? key}) : super(key: key);

  @override
  State<FindDevicesScreen> createState() => _FindDevicesScreenState();
}

class _FindDevicesScreenState extends State<FindDevicesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Devices'),
        actions: [
          if (Platform.isAndroid)
            ElevatedButton(
              child: const Text('TURN OFF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: () => FlutterBluePlus.instance.turnOff(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBluePlus.instance.startScan(timeout: const Duration(seconds: 15), androidUsesFineLocation: false),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(const Duration(seconds: 2))
                    .asyncMap((_) => FlutterBluePlus.instance.connectedDevices),
                initialData: const [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map((d) => ListTile(
                            title: Text(d.localName),
                            subtitle: Text(d.remoteId.toString()),
                            trailing: StreamBuilder<BluetoothConnectionState>(
                              stream: d.connectionState,
                              initialData: BluetoothConnectionState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.data == BluetoothConnectionState.connected) {
                                  return ElevatedButton(
                                    child: const Text('OPEN'),
                                    onPressed: () => Navigator.of(context)
                                        .push(MaterialPageRoute(builder: (context) => DeviceScreen(device: d))),
                                  );
                                }
                                return Text(snapshot.data.toString());
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.instance.scanResults,
                initialData: const [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map(
                        (r) => ScanResultTile(
                          result: r,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                            r.device.connect().catchError((e) {
                              if (mounted) {
                                final snackBar = SnackBar(content: Text('Error: [connect] ${e.toString()}'));
                                ScaffoldMessenger.of(context).showSnackBar(snackBar);
                              }
                            });
                            return DeviceScreen(device: r.device);
                          })),
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
        stream: FlutterBluePlus.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: const Icon(Icons.stop),
              onPressed: () {
                FlutterBluePlus.instance.stopScan().catchError((e) {
                  if (mounted) {
                    final snackBar = SnackBar(content: Text('Error: [stopScan] ${e.toString()}'));
                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  }
                });
              },
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: const Icon(Icons.search),
                onPressed: () {
                  FlutterBluePlus.instance
                      .startScan(timeout: const Duration(seconds: 15), androidUsesFineLocation: false)
                      .catchError((e) {
                    if (mounted) {
                      final snackBar = SnackBar(content: Text('Error: [startScan] ${e.toString()}'));
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    }
                  });
                });
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  List<int> _getRandomBytes() {
    final math = Random();
    return [math.nextInt(255), math.nextInt(255), math.nextInt(255), math.nextInt(255)];
  }

  List<Widget> _buildServiceTiles(BuildContext context, List<BluetoothService> services) {
    return services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map(
                  (c) => CharacteristicTile(
                    characteristic: c,
                    onReadPressed: () async {
                      try {
                        await c.read();
                      } catch (e) {
                        if (mounted) {
                          final snackBar = SnackBar(content: Text('Error: [read] ${e.toString()}'));
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                        }
                      }
                    },
                    onWritePressed: () async {
                      try {
                        await c.write(_getRandomBytes(), withoutResponse: true);
                        if (c.properties.read) {
                          await c.read();
                        }
                      } catch (e) {
                        if (mounted) {
                          final snackBar = SnackBar(content: Text('Error: [write] ${e.toString()}'));
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                        }
                      }
                    },
                    onNotificationPressed: () async {
                      try {
                        await c.setNotifyValue(!c.isNotifying);
                        if (c.properties.read) {
                          await c.read();
                        }
                      } catch (e) {
                        if (mounted) {
                          final snackBar = SnackBar(content: Text('Error: [setNotifyValue] ${e.toString()}'));
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                        }
                      }
                    },
                    descriptorTiles: c.descriptors
                        .map(
                          (d) => DescriptorTile(
                            descriptor: d,
                            onReadPressed: () => d.read(),
                            onWritePressed: () => d.write(_getRandomBytes()),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.localName),
        actions: <Widget>[
          StreamBuilder<BluetoothConnectionState>(
            stream: widget.device.connectionState,
            initialData: BluetoothConnectionState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothConnectionState.connected:
                  onPressed = () async {
                    try {
                      await widget.device.disconnect();
                    } catch (e) {
                      if (mounted) {
                        final snackBar = SnackBar(content: Text('Error: [disconnect] ${e.toString()}'));
                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                      }
                    }
                  };
                  text = 'DISCONNECT';
                  break;
                case BluetoothConnectionState.disconnected:
                  onPressed = () async {
                    try {
                      await widget.device.connect();
                    } catch (e) {
                      if (mounted) {
                        final snackBar = SnackBar(content: Text('Error: [connect] ${e.toString()}'));
                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                      }
                    }
                  };
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().split(".").last.toUpperCase();
                  break;
              }
              return TextButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothConnectionState>(
              stream: widget.device.connectionState,
              initialData: BluetoothConnectionState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    snapshot.data == BluetoothConnectionState.connected
                        ? const Icon(Icons.bluetooth_connected)
                        : const Icon(Icons.bluetooth_disabled),
                    snapshot.data == BluetoothConnectionState.connected
                        ? StreamBuilder<int>(
                            stream: rssiStream(),
                            builder: (context, snapshot) {
                              return Text(snapshot.hasData ? '${snapshot.data}dBm' : '',
                                  style: Theme.of(context).textTheme.bodySmall);
                            })
                        : Text('', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                title: Text('Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${widget.device.remoteId}'),
                trailing: StreamBuilder<bool>(
                  stream: widget.device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      TextButton(
                        child: const Text("Discover Services"),
                        onPressed: () async {
                          try {
                            await widget.device.discoverServices();
                          } catch (e) {
                            if (mounted) {
                              final snackBar = SnackBar(content: Text('Error: [discoverServices] ${e.toString()}'));
                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                            }
                          }
                        },
                      ),
                      const IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<int>(
              stream: widget.device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: const Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      try {
                        await widget.device.requestMtu(223);
                      } catch (e) {
                        if (mounted) {
                          final snackBar = SnackBar(content: Text('Error: [requestMtu] ${e.toString()}'));
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                        }
                      }
                    }),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: widget.device.services,
              initialData: const [],
              builder: (c, snapshot) {
                return Column(
                  children: _buildServiceTiles(context, snapshot.data!),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Stream<int> rssiStream({Duration frequency = const Duration(seconds: 1)}) async* {
    var isConnected = true;
    final subscription = widget.device.connectionState.listen((v) {
      isConnected = v == BluetoothConnectionState.connected;
    });
    while (isConnected) {
      try {
        yield await widget.device.readRssi();
      } catch (e) {
        print("Error reading RSSI: $e");
        break;
      }
      await Future.delayed(frequency);
    }
    // Device disconnected, stopping RSSI stream
    subscription.cancel();
  }
}
