// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.messages;

import android.bluetooth.BluetoothDevice;

import com.lib.flutter_blue_plus.MarshallingUtil;
import com.lib.flutter_blue_plus.l2cap.L2CapAttributeNames;

import java.util.HashMap;
import java.util.Map;

public class DeviceConnectedToL2CapChannel {
    public final BluetoothDevice device;
    public final int psm;

    public DeviceConnectedToL2CapChannel(BluetoothDevice device, int psm) {
        this.device = device;
        this.psm = psm;
    }

    public Map<String, Object> marshal() {
        final Map<String, Object> dataMap = new HashMap<>();
        dataMap.put(L2CapAttributeNames.KEY_PSM, psm);
        dataMap.put(L2CapAttributeNames.KEY_BLUETOOTH_DEVICE, MarshallingUtil.bmBluetoothDevice(device));
        return dataMap;
    }
}
