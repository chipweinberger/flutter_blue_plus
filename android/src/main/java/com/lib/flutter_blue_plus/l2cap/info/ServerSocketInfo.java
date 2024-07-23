// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap.info;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;
import android.os.Build;
import android.util.Log;

import androidx.annotation.RequiresApi;

import com.lib.flutter_blue_plus.l2cap.L2CapChannelManager;
import com.lib.flutter_blue_plus.l2cap.channel.L2CapServerChannel;

import java.io.IOException;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;

@RequiresApi(api = Build.VERSION_CODES.Q)
public class ServerSocketInfo implements L2CapInfo {

    private static final String TAG = ServerSocketInfo.class.getSimpleName();
    final BluetoothServerSocket serverSocket;
    private final List<L2CapServerChannel> openChannels;
    private final L2CapChannelManager.DeviceConnected deviceConnectedCallback;
    private boolean isAcceptingConnections;

    public ServerSocketInfo(BluetoothServerSocket serverSocket, final L2CapChannelManager.DeviceConnected deviceConnectedCallback) {
        this.serverSocket = serverSocket;
        this.deviceConnectedCallback = deviceConnectedCallback;
        openChannels = Collections.synchronizedList(new LinkedList<>());
        isAcceptingConnections = false;
    }

    @Override
    public Type getType() {
        return Type.SERVER;
    }

    @Override
    public int getPsm() {
        return serverSocket.getPsm();
    }

    void addConnection(final L2CapServerChannel channel) {
        openChannels.add(channel);
    }

    @Override
    public L2CapServerChannel getL2CapChannel(final BluetoothDevice remoteDevice) {
        for (L2CapServerChannel openChannel :
                openChannels) {
            if (remoteDevice.getAddress().equals(openChannel.getSocket().getRemoteDevice().getAddress())) {
                return openChannel;
            }
        }
        return null;
    }

    @Override
    public void close(final BluetoothDevice device) {
        final L2CapServerChannel channelToDelete = getL2CapChannel(device);
        if (channelToDelete == null) {
            return;
        }
        channelToDelete.close();
        openChannels.remove(channelToDelete);
    }

    public void acceptConnections() {
        isAcceptingConnections = true;
        new Thread(() -> {
            while (isAcceptingConnections) {
                try {
                    final BluetoothSocket socket = serverSocket.accept();
                    if (!isAcceptingConnections) {
                        Log.d(TAG, "Stopping server socket. Close thread.");
                        break;
                    }
                    final L2CapServerChannel l2capChannel = new L2CapServerChannel(socket);
                    l2capChannel.openStreams();
                    addConnection(l2capChannel);
                    deviceConnectedCallback.deviceConnected(socket.getRemoteDevice(), getPsm());
                } catch (IOException e) {
                    if (isAcceptingConnections) {
                        Log.e(TAG, "Accepting incoming connection failed.", e);
                    }
                }
            }
        }).start();
    }


    public void closeSocket() {
        for (L2CapServerChannel openChannel :
                openChannels) {
            openChannel.close();
        }
        openChannels.clear();
        isAcceptingConnections = false;
        try {
            serverSocket.close();
        } catch (IOException e) {
            Log.e(TAG, "Error while closing server socket.", e);
        }
    }
}
