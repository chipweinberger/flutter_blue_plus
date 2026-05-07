import 'scan_result.dart';

final class BluetoothScanBatchResultsEvent {
  const BluetoothScanBatchResultsEvent({
    required this.results,
  });

  factory BluetoothScanBatchResultsEvent.fromList(List<Object?> list) {
    return BluetoothScanBatchResultsEvent(
      results:
          list.map((result) => BluetoothScanResult.fromMap(result as Map<Object?, Object?>)).toList(growable: false),
    );
  }

  final List<BluetoothScanResult> results;
}

enum BluetoothCallbackType {
  allMatches(1),
  firstMatch(2),
  matchLost(4);

  const BluetoothCallbackType(this.value);

  factory BluetoothCallbackType.fromValue(int value) {
    for (final callbackType in BluetoothCallbackType.values) {
      if (callbackType.value == value) {
        return callbackType;
      }
    }

    return BluetoothCallbackType.allMatches;
  }

  final int value;
}

enum BluetoothMatchMode {
  aggressive(1),
  sticky(2);

  const BluetoothMatchMode(this.value);

  factory BluetoothMatchMode.fromValue(int value) {
    for (final matchMode in BluetoothMatchMode.values) {
      if (matchMode.value == value) {
        return matchMode;
      }
    }

    return BluetoothMatchMode.aggressive;
  }

  final int value;
}

enum BluetoothNumOfMatches {
  oneAdvertisement(1),
  fewAdvertisements(2),
  maxAdvertisements(3);

  const BluetoothNumOfMatches(this.value);

  factory BluetoothNumOfMatches.fromValue(int value) {
    for (final numOfMatches in BluetoothNumOfMatches.values) {
      if (numOfMatches.value == value) {
        return numOfMatches;
      }
    }

    return BluetoothNumOfMatches.maxAdvertisements;
  }

  final int value;
}

enum BluetoothPhy {
  le1m(1),
  leCoded(3),
  allSupported(255);

  const BluetoothPhy(this.value);

  factory BluetoothPhy.fromValue(int value) {
    for (final phy in BluetoothPhy.values) {
      if (phy.value == value) {
        return phy;
      }
    }

    return BluetoothPhy.allSupported;
  }

  final int value;
}

final class BluetoothScanFailedEvent {
  const BluetoothScanFailedEvent({
    required this.errorCode,
    required this.rawErrorCode,
  });

  factory BluetoothScanFailedEvent.fromMap(Map<Object?, Object?> map) {
    final rawErrorCode = map['errorCode'] as int? ?? -1;
    return BluetoothScanFailedEvent(
      errorCode: BluetoothScanFailureCode.fromValue(rawErrorCode),
      rawErrorCode: rawErrorCode,
    );
  }

  final BluetoothScanFailureCode errorCode;
  final int rawErrorCode;
}

enum BluetoothScanFailureCode {
  alreadyStarted(1),
  applicationRegistrationFailed(2),
  featureUnsupported(4),
  internalError(3),
  outOfHardwareResources(5),
  scanningTooFrequently(6),
  unknown(-1);

  const BluetoothScanFailureCode(this.value);

  factory BluetoothScanFailureCode.fromValue(int value) {
    for (final failureCode in BluetoothScanFailureCode.values) {
      if (failureCode.value == value) {
        return failureCode;
      }
    }

    return BluetoothScanFailureCode.unknown;
  }

  final int value;
}

enum BluetoothScanMode {
  opportunistic(-1),
  lowPower(0),
  balanced(1),
  lowLatency(2);

  const BluetoothScanMode(this.value);

  factory BluetoothScanMode.fromValue(int value) {
    for (final scanMode in BluetoothScanMode.values) {
      if (scanMode.value == value) {
        return scanMode;
      }
    }

    return BluetoothScanMode.lowPower;
  }

  final int value;
}
