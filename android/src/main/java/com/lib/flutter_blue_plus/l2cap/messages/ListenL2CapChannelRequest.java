// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.messages;

import com.lib.flutter_blue_plus.l2cap.L2CapAttributeNames;

import java.util.Map;

public class ListenL2CapChannelRequest {
    public final boolean secure;

    public ListenL2CapChannelRequest(boolean secure) {
        this.secure = secure;
    }

    public static ListenL2CapChannelRequest unmarshal(final Map<String, Object> data) {
        final boolean secure = (boolean) data.get(L2CapAttributeNames.KEY_SECURE);
        return new ListenL2CapChannelRequest(secure);
    }

}
