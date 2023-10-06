import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'widgets.dart';
import 'main.dart';

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.adapterState}) : super(key: key);

  final BluetoothAdapterState? adapterState;

  String get title {
    String? state = adapterState?.toString().split(".").last;
    return 'Bluetooth Adapter is ${state != null ? state : 'not available'}.';
  }

  TextStyle? titleStyle(BuildContext context) {
    return Theme.of(context).primaryTextTheme.titleSmall?.copyWith(color: Colors.white);
  }

  Widget buildTurnOnButton(BuildContext context) {
    return ElevatedButton(
      child: const Text('TURN ON'),
      onPressed: () async {
        try {
          if (Platform.isAndroid) {
            await FlutterBluePlus.turnOn();
          }
        } catch (e) {
          final snackBar = snackBarFail(prettyException("Error Turning On:", e));
          snackBarKeyA.currentState?.removeCurrentSnackBar();
          snackBarKeyA.currentState?.showSnackBar(snackBar);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: snackBarKeyA,
      child: Scaffold(
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
                title,
                style: titleStyle(context),
              ),
              if (Platform.isAndroid == false) buildTurnOnButton(context),
            ],
          ),
        ),
      ),
    );
  }
}
