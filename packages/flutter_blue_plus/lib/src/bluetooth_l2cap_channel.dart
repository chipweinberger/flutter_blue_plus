// Copyright 2017-2023, Charles Weinberger
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../flutter_blue_plus.dart';

class BluetoothL2capChannel {
  final DeviceIdentifier remoteId;
  final int psm;

  BluetoothL2capChannel({
    required this.remoteId,
    required this.psm,
  });

  /// The device associated with this channel
  BluetoothDevice get device => BluetoothDevice(remoteId: remoteId);

  /// Stream of data packets received on this channel
  Stream<List<int>> get inputStream => FlutterBluePlusPlatform.instance.onL2capDataReceived
      .where((p) => p.remoteId == remoteId && p.psm == psm)
      .map((p) => p.data);

  /// Stream emitting when this channel is closed
  Stream<void> get onClosed => FlutterBluePlusPlatform.instance.onL2capChannelClosed
      .where((p) => p.remoteId == remoteId && p.psm == psm)
      .map((_) {});

  /// Write data to this L2CAP channel
  Future<void> write(List<int> data) async {
    if (device.isDisconnected) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, "writeL2capChannel", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    var request = BmL2capWriteRequest(
      remoteId: remoteId,
      psm: psm,
      value: data,
    );

    await FlutterBluePlusPlatform.instance.writeL2capChannel(request);
  }

  /// Close this L2CAP channel
  Future<void> close() async {
    var request = BmL2capCloseRequest(
      remoteId: remoteId,
      psm: psm,
    );

    await FlutterBluePlusPlatform.instance.closeL2capChannel(request);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothL2capChannel &&
          runtimeType == other.runtimeType &&
          remoteId == other.remoteId &&
          psm == other.psm;

  @override
  int get hashCode => Object.hash(remoteId, psm);

  @override
  String toString() => 'BluetoothL2capChannel(remoteId: $remoteId, psm: $psm)';
}
