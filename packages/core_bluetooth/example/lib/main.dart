import 'dart:async';

import 'package:core_bluetooth/core_bluetooth.dart';
import 'package:flutter/material.dart';

import 'screens/bluetooth_off_screen.dart';
import 'screens/scan_screen.dart';
import 'central_manager_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CentralManagerController.instance;
  runApp(const CoreBluetoothApp());
}

class CoreBluetoothApp extends StatefulWidget {
  const CoreBluetoothApp({super.key});

  @override
  State<CoreBluetoothApp> createState() => _CoreBluetoothAppState();
}

class _CoreBluetoothAppState extends State<CoreBluetoothApp> {
  CBManagerState _adapterState = CBManagerState.unknown;

  late StreamSubscription<CBManagerState> _adapterStateSubscription;

  @override
  void initState() {
    super.initState();
    _adapterStateSubscription = CentralManagerController.instance.adapterState.stream.listen((state) {
      _adapterState = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _adapterStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = _adapterState == CBManagerState.poweredOn
        ? const ScanScreen()
        : BluetoothOffScreen(adapterState: _adapterState);

    return MaterialApp(
      color: Colors.lightBlue,
      debugShowCheckedModeBanner: false,
      home: screen,
      navigatorObservers: [BluetoothAdapterStateObserver()],
    );
  }
}

class BluetoothAdapterStateObserver extends NavigatorObserver {
  StreamSubscription<CBManagerState>? _adapterStateSubscription;

  @override
  void didPush(Route route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/DeviceScreen') {
      _adapterStateSubscription ??= CentralManagerController.instance.adapterState.stream.listen((state) {
        if (state != CBManagerState.poweredOn) {
          navigator?.pop();
        }
      });
    }
  }

  @override
  void didPop(Route route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}
