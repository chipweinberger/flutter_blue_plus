import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';

class FlutterBluePlusMacos extends FlutterBluePlusPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_blue_plus/methods');

  var _initialized = false;
  var _logLevel = LogLevel.none;

  final _onAdapterStateChangedController = StreamController<BmBluetoothAdapterState>.broadcast();
  final _onCharacteristicReceivedController = StreamController<BmCharacteristicData>.broadcast();
  final _onCharacteristicWrittenController = StreamController<BmCharacteristicData>.broadcast();
  final _onConnectionStateChangedController = StreamController<BmConnectionStateResponse>.broadcast();
  final _onDescriptorReadController = StreamController<BmDescriptorData>.broadcast();
  final _onDescriptorWrittenController = StreamController<BmDescriptorData>.broadcast();
  final _onDiscoveredServicesController = StreamController<BmDiscoverServicesResult>.broadcast();
  final _onMtuChangedController = StreamController<BmMtuChangedResponse>.broadcast();
  final _onNameChangedController = StreamController<BmNameChanged>.broadcast();
  final _onReadRssiController = StreamController<BmReadRssiResult>.broadcast();
  final _onScanResponseController = StreamController<BmScanResponse>.broadcast();
  final _onServicesResetController = StreamController<BmBluetoothDevice>.broadcast();

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged {
    return _onAdapterStateChangedController.stream;
  }

  @override
  Stream<BmCharacteristicData> get onCharacteristicReceived {
    return _onCharacteristicReceivedController.stream;
  }

  @override
  Stream<BmCharacteristicData> get onCharacteristicWritten {
    return _onCharacteristicWrittenController.stream;
  }

  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged {
    return _onConnectionStateChangedController.stream;
  }

  @override
  Stream<BmDescriptorData> get onDescriptorRead {
    return _onDescriptorReadController.stream;
  }

  @override
  Stream<BmDescriptorData> get onDescriptorWritten {
    return _onDescriptorWrittenController.stream;
  }

  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices {
    return _onDiscoveredServicesController.stream;
  }

  @override
  Stream<BmMtuChangedResponse> get onMtuChanged {
    return _onMtuChangedController.stream;
  }

  @override
  Stream<BmNameChanged> get onNameChanged {
    return _onNameChangedController.stream;
  }

  @override
  Stream<BmReadRssiResult> get onReadRssi {
    return _onReadRssiController.stream;
  }

  @override
  Stream<BmScanResponse> get onScanResponse {
    return _onScanResponseController.stream;
  }

  @override
  Stream<BmBluetoothDevice> get onServicesReset {
    return _onServicesResetController.stream;
  }

  static void registerWith() {
    FlutterBluePlusPlatform.instance = FlutterBluePlusMacos();
  }

  @override
  Future<void> connect(
    BmConnectRequest request,
  ) async {
    await _invokeMethod(
      'connect',
      request.toMap(),
    );
  }

  @override
  Future<void> disconnect(
    BmDisconnectRequest request,
  ) async {
    await _invokeMethod(
      'disconnect',
      request.remoteId.str,
    );
  }

  @override
  Future<void> discoverServices(
    BmDiscoverServicesRequest request,
  ) async {
    await _invokeMethod(
      'discoverServices',
      request.remoteId.str,
    );
  }

  @override
  Future<BmBluetoothAdapterName> getAdapterName(
    BmBluetoothAdapterNameRequest request,
  ) async {
    return BmBluetoothAdapterName(
      adapterName: await _invokeMethod(
        'getAdapterName',
      ),
    );
  }

  @override
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) async {
    return BmBluetoothAdapterState.fromMap(
      await _invokeMethod(
        'getAdapterState',
      ),
    );
  }

  @override
  Future<BmDevicesList> getSystemDevices(
    BmSystemDevicesRequest request,
  ) async {
    return BmDevicesList.fromMap(
      await _invokeMethod(
        'getSystemDevices',
        request.toMap(),
      ),
    );
  }

  @override
  Future<bool> isSupported(
    BmIsSupportedRequest request,
  ) async {
    return await _invokeMethod<bool>('isSupported') == true;
  }

  @override
  Future<void> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) async {
    await _invokeMethod(
      'readCharacteristic',
      request.toMap(),
    );
  }

  @override
  Future<void> readDescriptor(
    BmReadDescriptorRequest request,
  ) async {
    await _invokeMethod(
      'readDescriptor',
      request.toMap(),
    );
  }

  @override
  Future<void> readRssi(
    BmReadRssiRequest request,
  ) async {
    await _invokeMethod(
      'readRssi',
      request.remoteId.str,
    );
  }

  @override
  Future<void> setLogLevel(
    BmSetLogLevelRequest request,
  ) async {
    _logLevel = request.logLevel;

    await _invokeMethod(
      'setLogLevel',
      request.logLevel.index,
    );
  }

  @override
  Future<void> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) async {
    await _invokeMethod(
      'setNotifyValue',
      request.toMap(),
    );
  }

  @override
  Future<void> setOptions(
    BmSetOptionsRequest request,
  ) async {
    await _invokeMethod(
      'setOptions',
      request.toMap(),
    );
  }

  @override
  Future<void> startScan(
    BmScanSettings request,
  ) async {
    await _invokeMethod(
      'startScan',
      request.toMap(),
    );
  }

  @override
  Future<void> stopScan(
    BmStopScanRequest request,
  ) async {
    await _invokeMethod(
      'stopScan',
    );
  }

  @override
  Future<void> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) async {
    await _invokeMethod(
      'writeCharacteristic',
      request.toMap(),
    );
  }

  @override
  Future<void> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) async {
    await _invokeMethod(
      'writeDescriptor',
      request.toMap(),
    );
  }

  Future<T?> _invokeMethod<T>(
    String method, [
    dynamic arguments,
  ]) async {
    // initialize
    await _initFlutterBluePlus();

    // log args
    if (_logLevel == LogLevel.verbose) {
      print("[FBP] <$method> args: $arguments");
    }

    // invoke
    final result = await methodChannel.invokeMethod<T>(method, arguments);

    // log result
    if (_logLevel == LogLevel.verbose) {
      print("[FBP] ($method) result: $result");
    }

    return result;
  }

  Future<void> _initFlutterBluePlus() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    // set platform method handler
    methodChannel.setMethodCallHandler(_methodCallHandler);

    // flutter restart - wait for all devices to disconnect
    if ((await methodChannel.invokeMethod('flutterRestart')) != 0) {
      await Future.delayed(Duration(milliseconds: 50));
      while ((await methodChannel.invokeMethod('connectedCount')) != 0) {
        await Future.delayed(Duration(milliseconds: 50));
      }
    }
  }

  Future<void> _methodCallHandler(
    MethodCall call,
  ) async {
    // log result
    if (_logLevel == LogLevel.verbose) {
      if (call.method == 'OnDiscoveredServices') {
        // this is really slow so we can't pretty print anything that happens a lot
        print('[FBP] [[ ${call.method} ]] result: ${_prettyPrint(call.arguments)}');
      } else {
        print('[FBP] [[ ${call.method} ]] result: ${call.arguments}');
      }
    }

    // handle method call
    switch (call.method) {
      case 'OnAdapterStateChanged':
        return _onAdapterStateChangedController.add(
          BmBluetoothAdapterState.fromMap(
            call.arguments,
          ),
        );
      case 'OnCharacteristicReceived':
        return _onCharacteristicReceivedController.add(
          BmCharacteristicData.fromMap(
            call.arguments,
          ),
        );
      case 'OnCharacteristicWritten':
        return _onCharacteristicWrittenController.add(
          BmCharacteristicData.fromMap(
            call.arguments,
          ),
        );
      case 'OnConnectionStateChanged':
        return _onConnectionStateChangedController.add(
          BmConnectionStateResponse.fromMap(
            call.arguments,
          ),
        );
      case 'OnDescriptorRead':
        return _onDescriptorReadController.add(
          BmDescriptorData.fromMap(
            call.arguments,
          ),
        );
      case 'OnDescriptorWritten':
        return _onDescriptorWrittenController.add(
          BmDescriptorData.fromMap(
            call.arguments,
          ),
        );
      case 'OnDiscoveredServices':
        return _onDiscoveredServicesController.add(
          BmDiscoverServicesResult.fromMap(
            call.arguments,
          ),
        );
      case 'OnMtuChanged':
        return _onMtuChangedController.add(
          BmMtuChangedResponse.fromMap(
            call.arguments,
          ),
        );
      case 'OnNameChanged':
        return _onNameChangedController.add(
          BmNameChanged.fromMap(
            call.arguments,
          ),
        );
      case 'OnReadRssi':
        return _onReadRssiController.add(
          BmReadRssiResult.fromMap(
            call.arguments,
          ),
        );
      case 'OnScanResponse':
        return _onScanResponseController.add(
          BmScanResponse.fromMap(
            call.arguments,
          ),
        );
      case 'OnServicesReset':
        return _onServicesResetController.add(
          BmBluetoothDevice.fromMap(
            call.arguments,
          ),
        );
    }
  }

  String _prettyPrint(
    dynamic data,
  ) {
    if (data is Map || data is List) {
      return JsonEncoder.withIndent('  ').convert(data);
    } else {
      return data.toString();
    }
  }
}
