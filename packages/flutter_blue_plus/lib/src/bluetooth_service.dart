// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../flutter_blue_plus.dart';

class BluetoothService {
  final DeviceIdentifier remoteId;
  final Guid? primaryServiceUuid;
  final Guid serviceUuid;
  final List<BluetoothCharacteristic> characteristics;

  /// convenience accessor
  Guid get uuid => serviceUuid;

  /// for convenience
  bool get isPrimary => primaryServiceUuid == null;

  /// for convenience
  bool get isSecondary => primaryServiceUuid != null;

  /// (for primary services)
  ///  get it's secondary services (i.e. includedServices)
  List<BluetoothService> get includedServices {
    List<BluetoothService> out = [];
    if (FlutterBluePlus._knownServices[remoteId] != null) {
      for (var s in FlutterBluePlus._knownServices[remoteId]!.services) {
        if (s.primaryServiceUuid == serviceUuid) {
          out.add(BluetoothService.fromProto(s));
        }
      }
    }
    return out;
  }

  /// (for secondary services)
  ///  get the primary service it is associated with
  BluetoothService? get primaryService {
    if (primaryServiceUuid != null) {
      if (FlutterBluePlus._knownServices[remoteId] != null) {
        for (var s in FlutterBluePlus._knownServices[remoteId]!.services) {
          if (s.serviceUuid == primaryServiceUuid) {
            return BluetoothService.fromProto(s);
          }
        }
      }
    }
    return null;
  }

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
            _characteristicsEqual(characteristics, other.characteristics);
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

bool _characteristicsEqual(List<BluetoothCharacteristic> a, List<BluetoothCharacteristic> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
