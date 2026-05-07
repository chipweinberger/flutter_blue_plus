package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.bluetooth.*;
import android.os.Build;

import io.flutter.plugin.common.MethodChannel;

import java.util.*;

/** One peripheral-role GATT registration and its native callbacks. */
final class GattServer extends GattAttributes {
    final String id;
    final AndroidBluetoothPlugin p;
    final long generation;
    BluetoothGattServer server;
    volatile boolean closed;
    BluetoothGattService adding;

    GattServer(AndroidBluetoothPlugin p, String id) {
        this.p = p;
        generation = p.generation;
        this.id = id;
    }

    void event(String type, BluetoothDevice d, Object... entries) {
        if (closed) return;
        Map<String, Object> data = map(entries);
        if (d != null) data.put("device", deviceMap(d));
        p.emit(id, type, data, generation);
    }

    synchronized List<Object> registeredServices() {
        List<BluetoothGattService> active = new ArrayList<>();
        // Android retains failed additions in its list. Do not register those objects again.
        for (BluetoothGattService service : server.getServices())
            if (handles.containsKey(service)) active.add(service);
        // Parents can still reference a removed included service.
        return snapshot().services(active);
    }

    // BLUETOOTH_CONNECT grants belong to the app; Android enforces them and errors propagate.
    @android.annotation.SuppressLint("MissingPermission")
    void close() {
        closed = true;
        try {
            server.close();
        } finally {
            forget();
        }
    }

    final BluetoothGattServerCallback callback =
            new BluetoothGattServerCallback() {
                @Override
                public void onConnectionStateChange(BluetoothDevice d, int status, int state) {
                    event("onConnectionStateChange", d, "status", status, "newState", state);
                }

                @Override
                public void onServiceAdded(int status, BluetoothGattService service) {
                    p.main.post(
                            () -> {
                                if (closed) return;
                                event(
                                        "onServiceAdded",
                                        null,
                                        "status",
                                        status,
                                        "service",
                                        snapshot()
                                                .service(
                                                        service,
                                                        Collections.newSetFromMap(
                                                                new IdentityHashMap<>())));
                                if (status != 0) remove(service);
                                adding = null;
                            });
                }

                @Override
                public void onCharacteristicReadRequest(
                        BluetoothDevice d, int request, int offset, BluetoothGattCharacteristic c) {
                    event(
                            "onCharacteristicReadRequest",
                            d,
                            "requestId",
                            request,
                            "offset",
                            offset,
                            "characteristic",
                            characteristicEvent(c));
                }

                @Override
                public void onDescriptorReadRequest(
                        BluetoothDevice d,
                        int request,
                        int offset,
                        BluetoothGattDescriptor descriptor) {
                    event(
                            "onDescriptorReadRequest",
                            d,
                            "requestId",
                            request,
                            "offset",
                            offset,
                            "descriptor",
                            descriptorEvent(descriptor));
                }

                @Override
                public void onCharacteristicWriteRequest(
                        BluetoothDevice d,
                        int request,
                        BluetoothGattCharacteristic c,
                        boolean prepared,
                        boolean response,
                        int offset,
                        byte[] value) {
                    event(
                            "onCharacteristicWriteRequest",
                            d,
                            "requestId",
                            request,
                            "characteristic",
                            characteristicEvent(c),
                            "preparedWrite",
                            prepared,
                            "responseNeeded",
                            response,
                            "offset",
                            offset,
                            "value",
                            value.clone());
                }

                @Override
                public void onDescriptorWriteRequest(
                        BluetoothDevice d,
                        int request,
                        BluetoothGattDescriptor descriptor,
                        boolean prepared,
                        boolean response,
                        int offset,
                        byte[] value) {
                    event(
                            "onDescriptorWriteRequest",
                            d,
                            "requestId",
                            request,
                            "descriptor",
                            descriptorEvent(descriptor),
                            "preparedWrite",
                            prepared,
                            "responseNeeded",
                            response,
                            "offset",
                            offset,
                            "value",
                            value.clone());
                }

                @Override
                public void onExecuteWrite(BluetoothDevice d, int request, boolean execute) {
                    event("onExecuteWrite", d, "requestId", request, "execute", execute);
                }

                @Override
                public void onNotificationSent(BluetoothDevice d, int status) {
                    event("onNotificationSent", d, "status", status);
                }

                @Override
                public void onMtuChanged(BluetoothDevice d, int mtu) {
                    event("onMtuChanged", d, "mtu", mtu);
                }

                @Override
                public void onPhyRead(BluetoothDevice d, int tx, int rx, int status) {
                    event("onPhyRead", d, "txPhy", tx, "rxPhy", rx, "status", status);
                }

                @Override
                public void onPhyUpdate(BluetoothDevice d, int tx, int rx, int status) {
                    event("onPhyUpdate", d, "txPhy", tx, "rxPhy", rx, "status", status);
                }
            };

    @android.annotation.SuppressLint("MissingPermission")
    void handle(String method, Map<String, Object> a, MethodChannel.Result r) {
        BluetoothGattServer g = this.server;
        Object value;
        switch (method) {
            case "close":
                this.close();
                value = null;
                break;
            case "addService":
                {
                    if (this.adding != null)
                        throw new IllegalStateException(
                                "Wait for onServiceAdded before adding another service");
                    BluetoothGattService service = this.createService(object(a.get("service")));
                    try {
                        boolean accepted = g.addService(service);
                        if (accepted) this.adding = service;
                        else this.remove(service);
                        value = accepted;
                    } catch (RuntimeException e) {
                        this.remove(service);
                        throw e;
                    }
                    break;
                }
            case "removeService":
                {
                    if (this.adding != null)
                        throw new IllegalStateException("Service addition in progress");
                    BluetoothGattService service =
                            this.get(string(a, "handle"), BluetoothGattService.class);
                    boolean removed = g.removeService(service);
                    if (removed) this.remove(service);
                    value = removed;
                    break;
                }
            case "clearServices":
                if (this.adding != null)
                    throw new IllegalStateException("Service addition in progress");
                g.clearServices();
                this.clear();
                value = null;
                break;
            case "getServices":
                value = registeredServices();
                break;
            case "connect":
                value = g.connect(p.deviceBridge.device(a), bool(a, "autoConnect", false));
                break;
            case "cancelConnection":
                g.cancelConnection(p.deviceBridge.device(a));
                value = null;
                break;
            case "sendResponse":
                value =
                        g.sendResponse(
                                p.deviceBridge.device(a),
                                integer(a, "requestId", 0),
                                integer(a, "status", 0),
                                integer(a, "offset", 0),
                                (byte[]) a.get("value"));
                break;
            case "notifyCharacteristicChanged":
                {
                    BluetoothGattCharacteristic c =
                            this.get(string(a, "handle"), BluetoothGattCharacteristic.class);
                    if (Build.VERSION.SDK_INT >= 33)
                        value =
                                g.notifyCharacteristicChanged(
                                        p.deviceBridge.device(a),
                                        c,
                                        bool(a, "confirm", false),
                                        (byte[]) a.get("value"));
                    else {
                        c.setValue((byte[]) a.get("value"));
                        value =
                                g.notifyCharacteristicChanged(
                                                p.deviceBridge.device(a),
                                                c,
                                                bool(a, "confirm", false))
                                        ? 0
                                        : Integer.MAX_VALUE;
                    }
                    break;
                }
            case "readPhy":
                if (Build.VERSION.SDK_INT < 26)
                    throw new UnsupportedOperationException("Requires Android API 26");
                g.readPhy(p.deviceBridge.device(a));
                value = null;
                break;
            case "setPreferredPhy":
                if (Build.VERSION.SDK_INT < 26)
                    throw new UnsupportedOperationException("Requires Android API 26");
                g.setPreferredPhy(
                        p.deviceBridge.device(a),
                        integer(a, "txPhy", 1),
                        integer(a, "rxPhy", 1),
                        integer(a, "phyOptions", 0));
                value = null;
                break;
            default:
                r.notImplemented();
                return;
        }
        r.success(value);
    }
}
