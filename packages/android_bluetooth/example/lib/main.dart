import 'dart:async';
import 'package:android_bluetooth/android_bluetooth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MaterialApp(home: BluetoothExplorer()));

class BluetoothExplorer extends StatefulWidget {
  const BluetoothExplorer({super.key});
  @override
  State<BluetoothExplorer> createState() => _BluetoothExplorerState();
}

class _BluetoothExplorerState extends State<BluetoothExplorer> {
  final _devices = <String, ScanResult>{};
  final _log = <String>[];
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _psm = TextEditingController();
  final _scanner = BluetoothLeScanner.shared;
  BluetoothGatt? _gatt;
  BluetoothGattServer? _server;
  BluetoothAdvertisement? _advertisement;
  BluetoothServerSocket? _listener;
  BluetoothSocket? _socket;
  BluetoothDevice? _selected;
  List<BluetoothGattService> _services = [];
  Uint8List _value = Uint8List.fromList([0]);
  bool _busy = false;

  void _record(Object value) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, value.toString());
      if (_log.length > 100) _log.removeLast();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _record(error);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _permissions() async {
    final capabilities = await AndroidBluetooth.capabilities;
    final names = capabilities.apiLevel >= 31
        ? ['BLUETOOTH_SCAN', 'BLUETOOTH_CONNECT', 'BLUETOOTH_ADVERTISE']
        : ['ACCESS_FINE_LOCATION'];
    final result = await AndroidBluetooth.requestPermissions(names.map((p) => 'android.permission.$p').toList());
    if (result.values.any((granted) => !granted)) throw StateError('Required permissions were denied');
    if (!await BluetoothAdapter.shared.isEnabled) await BluetoothAdapter.shared.requestEnable();
  }

  Future<void> _scan() async {
    await _permissions();
    await _scanner.stopScan();
    setState(_devices.clear);
    await _scanner.startScan(settings: const ScanSettings(scanMode: ScanSettings.scanModeLowLatency));
  }

  Future<void> _connect(BluetoothDevice device) async {
    await _scanner.stopScan();
    await _gatt?.close();
    final gatt = await device.connectGatt();
    _gatt = gatt;
    setState(() {
      _selected = device;
      _services = [];
    });
    _subscriptions.add(gatt.events.listen((event) async {
      _record('${event.type}: status=${event.status} ${event.value ?? ''}');
      if (event.type == 'onConnectionStateChange' &&
          event.status == 0 &&
          event.newState == BluetoothProfile.stateConnected) {
        try {
          await gatt.discoverServices();
        } catch (e) {
          _record(e);
        }
      }
      if (event.type == 'onServicesDiscovered' && event.status == 0 && mounted) {
        setState(() => _services = event.services);
      }
      if (event.type == 'onServiceChanged' && mounted) setState(() => _services = []);
    }));
  }

  Future<void> _subscribe(BluetoothGattCharacteristic characteristic) async {
    final gatt = _gatt!;
    final cccd = characteristic.getDescriptor('2902');
    if (cccd == null) throw StateError('Characteristic has no CCCD');
    final indicate = characteristic.properties & BluetoothGattCharacteristic.propertyNotify == 0;
    final completion = Completer<BluetoothGattCallback>();
    final subscription = gatt.onDescriptorWrite.listen((event) {
      if (event.descriptor.handle == cccd.handle && !completion.isCompleted) completion.complete(event);
    });
    try {
      if (!await gatt.setCharacteristicNotification(characteristic, true)) throw StateError('Local routing failed');
      final accepted = await gatt.writeDescriptor(cccd,
          indicate ? BluetoothGattDescriptor.enableIndicationValue : BluetoothGattDescriptor.enableNotificationValue);
      if (accepted != 0) throw StateError('CCCD write rejected: $accepted');
      final event = await completion.future.timeout(const Duration(seconds: 15));
      if (event.status != 0) throw StateError('CCCD write failed: ${event.status}');
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _peripheral() async {
    await _permissions();
    if (_server != null) {
      await _advertisement?.stop();
      await _server!.close();
      setState(() {
        _server = null;
        _advertisement = null;
      });
      return;
    }
    final characteristic = BluetoothGattCharacteristic(
        'FFF1',
        BluetoothGattCharacteristic.propertyRead | BluetoothGattCharacteristic.propertyWrite,
        BluetoothGattCharacteristic.permissionRead | BluetoothGattCharacteristic.permissionWrite);
    final service = BluetoothGattService('FFF0', characteristics: [characteristic]);
    final server = await BluetoothManager.shared.openGattServer();
    _server = server;
    _subscriptions.add(server.events.listen((e) async {
      try {
        _record('server: ${e.type}');
        if (e.type == 'onCharacteristicReadRequest') {
          final offset = e.offset!;
          await server.sendResponse(e.device!, e.requestId!,
              offset > _value.length ? BluetoothGatt.gattInvalidOffset : BluetoothGatt.gattSuccess,
              offset: offset, value: offset > _value.length ? null : Uint8List.sublistView(_value, offset));
        } else if (e.type == 'onCharacteristicWriteRequest') {
          final status = e.preparedWrite == true
              ? BluetoothGatt.gattRequestNotSupported
              : e.offset != 0
                  ? BluetoothGatt.gattInvalidOffset
                  : BluetoothGatt.gattSuccess;
          if (status == 0) _value = e.value!;
          if (e.responseNeeded == true) await server.sendResponse(e.device!, e.requestId!, status);
        } else if (e.type == 'onExecuteWrite') {
          await server.sendResponse(e.device!, e.requestId!, BluetoothGatt.gattRequestNotSupported);
        }
      } catch (error) {
        _record(error);
      }
    }));
    try {
      final added = server.onServiceAdded.first.timeout(const Duration(seconds: 15));
      if (!await server.addService(service)) throw StateError('Service registration rejected');
      if ((await added).status != 0) throw StateError('Service registration failed');
      final advertisement = await BluetoothLeAdvertiser.shared.startAdvertising(
          data: const AdvertiseData(serviceUuids: ['FFF0']),
          scanResponse: const AdvertiseData(includeDeviceName: true));
      _advertisement = advertisement;
      _subscriptions.add(advertisement.events.listen((e) => _record('advertise: ${e.type} ${e.errorCode ?? ''}')));
      if (mounted) setState(() {});
    } catch (_) {
      await server.close();
      _server = null;
      rethrow;
    }
  }

  Future<void> _listenL2cap() async {
    await _permissions();
    final listener = await BluetoothAdapter.shared.listenUsingInsecureL2capChannel();
    _listener = listener;
    _record('L2CAP listening on PSM ${listener.psm}; advertise or publish this PSM to your peer');
    unawaited(() async {
      BluetoothSocket? socket;
      try {
        socket = await listener.accept();
        _record('L2CAP peer: ${socket.remoteDevice.address}');
        while (mounted) {
          final bytes = await socket.read();
          if (bytes.isEmpty) break;
          _record('L2CAP echo: $bytes');
          await socket.write(bytes);
        }
      } catch (e) {
        _record(e);
      } finally {
        await socket?.close();
      }
    }());
  }

  Future<void> _connectL2cap() async {
    final device = _selected;
    if (device == null) throw StateError('Select/connect a device first');
    final psm = int.parse(_psm.text);
    await _socket?.close();
    final socket = await device.createInsecureL2capChannel(psm);
    _socket = socket;
    await socket.connect();
    await socket.write(Uint8List.fromList([1, 2, 3]));
    _record('L2CAP connected and sent [1, 2, 3]');
  }

  @override
  void initState() {
    super.initState();
    _subscriptions.add(_scanner.events.listen((e) {
      if (mounted) {
        setState(() {
          for (final r in e.results) {
            _devices[r.device.address] = r;
          }
        });
      }
      if (e.errorCode != null) _record('Scan failed: ${e.errorCode}');
    }, onError: _record));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    for (final close in <Future<void> Function()>[
      _scanner.stopScan,
      if (_gatt != null) _gatt!.close,
      if (_server != null) _server!.close,
      if (_advertisement != null) _advertisement!.stop,
      if (_listener != null) _listener!.close,
      if (_socket != null) _socket!.close,
    ]) {
      unawaited(close().catchError((Object _) {}));
    }
    _psm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AndroidBluetooth BLE explorer')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: _busy ? null : () => _run(_scan), child: const Text('Scan')),
            OutlinedButton(onPressed: () => _run(_scanner.stopScan), child: const Text('Stop scan')),
            OutlinedButton(
                onPressed: () => _run(_peripheral),
                child: Text(_server == null ? 'Start peripheral' : 'Stop peripheral')),
            OutlinedButton(
                onPressed: _listener != null ? null : () => _run(_listenL2cap), child: const Text('Listen L2CAP')),
          ]),
          if (_busy) const LinearProgressIndicator(),
          ..._devices.values.map((r) => ListTile(
                title: Text(r.scanRecord?.deviceName ?? r.device.name ?? r.device.address),
                subtitle: Text('${r.device.address} · ${r.rssi} dBm'),
                onTap: _busy ? null : () => _run(() => _connect(r.device)),
              )),
          if (_selected != null) Text('Selected: ${_selected!.address}'),
          ..._services.map((s) => ExpansionTile(title: Text(s.uuid), children: [
                ...s.characteristics.map((c) => ListTile(
                    key: ValueKey(c.handle),
                    title: Text(c.uuid),
                    subtitle: Text('instance ${c.instanceId}, properties ${c.properties}'),
                    trailing: Wrap(children: [
                      if (c.properties & BluetoothGattCharacteristic.propertyRead != 0)
                        IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _run(() async {
                                  await _gatt!.readCharacteristic(c);
                                })),
                      if (c.properties &
                              (BluetoothGattCharacteristic.propertyNotify |
                                  BluetoothGattCharacteristic.propertyIndicate) !=
                          0)
                        IconButton(icon: const Icon(Icons.notifications), onPressed: () => _run(() => _subscribe(c))),
                    ]))),
              ])),
          TextField(
              controller: _psm,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Peer L2CAP PSM')),
          OutlinedButton(onPressed: () => _run(_connectL2cap), child: const Text('Connect L2CAP and send bytes')),
          const Divider(),
          const Text('Events'),
          ..._log.map((line) => SelectableText(line)),
        ]),
      );
}
