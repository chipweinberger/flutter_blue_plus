
import 'dart:convert';

import 'package:flutter/material.dart';

class DataEntry {

  static Future<List<int>?> enterData(BuildContext context) async {
    ValueNotifier<bool> isHex = ValueNotifier(false);
    TextEditingController dataController = TextEditingController(text: '');
    double width = MediaQuery.sizeOf(context).width;

    String? res = await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            content: SizedBox(
              width: width - 20,
              child: Form(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    ValueListenableBuilder(
                      valueListenable: isHex,
                      builder: (context, value, _) => SegmentedButton(
                        segments: [
                          ButtonSegment(value: false, label: const Text('String')),
                          ButtonSegment(value: true, label: const Text('Hex')),
                        ],
                        selected: {value},
                        multiSelectionEnabled: false,
                        onSelectionChanged: (values) {
                          isHex.value = values.contains(true);
                          dataController.text = '';
                        },
                      ),
                    ),
                    TextFormField(
                      controller: dataController,
                      decoration: const InputDecoration(hintText: "Enter data"),
                      minLines: 1,
                      maxLines: 10,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (isHex.value && _fromHex(value) == null) {
                            return "Invalid hex string";
                          }
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.send,
                      onFieldSubmitted: (value) => Navigator.pop(ctx, dataController.text),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, dataController.text),
                child: const Text("Submit"),
              ),
            ],
          );
        });

    if (res == null || res.isEmpty) {
      return null;
    }
    return isHex.value ? _fromHex(res) : utf8.encode(res);
  }

  static List<int>? _fromHex(String? value) {
    if (value == null || value.length % 2 != 0) {
      return null;
    }
    try {
      return [for (int i = 0; i < value.length; i += 2) int.parse(value.substring(i, i + 2), radix: 16)];
    } catch(_) {
      return null;
    }
  }
}
