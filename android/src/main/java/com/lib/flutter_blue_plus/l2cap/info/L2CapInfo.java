// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.info;

import android.bluetooth.BluetoothDevice;

import com.lib.flutter_blue_plus.l2cap.channel.L2CapChannel;

import java.io.IOException;

public interface L2CapInfo {

    Type getType();

    int getPsm();

    L2CapChannel getL2CapChannel(final BluetoothDevice remoteDevice);

    void close(final BluetoothDevice device) throws IOException;

    enum Type {
        CLIENT,
        SERVER,
    }
}
