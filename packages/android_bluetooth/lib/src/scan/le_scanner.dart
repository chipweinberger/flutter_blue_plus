import 'scan_api.dart';
import 'scan_filter.dart';
import 'scan_result.dart';
import 'scan_settings.dart';
import 'scan_types.dart';

final class BluetoothLeScanner {
  const BluetoothLeScanner._();

  static const instance = BluetoothLeScanner._();

  Future<bool> startScan({
    List<BluetoothScanFilter> filters = const [],
    BluetoothScanSettings settings = const BluetoothScanSettings(),
  }) async {
    return BluetoothScanApi.startScan(
      filters: filters,
      settings: settings,
    );
  }

  Future<bool> stopScan() async {
    return BluetoothScanApi.stopScan();
  }

  Future<bool> flushPendingScanResults() async {
    return BluetoothScanApi.flushPendingScanResults();
  }

  Stream<BluetoothScanResult> get onScanResult {
    return BluetoothScanApi.onScanResult;
  }

  Stream<BluetoothScanBatchResultsEvent> get onBatchScanResults {
    return BluetoothScanApi.onBatchScanResults;
  }

  Stream<BluetoothScanFailedEvent> get onScanFailed {
    return BluetoothScanApi.onScanFailed;
  }
}
