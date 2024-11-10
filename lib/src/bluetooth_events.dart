part of flutter_blue_plus;

class BluetoothEvents {
  Stream<OnConnectionStateChangedEvent> get onConnectionStateChanged =>
      FlutterBluePlus._extractEventStream<OnConnectionStateChangedEvent>();

  Stream<OnMtuChangedEvent> get onMtuChanged => FlutterBluePlus._extractEventStream<OnMtuChangedEvent>();

  Stream<OnReadRssiEvent> get onReadRssi => FlutterBluePlus._extractEventStream<OnReadRssiEvent>();

  Stream<OnServicesResetEvent> get onServicesReset => FlutterBluePlus._extractEventStream<OnServicesResetEvent>();

  Stream<OnDiscoveredServicesEvent> get onDiscoveredServices =>
      FlutterBluePlus._extractEventStream<OnDiscoveredServicesEvent>();

  Stream<OnCharacteristicReceivedEvent> get onCharacteristicReceived =>
      FlutterBluePlus._extractEventStream<OnCharacteristicReceivedEvent>();

  Stream<OnCharacteristicWrittenEvent> get onCharacteristicWritten =>
      FlutterBluePlus._extractEventStream<OnCharacteristicWrittenEvent>();

  Stream<OnDescriptorReadEvent> get onDescriptorRead => FlutterBluePlus._extractEventStream<OnDescriptorReadEvent>();

  Stream<OnDescriptorWrittenEvent> get onDescriptorWritten =>
      FlutterBluePlus._extractEventStream<OnDescriptorWrittenEvent>();

  Stream<OnNameChangedEvent> get onNameChanged => FlutterBluePlus._extractEventStream<OnNameChangedEvent>();

  Stream<OnBondStateChangedEvent> get onBondStateChanged =>
      FlutterBluePlus._extractEventStream<OnBondStateChangedEvent>();
}

class FbpError {
  final int errorCode;
  final String errorString;
  ErrorPlatform get platform => _nativeError;
  FbpError(this.errorCode, this.errorString);
}

//
// Mixins
//
mixin GetDeviceMixin {
  dynamic get _response;

  /// the relevant device
  BluetoothDevice get device => FlutterBluePlus._deviceForId(_response.remoteId);
}

mixin GetAttributeValueMixin {
  dynamic get _response;
  BluetoothValueAttribute get attribute;

  /// the new data
  List<int> get value => _response.value;
}

mixin GetCharacteristicMixin on GetAttributeValueMixin, GetDeviceMixin {
  /// the relevant characteristic
  BluetoothCharacteristic get characteristic => device._characteristicForIdentifier(_response.identifier);

  /// the relevant attribute
  BluetoothValueAttribute get attribute => characteristic;
}

mixin GetDescriptorMixin on GetAttributeValueMixin, GetDeviceMixin {
  /// the relevant descriptor
  BluetoothDescriptor get descriptor => device._descriptorForIdentifier(_response.identifier);

  /// the relevant attribute
  BluetoothValueAttribute get attribute => descriptor;
}

mixin GetExceptionMixin {
  BmStatus get _response;

  FbpError? get error => _response.success ? null : FbpError(_response.errorCode, _response.errorString);

  FlutterBluePlusException? exception(String method) => _response.success
      ? null
      : FlutterBluePlusException(_nativeError, method, _response.errorCode, _response.errorString);

  void ensureSuccess(String method) {
    if (!_response.success) {
      throw exception(method)!;
    }
  }
}

//
// Event Classes
//

// On Detached From Engine
class OnDetachedFromEngineEvent {
  static const String method = "OnDetachedFromEngine";
}

// On Turn On Response
class OnTurnOnResponseEvent {
  static const String method = "OnTurnOnResponse";

  final BmTurnOnResponse _response;

  OnTurnOnResponseEvent(this._response);

  /// user accepted response
  bool get userAccepted => _response.userAccepted;
}

// On Scan Response
class OnScanResponseEvent with GetExceptionMixin {
  static const String method = "OnScanResponse";

  final BmScanResponse _response;

  OnScanResponseEvent(this._response);

  /// the new scan state
  List<ScanResult> get advertisements => _response.advertisements.map((a) => ScanResult.fromProto(a)).toList();
}

// On Connection State Changed
class OnConnectionStateChangedEvent with GetDeviceMixin {
  static const String method = "OnConnectionStateChanged";

  final BmConnectionStateResponse _response;

  OnConnectionStateChangedEvent(this._response);

  /// the new connection state
  BluetoothConnectionState get connectionState => _bmToConnectionState(_response.connectionState);

  /// the disconnect reason
  DisconnectReason? get disconnectReason =>
      DisconnectReason(_nativeError, _response.disconnectReasonCode, _response.disconnectReasonString);
}

// On Adapter State Changed
class OnAdapterStateChangedEvent {
  static const String method = "OnAdapterStateChanged";

  final BmBluetoothAdapterState _response;

  OnAdapterStateChangedEvent(this._response);

  /// the new adapter state
  BluetoothAdapterState get adapterState => _bmToAdapterState(_response.adapterState);
}

// On Mtu Changed
class OnMtuChangedEvent with GetDeviceMixin, GetExceptionMixin {
  static const String method = "OnMtuChanged";

  final BmMtuChangedResponse _response;

  OnMtuChangedEvent(this._response);

  /// the new mtu
  int get mtu => _response.mtu;
}

// On Read Rssi
class OnReadRssiEvent with GetDeviceMixin, GetExceptionMixin {
  static const String method = "OnReadRssi";

  final BmReadRssiResult _response;

  OnReadRssiEvent(this._response);

  /// rssi
  int get rssi => _response.rssi;
}

// On Services Reset
class OnServicesResetEvent with GetDeviceMixin {
  static const String method = "OnServicesReset";

  final BmBluetoothDevice _response;

  OnServicesResetEvent(this._response);
}

// On Discovered Services
class OnDiscoveredServicesEvent with GetDeviceMixin, GetExceptionMixin {
  static const String method = "OnDiscoveredServices";

  final BmDiscoverServicesResult _response;

  OnDiscoveredServicesEvent(this._response);

  /// the new services
  List<BluetoothService> _constructServices() {
    final List<BluetoothService> services = [];
    Map<BluetoothService, List<String>> includedServicesMap = {};
    for (final bmService in _response.services) {
      final service = BluetoothService.fromProto(device, bmService);
      services.add(service);
      includedServicesMap[service] = bmService.includedServices;
    }

    for (final entry in includedServicesMap.entries) {
      final service = entry.key;
      final includedServices = entry.value;
      service.includedServices = includedServices.map((uuid) {
        final includedService = services._firstWhereOrNull((s) => s.identifier == uuid);
        if (includedService == null) {
          throw FlutterBluePlusException(
              ErrorPlatform.fbp, method, FbpErrorCode.serviceNotFound.index, "service not found: $uuid");
        }
        return includedService;
      }).toList();
    }

    return services;
  }
}

// On Characteristic Received
class OnCharacteristicReceivedEvent
    with GetDeviceMixin, GetAttributeValueMixin, GetCharacteristicMixin, GetExceptionMixin {
  static const String method = "OnCharacteristicReceived";

  final BmCharacteristicData _response;

  OnCharacteristicReceivedEvent(this._response);
}

// On Characteristic Written
class OnCharacteristicWrittenEvent
    with GetDeviceMixin, GetAttributeValueMixin, GetCharacteristicMixin, GetExceptionMixin {
  static const String method = "OnCharacteristicWritten";

  final BmCharacteristicData _response;

  OnCharacteristicWrittenEvent(this._response);
}

// On Descriptor Received
class OnDescriptorReadEvent with GetDeviceMixin, GetAttributeValueMixin, GetDescriptorMixin, GetExceptionMixin {
  static const String method = "OnDescriptorRead";

  final BmDescriptorData _response;

  OnDescriptorReadEvent(this._response);
}

// On Descriptor Written
class OnDescriptorWrittenEvent with GetDeviceMixin, GetAttributeValueMixin, GetDescriptorMixin, GetExceptionMixin {
  static const String method = "OnDescriptorWritten";

  final BmDescriptorData _response;

  OnDescriptorWrittenEvent(this._response);
}

// On Name Changed
class OnNameChangedEvent with GetDeviceMixin {
  static const String method = "OnNameChanged";

  final BmNameChanged _response; // TODO: Used to be BmBluetoothDevice??

  OnNameChangedEvent(this._response);

  /// the new name
  String? get name => _response.name; // TODO: Used to be BmBluetoothDevice??
}

// On Bond State Changed
class OnBondStateChangedEvent with GetDeviceMixin {
  static const String method = "OnBondStateChanged";

  final BmBondStateResponse _response;

  OnBondStateChangedEvent(this._response);

  /// the new bond state
  BluetoothBondState get bondState => _bmToBondState(_response.bondState);
  BluetoothBondState? get prevState => _response.prevState == null ? null : _bmToBondState(_response.prevState!);
}
