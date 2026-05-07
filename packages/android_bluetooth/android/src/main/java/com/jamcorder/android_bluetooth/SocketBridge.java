package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.bluetooth.*;
import android.os.Build;

import io.flutter.plugin.common.MethodChannel;

import java.io.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

final class SocketBridge {
    final AndroidBluetoothPlugin p;

    static final class SocketEntry {
        final BluetoothSocket socket;
        final long generation;
        final AtomicBoolean reading = new AtomicBoolean(),
                writing = new AtomicBoolean(),
                connecting = new AtomicBoolean();

        SocketEntry(BluetoothSocket socket, long generation) {
            this.socket = socket;
            this.generation = generation;
        }
    }

    static final class ListenerEntry {
        final BluetoothServerSocket socket;
        final long generation;
        final AtomicBoolean accepting = new AtomicBoolean();

        ListenerEntry(BluetoothServerSocket socket, long generation) {
            this.socket = socket;
            this.generation = generation;
        }
    }

    final Map<String, SocketEntry> sockets = new ConcurrentHashMap<>();
    final Map<String, ListenerEntry> listeners = new ConcurrentHashMap<>();

    SocketBridge(AndroidBluetoothPlugin p) {
        this.p = p;
    }

    static Object settings(Map<String, Object> a) throws Exception {
        if (Build.VERSION.SDK_INT < 36)
            throw new UnsupportedOperationException("Requires Android API 36");
        Object b =
                Class.forName("android.bluetooth.BluetoothSocketSettings$Builder")
                        .getConstructor()
                        .newInstance();
        optional(
                b,
                "setSocketType",
                new Class<?>[] {int.class},
                BluetoothSocket.class.getField("TYPE_LE").getInt(null));
        optional(
                b,
                "setAuthenticationRequired",
                new Class<?>[] {boolean.class},
                bool(a, "authenticationRequired", false));
        optional(
                b,
                "setEncryptionRequired",
                new Class<?>[] {boolean.class},
                bool(a, "encryptionRequired", false));
        if (a.get("l2capPsm") != null)
            optional(b, "setL2capPsm", new Class<?>[] {int.class}, integer(a, "l2capPsm", 0));
        return optional(b, "build", new Class<?>[0]);
    }

    Map<String, Object> register(BluetoothSocket socket) throws IOException {
        return register(socket, p.generation);
    }

    Map<String, Object> register(BluetoothSocket socket, long expectedGeneration)
            throws IOException {
        synchronized (sockets) {
            if (p.detached || p.generation != expectedGeneration) {
                socket.close();
                throw new IOException("Flutter engine detached");
            }
            String id = id("socket");
            sockets.put(id, new SocketEntry(socket, expectedGeneration));
            return map("id", id, "device", deviceMap(socket.getRemoteDevice()));
        }
    }

    void closeAll() {
        synchronized (sockets) {
            for (SocketEntry e : sockets.values())
                try {
                    e.socket.close();
                } catch (IOException ignored) {
                }
            sockets.clear();
        }
        for (ListenerEntry e : listeners.values())
            try {
                e.socket.close();
            } catch (IOException ignored) {
            }
        listeners.clear();
    }

    // BLUETOOTH_CONNECT grants belong to the app; Android enforces them and errors propagate.
    @android.annotation.SuppressLint("MissingPermission")
    void handle(String method, Map<String, Object> a, MethodChannel.Result r) throws Exception {
        if (Build.VERSION.SDK_INT < 29)
            throw new UnsupportedOperationException("Requires Android API 29");
        if (method.equals("createSettings")) {
            if (Build.VERSION.SDK_INT < 36)
                throw new UnsupportedOperationException("Requires Android API 36");
            r.success(
                    register(
                            (BluetoothSocket)
                                    optional(
                                            p.deviceBridge.device(a),
                                            "createUsingSocketSettings",
                                            new Class<?>[] {
                                                Class.forName(
                                                        "android.bluetooth.BluetoothSocketSettings")
                                            },
                                            settings(object(a.get("settings"))))));
            return;
        }
        if (method.equals("listenSettings")) {
            if (Build.VERSION.SDK_INT < 36)
                throw new UnsupportedOperationException("Requires Android API 36");
            BluetoothServerSocket socket =
                    (BluetoothServerSocket)
                            optional(
                                    p.adapterBridge.adapter(),
                                    "listenUsingSocketSettings",
                                    new Class<?>[] {
                                        Class.forName("android.bluetooth.BluetoothSocketSettings")
                                    },
                                    settings(object(a.get("settings"))));
            String id = id("listener");
            listeners.put(id, new ListenerEntry(socket, p.generation));
            r.success(map("id", id, "psm", socket.getPsm()));
            return;
        }
        if (method.equals("create")) {
            BluetoothDevice d = p.deviceBridge.device(a);
            int psm = integer(a, "psm", 0);
            r.success(
                    register(
                            bool(a, "secure", true)
                                    ? d.createL2capChannel(psm)
                                    : d.createInsecureL2capChannel(psm)));
            return;
        }
        if (method.equals("listen")) {
            BluetoothServerSocket socket =
                    bool(a, "secure", true)
                            ? p.adapterBridge.adapter().listenUsingL2capChannel()
                            : p.adapterBridge.adapter().listenUsingInsecureL2capChannel();
            String id = id("listener");
            listeners.put(id, new ListenerEntry(socket, p.generation));
            r.success(map("id", id, "psm", socket.getPsm()));
            return;
        }
        String id = string(a, "id");
        if (method.equals("accept") || method.equals("closeServer")) {
            ListenerEntry e = listeners.get(id);
            if (e == null) {
                if (method.equals("closeServer")) {
                    r.success(null);
                    return;
                }
                throw new IllegalStateException("Listening socket closed or unknown");
            }
            if (method.equals("closeServer")) {
                e.socket.close();
                listeners.remove(id);
                r.success(null);
                return;
            }
            if (!e.accepting.compareAndSet(false, true))
                throw new IllegalStateException("An accept is already pending");
            p.worker(
                    r,
                    () -> {
                        try {
                            return register(
                                    e.socket.accept(integer(a, "timeoutMillis", -1)), e.generation);
                        } finally {
                            e.accepting.set(false);
                        }
                    });
            return;
        }
        SocketEntry e = sockets.get(id);
        if (e == null) {
            if (method.equals("close")) {
                r.success(null);
                return;
            }
            throw new IllegalStateException("Socket closed or unknown");
        }
        switch (method) {
            case "close":
                e.socket.close();
                sockets.remove(id);
                r.success(null);
                return;
            case "isConnected":
                r.success(e.socket.isConnected());
                return;
            case "connectionType":
                r.success(e.socket.getConnectionType());
                return;
            case "maxReceivePacketSize":
                r.success(e.socket.getMaxReceivePacketSize());
                return;
            case "maxTransmitPacketSize":
                r.success(e.socket.getMaxTransmitPacketSize());
                return;
            case "connect":
                if (!e.connecting.compareAndSet(false, true))
                    throw new IllegalStateException("A connect is already pending");
                p.worker(
                        r,
                        () -> {
                            try {
                                e.socket.connect();
                                return null;
                            } finally {
                                e.connecting.set(false);
                            }
                        });
                return;
            case "read":
                {
                    int length = integer(a, "maxLength", 4096);
                    if (length < 1 || length > 1024 * 1024)
                        throw new IllegalArgumentException("maxLength must be 1..1048576");
                    if (!e.reading.compareAndSet(false, true))
                        throw new IllegalStateException("A read is already pending");
                    p.worker(
                            r,
                            () -> {
                                try {
                                    byte[] buffer = new byte[length];
                                    int count = e.socket.getInputStream().read(buffer);
                                    return count < 0 ? new byte[0] : Arrays.copyOf(buffer, count);
                                } finally {
                                    e.reading.set(false);
                                }
                            });
                    return;
                }
            case "write":
            case "flush":
                if (!e.writing.compareAndSet(false, true))
                    throw new IllegalStateException(
                            "A write or flush is already pending; await it first");
                p.worker(
                        r,
                        () -> {
                            try {
                                if (method.equals("write"))
                                    e.socket.getOutputStream().write((byte[]) a.get("value"));
                                else e.socket.getOutputStream().flush();
                                return null;
                            } finally {
                                e.writing.set(false);
                            }
                        });
                return;
            case "available":
                p.worker(r, () -> e.socket.getInputStream().available());
                return;
            default:
                r.notImplemented();
        }
    }
}
