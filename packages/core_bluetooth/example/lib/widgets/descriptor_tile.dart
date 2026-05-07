import 'dart:async';
import 'dart:typed_data';

import 'package:core_bluetooth/core_bluetooth.dart';
import 'package:flutter/material.dart';

import '../utils/data_entry.dart';
import '../utils/snackbar.dart';

class DescriptorTile extends StatefulWidget {
  const DescriptorTile({super.key, required this.descriptor});

  final CBDescriptor descriptor;

  @override
  State<DescriptorTile> createState() => _DescriptorTileState();
}

class _DescriptorTileState extends State<DescriptorTile> {
  Object? _value;

  StreamSubscription<DidUpdateValueForDescriptorResult>? _valueSubscription;
  StreamSubscription<DidWriteValueForDescriptorResult>? _writeSubscription;

  @override
  void initState() {
    super.initState();
    _value = widget.descriptor.value;

    final peripheral = widget.descriptor.characteristic?.service?.peripheral;
    if (peripheral != null) {
      _valueSubscription = peripheral.onDidUpdateValueForDescriptor.listen((result) {
        if (result.descriptor.handle == widget.descriptor.handle) {
          _value = result.descriptor.value;
          _update();
        }
      });
      _writeSubscription = peripheral.onDidWriteValueForDescriptor.listen((result) {
        if (result.descriptor.handle == widget.descriptor.handle) {
          _update();
        }
      });
    }
  }

  @override
  void dispose() {
    _valueSubscription?.cancel();
    _writeSubscription?.cancel();
    super.dispose();
  }

  CBDescriptor get d => widget.descriptor;

  CBPeripheral? get peripheral => d.characteristic?.service?.peripheral;

  Future<void> onReadPressed() async {
    try {
      await peripheral?.readValue(d);
      Snackbar.show(ABC.c, "Descriptor Read: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Descriptor Read Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Future<void> onWritePressed() async {
    try {
      final value = await DataEntry.enterData(context);
      if (value != null && peripheral != null) {
        await peripheral!.writeValue(Uint8List.fromList(value), forAttribute: d);
        Snackbar.show(ABC.c, "Descriptor Write: Success", success: true);
        await peripheral!.readValue(d);
      }
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Descriptor Write Error:", e), success: false);
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Widget buildUuid(BuildContext context) {
    return Text(d.uuid.uuidString.toUpperCase(), style: const TextStyle(fontSize: 13));
  }

  Widget buildValue(BuildContext context) {
    return Text('${_value ?? ''}', style: const TextStyle(fontSize: 13, color: Colors.grey));
  }

  Widget buildReadButton(BuildContext context) {
    return TextButton(
      onPressed: onReadPressed,
      child: const Text("Read"),
    );
  }

  Widget buildWriteButton(BuildContext context) {
    return TextButton(
      onPressed: onWritePressed,
      child: const Text("Write"),
    );
  }

  Widget buildButtonRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        buildReadButton(context),
        buildWriteButton(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Descriptor', style: TextStyle(color: Theme.of(context).primaryColor)),
          buildUuid(context),
          buildValue(context),
        ],
      ),
      subtitle: buildButtonRow(context),
    );
  }

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }
}
