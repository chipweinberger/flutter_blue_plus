// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.channel;

import android.annotation.TargetApi;
import android.bluetooth.BluetoothSocket;
import android.os.Build;

import com.lib.flutter_blue_plus.log.LogLevel;

import java.io.IOException;

public class L2CapServerChannel extends L2CapChannel {


    public L2CapServerChannel(final BluetoothSocket socket) {
        this(socket, DEFAULT_READ_BUFFER_SIZE);
    }

    public L2CapServerChannel(final BluetoothSocket socket, final int readBufferSize) {
        super(readBufferSize);
        this.socket = socket;
    }

    @TargetApi(Build.VERSION_CODES.Q)
    public synchronized void openStreams() throws IOException {
        LogLevel.DEBUG.log("Opening streams");
        inputStream = socket.getInputStream();
        outputStream = socket.getOutputStream();
    }
}
