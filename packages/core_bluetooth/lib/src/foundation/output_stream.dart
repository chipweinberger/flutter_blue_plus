part of '../core_bluetooth.dart';

final class OutputStream {
  OutputStream._({
    required String handle,
  }) : _handle = handle;

  final String _handle;

  Future<void> close() {
    return CoreBluetoothHost.instance.invokeMethod<void>(
      'l2capChannel.closeOutputStream',
      {
        'channelHandle': _handle,
      },
    );
  }

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
