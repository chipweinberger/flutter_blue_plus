// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
part of flutter_blue_plus;

class L2CapChannelConnected {
  final BluetoothDevice device;
  final int psm;

  L2CapChannelConnected.fromMap(Map<dynamic, dynamic> map)
      : device = BluetoothDevice.fromProto(
            BmBluetoothDevice.fromMap(map[keyBluetoothDevice])),
        psm = map[keyPsm];
}

class ListenL2CapChannelRequest {
  final bool secure;

  ListenL2CapChannelRequest({required this.secure});

  Map<dynamic, dynamic> toMap() {
    return {
      keySecure: secure,
    };
  }
}

class ListenL2CapChannelResponse {
  final int psm;

  ListenL2CapChannelResponse.fromMap(Map<dynamic, dynamic> map)
      : psm = map[keyPsm];
}

class CloseL2CapServer {
  final int psm;

  CloseL2CapServer({required this.psm});

  Map<dynamic, dynamic> toMap() {
    return {
      keyPsm: psm,
    };
  }
}

class OpenL2CapChannelRequest {
  final String remoteId;
  final int psm;
  final bool secure;

  OpenL2CapChannelRequest({
    required this.remoteId,
    required this.psm,
    required this.secure,
  });

  Map<dynamic, dynamic> toMap() {
    return {
      keyPsm: psm,
      keyRemoteId: remoteId,
      keySecure: secure,
    };
  }
}

class CloseL2CapChannelRequest {
  final String remoteId;
  final int psm;

  CloseL2CapChannelRequest({
    required this.remoteId,
    required this.psm,
  });

  Map<dynamic, dynamic> toMap() {
    return {
      keyPsm: psm,
      keyRemoteId: remoteId,
    };
  }
}

class ReadL2CapChannelRequest {
  final String remoteId;
  final int psm;

  ReadL2CapChannelRequest({
    required this.remoteId,
    required this.psm,
  });

  Map<dynamic, dynamic> toMap() {
    return {
      keyPsm: psm,
      keyRemoteId: remoteId,
    };
  }
}

class ReadL2CapChannelResponse {
  final String remoteId;
  final int psm;
  final int bytesRead;
  final List<int> value;

  ReadL2CapChannelResponse.fromMap(Map<dynamic, dynamic> map)
      : remoteId = map[keyRemoteId],
        psm = map[keyPsm],
        bytesRead = map[keyBytesRead],
        value = _hexDecode(map[keyValue]);
}

class WriteL2CapChannelRequest {
  final String remoteId;
  final int psm;
  final List<int> value;

  WriteL2CapChannelRequest(
      {required this.remoteId, required this.psm, required this.value});

  Map<dynamic, dynamic> toMap() {
    return {
      keyPsm: psm,
      keyRemoteId: remoteId,
      keyValue: _hexEncode(value),
    };
  }
}
