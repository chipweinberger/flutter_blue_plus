part of '../flutter_blue_plus_linux.dart';

final class _BlueZFoundCharacteristic {
  final BlueZGattService service;
  final BlueZGattCharacteristic characteristic;

  const _BlueZFoundCharacteristic({
    required this.service,
    required this.characteristic,
  });
}

// https://github.com/bluez/bluez/blob/master/doc/org.bluez.Device.rst#properties
enum _BlueZDeviceProperty {
  adapter('Adapter'),
  address('Address'),
  addressType('AddressType'),
  advertisingData('AdvertisingData'),
  advertisingFlags('AdvertisingFlags'),
  alias('Alias'),
  appearance('Appearance'),
  blocked('Blocked'),
  bonded('Bonded'),
  cablePairing('CablePairing'),
  connectable('Connectable'),
  connected('Connected'),
  deviceClass('Class'),
  encryptionType('EncryptionType'),
  icon('Icon'),
  legacyPairing('LegacyPairing'),
  manufacturerData('ManufacturerData'),
  modalias('Modalias'),
  name('Name'),
  paired('Paired'),
  preferredBearer('PreferredBearer'),
  rssi('RSSI'),
  securityLevel('SecurityLevel'),
  serviceData('ServiceData'),
  servicesResolved('ServicesResolved'),
  sets('Sets'),
  trusted('Trusted'),
  txPower('TxPower'),
  uuids('UUIDs'),
  wakeAllowed('WakeAllowed');

  final String dbusName;
  const _BlueZDeviceProperty(this.dbusName);
}

final class _BlueZDevicePropertyChanges {
  final List<String> _names;
  final Set<_BlueZDeviceProperty> _properties;

  _BlueZDevicePropertyChanges(this._names)
      : _properties = _BlueZDeviceProperty.values.where((property) => _names.contains(property.dbusName)).toSet();

  bool contains(_BlueZDeviceProperty property) => _properties.contains(property);

  @override
  String toString() => _names.toString();
}

final class _BlueZDeviceState {
  final BlueZDevice device;
  final DeviceIdentifier remoteId;
  final Stream<_BlueZDevicePropertyChanges> propertyChanges;
  final characteristicSubscriptions = <StreamSubscription<List<String>>>[];
  late final StreamSubscription<_BlueZDevicePropertyChanges> subscription;

  _BlueZDeviceState(this.device)
      : remoteId = device.remoteId,
        propertyChanges = device.propertiesChanged.map(_BlueZDevicePropertyChanges.new);

  // BlueZ recreates device wrappers.
  // Their property-change streams compare equal for the same cached object.
  bool matches(BlueZDevice other) => device.propertiesChanged == other.propertiesChanged;
}
