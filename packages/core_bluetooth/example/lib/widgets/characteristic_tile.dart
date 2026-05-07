import 'dart:async';
import 'dart:typed_data';

import 'package:core_bluetooth/core_bluetooth.dart';
import 'package:flutter/material.dart';

import '../utils/data_entry.dart';
import '../utils/snackbar.dart';
import 'descriptor_tile.dart';

class CharacteristicTile extends StatefulWidget {
  const CharacteristicTile({super.key, required this.characteristic, required this.descriptorTiles});

  final CBCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  Uint8List? _value;

  StreamSubscription<DidUpdateValueForCharacteristicResult>? _valueSubscription;
  StreamSubscription<DidUpdateNotificationStateForCharacteristicResult>? _notifySubscription;
  StreamSubscription<DidWriteValueForCharacteristicResult>? _writeSubscription;

  @override
  void initState() {
    super.initState();
    _value = widget.characteristic.value;

    final peripheral = widget.characteristic.service?.peripheral;
    if (peripheral != null) {
      _valueSubscription = peripheral.onDidUpdateValueForCharacteristic.listen((result) {
        if (result.characteristic.handle == widget.characteristic.handle) {
          _value = result.characteristic.value;
          _update();
        }
      });
      _notifySubscription = peripheral.onDidUpdateNotificationStateForCharacteristic.listen((result) {
        if (result.characteristic.handle == widget.characteristic.handle) {
          _update();
        }
      });
      _writeSubscription = peripheral.onDidWriteValueForCharacteristic.listen((result) {
        if (result.characteristic.handle == widget.characteristic.handle) {
          _update();
        }
      });
    }
  }

  @override
  void dispose() {
    _valueSubscription?.cancel();
    _notifySubscription?.cancel();
    _writeSubscription?.cancel();
    super.dispose();
  }

  CBCharacteristic get c => widget.characteristic;

  CBPeripheral? get peripheral => c.service?.peripheral;

  Future<void> onReadPressed() async {
    try {
      await peripheral?.readValue(c);
      Snackbar.show(ABC.c, "Read: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Read Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Future<void> onWritePressed() async {
    try {
      final value = await DataEntry.enterData(context);
      if (value != null && peripheral != null) {
        final withoutResponse = c.properties.hasWriteWithoutResponse && !c.properties.hasWrite;
        await peripheral!.writeValue(
          Uint8List.fromList(value),
          forAttribute: c,
          type: withoutResponse ? CBCharacteristicWriteType.withoutResponse : CBCharacteristicWriteType.withResponse,
        );
        Snackbar.show(ABC.c, "Write: Success", success: true);
        if (c.properties.hasRead) {
          await peripheral!.readValue(c);
        }
      }
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Write Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Future<void> onSubscribePressed() async {
    try {
      final op = c.isNotifying == false ? "Subscribe" : "Unsubscribe";
      await peripheral?.setNotifyValue(c.isNotifying == false, c);
      Snackbar.show(ABC.c, "$op : Success", success: true);
      if (c.properties.hasRead) {
        await peripheral?.readValue(c);
      }
      _update();
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Subscribe Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Widget buildUuid(BuildContext context) {
    return Text(c.uuid.uuidString.toUpperCase(), style: const TextStyle(fontSize: 13));
  }

  Widget buildValue(BuildContext context) {
    final data = (_value ?? Uint8List(0)).toList().toString();
    return Text(data, style: const TextStyle(fontSize: 13, color: Colors.grey));
  }

  Widget buildReadButton(BuildContext context) {
    return TextButton(
      child: const Text("Read"),
      onPressed: () async {
        await onReadPressed();
        _update();
      },
    );
  }

  Widget buildWriteButton(BuildContext context) {
    final withoutResp = c.properties.hasWriteWithoutResponse && !c.properties.hasWrite;
    return TextButton(
      child: Text(withoutResp ? "WriteNoResp" : "Write"),
      onPressed: () async {
        await onWritePressed();
        _update();
      },
    );
  }

  Widget buildSubscribeButton(BuildContext context) {
    final isNotifying = c.isNotifying;
    return TextButton(
      child: Text(isNotifying ? "Unsubscribe" : "Subscribe"),
      onPressed: () async {
        await onSubscribePressed();
        _update();
      },
    );
  }

  Widget buildButtonRow(BuildContext context) {
    final read = c.properties.hasRead;
    final write = c.properties.hasWrite || c.properties.hasWriteWithoutResponse;
    final notify = c.properties.hasNotify;
    final indicate = c.properties.hasIndicate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (read) buildReadButton(context),
        if (write) buildWriteButton(context),
        if (notify || indicate) buildSubscribeButton(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: ListTile(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Characteristic', style: TextStyle(color: Theme.of(context).primaryColor)),
            buildUuid(context),
            buildValue(context),
          ],
        ),
        subtitle: buildButtonRow(context),
        contentPadding: EdgeInsets.zero,
      ),
      children: widget.descriptorTiles,
    );
  }

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }
}
