package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.bluetooth.*;
import android.os.Build;

import io.flutter.plugin.common.MethodChannel;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

final class GattBridge {
    final AndroidBluetoothPlugin p;
    final Map<String, GattClient> clients = new ConcurrentHashMap<>();
    final Map<String, GattServer> servers = new ConcurrentHashMap<>();

    GattBridge(AndroidBluetoothPlugin p) {
        this.p = p;
    }

    void closeAll() {
        for (GattClient c : clients.values())
            try {
                c.close();
            } catch (SecurityException ignored) {
                // The OS may already have revoked permission and torn down the registration.
            } catch (Exception ignored) {
            }
        for (GattServer s : servers.values())
            try {
                s.close();
            } catch (SecurityException ignored) {
                // The OS may already have revoked permission and torn down the registration.
            } catch (Exception ignored) {
            }
        clients.clear();
        servers.clear();
    }

    // BLUETOOTH_CONNECT grants belong to the app; Android enforces them and errors propagate.
    @android.annotation.SuppressLint("MissingPermission")
    void handle(String method, Map<String, Object> a, MethodChannel.Result r) throws Exception {
        if (method.equals("gatt.open")) {
            String id = id("gatt");
            GattClient c =
                    new GattClient(
                            p,
                            id,
                            p.deviceBridge.device(a),
                            bool(a, "preserveAttributeHandles", false));
            clients.put(id, c);
            try {
                if (Build.VERSION.SDK_INT >= 26)
                    c.gatt =
                            c.device.connectGatt(
                                    p.context,
                                    bool(a, "autoConnect", false),
                                    c.callback,
                                    BluetoothDevice.TRANSPORT_LE,
                                    integer(a, "phy", 1),
                                    p.main);
                else if (Build.VERSION.SDK_INT >= 23)
                    c.gatt =
                            c.device.connectGatt(
                                    p.context,
                                    bool(a, "autoConnect", false),
                                    c.callback,
                                    BluetoothDevice.TRANSPORT_LE);
                else
                    c.gatt =
                            GattClient.connectLegacyLe(
                                    c.device, p.context, bool(a, "autoConnect", false), c.callback);
                if (c.gatt == null)
                    throw new IllegalStateException("Android failed to register GATT client");
                r.success(id);
            } catch (Exception e) {
                clients.remove(id);
                c.close();
                throw e;
            }
            return;
        }
        if (method.equals("server.open")) {
            p.adapterBridge.adapter();
            String id = id("server");
            GattServer s = new GattServer(p, id);
            s.server = p.manager.openGattServer(p.context, s.callback);
            if (s.server == null)
                throw new IllegalStateException("Android failed to register GATT server");
            servers.put(id, s);
            r.success(id);
            return;
        }
        if (method.startsWith("server.")) {
            serverCall(method.substring(7), a, r);
            return;
        }
        String id = string(a, "id");
        GattClient c = clients.get(id);
        if (c == null) {
            if (method.equals("gatt.close")) {
                r.success(null);
                return;
            }
            throw new IllegalStateException("GATT registration closed or unknown");
        }
        if (c.closed && !method.equals("gatt.close"))
            throw new IllegalStateException(
                    "GATT registration is closing or closed; only close can be retried");
        c.handle(method.substring(5), a, r);
        if (method.equals("gatt.close")) clients.remove(id);
    }

    // BLUETOOTH_CONNECT grants belong to the app; Android enforces them and errors propagate.
    @android.annotation.SuppressLint("MissingPermission")
    void serverCall(String method, Map<String, Object> a, MethodChannel.Result r) {
        String id = string(a, "id");
        GattServer s = servers.get(id);
        if (s == null) {
            if (method.equals("close")) {
                r.success(null);
                return;
            }
            throw new IllegalStateException("GATT server closed or unknown");
        }
        if (s.closed && !method.equals("close"))
            throw new IllegalStateException(
                    "GATT server is closing or closed; only close can be retried");
        s.handle(method, a, r);
        if (method.equals("close")) servers.remove(id);
    }
}
