part of flutter_blue_plus;

class BluetoothEvents {
  Stream<OnConnectionStateChangedEvent> get onConnectionStateChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnConnectionStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmConnectionStateResponse.fromMap(args))
        .map((p) => OnConnectionStateChangedEvent(p));
  }

  Stream<OnMtuChangedEvent> get onMtuChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnMtuChanged")
        .map((m) => m.arguments)
        .map((args) => BmMtuChangedResponse.fromMap(args))
        .map((p) => OnMtuChangedEvent(p));
  }

  Stream<OnReadRssiEvent> get onReadRssi {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnReadRssi")
        .map((m) => m.arguments)
        .map((args) => BmReadRssiResult.fromMap(args))
        .map((p) => OnReadRssiEvent(p));
  }

  Stream<OnServicesResetEvent> get onServicesReset {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnServicesReset")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothDevice.fromMap(args))
        .map((p) => OnServicesResetEvent(p));
  }

  Stream<OnDiscoveredServicesEvent> get onDiscoveredServices {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnDiscoveredServices")
        .map((m) => m.arguments)
        .map((args) => BmDiscoverServicesResult.fromMap(args))
        .map((p) => OnDiscoveredServicesEvent(p));
  }

  Stream<OnCharacteristicReceivedEvent> get onCharacteristicReceived {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnCharacteristicReceived")
        .map((m) => m.arguments)
        .map((args) => BmCharacteristicData.fromMap(args))
        .map((p) => OnCharacteristicReceivedEvent(p));
  }

  Stream<OnCharacteristicWrittenEvent> get onCharacteristicWritten {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnCharacteristicWritten")
        .map((m) => m.arguments)
        .map((args) => BmCharacteristicData.fromMap(args))
        .map((p) => OnCharacteristicWrittenEvent(p));
  }

  Stream<OnDescriptorReadEvent> get onDescriptorRead {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnDescriptorRead")
        .map((m) => m.arguments)
        .map((args) => BmDescriptorData.fromMap(args))
        .map((p) => OnDescriptorReadEvent(p));
  }

  Stream<OnDescriptorWrittenEvent> get onDescriptorWritten {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnDescriptorWritten")
        .map((m) => m.arguments)
        .map((args) => BmDescriptorData.fromMap(args))
        .map((p) => OnDescriptorWrittenEvent(p));
  }

  Stream<OnNameChangedEvent> get onNameChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnNameChanged")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothDevice.fromMap(args))
        .map((p) => OnNameChangedEvent(p));
  }

  Stream<OnBondStateChangedEvent> get onBondStateChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnBondStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmBondStateResponse.fromMap(args))
        .map((p) => OnBondStateChangedEvent(p));
  }
}

class FbpError {
  final int errorCode;
  final String errorString;
  ErrorPlatform get platform => _nativeError;
  FbpError(this.errorCode, this.errorString);
}

//
// Event Classes
//

// On Connection State Changed
class OnConnectionStateChangedEvent {
  final BmConnectionStateResponse _response;

  OnConnectionStateChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new connection state
  BluetoothConnectionState get connectionState => _bmToConnectionState(_response.connectionState);
}

// On Mtu Changed
class OnMtuChangedEvent {
  final BmMtuChangedResponse _response;

  OnMtuChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new mtu
  int get mtu => _response.mtu;

  /// failed?
  FbpError? get error => _response.success ? null : FbpError(_response.errorCode, _response.errorString);
}

// On Read Rssi
class OnReadRssiEvent {
  final BmReadRssiResult _response;

  OnReadRssiEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// rssi
  int get rssi => _response.rssi;

  /// failed?
  FbpError? get error => _response.success ? null : FbpError(_response.errorCode, _response.errorString);
}

// On Services Reset
class OnServicesResetEvent {
  final BmBluetoothDevice _response;

  OnServicesResetEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);
}

// On Discovered Services
class OnDiscoveredServicesEvent {
  final BmDiscoverServicesResult _response;

  OnDiscoveredServicesEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the discovered services
  List<BluetoothService> get services => _response.services.map((p) => BluetoothService.fromProto(p)).toList();

  /// failed?
  FbpError? get error => _response.success ? null : FbpError(_response.errorCode, _response.errorString);
}

// On Characteristic Received
class OnCharacteristicReceivedEvent {
  final BmCharacteristicData _response;

  OnCharacteristicReceivedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the relevant characteristic
  BluetoothCharacteristic get characteristic => BluetoothCharacteristic(
      remoteId: DeviceIdentifier(_response.remoteId),
      characteristicUuid: _response.characteristicUuid,
      serviceUuid: _response.serviceUuid,
      secondaryServiceUuid: _response.secondaryServiceUuid);

  /// the new data
  List<int> get value => _response.value;

  /// failed?
  FbpError? get error => _response.success ? null : FbpError(_response.errorCode, _response.errorString);
}

// On Characteristic Written
class OnCharacteristicWrittenEvent {
  final BmCharacteristicData _response;

  OnCharacteristicWrittenEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the relevant characteristic
  BluetoothCharacteristic get characteristic => BluetoothCharacteristic(
      remoteId: DeviceIdentifier(_response.remoteId),
      characteristicUuid: _response.characteristicUuid,
      serviceUuid: _response.serviceUuid,
      secondaryServiceUuid: _response.secondaryServiceUuid);

  /// the new data
  List<int> get value => _response.value;

  /// failed?
  FbpError? get error => _response.success ? null : FbpError(_response.errorCode, _response.errorString);
}

// On Descriptor Received
class OnDescriptorReadEvent {
  final BmDescriptorData _response;

  OnDescriptorReadEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the relevant descriptor
  BluetoothDescriptor get descriptor => BluetoothDescriptor(
      remoteId: DeviceIdentifier(_response.remoteId),
      serviceUuid: _response.serviceUuid,
      characteristicUuid: _response.characteristicUuid,
      descriptorUuid: _response.descriptorUuid);

  /// the new data
  List<int> get value => _response.value;

  /// failed?
  FbpError? get error => _response.success ? null : FbpError(_response.errorCode, _response.errorString);
}

// On Descriptor Written
class OnDescriptorWrittenEvent {
  final BmDescriptorData _response;

  OnDescriptorWrittenEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the relevant descriptor
  BluetoothDescriptor get descriptor => BluetoothDescriptor(
      remoteId: DeviceIdentifier(_response.remoteId),
      serviceUuid: _response.serviceUuid,
      characteristicUuid: _response.characteristicUuid,
      descriptorUuid: _response.descriptorUuid);

  /// the new data
  List<int> get value => _response.value;

  /// failed?
  FbpError? get error => _response.success ? null : FbpError(_response.errorCode, _response.errorString);
}

// On Name Changed
class OnNameChangedEvent {
  final BmBluetoothDevice _response;

  OnNameChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new name
  String? get name => _response.platformName;
}

// On Bond State Changed
class OnBondStateChangedEvent {
  final BmBondStateResponse _response;

  OnBondStateChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new bond state
  BluetoothBondState get bondState => _bmToBondState(_response.bondState);
}
