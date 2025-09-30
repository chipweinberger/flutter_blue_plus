import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vx_flutter_blue_platform_interface/vx_flutter_blue_platform_interface.dart';

final class FlutterBluePlusAndroid extends FlutterBluePlusPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('vx_flutter_blue/methods');

  var _didRestart = false;
  var _logLevel = LogLevel.none;
  var _logColor = true;

  final _onAdapterStateChangedController = StreamController<BmBluetoothAdapterState>.broadcast();
  final _onBondStateChangedController = StreamController<BmBondStateResponse>.broadcast();
  final _onCharacteristicReceivedController = StreamController<BmCharacteristicData>.broadcast();
  final _onCharacteristicWrittenController = StreamController<BmCharacteristicData>.broadcast();
  final _onConnectionStateChangedController = StreamController<BmConnectionStateResponse>.broadcast();
  final _onDescriptorReadController = StreamController<BmDescriptorData>.broadcast();
  final _onDescriptorWrittenController = StreamController<BmDescriptorData>.broadcast();
  final _onDetachedFromEngineController = StreamController<BmDetachedFromEngineResponse>.broadcast();
  final _onDiscoveredServicesController = StreamController<BmDiscoverServicesResult>.broadcast();
  final _onMtuChangedController = StreamController<BmMtuChangedResponse>.broadcast();
  final _onNameChangedController = StreamController<BmNameChanged>.broadcast();
  final _onReadRssiController = StreamController<BmReadRssiResult>.broadcast();
  final _onScanResponseController = StreamController<BmScanResponse>.broadcast();
  final _onServicesResetController = StreamController<BmBluetoothDevice>.broadcast();
  final _onTurnOnResponseController = StreamController<BmTurnOnResponse>.broadcast();

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged {
    return _onAdapterStateChangedController.stream;
  }

  @override
  Stream<BmBondStateResponse> get onBondStateChanged {
    return _onBondStateChangedController.stream;
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
  Stream<BmDetachedFromEngineResponse> get onDetachedFromEngine {
    return _onDetachedFromEngineController.stream;
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

  @override
  Stream<BmTurnOnResponse> get onTurnOnResponse {
    return _onTurnOnResponseController.stream;
  }

  static void registerWith() {
    FlutterBluePlusPlatform.instance = FlutterBluePlusAndroid();
  }

  @override
  Future<bool> clearGattCache(
    BmClearGattCacheRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'clearGattCache',
      request.remoteId.str,
    ) == true;
  }

  @override
  Future<bool> connect(
    BmConnectRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'connect',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> createBond(
    BmCreateBondRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'createBond',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> disconnect(
    BmDisconnectRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'disconnect',
      request.remoteId.str,
    ) == true;
  }

  @override
  Future<bool> discoverServices(
    BmDiscoverServicesRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'discoverServices',
      request.remoteId.str,
    ) == true;
  }

  @override
  Future<BmBluetoothAdapterName> getAdapterName(
    BmBluetoothAdapterNameRequest request,
  ) async {
    return BmBluetoothAdapterName(
      adapterName: await _callAndroidMethod(
        'getAdapterName',
      ),
    );
  }

  @override
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) async {
    return BmBluetoothAdapterState.fromMap(
      await _callAndroidMethod(
        'getAdapterState',
      ),
    );
  }

  @override
  Future<BmBondStateResponse> getBondState(
    BmBondStateRequest request,
  ) async {
    return BmBondStateResponse.fromMap(
      await _callAndroidMethod(
        'getBondState',
        request.remoteId.str,
      ),
    );
  }

  @override
  Future<BmDevicesList> getBondedDevices(
    BmBondedDevicesRequest request,
  ) async {
    return BmDevicesList.fromMap(
      await _callAndroidMethod(
        'getBondedDevices',
      ),
    );
  }

  @override
  Future<PhySupport> getPhySupport(
    PhySupportRequest request,
  ) async {
    return PhySupport.fromMap(
      await _callAndroidMethod(
        'getPhySupport',
      ),
    );
  }

  @override
  Future<BmDevicesList> getSystemDevices(
    BmSystemDevicesRequest request,
  ) async {
    return BmDevicesList.fromMap(
      await _callAndroidMethod(
        'getSystemDevices',
      ),
    );
  }

  @override
  Future<bool> isSupported(
    BmIsSupportedRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'isSupported',
    ) == true;
  }

  @override
  Future<bool> readCharacteristic(
    BmReadCharacteristicRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'readCharacteristic',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> readDescriptor(
    BmReadDescriptorRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'readDescriptor',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> readRssi(
    BmReadRssiRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'readRssi',
      request.remoteId.str,
    ) == true;
  }

  @override
  Future<bool> removeBond(
    BmRemoveBondRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'removeBond',
      request.remoteId.str,
    ) == true;
  }

  @override
  Future<bool> requestConnectionPriority(
    BmConnectionPriorityRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'requestConnectionPriority',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> requestMtu(
    BmMtuChangeRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'requestMtu',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> setLogLevel(
    BmSetLogLevelRequest request,
  ) async {
    _logLevel = request.logLevel;
    _logColor = request.logColor;

    return await _callAndroidMethod<bool>(
      'setLogLevel',
      request.logLevel.index,
    ) == true;
  }

  @override
  Future<bool> setNotifyValue(
    BmSetNotifyValueRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'setNotifyValue',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> setOptions(
    BmSetOptionsRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'setOptions',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> setPreferredPhy(
    BmPreferredPhy request,
  ) async {
    return await _callAndroidMethod<bool>(
      'setPreferredPhy',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> startScan(
    BmScanSettings request,
  ) async {
    return await _callAndroidMethod<bool>(
      'startScan',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> stopScan(
    BmStopScanRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'stopScan',
    ) == true;
  }

  @override
  Future<bool> turnOff(
    BmTurnOffRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'turnOff',
    ) == true;
  }

  @override
  Future<bool> turnOn(
    BmTurnOnRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'turnOn',
    ) == true;
  }

  @override
  Future<bool> writeCharacteristic(
    BmWriteCharacteristicRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'writeCharacteristic',
      request.toMap(),
    ) == true;
  }

  @override
  Future<bool> writeDescriptor(
    BmWriteDescriptorRequest request,
  ) async {
    return await _callAndroidMethod<bool>(
      'writeDescriptor',
      request.toMap(),
    ) == true;
  }

  Future<T?> _callAndroidMethod<T>(
    String method, [
    dynamic arguments,
  ]) async {
    // restart platform
    if (!_didRestart && method != "setLogLevel") {
      await _flutterRestart();
    }

    // set platform method handler
    methodChannel.setMethodCallHandler(_methodCallHandler);

    // log args
    if (_logLevel == LogLevel.verbose) {
      var func = '<$method>';
      var args = arguments.toString();
      func = _logColor ? '\x1B[1;30m$func\x1B[0m' : func;
      args = _logColor ? '\x1B[1;35m$args\x1B[0m' : args;
      FlutterBluePlusPlatform.log('[FBP] $func args: $args');
    }

    // invoke
    final out = await methodChannel.invokeMethod<T>(method, arguments);

    // log result
    if (_logLevel == LogLevel.verbose) {
      var func = '($method)';
      var result = out.toString();
      func = _logColor ? '\x1B[1;30m$func\x1B[0m' : func;
      result = _logColor ? '\x1B[1;33m$result\x1B[0m' : result;
      FlutterBluePlusPlatform.log('[FBP] $func result: $result');
    }

    return out;
  }

  Future<void> _flutterRestart() async {
    // wait for all devices to disconnect
    if ((await methodChannel.invokeMethod('flutterRestart')) != 0) {
      await Future.delayed(Duration(milliseconds: 50));
      while ((await methodChannel.invokeMethod('connectedCount')) != 0) {
        await Future.delayed(Duration(milliseconds: 50));
      }
    }
    _didRestart = true;
  }

  Future<void> _methodCallHandler(
    MethodCall call,
  ) async {
    // log result
    if (_logLevel == LogLevel.verbose) {
      var func = '[[ ${call.method} ]]';
      var result = switch (call.method) {
        'OnDiscoveredServices' => _prettyPrint(call.arguments),
        _ => call.arguments.toString(),
      };
      func = _logColor ? '\x1B[1;30m$func\x1B[0m' : func;
      result = _logColor ? '\x1B[1;33m$result\x1B[0m' : result;
      FlutterBluePlusPlatform.log('[FBP] $func result: $result');
    }

    // handle method call
    switch (call.method) {
      case 'OnAdapterStateChanged':
        return _onAdapterStateChangedController.add(
          BmBluetoothAdapterState.fromMap(
            call.arguments,
          ),
        );
      case 'OnBondStateChanged':
        return _onBondStateChangedController.add(
          BmBondStateResponse.fromMap(
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
      case 'OnDetachedFromEngine':
        return _onDetachedFromEngineController.add(
          BmDetachedFromEngineResponse(),
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
      case 'OnTurnOnResponse':
        return _onTurnOnResponseController.add(
          BmTurnOnResponse.fromMap(
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
