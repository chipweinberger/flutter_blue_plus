import 'dart:async';
import 'dart:typed_data';

import 'package:core_bluetooth/core_bluetooth.dart';
import 'package:flutter/material.dart';

import '../central_manager_controller.dart';

class ScanResultTile extends StatefulWidget {
  const ScanResultTile({super.key, required this.result, this.onTap});

  final ScanResult result;
  final VoidCallback? onTap;

  @override
  State<ScanResultTile> createState() => _ScanResultTileState();
}

class _ScanResultTileState extends State<ScanResultTile> {
  CBPeripheralState _connectionState = CBPeripheralState.disconnected;

  late StreamSubscription<CBPeripheralState> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.result.peripheral.connectionState.listen((state) {
      _connectionState = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  String getNiceHexArray(List<int> bytes) {
    return '[${bytes.map((i) => i.toRadixString(16).padLeft(2, '0')).join(', ')}]';
  }

  String getNiceManufacturerData(Uint8List data) {
    return getNiceHexArray(data).toUpperCase();
  }

  String getNiceServiceData(Map<CBUUID, Uint8List> data) {
    return data.entries.map((v) => '${v.key.uuidString}: ${getNiceHexArray(v.value)}').join(', ').toUpperCase();
  }

  String getNiceServiceUuids(List<CBUUID> serviceUuids) {
    return serviceUuids.map((uuid) => uuid.uuidString).join(', ').toUpperCase();
  }

  bool get isConnected {
    return _connectionState == CBPeripheralState.connected;
  }

  Widget _buildTitle(BuildContext context) {
    final name = widget.result.peripheral.name;
    if (name != null && name.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            widget.result.peripheral.identifier.uuidString,
            style: Theme.of(context).textTheme.bodySmall,
          )
        ],
      );
    } else {
      return Text(widget.result.peripheral.identifier.uuidString);
    }
  }

  Widget _buildConnectButton(BuildContext context) {
    return TextButton(
      onPressed: widget.result.advertisementData.isConnectable ?? true ? widget.onTap : null,
      child: isConnected ? const Text('Open') : const Text('Connect'),
    );
  }

  Widget _buildAdvRow(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(
            width: 12.0,
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.apply(color: Colors.black),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var adv = widget.result.advertisementData;
    return ExpansionTile(
      title: _buildTitle(context),
      leading: Text(widget.result.rssi.toString()),
      trailing: _buildConnectButton(context),
      children: <Widget>[
        if ((adv.localName ?? '').isNotEmpty) _buildAdvRow(context, 'Name', adv.localName!),
        if (adv.txPowerLevel != null) _buildAdvRow(context, 'Tx Power Level', '${adv.txPowerLevel}'),
        if ((adv.manufacturerData?.isNotEmpty ?? false))
          _buildAdvRow(context, 'Manufacturer Data', getNiceManufacturerData(adv.manufacturerData!)),
        if ((adv.serviceUUIDs?.isNotEmpty ?? false))
          _buildAdvRow(context, 'Service UUIDs', getNiceServiceUuids(adv.serviceUUIDs!)),
        if (adv.serviceData.isNotEmpty) _buildAdvRow(context, 'Service Data', getNiceServiceData(adv.serviceData)),
      ],
    );
  }
}
