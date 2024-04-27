import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart' as web;

class FlutterBluePlusWeb {
  static late Future<dynamic> Function(MethodCall) _methodCallHandler;

  static Map<DeviceIdentifier, web.BluetoothDevice> _devices = {};

  static setMethodCallHandler(methodCallHandler) {
    _methodCallHandler = methodCallHandler;
  }

  static Future invokeMethod(String method, [dynamic arguments]) async {
    if (method == "setOptions") {
    } else if (method == "flutterRestart") {
      // disconnect all devices
    } else if (method == "connectedCount") {
    } else if (method == "setLogLevel") {
    } else if (method == "isSupported") {
    } else if (method == "getAdapterState") {
    } else if (method == "turnOn") {
    } else if (method == "turnOff") {
    } else if (method == "startScan") {
      // parse arguments
      var settings = BmScanSettings.fromMap(arguments);
      if (settings.withServices.length != 1) {
        throw FlutterBluePlusException(ErrorPlatform.web, "startScan", -1, "on web, you must specify 1 withServices");
      }

      // filter
      var filterService = web.RequestFilterBuilder(services: [settings.withServices.first.str128]);

      // todo: support other filters

      // options
      var options = web.RequestOptionsBuilder([filterService]);

      // scan
      web.BluetoothDevice device = await web.FlutterWebBluetooth.instance.requestDevice(options);

      // remember device
      _devices[DeviceIdentifier(device.id)] = device;

      // convert to advertisement
      var adv = BmScanAdvertisement(
        remoteId: DeviceIdentifier(device.id),
        platformName: device.name ?? "Unknown",
        advName: device.name ?? "Unknown",
        connectable: true,
        txPowerLevel: 0,
        appearance: 0,
        manufacturerData: {},
        serviceData: {},
        serviceUuids: [],
        rssi: 0,
      );

      _methodCallHandler(MethodCall("OnScanResult", adv.toMap()));
    } else if (method == "stopScan") {
    } else if (method == "getSystemDevices") {
    } else if (method == "connect") {
    } else if (method == "disconnect") {
    } else if (method == "discoverServices") {
    } else if (method == "readCharacteristic") {
    } else if (method == "writeCharacteristic") {
    } else if (method == "readDescriptor") {
    } else if (method == "writeDescriptor") {
    } else if (method == "setNotifyValue") {
    } else if (method == "requestMtu") {
    } else if (method == "readRssi") {
    } else if (method == "requestConnectionPriority") {
      // unsupported
      throw FlutterBluePlusException(ErrorPlatform.web, "requestConnectionPriority", -1, "not supported on web");
    } else if (method == "getPhySupport") {
      // unsupported
      throw FlutterBluePlusException(ErrorPlatform.web, "getPhySupport", -1, "not supported on web");
    } else if (method == "setPreferredPhy") {
      // unsupported
      throw FlutterBluePlusException(ErrorPlatform.web, "setPreferredPhy", -1, "not supported on web");
    } else if (method == "getBondedDevices") {
      // unsupported
      throw FlutterBluePlusException(ErrorPlatform.web, "getBondedDevices", -1, "not supported on web");
    } else if (method == "createBond") {
      // unsupported
      throw FlutterBluePlusException(ErrorPlatform.web, "createBond", -1, "not supported on web");
    } else if (method == "removeBond") {
      // unsupported
      throw FlutterBluePlusException(ErrorPlatform.web, "removeBond", -1, "not supported on web");
    } else if (method == "clearGattCache") {
      // unsupported
      throw FlutterBluePlusException(ErrorPlatform.web, "clearGattCache", -1, "not supported on web");
    } else {
      // unsupported
      throw FlutterBluePlusException(ErrorPlatform.web, method, -1, "not supported on web");
    }

    return Future.delayed(Duration.zero);
  }
}
