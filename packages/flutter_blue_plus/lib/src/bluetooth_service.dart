// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../flutter_blue_plus.dart';

class BluetoothService {
  final DeviceIdentifier remoteId;
  final Guid? primaryServiceUuid;
  final Guid serviceUuid;
  final List<BluetoothCharacteristic> characteristics;

  /// for convenience
  Guid get uuid => serviceUuid;
  bool get isPrimary => primaryServiceUuid == null;
  bool get isSecondary => primaryServiceUuid != null;

  /// (for primary services)
  ///  get it's secondary services (i.e. includedServices)
  List<BluetoothService> get includedServices =>
      _findIncludedServices(FlutterBluePlus._knownServices[remoteId], serviceUuid);

  /// (for secondary services)
  ///  get the primary service it is associated with
  BluetoothService? get primaryService =>
      _findPrimaryService(FlutterBluePlus._knownServices[remoteId], primaryServiceUuid);

  /// for internal use
  BluetoothService.fromProto(BmBluetoothService p)
      : remoteId = p.remoteId,
        primaryServiceUuid = p.primaryServiceUuid,
        serviceUuid = p.serviceUuid,
        characteristics = p.characteristics.map((c) => BluetoothCharacteristic.fromProto(c)).toList();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BluetoothService &&
            remoteId == other.remoteId &&
            primaryServiceUuid == other.primaryServiceUuid &&
            serviceUuid == other.serviceUuid &&
            listEquals(characteristics, other.characteristics);
  }

  @override
  int get hashCode => Object.hash(remoteId, primaryServiceUuid, serviceUuid, Object.hashAll(characteristics));

  @override
  String toString() {
    return 'BluetoothService{'
        'remoteId: $remoteId, '
        'primaryServiceUuid: $primaryServiceUuid, '
        'serviceUuid: $serviceUuid, '
        'characteristics: $characteristics, '
        '}';
  }

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get deviceId => remoteId;
}
