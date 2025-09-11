// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.channel;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.bluetooth.BluetoothDevice;
import android.os.Build;

import com.lib.flutter_blue_plus.ErrorCodes;
import com.lib.flutter_blue_plus.log.LogLevel;

import java.io.IOException;

import io.flutter.plugin.common.MethodChannel.Result;

public class L2CapClientChannel extends L2CapChannel {
    private final BluetoothDevice device;
    private final int psm;

    public L2CapClientChannel(final BluetoothDevice device, final int psm) {
        this(device, psm, DEFAULT_READ_BUFFER_SIZE);
    }

    public L2CapClientChannel(final BluetoothDevice device, final int psm, final int readBufferSize) {
        super(readBufferSize);
        this.psm = psm;
        this.device = device;
    }

    @SuppressLint("MissingPermission")
    @TargetApi(Build.VERSION_CODES.Q)
    public synchronized void connectToL2CapChannel(final boolean secure, final Result resultCallback) {
        try {
            if (secure) {
                socket = device.createL2capChannel(psm);
            } else {
                socket = device.createInsecureL2capChannel(psm);
            }
            socket.connect();
            inputStream = socket.getInputStream();
            outputStream = socket.getOutputStream();
            resultCallback.success(null);
        } catch (IOException e) {
            LogLevel.ERROR.log(e.getMessage(), e);
            resultCallback.error(ErrorCodes.OPEN_L2CAP_CHANNEL_FAILED, e.getMessage(), e);
        }
    }

    public BluetoothDevice getDevice() {
        return device;
    }

    public int getPsm() {
        return psm;
    }
}
