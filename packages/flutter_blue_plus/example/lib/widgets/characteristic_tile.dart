import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../utils/data_entry.dart';
import "../utils/snackbar.dart";

import "descriptor_tile.dart";

class CharacteristicTile extends StatefulWidget {
  final BluetoothCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;

  const CharacteristicTile({super.key, required this.characteristic, required this.descriptorTiles});

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  List<int> _value = [];

  late StreamSubscription<List<int>> _lastValueSubscription;

  @override
  void initState() {
    super.initState();
    _lastValueSubscription = widget.characteristic.lastValueStream.listen((value) {
      _value = value;
      _update();
    });
  }

  @override
  void dispose() {
    _lastValueSubscription.cancel();
    super.dispose();
  }

  BluetoothCharacteristic get c => widget.characteristic;

  Future onReadPressed() async {
    try {
      await c.read();
      Snackbar.show(ABC.c, "Read: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Read Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Future onWritePressed() async {
    try {
      List<int>? value = await DataEntry.enterData(context);
      if (value != null) {
        await c.write(value, withoutResponse: c.properties.writeWithoutResponse);
        Snackbar.show(ABC.c, "Write: Success", success: true);
        if (c.properties.read) {
          await c.read();
        }
      }
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Write Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Future onSubscribePressed() async {
    try {
      String op = c.isNotifying == false ? "Subscribe" : "Unubscribe";
      await c.setNotifyValue(c.isNotifying == false);
      Snackbar.show(ABC.c, "$op : Success", success: true);
      if (c.properties.read) {
        await c.read();
      }
      _update();
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Subscribe Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Widget buildUuid(BuildContext context) {
    String uuid = '0x${widget.characteristic.uuid.str.toUpperCase()}';
    return Text(uuid, style: TextStyle(fontSize: 13));
  }

  Widget buildValue(BuildContext context) {
    String data = _value.toString();
    return Text(data, style: TextStyle(fontSize: 13, color: Colors.grey));
  }

  Widget buildReadButton(BuildContext context) {
    return TextButton(
        child: Text("Read"),
        onPressed: () async {
          await onReadPressed();
          _update();
        });
  }

  Widget buildWriteButton(BuildContext context) {
    bool withoutResp = widget.characteristic.properties.writeWithoutResponse;
    return TextButton(
        child: Text(withoutResp ? "WriteNoResp" : "Write"),
        onPressed: () async {
          await onWritePressed();
          _update();
        });
  }

  Widget buildSubscribeButton(BuildContext context) {
    bool isNotifying = widget.characteristic.isNotifying;
    return TextButton(
        child: Text(isNotifying ? "Unsubscribe" : "Subscribe"),
        onPressed: () async {
          await onSubscribePressed();
          _update();
        });
  }

  Widget buildButtonRow(BuildContext context) {
    bool read = widget.characteristic.properties.read;
    bool write = widget.characteristic.properties.write;
    bool notify = widget.characteristic.properties.notify;
    bool indicate = widget.characteristic.properties.indicate;
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
        contentPadding: const EdgeInsets.all(0.0),
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
