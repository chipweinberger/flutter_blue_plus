part of '../core_bluetooth.dart';

final class InputStream {
  InputStream._({
    required String handle,
  }) : _handle = handle;

  final String _handle;

  /// Closes input and fails pending reads with a `stream_closed` PlatformException.
  Future<void> close() {
    return CoreBluetoothHost.instance.invokeMethod<void>(
      'l2capChannel.closeInputStream',
      {
        'channelHandle': _handle,
      },
    );
  }

  /// Reads on the native stream's background loop, in submission order.
  ///
  /// Returns up to [maxLength] bytes. Native reads use at most 64 KiB of scratch
  /// space, so larger requests can return partial chunks. Read again to consume
  /// the remaining data; application message boundaries are not preserved.
  /// For a positive [maxLength], empty bytes indicate clean end-of-stream.
  /// Native read failures throw PlatformException with code `stream_error`;
  /// its details contain the NSError `domain` and `code`, when available.
  Future<Uint8List> read({
    int maxLength = 4096,
  }) async {
    return bytesFromObject(
      await CoreBluetoothHost.instance.invokeMethod<Object?>(
            'l2capChannel.readInputStream',
            {
              'channelHandle': _handle,
              'maxLength': maxLength,
            },
          ) ??
          const <Object?>[],
    );
  }
}
