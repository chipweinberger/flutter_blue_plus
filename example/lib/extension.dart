// Copyright 2023, Christopher Schott
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// Local hex helpers to avoid external dependencies

extension BytesToHexString on List<int> {
  String bytesToHexString() {
    if (isEmpty) {
      return '';
    } else {
      final StringBuffer buffer = StringBuffer();
      for (final int byte in this) {
        final String hexByte = byte.toRadixString(16).padLeft(2, '0');
        buffer.write(hexByte);
      }
      return buffer.toString();
    }
  }
}
