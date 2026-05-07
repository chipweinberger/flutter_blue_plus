import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:core_bluetooth/core_bluetooth.dart';

import '../utils/snackbar.dart';

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({super.key, this.adapterState});

  final CBManagerState? adapterState;

  Widget buildBluetoothOffIcon(BuildContext context) {
    return const Icon(
      Icons.bluetooth_disabled,
      size: 200.0,
      color: Colors.white54,
    );
  }

  Widget buildTitle(BuildContext context) {
    String? state = adapterState?.toString().split(".").last;
    return Text(
      'Bluetooth Adapter is ${state ?? 'not available'}',
      style: Theme.of(context).primaryTextTheme.titleSmall?.copyWith(color: Colors.white),
    );
  }

  Widget buildTurnOnButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ElevatedButton(
        onPressed: null,
        child: const Text('TURN ON'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyA,
      child: Scaffold(
        backgroundColor: Colors.lightBlue,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              buildBluetoothOffIcon(context),
              buildTitle(context),
              if (!kIsWeb && Platform.isAndroid) buildTurnOnButton(context),
            ],
          ),
        ),
      ),
    );
  }
}
