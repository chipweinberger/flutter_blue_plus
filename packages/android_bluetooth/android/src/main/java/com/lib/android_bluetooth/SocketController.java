package com.lib.android_bluetooth;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

public final class SocketController
{
    private final AtomicInteger nextSocketId = new AtomicInteger(1);
    private final AtomicInteger nextServerSocketId = new AtomicInteger(1);
    private final Map<Integer, BluetoothServerSocket> serverSockets = new ConcurrentHashMap<>();
    private final Map<Integer, BluetoothSocket> sockets = new ConcurrentHashMap<>();

    public Integer createL2capChannel(BluetoothDevice device, Integer psm, boolean insecure)
    {
        if (device == null || psm == null || android.os.Build.VERSION.SDK_INT < 29) {
            return null;
        }

        try {
            BluetoothSocket socket = insecure ? device.createInsecureL2capChannel(psm) : device.createL2capChannel(psm);
            int socketId = nextSocketId.getAndIncrement();
            sockets.put(socketId, socket);
            return socketId;
        } catch (SecurityException exception) {
            return null;
        } catch (IOException exception) {
            return null;
        }
    }

    public Integer listenUsingL2capChannel(android.bluetooth.BluetoothAdapter bluetoothAdapter, boolean insecure)
    {
        if (bluetoothAdapter == null || android.os.Build.VERSION.SDK_INT < 29) {
            return null;
        }

        try {
            BluetoothServerSocket serverSocket = insecure ?
                bluetoothAdapter.listenUsingInsecureL2capChannel() :
                bluetoothAdapter.listenUsingL2capChannel();
            int serverSocketId = nextServerSocketId.getAndIncrement();
            serverSockets.put(serverSocketId, serverSocket);
            return serverSocketId;
        } catch (IOException exception) {
            return null;
        } catch (SecurityException exception) {
            return null;
        }
    }

    public Integer acceptServerSocket(int serverSocketId, Integer timeoutMillis)
    {
        BluetoothServerSocket serverSocket = serverSockets.get(serverSocketId);
        if (serverSocket == null) {
            return null;
        }

        try {
            BluetoothSocket socket = timeoutMillis == null ? serverSocket.accept() : serverSocket.accept(timeoutMillis);
            int socketId = nextSocketId.getAndIncrement();
            sockets.put(socketId, socket);
            return socketId;
        } catch (IOException exception) {
            return null;
        } catch (SecurityException exception) {
            return null;
        }
    }

    public boolean closeServerSocket(int serverSocketId)
    {
        BluetoothServerSocket serverSocket = serverSockets.remove(serverSocketId);
        if (serverSocket == null) {
            return false;
        }

        try {
            serverSocket.close();
            return true;
        } catch (IOException exception) {
            return false;
        }
    }

    public Integer getServerSocketPsm(int serverSocketId)
    {
        BluetoothServerSocket serverSocket = serverSockets.get(serverSocketId);
        if (serverSocket == null) {
            return null;
        }

        try {
            return serverSocket.getPsm();
        } catch (SecurityException exception) {
            return null;
        }
    }

    public boolean closeSocket(int socketId)
    {
        BluetoothSocket socket = sockets.remove(socketId);
        if (socket == null) {
            return false;
        }

        try {
            socket.close();
            return true;
        } catch (IOException exception) {
            return false;
        }
    }

    public boolean connectSocket(int socketId)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null) {
            return false;
        }

        try {
            socket.connect();
            return true;
        } catch (IOException exception) {
            return false;
        } catch (SecurityException exception) {
            return false;
        }
    }

    public Integer getSocketConnectionType(int socketId)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null) {
            return null;
        }

        try {
            return socket.getConnectionType();
        } catch (SecurityException exception) {
            return null;
        }
    }

    public Integer getSocketMaxReceivePacketSize(int socketId)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null || android.os.Build.VERSION.SDK_INT < 23) {
            return null;
        }

        try {
            return socket.getMaxReceivePacketSize();
        } catch (SecurityException exception) {
            return null;
        }
    }

    public Integer getSocketMaxTransmitPacketSize(int socketId)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null || android.os.Build.VERSION.SDK_INT < 23) {
            return null;
        }

        try {
            return socket.getMaxTransmitPacketSize();
        } catch (SecurityException exception) {
            return null;
        }
    }

    public Integer getSocketInputStreamAvailable(int socketId)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null) {
            return null;
        }

        try {
            InputStream inputStream = socket.getInputStream();
            return inputStream.available();
        } catch (IOException exception) {
            return null;
        }
    }

    public Integer readSocketInputStreamByte(int socketId)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null) {
            return null;
        }

        try {
            InputStream inputStream = socket.getInputStream();
            return inputStream.read();
        } catch (IOException exception) {
            return null;
        }
    }

    public byte[] readSocketInputStream(int socketId, Integer maxBytes)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null) {
            return null;
        }

        int readSize = maxBytes == null || maxBytes <= 0 ? 1024 : maxBytes;
        byte[] buffer = new byte[readSize];

        try {
            InputStream inputStream = socket.getInputStream();
            int bytesRead = inputStream.read(buffer);
            if (bytesRead < 0) {
                return new byte[0];
            }

            byte[] bytes = new byte[bytesRead];
            System.arraycopy(buffer, 0, bytes, 0, bytesRead);
            return bytes;
        } catch (IOException exception) {
            return null;
        }
    }

    public Integer skipSocketInputStream(int socketId, Integer byteCount)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null || byteCount == null) {
            return null;
        }

        try {
            InputStream inputStream = socket.getInputStream();
            return (int) inputStream.skip(byteCount.longValue());
        } catch (IOException exception) {
            return null;
        }
    }

    public boolean writeSocketOutputStreamByte(int socketId, Integer value)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null || value == null) {
            return false;
        }

        try {
            OutputStream outputStream = socket.getOutputStream();
            outputStream.write(value);
            return true;
        } catch (IOException exception) {
            return false;
        }
    }

    public boolean writeSocketOutputStream(int socketId, byte[] bytes)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null || bytes == null) {
            return false;
        }

        try {
            OutputStream outputStream = socket.getOutputStream();
            outputStream.write(bytes);
            return true;
        } catch (IOException exception) {
            return false;
        }
    }

    public boolean flushSocketOutputStream(int socketId)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null) {
            return false;
        }

        try {
            OutputStream outputStream = socket.getOutputStream();
            outputStream.flush();
            return true;
        } catch (IOException exception) {
            return false;
        }
    }

    public HashMap<String, Object> getSocketRemoteDevice(int socketId)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null) {
            return null;
        }

        try {
            return BluetoothDeviceSerializer.serialize(socket.getRemoteDevice());
        } catch (SecurityException exception) {
            return null;
        }
    }

    public boolean isSocketConnected(int socketId)
    {
        BluetoothSocket socket = sockets.get(socketId);
        if (socket == null) {
            return false;
        }

        try {
            return socket.isConnected();
        } catch (SecurityException exception) {
            return false;
        }
    }

    public void closeAll()
    {
        for (Map.Entry<Integer, BluetoothServerSocket> entry : serverSockets.entrySet()) {
            try {
                entry.getValue().close();
            } catch (IOException ignored) {
            }
        }
        serverSockets.clear();

        for (Map.Entry<Integer, BluetoothSocket> entry : sockets.entrySet()) {
            try {
                entry.getValue().close();
            } catch (IOException ignored) {
            }
        }
        sockets.clear();
    }
}
