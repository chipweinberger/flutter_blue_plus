import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart';
import 'package:flutter/material.dart';

import '../central_manager_controller.dart';

class SystemDeviceTile extends StatefulWidget {
  const SystemDeviceTile({
    super.key,
    required this.device,
    required this.onOpen,
    required this.onConnect,
  });

  final CBPeripheral device;
  final VoidCallback onOpen;
  final VoidCallback onConnect;

  @override
  State<SystemDeviceTile> createState() => _SystemDeviceTileState();
}

class _SystemDeviceTileState extends State<SystemDeviceTile> {
  CBPeripheralState _connectionState = CBPeripheralState.disconnected;

  late StreamSubscription<CBPeripheralState> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.device.connectionState.listen((state) {
      _connectionState = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == CBPeripheralState.connected;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.device.name ?? widget.device.identifier.uuidString),
      subtitle: Text(widget.device.identifier.uuidString),
      trailing: ElevatedButton(
        onPressed: isConnected ? widget.onOpen : widget.onConnect,
        child: isConnected ? const Text('OPEN') : const Text('CONNECT'),
      ),
    );
  }
}
