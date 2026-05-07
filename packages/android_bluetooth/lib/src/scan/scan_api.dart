import 'dart:async';

import '../internal/channels.dart';
import 'scan_filter.dart';
import 'scan_settings.dart';
import 'scan_result.dart';
import 'scan_types.dart';

final class BluetoothScanApi {
  BluetoothScanApi._();

  static Stream<BluetoothScanBatchResultsEvent>? _scanBatchResults;
  static Stream<BluetoothScanResult>? _scanResults;
  static Stream<BluetoothScanFailedEvent>? _scanFailed;

  static Future<bool> isScanning() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('isScanning')) ?? false;
  }

  static Future<bool> startScan({
    List<BluetoothScanFilter> filters = const [],
    BluetoothScanSettings settings = const BluetoothScanSettings(),
  }) async {
    return (await BluetoothChannels.method.invokeMethod<bool>('startScan', {
          'filters': filters.map((filter) => filter.toMap()).toList(),
          'settings': settings.toMap(),
        })) ??
        false;
  }

  static Future<bool> stopScan() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('stopScan')) ?? false;
  }

  static Future<bool> flushPendingScanResults() async {
    return (await BluetoothChannels.method.invokeMethod<bool>('flushPendingScanResults')) ?? false;
  }

  static Stream<BluetoothScanResult> get onScanResult {
    return _scanResults ??= BluetoothChannels.scanResults.receiveBroadcastStream().map((dynamic event) {
      return BluetoothScanResult.fromMap(event as Map<Object?, Object?>);
    });
  }

  static Stream<BluetoothScanBatchResultsEvent> get onBatchScanResults {
    return _scanBatchResults ??= BluetoothChannels.scanBatchResults.receiveBroadcastStream().map((dynamic event) {
      return BluetoothScanBatchResultsEvent.fromList((event as List<Object?>));
    });
  }

  static Stream<BluetoothScanFailedEvent> get onScanFailed {
    return _scanFailed ??= BluetoothChannels.scanFailed.receiveBroadcastStream().map((dynamic event) {
      return BluetoothScanFailedEvent.fromMap(event as Map<Object?, Object?>);
    });
  }
}
