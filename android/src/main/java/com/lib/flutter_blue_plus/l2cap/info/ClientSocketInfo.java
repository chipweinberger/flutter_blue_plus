// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.info;

import android.bluetooth.BluetoothDevice;

import androidx.annotation.NonNull;

import com.lib.flutter_blue_plus.l2cap.channel.L2CapChannel;
import com.lib.flutter_blue_plus.l2cap.channel.L2CapClientChannel;

public class ClientSocketInfo implements L2CapInfo {

    final L2CapClientChannel l2capChannel;

    public ClientSocketInfo(@NonNull final L2CapClientChannel l2capChannel) {
        this.l2capChannel = l2capChannel;
    }

    @Override
    public Type getType() {
        return Type.CLIENT;
    }

    @Override
    public int getPsm() {
        return l2capChannel.getPsm();
    }

    @Override
    public L2CapChannel getL2CapChannel(BluetoothDevice remoteDevice) {
        if (remoteDevice.getAddress().equals(l2capChannel.getDevice().getAddress())) {
            return l2capChannel;
        }
        return null;
    }

    @Override
    public void close(final BluetoothDevice device) {
        l2capChannel.close();
    }
}
