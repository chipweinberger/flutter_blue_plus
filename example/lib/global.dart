import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum ABC {
  a,
  b,
  c,
}

class Global {
  static final snackBarKeyA = GlobalKey<ScaffoldMessengerState>();
  static final snackBarKeyB = GlobalKey<ScaffoldMessengerState>();
  static final snackBarKeyC = GlobalKey<ScaffoldMessengerState>();
  static final Map<DeviceIdentifier, ValueNotifier<bool>> isConnectingOrDisconnecting = {};
  static final Map<DeviceIdentifier, StreamController<List<BluetoothService>>> servicesStream = {};

  static GlobalKey<ScaffoldMessengerState> getSnackbar(ABC abc) {
    switch (abc) {
      case ABC.a:
        return snackBarKeyA;
      case ABC.b:
        return snackBarKeyB;
      case ABC.c:
        return snackBarKeyC;
    }
  }

  static showSnackbar(ABC abc, String msg, {required bool success}) {
    final snackBar = success
        ? SnackBar(content: Text(msg), backgroundColor: Colors.blue)
        : SnackBar(content: Text(msg), backgroundColor: Colors.red);
    getSnackbar(abc).currentState?.removeCurrentSnackBar();
    getSnackbar(abc).currentState?.showSnackBar(snackBar);
  }

  static getIsConnectingOrDisconnecting(DeviceIdentifier remoteId) {
    isConnectingOrDisconnecting[remoteId] ??= ValueNotifier(false);
    return isConnectingOrDisconnecting[remoteId]!.value;
  }

  static setIsConnectingOrDisconnecting(DeviceIdentifier remoteId, bool value) {
    isConnectingOrDisconnecting[remoteId] ??= ValueNotifier(false);
    isConnectingOrDisconnecting[remoteId]!.value = value;
  }

  static listenToIsConnectingOrDisconnecting(DeviceIdentifier remoteId, Function(bool) callback) {
    isConnectingOrDisconnecting[remoteId] ??= ValueNotifier(false);
    isConnectingOrDisconnecting[remoteId]!.addListener(() {
      callback(isConnectingOrDisconnecting[remoteId]!.value);
    });
  }
}
