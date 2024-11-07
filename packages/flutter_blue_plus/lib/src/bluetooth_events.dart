part of flutter_blue_plus;

class BluetoothEvents {
  Stream<OnConnectionStateChangedEvent> get onConnectionStateChanged {
    return FlutterBluePlusPlatform.instance.onConnectionStateChanged
        .map((p) => OnConnectionStateChangedEvent(p));
  }

  Stream<OnMtuChangedEvent> get onMtuChanged {
    return FlutterBluePlusPlatform.instance.onMtuChanged
        .map((p) => OnMtuChangedEvent(p));
  }

  Stream<OnReadRssiEvent> get onReadRssi {
    return FlutterBluePlusPlatform.instance.onReadRssi
        .map((p) => OnReadRssiEvent(p));
  }

  Stream<OnServicesResetEvent> get onServicesReset {
    return FlutterBluePlusPlatform.instance.onServicesReset
        .map((p) => OnServicesResetEvent(p));
  }

  Stream<OnDiscoveredServicesEvent> get onDiscoveredServices {
    return FlutterBluePlusPlatform.instance.onDiscoveredServices
        .map((p) => OnDiscoveredServicesEvent(p));
  }

  Stream<OnCharacteristicReceivedEvent> get onCharacteristicReceived {
    return FlutterBluePlusPlatform.instance.onCharacteristicReceived
        .map((p) => OnCharacteristicReceivedEvent(p));
  }

  Stream<OnCharacteristicWrittenEvent> get onCharacteristicWritten {
    return FlutterBluePlusPlatform.instance.onCharacteristicWritten
        .map((p) => OnCharacteristicWrittenEvent(p));
  }

  Stream<OnDescriptorReadEvent> get onDescriptorRead {
    return FlutterBluePlusPlatform.instance.onDescriptorRead
        .map((p) => OnDescriptorReadEvent(p));
  }

  Stream<OnDescriptorWrittenEvent> get onDescriptorWritten {
    return FlutterBluePlusPlatform.instance.onDescriptorWritten
        .map((p) => OnDescriptorWrittenEvent(p));
  }

  Stream<OnNameChangedEvent> get onNameChanged {
    return FlutterBluePlusPlatform.instance.onNameChanged
        .map((p) => OnNameChangedEvent(p));
  }

  Stream<OnBondStateChangedEvent> get onBondStateChanged {
    return FlutterBluePlusPlatform.instance.onBondStateChanged
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
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the new connection state
  BluetoothConnectionState get connectionState => _bmToConnectionState(_response.connectionState);
}

// On Mtu Changed
class OnMtuChangedEvent {
  final BmMtuChangedResponse _response;

  OnMtuChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

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
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

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
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);
}

// On Discovered Services
class OnDiscoveredServicesEvent {
  final BmDiscoverServicesResult _response;

  OnDiscoveredServicesEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

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
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the relevant characteristic
  BluetoothCharacteristic get characteristic => BluetoothCharacteristic(
      remoteId: _response.remoteId,
      characteristicUuid: _response.characteristicUuid,
      serviceUuid: _response.serviceUuid,
      primaryServiceUuid: _response.primaryServiceUuid);

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
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the relevant characteristic
  BluetoothCharacteristic get characteristic => BluetoothCharacteristic(
      remoteId: _response.remoteId,
      characteristicUuid: _response.characteristicUuid,
      serviceUuid: _response.serviceUuid,
      primaryServiceUuid: _response.primaryServiceUuid);

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
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the relevant descriptor
  BluetoothDescriptor get descriptor => BluetoothDescriptor(
      remoteId: _response.remoteId,
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
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the relevant descriptor
  BluetoothDescriptor get descriptor => BluetoothDescriptor(
      remoteId: _response.remoteId,
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
  final BmNameChanged _response;

  OnNameChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the new name
  String? get name => _response.name;
}

// On Bond State Changed
class OnBondStateChangedEvent {
  final BmBondStateResponse _response;

  OnBondStateChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice(remoteId: _response.remoteId);

  /// the new bond state
  BluetoothBondState get bondState => _bmToBondState(_response.bondState);
}
