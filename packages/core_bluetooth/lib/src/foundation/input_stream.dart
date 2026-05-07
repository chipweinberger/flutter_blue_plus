part of '../core_bluetooth.dart';

final class InputStream {
  InputStream._({
    required String handle,
  }) : _handle = handle;

  final String _handle;

  Future<void> close() {
    return CoreBluetoothHost.instance.invokeMethod<void>(
      'l2capChannel.closeInputStream',
      {
        'channelHandle': _handle,
      },
    );
  }

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
