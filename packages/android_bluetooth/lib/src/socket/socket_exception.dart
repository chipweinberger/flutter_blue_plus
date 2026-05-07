final class BluetoothSocketException implements Exception {
  const BluetoothSocketException(this.errorCode, [this.message]);

  const BluetoothSocketException.unspecified([this.message]) : errorCode = unspecifiedError;

  final int errorCode;
  final String? message;

  static const int unspecifiedError = 0;
  static const int l2capUnknown = 1;
  static const int l2capAclFailure = 2;
  static const int l2capClientSecurityFailure = 3;
  static const int l2capInsufficientAuthentication = 4;
  static const int l2capInsufficientAuthorization = 5;
  static const int l2capInsufficientEncryptKeySize = 6;
  static const int l2capInsufficientEncryption = 7;
  static const int l2capInvalidSourceCid = 8;
  static const int l2capSourceCidAlreadyAllocated = 9;
  static const int l2capUnacceptableParameters = 10;
  static const int l2capInvalidParameters = 11;
  static const int l2capNoResources = 12;
  static const int l2capNoPsmAvailable = 13;
  static const int l2capTimeout = 14;
  static const int bluetoothOffFailure = 15;
  static const int socketManagerFailure = 16;
  static const int socketClosed = 17;
  static const int socketConnectionFailure = 18;
  static const int nullDevice = 19;
  static const int rpcFailure = 20;

  int getErrorCode() {
    return errorCode;
  }

  @override
  String toString() {
    if (message == null || message!.isEmpty) {
      return 'BluetoothSocketException($errorCode)';
    }

    return 'BluetoothSocketException($errorCode, $message)';
  }
}
