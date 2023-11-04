part of flutter_blue_plus;

class BluetoothEvents {
  Stream<ConnectionStateEvent> get connectionState {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnConnectionStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmConnectionStateResponse.fromMap(args))
        .map((p) => ConnectionStateEvent(p));
  }

  Stream<DiscoveredServicesEvent> get onDiscoveredServices {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnDiscoverServicesResult")
        .map((m) => m.arguments)
        .map((args) => BmDiscoverServicesResult.fromMap(args))
        .map((p) => DiscoveredServicesEvent(p));
  }

  Stream<MtuEvent> get onMtuChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnMtuChanged")
        .map((m) => m.arguments)
        .map((args) => BmMtuChangedResponse.fromMap(args))
        .map((p) => MtuEvent(p));
  }

  Stream<CharacteristicReceivedEvent> get onCharacteristicReceived {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnCharacteristicReceived")
        .map((m) => m.arguments)
        .map((args) => BmCharacteristicData.fromMap(args))
        .map((p) => CharacteristicReceivedEvent(p));
  }

  Stream<DescriptorReadEvent> get onDescriptorRead {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnDescriptorRead")
        .map((m) => m.arguments)
        .map((args) => BmDescriptorData.fromMap(args))
        .map((p) => DescriptorReadEvent(p));
  }

  Stream<OnNameChangedEvent> get onNameChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnNameChanged")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothDevice.fromMap(args))
        .map((p) => OnNameChangedEvent(p));
  }

  Stream<OnServicesResetEvent> get onServicesReset {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnServicesReset")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothDevice.fromMap(args))
        .map((p) => OnServicesResetEvent(p));
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

// ConnectionState
class ConnectionStateEvent {
  final BmConnectionStateResponse _response;

  ConnectionStateEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new connection state
  BluetoothConnectionState get connectionState => _bmToConnectionState(_response.connectionState);
}

// Discovered Services Event
class DiscoveredServicesEvent {
  final BmDiscoverServicesResult _response;

  DiscoveredServicesEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the discovered services
  List<BluetoothService> get services => _response.services.map((p) => BluetoothService.fromProto(p)).toList();

  /// failed?
  FbpError? get error => _response.success ? null : FbpError(_response.errorCode, _response.errorString);
}

// Mtu Event
class MtuEvent {
  final BmMtuChangedResponse _response;

  MtuEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new mtu
  int get mtu => _response.mtu;

  /// failed?
  FbpError? get error => _response.success ? null : FbpError(_response.errorCode, _response.errorString);
}

// Characteristic Received
class CharacteristicReceivedEvent {
  final BmCharacteristicData _response;

  CharacteristicReceivedEvent(this._response);

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

// Descriptor Received
class DescriptorReadEvent {
  final BmDescriptorData _response;

  DescriptorReadEvent(this._response);

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

// On Services Changed
class OnServicesResetEvent {
  final BmBluetoothDevice _response;

  OnServicesResetEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);
}

// BondState
class OnBondStateChangedEvent {
  final BmBondStateResponse _response;

  OnBondStateChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new bond state
  BluetoothBondState get bondState => _bmToBondState(_response.bondState);
}
