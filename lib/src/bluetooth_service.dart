// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothService {
  final Guid serviceUuid;
  final DeviceIdentifier remoteId;
  final bool isPrimary;
  final List<BluetoothCharacteristic> characteristics;
  final List<BluetoothService> includedServices;

  @Deprecated('Use deviceId instead')
  DeviceIdentifier get deviceId => remoteId;

  @Deprecated('Use serviceUuid instead')
  Guid get uuid => serviceUuid;

  BluetoothService.fromProto(BmBluetoothService p)
      : serviceUuid = Guid(p.serviceUuid),
        remoteId = DeviceIdentifier(p.remoteId),
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
        'serviceUuid: $serviceUuid, '
        'remoteId: $remoteId, '
        'isPrimary: $isPrimary, '
        'characteristics: $characteristics, '
        'includedServices: $includedServices'
        '}';
  }
}
