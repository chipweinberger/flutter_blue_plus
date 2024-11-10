// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothService extends BluetoothAttribute {
  final bool isPrimary;
  late final List<BluetoothService> includedServices;
  late final List<BluetoothCharacteristic> characteristics;

  /// convenience accessor
  Guid get serviceUuid => uuid;

  /// for convenience
  bool get isSecondary => !isPrimary;

  /// for internal use
  BluetoothService.fromProto(BluetoothDevice device, BmBluetoothService p)
      : isPrimary = p.isPrimary,
        super(device: device, uuid: p.uuid, index: p.index) {
    characteristics = p.characteristics.map((c) => BluetoothCharacteristic.fromProto(c, this)).toList();
  }

  @override
  String toString() {
    return 'BluetoothService{'
        'remoteId: $remoteId, '
        'isPrimary: $isPrimary, '
        'characteristics: $characteristics, '
        'includedServices: $includedServices'
        '}';
  }
}
