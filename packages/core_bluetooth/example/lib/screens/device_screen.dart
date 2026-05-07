import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart';
import 'package:flutter/material.dart';

import '../central_manager_controller.dart';
import '../utils/snackbar.dart';
import '../widgets/characteristic_tile.dart';
import '../widgets/descriptor_tile.dart';
import '../widgets/service_tile.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key, required this.device});

  final CBPeripheral device;

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  int? _rssi;
  CBPeripheralState _connectionState = CBPeripheralState.disconnected;
  List<CBService> _services = [];
  bool _isDiscoveringServices = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  late StreamSubscription<CBPeripheralState> _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<DidReadRssiResult> _didReadRssiSubscription;
  late StreamSubscription<DidDiscoverServicesResult> _didDiscoverServicesSubscription;
  late StreamSubscription<DidDiscoverCharacteristicsForServiceResult> _didDiscoverCharacteristicsSubscription;
  late StreamSubscription<DidDiscoverDescriptorsForCharacteristicResult> _didDiscoverDescriptorsSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == CBPeripheralState.connected) {
        _services = [];
        if (_rssi == null) {
          await widget.device.readRSSI();
        }
      }
      if (mounted) {
        setState(() {});
      }
    });

    _isConnectingSubscription = widget.device.isConnecting.listen((value) {
      _isConnecting = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isDisconnectingSubscription = widget.device.isDisconnecting.listen((value) {
      _isDisconnecting = value;
      if (mounted) {
        setState(() {});
      }
    });

    _didReadRssiSubscription = widget.device.onDidReadRSSI.listen((result) {
      _rssi = result.rssi;
      if (mounted) {
        setState(() {});
      }
    });

    _didDiscoverServicesSubscription = widget.device.onDidDiscoverServices.listen((result) async {
      _services = result.services ?? const [];
      if (mounted) {
        setState(() {});
      }
      for (final service in _services) {
        await widget.device.discoverCharacteristics(forService: service);
      }
    });

    _didDiscoverCharacteristicsSubscription =
        widget.device.onDidDiscoverCharacteristicsForService.listen((result) async {
      if (mounted) {
        setState(() {});
      }
      for (final characteristic in result.characteristics ?? const <CBCharacteristic>[]) {
        await widget.device.discoverDescriptors(characteristic);
      }
    });

    _didDiscoverDescriptorsSubscription = widget.device.onDidDiscoverDescriptorsForCharacteristic.listen((result) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    _didReadRssiSubscription.cancel();
    _didDiscoverServicesSubscription.cancel();
    _didDiscoverCharacteristicsSubscription.cancel();
    _didDiscoverDescriptorsSubscription.cancel();
    super.dispose();
  }

  bool get isConnected => _connectionState == CBPeripheralState.connected;

  Future<void> onConnectPressed() async {
    try {
      await widget.device.connectAndUpdateStream();
      Snackbar.show(ABC.c, "Connect: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Future<void> onCancelPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream();
      Snackbar.show(ABC.c, "Cancel: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Cancel Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Future<void> onDisconnectPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream();
      Snackbar.show(ABC.c, "Disconnect: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Disconnect Error:", e), success: false);
      print("$e backtrace: $backtrace");
    }
  }

  Future<void> onDiscoverServicesPressed() async {
    if (mounted) {
      setState(() {
        _isDiscoveringServices = true;
      });
    }
    try {
      await widget.device.discoverServices();
      Snackbar.show(ABC.c, "Discover Services: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Discover Services Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
    if (mounted) {
      setState(() {
        _isDiscoveringServices = false;
      });
    }
  }

  List<Widget> _buildServiceTiles() {
    return _services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles:
                (s.characteristics ?? const <CBCharacteristic>[]).map((c) => _buildCharacteristicTile(c)).toList(),
          ),
        )
        .toList();
  }

  CharacteristicTile _buildCharacteristicTile(CBCharacteristic c) {
    return CharacteristicTile(
      characteristic: c,
      descriptorTiles: (c.descriptors ?? const <CBDescriptor>[]).map((d) => DescriptorTile(descriptor: d)).toList(),
    );
  }

  Widget buildSpinner(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
        ),
      ),
    );
  }

  Widget buildRemoteId(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(widget.device.identifier.uuidString),
    );
  }

  Widget buildRssiTile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isConnected ? const Icon(Icons.bluetooth_connected) : const Icon(Icons.bluetooth_disabled),
        Text(
          ((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget buildGetServices(BuildContext context) {
    return IndexedStack(
      index: (_isDiscoveringServices) ? 1 : 0,
      children: <Widget>[
        TextButton(
          onPressed: onDiscoverServicesPressed,
          child: const Text("Get Services"),
        ),
        const IconButton(
          icon: SizedBox(
            width: 18.0,
            height: 18.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.grey),
            ),
          ),
          onPressed: null,
        ),
      ],
    );
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(
      children: [
        if (_isConnecting || _isDisconnecting) buildSpinner(context),
        ElevatedButton(
          onPressed: _isConnecting ? onCancelPressed : (isConnected ? onDisconnectPressed : onConnectPressed),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(
            _isConnecting ? "CANCEL" : (isConnected ? "DISCONNECT" : "CONNECT"),
            style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.name ?? widget.device.identifier.uuidString),
          actions: [buildConnectButton(context), const SizedBox(width: 15)],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              buildRemoteId(context),
              ListTile(
                leading: buildRssiTile(context),
                title: Text('Device is ${_connectionState.name}.'),
                trailing: buildGetServices(context),
              ),
              ..._buildServiceTiles(),
            ],
          ),
        ),
      ),
    );
  }
}
