// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.channel;

import android.bluetooth.BluetoothSocket;

import com.lib.flutter_blue_plus.ErrorCodes;
import com.lib.flutter_blue_plus.l2cap.messages.ReadL2CapChannelRequest;
import com.lib.flutter_blue_plus.l2cap.messages.ReadL2CapChannelResponse;
import com.lib.flutter_blue_plus.l2cap.messages.WriteL2CapChannelRequest;
import com.lib.flutter_blue_plus.log.LogLevel;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import io.flutter.plugin.common.MethodChannel.Result;

public abstract class L2CapChannel {

    protected static final int DEFAULT_READ_BUFFER_SIZE = 50;
    protected final byte[] readBuffer;
    protected BluetoothSocket socket;
    protected OutputStream outputStream;
    protected InputStream inputStream;

    public L2CapChannel(final int readBufferSize) {
        readBuffer = new byte[readBufferSize];
    }

    public BluetoothSocket getSocket() {
        return socket;
    }

    public void read(final ReadL2CapChannelRequest request, final Result resultCallback) {
        if (inputStream == null || socket == null || !socket.isConnected()) {
            resultCallback.error(ErrorCodes.SOCKET_NOT_OPEN, "The bluetooth socket or the input stream is not open.", null);
            return;
        }
        try {
            final int bytesRead = inputStream.read(readBuffer);
            final ReadL2CapChannelResponse response = new ReadL2CapChannelResponse(request.remoteId, request.psm, bytesRead, readBuffer);
            resultCallback.success(response.marshal());
        } catch (IOException e) {
            LogLevel.ERROR.log(e.getMessage(), e);
            resultCallback.error(ErrorCodes.INPUT_STREAM_READ_FAILED, e.getMessage(), e);
        }
    }

    public void write(final WriteL2CapChannelRequest request, final Result resultCallback) {
        if (outputStream == null || socket == null || !socket.isConnected()) {
            resultCallback.error(ErrorCodes.SOCKET_NOT_OPEN, "The bluetooth socket or the output stream is not open.", null);
            return;
        }
        final byte[] data = request.value;
        try {
            outputStream.write(data);
            resultCallback.success(null);
        } catch (IOException e) {
            LogLevel.ERROR.log(e.getMessage(), e);
            resultCallback.error(ErrorCodes.OUTPUT_STREAM_WRITE_FAILED, e.getMessage(), e);
        }
    }

    public synchronized void close() {
        if (outputStream != null) {
            try {
                outputStream.close();
            } catch (IOException e) {
                LogLevel.ERROR.log(e.getMessage(), e);
            } finally {
                outputStream = null;
            }
        }
        if (inputStream != null) {
            try {
                inputStream.close();
            } catch (IOException e) {
                LogLevel.ERROR.log(e.getMessage(), e);
            } finally {
                inputStream = null;
            }
        }
        if (socket != null) {
            try {
                socket.close();
            } catch (IOException e) {
                LogLevel.ERROR.log(e.getMessage(), e);
            } finally {
                socket = null;
            }
        }
    }
}
