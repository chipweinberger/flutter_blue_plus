// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothService {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final bool isPrimary;
  final List<BluetoothCharacteristic> characteristics;
  final List<BluetoothService> includedServices;

  /// convenience accessor
  Guid get uuid => serviceUuid;

  BluetoothService.fromProto(BmBluetoothService p)
      : remoteId = DeviceIdentifier(p.remoteId),
        serviceUuid = p.serviceUuid,
        isPrimary = p.isPrimary,
        characteristics = p.characteristics
            .map((c) => BluetoothCharacteristic.fromProto(c))
            .toList(),
        includedServices = p.includedServices
            .map((s) => BluetoothService.fromProto(s))
            .toList();

  @override
  String toString() {
    return 'BluetoothService{'
        'remoteId: $remoteId, '
        'serviceUuid: $serviceUuid, '
        'isPrimary: $isPrimary, '
        'characteristics: $characteristics, '
        'includedServices: $includedServices'
        '}';
  }

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get deviceId => remoteId;
}
