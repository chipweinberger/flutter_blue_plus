// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.messages;

import com.lib.flutter_blue_plus.MarshallingUtil;
import com.lib.flutter_blue_plus.l2cap.L2CapAttributeNames;

import java.util.Map;

public class WriteL2CapChannelRequest {
    public final String remoteId;
    public final int psm;
    public final byte[] value;

    public WriteL2CapChannelRequest(String remoteId, int psm, byte[] value) {
        this.remoteId = remoteId;
        this.psm = psm;
        this.value = value;
    }

    public static WriteL2CapChannelRequest unmarshal(final Map<String, Object> data) {
        final int psm = (int) data.get(L2CapAttributeNames.KEY_PSM);
        final String remoteId = (String) data.get(L2CapAttributeNames.KEY_REMOTE_ID);
        final String valueAsString = (String) data.get(L2CapAttributeNames.KEY_VALUE);
        return new WriteL2CapChannelRequest(remoteId, psm, MarshallingUtil.hexToBytes(valueAsString));
    }

}
