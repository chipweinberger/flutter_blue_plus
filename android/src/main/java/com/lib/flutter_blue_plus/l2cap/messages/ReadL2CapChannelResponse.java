// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.messages;

import com.lib.flutter_blue_plus.MarshallingUtil;
import com.lib.flutter_blue_plus.l2cap.L2CapAttributeNames;

import java.util.HashMap;
import java.util.Map;

public class ReadL2CapChannelResponse {
    public final String remoteId;
    public final int psm;
    public final int bytesRead;
    public final byte[] value;

    public ReadL2CapChannelResponse(String remoteId, int psm, int bytesRead, byte[] value) {
        this.remoteId = remoteId;
        this.psm = psm;
        this.bytesRead = bytesRead;
        this.value = value;
    }

    public Map<String, Object> marshal() {
        final Map<String, Object> dataMap = new HashMap<>();
        dataMap.put(L2CapAttributeNames.KEY_REMOTE_ID, remoteId);
        dataMap.put(L2CapAttributeNames.KEY_PSM, psm);
        dataMap.put(L2CapAttributeNames.KEY_BYTES_READ, bytesRead);
        dataMap.put(L2CapAttributeNames.KEY_VALUE, MarshallingUtil.bytesToHex(value));
        return dataMap;
    }
}
