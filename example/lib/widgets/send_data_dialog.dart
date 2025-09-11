import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SendDataDialog extends StatefulWidget {
  final L2CapChannelConnected _connection;

  const SendDataDialog({Key? key, required L2CapChannelConnected connection})
      : _connection = connection,
        super(key: key);

  @override
  State<SendDataDialog> createState() => _SendDataDialogState();
}

class _SendDataDialogState extends State<SendDataDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  List<int> _hexStringToIntList(String str) {
    return hex.decode(str.replaceAll(' ', ''));
  }

  @override
  Widget build(BuildContext context) {
    final hexReg = RegExp(r'^(?:[\dA-Fa-f]{2} ){0,31}[\dA-Fa-f]{2}$');

    return AlertDialog(
      title: const Text("Send data"),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
            hintText: 'Enter data in hex',
            errorText: hexReg.hasMatch(_controller.text)
                ? null
                : 'Please enter data in hex!'),
        onChanged: (value) {
          setState(() {});
        },
      ),
      actions: [
        TextButton(
          onPressed: hexReg.hasMatch(_controller.text)
              ? () {
                  widget._connection.device.writeL2CapChannel(
                    psm: widget._connection.psm,
                    bytesToSend: _hexStringToIntList(_controller.text),
                  );
                }
              : null,
          child: const Text("Ok"),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
