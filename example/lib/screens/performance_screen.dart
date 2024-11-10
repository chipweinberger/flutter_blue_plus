import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PerformanceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const PerformanceScreen({
    Key? key,
    required this.device,
  }) : super(key: key);

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final epochText = TextEditingController(text: '1');
  final bytesText = TextEditingController(text: '512');
  final requestsText = TextEditingController(text: '100');
  final form = GlobalKey<FormState>();
  final elapsedTimes = <_ElapsedTime>[];

  String? error;
  Stream<int>? epochProgress;
  Stream<double>? writeProgress;

  BluetoothCharacteristic? get writableChar => widget.device.servicesList
      .cast<BluetoothService?>()
      .firstWhere((service) {
        return service!.characteristics.any((char) {
          return char.properties.write | char.properties.writeWithoutResponse;
        });
      }, orElse: () => null)
      ?.characteristics
      .firstWhere((char) => char.properties.write | char.properties.writeWithoutResponse);

  @override
  Widget build(BuildContext context) {
    late Widget body;
    if (writeProgress == null) {
      body = Form(
        key: form,
        child: ListView(children: [
          if (error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            ),
          if (elapsedTimes.isNotEmpty) ...[
            Center(child: Text('History Table')),
            SelectionArea(
              child: Table(
                border: TableBorder.all(color: Colors.grey),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(children: const [
                    TableCell(child: Text('Start', textAlign: TextAlign.center)),
                    TableCell(child: Text('Duration', textAlign: TextAlign.center)),
                  ]),
                  for (final time in elapsedTimes)
                    TableRow(children: [
                      TableCell(child: Text(time.startString(), textAlign: TextAlign.center)),
                      TableCell(child: Text(time.durationString(), textAlign: TextAlign.center)),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            ElevatedButton(
              onPressed: start,
              child: const Text('Start'),
            ),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: epochText,
            decoration: const InputDecoration(labelText: 'Epoch'),
            keyboardType: TextInputType.number,
            validator: _validateNumber,
          ),
          TextFormField(
            controller: bytesText,
            decoration: const InputDecoration(labelText: 'Bytes to send'),
            keyboardType: TextInputType.number,
            validator: _validateNumber,
          ),
          TextFormField(
            controller: requestsText,
            decoration: const InputDecoration(labelText: 'Send requests'),
            keyboardType: TextInputType.number,
            validator: _validateNumber,
          ),
        ]),
      );
    } else {
      body = Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          StreamBuilder<double>(
            stream: writeProgress,
            builder: (context, snapshot) {
              final v = ((snapshot.data ?? 0) * 100).toInt();
              return Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(value: snapshot.data),
                const SizedBox(height: 8),
                Text('$v%'),
              ]);
            },
          ),
          const SizedBox(height: 8),
          StreamBuilder<int>(
            stream: epochProgress,
            builder: (context, snapshot) {
              final v = snapshot.data ?? 1;
              final total = int.parse(epochText.text);
              return Text('Epoch: $v/$total');
            },
          ),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: body,
      ),
    );
  }

  void start() {
    if (form.currentState?.validate() != true) {
      return;
    }

    final char = writableChar;
    if (char == null) {
      setState(() {
        error = 'No writable characteristic found';
      });
      return;
    }

    elapsedTimes.clear();

    final controller = StreamController<int>();
    final stream = batch(char, controller);

    setState(() {
      writeProgress = stream;
      epochProgress = controller.stream;
    });
  }

  Stream<double> batch(BluetoothCharacteristic char, StreamController controller) async* {
    final bytes = await widget.device.requestMtu(int.parse(bytesText.text));

    final epochs = int.parse(epochText.text);
    final count = int.parse(requestsText.text);
    final data = Uint8List.fromList(List<int>.generate(bytes - 5, (index) => index));

    var stop = false;
    for (var i = 0; i < epochs; i++) {
      elapsedTimes.add(_ElapsedTime.start());
      yield* _write(char, count, bytes, data).handleError((e) {
        if (mounted) {
          setState(() {
            writeProgress = null;
            epochProgress = null;
            elapsedTimes.last.finish();
            error = e.toString();
          });
        }

        stop = true;
      });
      if (stop) {
        break;
      }

      elapsedTimes.last.finish();
      controller.add(i + 1);
    }

    await controller.close();
    setState(() {
      writeProgress = null;
      epochProgress = null;
      error = null;
    });
  }

  /// Write [bytes] length of data one by one and will send [count] times.
  Stream<double> _write(
    BluetoothCharacteristic char,
    int count,
    int bytes,
    Uint8List data,
  ) async* {
    for (var i = 0; i < count; i++) {
      await char.write(data, withoutResponse: char.properties.writeWithoutResponse);

      yield (i + 1) / count;
    }
  }
}

String? _validateNumber(String? value) {
  return int.tryParse(value ?? '') == null ? 'Invalid number' : null;
}

class _ElapsedTime {
  final DateTime start;
  late final DateTime end;
  late final Duration elapsed;

  _ElapsedTime(this.start);

  factory _ElapsedTime.start() => _ElapsedTime(DateTime.now());

  void finish() {
    end = DateTime.now();
    elapsed = end.difference(start);
  }

  String startString() {
    final hour = start.hour.toString().padLeft(2, '0');
    final minute = start.minute.toString().padLeft(2, '0');
    final second = start.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String durationString() {
    return (elapsed.inMilliseconds / 1000).toStringAsPrecision(5);
  }
}
