part of '../core_bluetooth.dart';

final class OutputStream {
  OutputStream._({
    required String handle,
  }) : _handle = handle;

  final String _handle;

  /// Closes output and fails pending writes with a `stream_closed` PlatformException.
  Future<void> close() {
    return CoreBluetoothHost.instance.invokeMethod<void>(
      'l2capChannel.closeOutputStream',
      {
        'channelHandle': _handle,
      },
    );
  }

  /// Writes on the native stream's background loop, in submission order.
  /// Returns the native byte count, including partial writes and -1 on failure.
  Future<int> write(Uint8List data) async {
    return await CoreBluetoothHost.instance.invokeMethod<int>(
          'l2capChannel.writeOutputStream',
          {
            'channelHandle': _handle,
            'value': data,
          },
        ) ??
        0;
  }
}
