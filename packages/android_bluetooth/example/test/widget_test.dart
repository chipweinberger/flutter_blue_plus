import 'package:android_bluetooth_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explorer opens without requesting permissions or starting a scan', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.android_bluetooth/events'), (call) async => null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('dev.android_bluetooth/methods'),
        (call) async {
      calls.add(call.method);
      return null;
    });
    await tester.pumpWidget(const MaterialApp(home: BluetoothExplorer()));
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Start peripheral'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
