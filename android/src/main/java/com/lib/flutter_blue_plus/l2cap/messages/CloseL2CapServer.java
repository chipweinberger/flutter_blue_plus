// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.messages;

import com.lib.flutter_blue_plus.l2cap.L2CapAttributeNames;

import java.util.Map;

public class CloseL2CapServer {
    public final int psm;

    public CloseL2CapServer(int psm) {
        this.psm = psm;
    }

    public static CloseL2CapServer unmarshal(final Map<String, Object> data) {
        final int psm = (int) data.get(L2CapAttributeNames.KEY_PSM);
        return new CloseL2CapServer(psm);
    }

}
