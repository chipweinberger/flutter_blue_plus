import 'utils.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final Map<DeviceIdentifier, StreamControllerReemit<bool>> _global = {};

/// connect & disconnect + update stream
extension Extra on BluetoothDevice {
  // convenience
  StreamControllerReemit<bool> get _stream {
    _global[remoteId] ??= StreamControllerReemit(initialValue: false);
    return _global[remoteId]!;
  }

  // get stream
  Stream<bool> get isConnectingOrDisconnecting {
    return _stream.stream;
  }

  // connect & update stream
  Future<void> connectAndUpdateStream() async {
    _stream.add(true);
    try {
      await connect();
    } finally {
      _stream.add(false);
    }
  }

  // disconnect & update stream
  Future<void> disconnectAndUpdateStream() async {
    _stream.add(true);
    try {
      await disconnect();
    } finally {
      _stream.add(false);
    }
  }
}
