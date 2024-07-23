// Copyright 2023, Christopher Schott
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:convert/convert.dart';

extension BytesToHexString on List<int> {
  String bytesToHexString() {
    if (isEmpty) {
      return '';
    } else {
      return hex.encode(this);
    }
  }
}
