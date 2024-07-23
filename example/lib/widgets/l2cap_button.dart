import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class L2CapButton extends StatefulWidget {
  const L2CapButton({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _L2CapButtonState();
  }
}

class _L2CapButtonState extends State<L2CapButton> {
  bool l2CapListening = false;
  int psm = 0;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _handleButtonClick(context),
      icon: const Icon(Icons.bluetooth_audio_rounded),
    );
  }

  void _handleButtonClick(BuildContext context) async {
    if (l2CapListening) {
      await FlutterBluePlus.closeL2CapServer(psm: psm);
      setState(() {
        l2CapListening = false;
      });
    } else {
      final int newPsm = await FlutterBluePlus.listenL2CapChannel(secure: true);
      final snackBar = SnackBar(
        content: Text('NEW PSM IS: $newPsm'),
      );
      setState(() {
        psm = newPsm;
        l2CapListening = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      });
    }
  }
}
