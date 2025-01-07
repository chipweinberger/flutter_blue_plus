// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothService {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? primaryServiceUuid;
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
        serviceUuid = p.serviceUuid,
        primaryServiceUuid = p.primaryServiceUuid,
        characteristics = p.characteristics.map((c) => BluetoothCharacteristic.fromProto(c)).toList();

  @override
  String toString() {
    return 'BluetoothService{'
        'remoteId: $remoteId, '
        'serviceUuid: $serviceUuid, '
        'primaryServiceUuid: $primaryServiceUuid, '
        'characteristics: $characteristics, '
        '}';
  }

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get deviceId => remoteId;
}
