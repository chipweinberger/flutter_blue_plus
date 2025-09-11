// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.messages;

import com.lib.flutter_blue_plus.l2cap.L2CapAttributeNames;

import java.util.Map;

public class CloseL2CapChannelRequest {
    public final String remoteId;
    public final int psm;


    public CloseL2CapChannelRequest(String remoteId, int psm) {
        this.remoteId = remoteId;
        this.psm = psm;
    }

    public static CloseL2CapChannelRequest unmarshal(final Map<String, Object> data) {
        final String remoteId = (String) data.get(L2CapAttributeNames.KEY_REMOTE_ID);
        final int psm = (int) data.get(L2CapAttributeNames.KEY_PSM);
        return new CloseL2CapChannelRequest(remoteId, psm);
    }


}
