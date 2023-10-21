part of flutter_blue_plus;

class BluetoothEvents {
  static Stream<ConnectionStateEvent> get connectionState {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnConnectionStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmConnectionStateResponse.fromMap(args))
        .map((p) => ConnectionStateEvent(p));
  }

  static Stream<CharacteristicReceivedEvent> get onCharacteristicReceived {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnCharacteristicReceived")
        .map((m) => m.arguments)
        .map((args) => BmCharacteristicData.fromMap(args))
        .map((p) => CharacteristicReceivedEvent(p));
  }

  static Stream<DescriptorReadEvent> get onDescriptorRead {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnDescriptorRead")
        .map((m) => m.arguments)
        .map((args) => BmDescriptorData.fromMap(args))
        .map((p) => DescriptorReadEvent(p));
  }

  static Stream<OnNameChangedEvent> get onNameChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnNameChanged")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothDevice.fromMap(args))
        .map((p) => OnNameChangedEvent(p));
  }

  static Stream<OnServicesChangedEvent> get onServicesChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnServicesChanged")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothDevice.fromMap(args))
        .map((p) => OnServicesChangedEvent(p));
  }

  static Stream<BondStateEvent> get bondState {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnBondStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmBondStateResponse.fromMap(args))
        .map((p) => BondStateEvent(p));
  }
}

//
// Events
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
class OnServicesChangedEvent {
  final BmBluetoothDevice _response;

  OnServicesChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);
}

// BondState
class BondStateEvent {
  final BmBondStateResponse _response;

  BondStateEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new bond state
  BluetoothBondState get bondState => _bmToBondState(_response.bondState);
}
