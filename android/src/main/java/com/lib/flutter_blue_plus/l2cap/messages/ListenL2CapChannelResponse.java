// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.messages;

import com.lib.flutter_blue_plus.l2cap.L2CapAttributeNames;

import java.util.HashMap;
import java.util.Map;

public class ListenL2CapChannelResponse {
    public final int psm;

    public ListenL2CapChannelResponse(final int psm) {
        this.psm = psm;
    }

    public Map<String, Object> marshal() {
        final Map<String, Object> dataMap = new HashMap<>();
        dataMap.put(L2CapAttributeNames.KEY_PSM, psm);
        return dataMap;
    }
}
