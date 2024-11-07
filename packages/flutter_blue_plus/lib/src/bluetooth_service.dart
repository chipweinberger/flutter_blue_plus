// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothService {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? primaryServiceUuid;
  final List<BluetoothCharacteristic> characteristics;

  // for convenience
  bool get isPrimary => primaryServiceUuid == null;

  // for convenience
  bool get isSecondary => primaryServiceUuid != null;

  /// convenience accessor
  Guid get uuid => serviceUuid;

  BluetoothService.fromProto(BmBluetoothService p)
      : remoteId = p.remoteId,
        serviceUuid = p.serviceUuid,
        primaryServiceUuid = p.primaryServiceUuid,
        characteristics = p.characteristics.map((c) => BluetoothCharacteristic.fromProto(c)).toList();

  @override
  String toString() {
    return 'BluetoothService{'
        'remoteId: $remoteId, '
        'serviceUuid: $serviceUuid, '
        'primaryService: $primaryServiceUuid, '
        'characteristics: $characteristics, '
        '}';
  }

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get deviceId => remoteId;
}
