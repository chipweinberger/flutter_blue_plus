// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus.l2cap;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothServerSocket;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lib.flutter_blue_plus.ErrorCodes;
import com.lib.flutter_blue_plus.l2cap.channel.L2CapChannel;
import com.lib.flutter_blue_plus.l2cap.channel.L2CapClientChannel;
import com.lib.flutter_blue_plus.l2cap.info.ClientSocketInfo;
import com.lib.flutter_blue_plus.l2cap.info.L2CapInfo;
import com.lib.flutter_blue_plus.l2cap.info.ServerSocketInfo;
import com.lib.flutter_blue_plus.l2cap.messages.CloseL2CapChannelRequest;
import com.lib.flutter_blue_plus.l2cap.messages.CloseL2CapServer;
import com.lib.flutter_blue_plus.l2cap.messages.ListenL2CapChannelRequest;
import com.lib.flutter_blue_plus.l2cap.messages.ListenL2CapChannelResponse;
import com.lib.flutter_blue_plus.l2cap.messages.OpenL2CapChannelRequest;
import com.lib.flutter_blue_plus.l2cap.messages.ReadL2CapChannelRequest;
import com.lib.flutter_blue_plus.l2cap.messages.WriteL2CapChannelRequest;
import com.lib.flutter_blue_plus.log.LogLevel;

import java.io.IOException;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;

import io.flutter.plugin.common.MethodChannel.Result;

@TargetApi(Build.VERSION_CODES.Q)
public class L2CapChannelManager {
    private final BluetoothAdapter adapter;
    private final DeviceConnected deviceConnectedCallback;
    private final List<L2CapInfo> openL2CapChannelInfos = Collections.synchronizedList(new LinkedList<>());

    public L2CapChannelManager(@NonNull final BluetoothAdapter adapter, @NonNull final DeviceConnected deviceConnectedCallback) {
        this.adapter = adapter;
        this.deviceConnectedCallback = deviceConnectedCallback;
    }

    @SuppressLint("MissingPermission")
    public synchronized void listenUsingL2capChannel(ListenL2CapChannelRequest request, final Result resultCallback) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            firePlatformNotSupportedError(resultCallback);
            return;
        }
        if (!adapter.isEnabled()) {
            LogLevel.DEBUG.log("Bluetooth is disabled. Please enable first.");
            resultCallback.error(ErrorCodes.BLUETOOTH_TURNED_OFF, "Bluetooth is turned off.", null);
            return;
        }

        try {
            final BluetoothServerSocket serverSocket;
            if (request.secure) {
                serverSocket = adapter.listenUsingL2capChannel();
            } else {
                serverSocket = adapter.listenUsingInsecureL2capChannel();
            }
            final ServerSocketInfo socketInfo = new ServerSocketInfo(serverSocket, deviceConnectedCallback);
            openL2CapChannelInfos.add(socketInfo);
            final int psm = serverSocket.getPsm();
            socketInfo.acceptConnections();

            final ListenL2CapChannelResponse response = new ListenL2CapChannelResponse(psm);
            resultCallback.success(response.marshal());

        } catch (IOException e) {
            LogLevel.ERROR.log(e.getMessage(), e);
            resultCallback.error(ErrorCodes.OPEN_L2CAP_CHANNEL_FAILED, e.getMessage(), e);
        }

    }

    public synchronized void connectToL2CapChannel(final OpenL2CapChannelRequest request, final Result resultCallback) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            firePlatformNotSupportedError(resultCallback);
            return;
        }
        final String deviceId = request.remoteId;
        final BluetoothDevice device = adapter.getRemoteDevice(deviceId);
        final int psm = request.psm;
        final boolean secure = request.secure;

        L2CapInfo l2CapInfo = findInfo(psm);
        if (l2CapInfo == null) {
            LogLevel.DEBUG.log("L2CAP Channel with for device " + device.getAddress() + " / psm " + psm + " not open yet. Create channel.");
            l2CapInfo = new ClientSocketInfo(new L2CapClientChannel(device, psm));
            openL2CapChannelInfos.add(l2CapInfo);
        }
        final L2CapClientChannel l2CapChannel = ((L2CapClientChannel) l2CapInfo.getL2CapChannel(device));
        l2CapChannel.connectToL2CapChannel(secure, resultCallback);
    }

    public void read(final ReadL2CapChannelRequest request, final Result resultCallback) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            firePlatformNotSupportedError(resultCallback);
            return;
        }
        final String deviceId = request.remoteId;
        final BluetoothDevice device = adapter.getRemoteDevice(deviceId);
        final int psm = request.psm;
        final L2CapChannel channel = findChannel(psm, device);
        if (channel == null) {
            resultCallback.error(ErrorCodes.NO_OPEN_L2CAP_CHANNEL_FOUND, "No open channel found for device " + device.getAddress() + " / psm " + psm, null);
            return;
        }
        channel.read(request, resultCallback);
    }

    public void write(final WriteL2CapChannelRequest request, final Result resultCallback) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            firePlatformNotSupportedError(resultCallback);
            return;
        }
        final String deviceId = request.remoteId;
        final BluetoothDevice device = adapter.getRemoteDevice(deviceId);
        final int psm = request.psm;
        final L2CapChannel channel = findChannel(psm, device);
        if (channel == null) {
            resultCallback.error(ErrorCodes.NO_OPEN_L2CAP_CHANNEL_FOUND, "No open channel found for device " + device.getAddress() + " / psm " + psm, null);
            return;
        }
        channel.write(request, resultCallback);
    }

    public synchronized void closeChannel(final CloseL2CapChannelRequest request, final Result resultCallback) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            firePlatformNotSupportedError(resultCallback);
            return;
        }
        final String deviceId = request.remoteId;
        final BluetoothDevice device = adapter.getRemoteDevice(deviceId);
        final int psm = request.psm;
        final L2CapInfo channelInfo = findInfo(psm);
        if (channelInfo != null) {
            try {
                channelInfo.close(device);
            } catch (IOException e) {
                LogLevel.ERROR.log(e.getMessage(), e);
                resultCallback.error(ErrorCodes.CLOSE_L2CAP_CHANNEL_FAILED, "Can't close channel with psm " + psm, null);
            }
            if (channelInfo.getType() == L2CapInfo.Type.CLIENT) {
                openL2CapChannelInfos.remove(channelInfo);
            }
        } else {
            LogLevel.DEBUG.log("No channel found which is matching device " + device.getAddress() + " / psm " + psm);
        }
        resultCallback.success(null);
    }

    public synchronized void closeServerSocket(CloseL2CapServer options, final Result resultCallback) {
        final int psm = options.psm;
        final L2CapInfo channelInfo = findInfo(psm);
        if (channelInfo != null && channelInfo.getType() == L2CapInfo.Type.SERVER) {
            ((ServerSocketInfo) channelInfo).closeSocket();
            openL2CapChannelInfos.remove(channelInfo);
        } else {
            LogLevel.DEBUG.log("No server socket found with psm " + psm);
        }
        resultCallback.success(null);
    }

    private void firePlatformNotSupportedError(Result resultCallback) {
        resultCallback.error(ErrorCodes.PLATFORM_NOT_SUPPORTED, "The device is running an older Android version. Minimum version is Android Q.", null);
    }

    @Nullable
    private L2CapInfo findInfo(final int psm) {
        for (L2CapInfo channelInfo : openL2CapChannelInfos) {
            if (psm == channelInfo.getPsm()) {
                return channelInfo;
            }
        }
        return null;
    }

    @Nullable
    private L2CapChannel findChannel(final int psm, final BluetoothDevice remoteDevice) {
        final L2CapInfo l2CapInfo = findInfo(psm);
        if (l2CapInfo == null) {
            return null;
        }
        return l2CapInfo.getL2CapChannel(remoteDevice);
    }


    public interface DeviceConnected {
        void deviceConnected(BluetoothDevice remoteDevice, int psm);
    }
}
