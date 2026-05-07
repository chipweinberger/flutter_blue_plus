import 'scan_types.dart';

final class BluetoothScanSettings {
  const BluetoothScanSettings({
    this.callbackType = BluetoothCallbackType.allMatches,
    this.legacy = true,
    this.matchMode,
    this.numOfMatches,
    this.phy = BluetoothPhy.allSupported,
    this.reportDelay = Duration.zero,
    this.scanMode = BluetoothScanMode.lowPower,
  });

  final BluetoothCallbackType callbackType;
  final bool legacy;
  final BluetoothMatchMode? matchMode;
  final BluetoothNumOfMatches? numOfMatches;
  final BluetoothPhy phy;
  final Duration reportDelay;
  final BluetoothScanMode scanMode;

  Map<String, Object?> toMap() {
    return {
      'callbackType': callbackType.value,
      'legacy': legacy,
      if (matchMode != null) 'matchMode': matchMode!.value,
      if (numOfMatches != null) 'numOfMatches': numOfMatches!.value,
      'phy': phy.value,
      'reportDelayMillis': reportDelay.inMilliseconds,
      'scanMode': scanMode.value,
    };
  }
}

final class BluetoothScanSettingsBuilder {
  BluetoothCallbackType _callbackType = BluetoothCallbackType.allMatches;
  bool _legacy = true;
  BluetoothMatchMode? _matchMode;
  BluetoothNumOfMatches? _numOfMatches;
  BluetoothPhy _phy = BluetoothPhy.allSupported;
  Duration _reportDelay = Duration.zero;
  BluetoothScanMode _scanMode = BluetoothScanMode.lowPower;

  BluetoothScanSettingsBuilder setCallbackType(BluetoothCallbackType callbackType) {
    _callbackType = callbackType;
    return this;
  }

  BluetoothScanSettingsBuilder setLegacy(bool legacy) {
    _legacy = legacy;
    return this;
  }

  BluetoothScanSettingsBuilder setMatchMode(BluetoothMatchMode matchMode) {
    _matchMode = matchMode;
    return this;
  }

  BluetoothScanSettingsBuilder setNumOfMatches(BluetoothNumOfMatches numOfMatches) {
    _numOfMatches = numOfMatches;
    return this;
  }

  BluetoothScanSettingsBuilder setPhy(BluetoothPhy phy) {
    _phy = phy;
    return this;
  }

  BluetoothScanSettingsBuilder setReportDelay(Duration reportDelay) {
    _reportDelay = reportDelay;
    return this;
  }

  BluetoothScanSettingsBuilder setScanMode(BluetoothScanMode scanMode) {
    _scanMode = scanMode;
    return this;
  }

  BluetoothScanSettings build() {
    return BluetoothScanSettings(
      callbackType: _callbackType,
      legacy: _legacy,
      matchMode: _matchMode,
      numOfMatches: _numOfMatches,
      phy: _phy,
      reportDelay: _reportDelay,
      scanMode: _scanMode,
    );
  }
}
