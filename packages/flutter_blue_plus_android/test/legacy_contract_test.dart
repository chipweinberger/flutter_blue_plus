import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/android_host.dart';

Map<String, Object?> _identity(
        DeviceIdentifier remoteId, Guid? primary, Guid service, Guid characteristic, int instance) =>
    {
      'remote_id': remoteId.str,
      if (primary != null) 'primary_service_uuid': primary.str,
      'service_uuid': service.str,
      'characteristic_uuid': characteristic.str,
      'instance_id': instance,
    };
Map<String, Object?> _descriptor(BmBluetoothDescriptor d) => {
      ..._identity(d.remoteId, d.primaryServiceUuid, d.serviceUuid, d.characteristicUuid, d.instanceId),
      'descriptor_uuid': d.descriptorUuid.str,
    };
Map<String, Object?> _characteristic(BmBluetoothCharacteristic c) {
  final p = c.properties;
  return {
    ..._identity(c.remoteId, c.primaryServiceUuid, c.serviceUuid, c.characteristicUuid, c.instanceId),
    'descriptors': c.descriptors.map(_descriptor).toList(),
    'properties': {
      'broadcast': p.broadcast ? 1 : 0,
      'read': p.read ? 1 : 0,
      'write_without_response': p.writeWithoutResponse ? 1 : 0,
      'write': p.write ? 1 : 0,
      'notify': p.notify ? 1 : 0,
      'indicate': p.indicate ? 1 : 0,
      'authenticated_signed_writes': p.authenticatedSignedWrites ? 1 : 0,
      'extended_properties': p.extendedProperties ? 1 : 0,
      'notify_encryption_required': p.notifyEncryptionRequired ? 1 : 0,
      'indicate_encryption_required': p.indicateEncryptionRequired ? 1 : 0,
    },
  };
}

Map<String, Object?> _service(BmBluetoothService s) => {
      'remote_id': s.remoteId.str,
      if (s.primaryServiceUuid != null) 'primary_service_uuid': s.primaryServiceUuid!.str,
      'service_uuid': s.serviceUuid.str,
      'characteristics': s.characteristics.map(_characteristic).toList(),
    };
Map<String, Object?> _advertisement(BmScanAdvertisement a) => {
      'remote_id': a.remoteId.str,
      'platform_name': a.platformName,
      'adv_name': a.advName,
      'connectable': a.connectable ? 1 : 0,
      'rssi': a.rssi,
      if (a.appearance != null) 'appearance': a.appearance,
      if (a.txPowerLevel != null) 'tx_power_level': a.txPowerLevel,
      'manufacturer_data': {for (final entry in a.manufacturerData.entries) '${entry.key}': entry.value},
      'service_data': {for (final entry in a.serviceData.entries) entry.key.str: entry.value},
      'service_uuids': a.serviceUuids.map((u) => u.str).toList(),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configFile = File('.dart_tool/package_config.json');
  final config = jsonDecode(configFile.readAsStringSync()) as Map;
  final package = (config['packages'] as List).singleWhere((p) => p['name'] == 'flutter_blue_plus_android');
  final rootUri = package['rootUri'] as String;
  final packageRoot = configFile.absolute.uri.resolve(rootUri.endsWith('/') ? rootUri : '$rootUri/');
  final fixtures =
      jsonDecode(File.fromUri(packageRoot.resolve('test/reference/contract.json')).readAsStringSync()) as Map;
  final graphs = <String, List<Map<String, Object?>>>{
    'unique': [service('s')],
    'duplicateCharacteristics': [
      service('s', characteristics: [characteristic('a', instanceId: 4), characteristic('b', instanceId: 9)])
    ],
    'duplicateServices': [
      service('s1', characteristics: [characteristic('a'), characteristic('b', id: '2a38', instanceId: 78)]),
      service('s2', characteristics: [characteristic('c', instanceId: 79)])
    ],
    'included': [
      service('p',
          id: '1800',
          characteristics: [characteristic('pc', id: '2a00', instanceId: 3)],
          included: [service('secondary', type: 1)])
    ],
  };
  late AndroidHost host;
  setUp(() async {
    host = AndroidHost();
    await host.setUp();
  });
  tearDown(() => host.tearDown());

  for (final graph in graphs.entries) {
    test('${graph.key} matches actual original Java service serialization', () async {
      host.services = graph.value;
      final discovered = host.collect(host.backend.onDiscoveredServices);
      await host.connect();
      expect(discovered.single.services.map(_service).toList(), fixtures[graph.key]);
    });
  }

  test('advertisement matches actual original Java serialization', () async {
    final responses = host.collect(host.backend.onScanResponse);
    await host.backend.startScan(scanSettings());
    await host.advertisement([4, 255, 0x4c, 0, 1, 4, 255, 0x4c, 0, 2, 3, 0x19, 0x40, 3, 0]);
    expect(_advertisement(responses.single.advertisements.single), fixtures['advertisement']);
  });
}
