import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'widgets.dart';
import 'main.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;
  late StreamSubscription<int> _rssiSubscription;
  late StreamSubscription<int> _mtuSubscription;
  late StreamSubscription<List<BluetoothService>> _servicesSubscription;

  @override
  void initState() {
    super.initState();

    isConnectingOrDisconnecting[widget.device.remoteId] ??= ValueNotifier(false);
    servicesStream[widget.device.remoteId] ??= StreamController<List<BluetoothService>>.broadcast();

    _connectionStateSubscription = widget.device.connectionState.listen((state) {
      _connectionState = state;
      setState(() {});
    });

    _rssiSubscription = rssiStream(maxItems: 1).listen((value) {
      _rssi = value;
      setState(() {});
    });

    _mtuSubscription = widget.device.mtu.listen((value) {
      _mtuSize = value;
      setState(() {});
    });

    _servicesSubscription = servicesStream[widget.device.remoteId]!.stream.listen((services) {
      _services = services;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _rssiSubscription.cancel();
    _mtuSubscription.cancel();
    _servicesSubscription.cancel();
    super.dispose();
  }

  List<int> _getRandomBytes() {
    final math = Random();
    return [math.nextInt(255), math.nextInt(255), math.nextInt(255), math.nextInt(255)];
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnectButtonPressed() async {
    isConnectingOrDisconnecting[widget.device.remoteId] ??= ValueNotifier(true);
    isConnectingOrDisconnecting[widget.device.remoteId]!.value = true;
    try {
      await widget.device.connect(timeout: Duration(seconds: 35));
      final snackBar = snackBarGood("Connect: Success");
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    } catch (e) {
      final snackBar = snackBarFail(prettyException("Connect Error:", e));
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    }
    isConnectingOrDisconnecting[widget.device.remoteId] ??= ValueNotifier(false);
    isConnectingOrDisconnecting[widget.device.remoteId]!.value = false;
  }

  Future onDisconnectButtonPressed() async {
    isConnectingOrDisconnecting[widget.device.remoteId] ??= ValueNotifier(true);
    isConnectingOrDisconnecting[widget.device.remoteId]!.value = true;
    try {
      await widget.device.disconnect();
      final snackBar = snackBarGood("Disconnect: Success");
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    } catch (e) {
      final snackBar = snackBarFail(prettyException("Disconnect Error:", e));
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    }
    isConnectingOrDisconnecting[widget.device.remoteId] ??= ValueNotifier(false);
    isConnectingOrDisconnecting[widget.device.remoteId]!.value = false;
  }

  Future onDiscoverServicesPressed() async {
    setState(() {
      _isDiscoveringServices = true;
    });
    try {
      await widget.device.discoverServices();
      servicesStream[widget.device.remoteId] ??= StreamController<List<BluetoothService>>.broadcast();
      servicesStream[widget.device.remoteId]!.add(widget.device.servicesList ?? []);
      final snackBar = snackBarGood("Discover Services: Success");
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    } catch (e) {
      final snackBar = snackBarFail(prettyException("Discover Services Error:", e));
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    }
    setState(() {
      _isDiscoveringServices = false;
    });
  }

  Future onRequestMtuPressed() async {
    try {
      await widget.device.requestMtu(223);
      final snackBar = snackBarGood("Request Mtu: Success");
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    } catch (e) {
      final snackBar = snackBarFail(prettyException("Change Mtu Error:", e));
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    }
  }

  Future onReadPressed(BluetoothCharacteristic c) async {
    try {
      await c.read();
      final snackBar = snackBarGood("Read: Success");
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    } catch (e) {
      final snackBar = snackBarFail(prettyException("Read Error:", e));
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    }
  }

  Future onWritePressed(BluetoothCharacteristic c) async {
    try {
      await c.write(_getRandomBytes(), withoutResponse: c.properties.writeWithoutResponse);
      final snackBar = snackBarGood("Write: Success");
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
      if (c.properties.read) {
        await c.read();
      }
    } catch (e) {
      final snackBar = snackBarFail(prettyException("Write Error:", e));
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    }
  }

  Future onSubscribePressed(BluetoothCharacteristic c) async {
    try {
      String op = c.isNotifying == false ? "Subscribe" : "Unubscribe";
      await c.setNotifyValue(c.isNotifying == false);
      final snackBar = snackBarGood("$op : Success");
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
      if (c.properties.read) {
        await c.read();
      }
    } catch (e) {
      final snackBar = snackBarFail(prettyException("Subscribe Error:", e));
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    }
  }

  Future onReadDescriptorPressed(BluetoothDescriptor d) async {
    try {
      await d.read();
      final snackBar = snackBarGood("Descriptor Read: Success");
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    } catch (e) {
      final snackBar = snackBarFail(prettyException("Descriptor Read Error:", e));
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    }
  }

  Future onWriteDescriptorPressed(BluetoothDescriptor d) async {
    try {
      await d.write(_getRandomBytes());
      final snackBar = snackBarGood("Descriptor Write: Success");
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    } catch (e) {
      final snackBar = snackBarFail(prettyException("Descriptor Write Error:", e));
      snackBarKeyC.currentState?.removeCurrentSnackBar();
      snackBarKeyC.currentState?.showSnackBar(snackBar);
    }
  }

  List<Widget> _buildServiceTiles(BuildContext context) {
    return _services.map(
      (s) => ServiceTile(
        service: s,
        characteristicTiles: s.characteristics
            .map((c) => _buildCharacteristicTile(c))
            .toList(),
      ),
    ).toList();
  }

  CharacteristicTile _buildCharacteristicTile(BluetoothCharacteristic c) {
    return CharacteristicTile(
      characteristic: c,
      onReadPressed: () => onReadPressed(c),
      onWritePressed: () => onWritePressed(c),
      onNotificationPressed: () => onSubscribePressed(c),
      descriptorTiles: c.descriptors.map(
        (d) => DescriptorTile(
          descriptor: d,
          onReadPressed: () => onReadDescriptorPressed(d),
          onWritePressed: () => onWriteDescriptorPressed(d),
        ),
      ).toList(),
    );
  }

  Widget buildSpinner(BuildContext context) {
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

  Widget buildConnectOrDisconnectButton(BuildContext context) {
    return TextButton(
        onPressed: isConnected ? onDisconnectButtonPressed : onConnectButtonPressed,
        child: Text(
          isConnected ? "DISCONNECT" : "CONNECT",
          style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(color: Colors.white),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName),
          actions: <Widget>[
            ValueListenableBuilder<bool>(
                valueListenable: isConnectingOrDisconnecting[widget.device.remoteId]!,
                builder: (context, value, child) {
                  if (isConnectingOrDisconnecting[widget.device.remoteId]!.value == true) {
                    return buildSpinner(context);
                  } else {
                    return buildConnectOrDisconnectButton(context);
                  }
                })
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('${widget.device.remoteId}'),
                  ),
                  ListTile(
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        isConnected ? const Icon(Icons.bluetooth_connected) : const Icon(Icons.bluetooth_disabled),
                        Text(((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''),
                            style: Theme.of(context).textTheme.bodySmall)
                      ],
                    ),
                    title: Text('Device is ${_connectionState.toString().split('.')[1]}.'),
                    trailing: IndexedStack(
                      index: (_isDiscoveringServices) ? 1 : 0,
                      children: <Widget>[
                        TextButton(
                          child: const Text("Get Services"),
                          onPressed: onDiscoverServicesPressed,
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
                ],
              ),
              ListTile(
                  title: const Text('MTU Size'),
                  subtitle: Text('$_mtuSize bytes'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: onRequestMtuPressed,
                  )),
              Column(
                children: _buildServiceTiles(context),
              )
            ],
          ),
        ),
      ),
    );
  }

  Stream<int> rssiStream({Duration frequency = const Duration(seconds: 5), int? maxItems = null}) async* {
    var isConnected = true;
    final subscription = widget.device.connectionState.listen((v) {
      isConnected = v == BluetoothConnectionState.connected;
    });
    int i = 0;
    while (isConnected && (maxItems == null || i < maxItems)) {
      try {
        yield await widget.device.readRssi();
      } catch (e) {
        print("Error reading RSSI: $e");
        break;
      }
      await Future.delayed(frequency);
      i++;
    }
    // Device disconnected, stopping RSSI stream
    subscription.cancel();
  }
}
