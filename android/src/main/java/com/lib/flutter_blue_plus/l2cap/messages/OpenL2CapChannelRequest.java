// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.messages;

import com.lib.flutter_blue_plus.l2cap.L2CapAttributeNames;

import java.util.Map;

public class OpenL2CapChannelRequest {
    public final String remoteId;
    public final int psm;
    public final boolean secure;

    public OpenL2CapChannelRequest(String remoteId, int psm, boolean secure) {
        this.remoteId = remoteId;
        this.psm = psm;
        this.secure = secure;
    }

    public static OpenL2CapChannelRequest unmarshal(final Map<String, Object> data) {
        final String remoteId = (String) data.get(L2CapAttributeNames.KEY_REMOTE_ID);
        final int psm = (int) data.get(L2CapAttributeNames.KEY_PSM);
        final boolean secure = (boolean) data.get(L2CapAttributeNames.KEY_SECURE);
        return new OpenL2CapChannelRequest(remoteId, psm, secure);
    }


}
