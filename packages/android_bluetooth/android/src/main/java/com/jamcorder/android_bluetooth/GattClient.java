package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.bluetooth.*;
import android.content.Context;
import android.os.Build;

import io.flutter.plugin.common.MethodChannel;

import java.util.*;

/** One central-role GATT registration and its native callbacks. */
final class GattClient extends GattAttributes {
    final String id;
    final AndroidBluetoothPlugin p;
    final long generation;
    final BluetoothDevice device;
    final boolean preserveAttributeHandles;
    volatile BluetoothGatt gatt;
    volatile boolean closed;
    volatile boolean servicesValid;

    GattClient(AndroidBluetoothPlugin p, String id, BluetoothDevice device) {
        this(p, id, device, false);
    }

    GattClient(
            AndroidBluetoothPlugin p,
            String id,
            BluetoothDevice device,
            boolean preserveAttributeHandles) {
        this.p = p;
        generation = p.generation;
        this.id = id;
        this.device = device;
        this.preserveAttributeHandles = preserveAttributeHandles;
    }

    @android.annotation.SuppressLint("MissingPermission")
    static BluetoothGatt connectLegacyLe(
            BluetoothDevice device,
            Context context,
            boolean autoConnect,
            BluetoothGattCallback callback) {
        try {
            java.lang.reflect.Method method =
                    device.getClass()
                            .getDeclaredMethod(
                                    "connectGatt",
                                    Context.class,
                                    boolean.class,
                                    BluetoothGattCallback.class,
                                    int.class);
            method.setAccessible(true);
            return (BluetoothGatt) method.invoke(device, context, autoConnect, callback, 2);
        } catch (Exception unavailable) {
            return device.connectGatt(context, autoConnect, callback);
        }
    }

    @Override
    synchronized <T> T get(String handle, Class<T> type) {
        if (!servicesValid)
            throw new IllegalStateException("Discover services before using attributes");
        return super.get(handle, type);
    }

    void invalidate() {
        servicesValid = false;
        clear();
    }

    void event(String type, Object... data) {
        if (!closed) {
            Map<String, Object> payload = map(data);
            payload.put("device", deviceMap(device));
            p.emit(id, type, payload, generation);
        }
    }

    // BLUETOOTH_CONNECT grants belong to the app; Android enforces them and errors propagate.
    @android.annotation.SuppressLint("MissingPermission")
    void close() {
        closed = true;
        p.deviceBridge.clearPairingPin(device);
        try {
            if (gatt != null) gatt.close();
        } finally {
            invalidate();
            forget();
        }
    }

    final BluetoothGattCallback callback =
            new BluetoothGattCallback() {
                @Override
                public void onConnectionStateChange(BluetoothGatt g, int status, int state) {
                    if (state == BluetoothProfile.STATE_DISCONNECTED)
                        p.deviceBridge.clearPairingPin(device);
                    event("onConnectionStateChange", "status", status, "newState", state);
                }

                @Override
                public void onServicesDiscovered(BluetoothGatt g, int status) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        clear();
                        servicesValid = true;
                    }
                    event(
                            "onServicesDiscovered",
                            "status",
                            status,
                            "services",
                            status == 0 || preserveAttributeHandles
                                    ? services(g.getServices())
                                    : Collections.emptyList());
                }

                @Override
                public void onCharacteristicRead(
                        BluetoothGatt g, BluetoothGattCharacteristic c, int status) {
                    if (Build.VERSION.SDK_INT < 33) read(c, c.getValue(), status);
                }

                @Override
                public void onCharacteristicRead(
                        BluetoothGatt g, BluetoothGattCharacteristic c, byte[] value, int status) {
                    read(c, value, status);
                }

                void read(BluetoothGattCharacteristic c, byte[] value, int status) {
                    event(
                            "onCharacteristicRead",
                            "status",
                            status,
                            "characteristic",
                            characteristicEvent(c),
                            "value",
                            value == null ? null : value.clone());
                }

                @Override
                public void onCharacteristicWrite(
                        BluetoothGatt g, BluetoothGattCharacteristic c, int status) {
                    event(
                            "onCharacteristicWrite",
                            "status",
                            status,
                            "characteristic",
                            characteristicEvent(c));
                }

                @Override
                public void onCharacteristicChanged(
                        BluetoothGatt g, BluetoothGattCharacteristic c) {
                    if (Build.VERSION.SDK_INT < 33) changed(c, c.getValue());
                }

                @Override
                public void onCharacteristicChanged(
                        BluetoothGatt g, BluetoothGattCharacteristic c, byte[] value) {
                    changed(c, value);
                }

                void changed(BluetoothGattCharacteristic c, byte[] value) {
                    event(
                            "onCharacteristicChanged",
                            "characteristic",
                            characteristicEvent(c),
                            "value",
                            value == null ? null : value.clone());
                }

                @Override
                public void onDescriptorRead(
                        BluetoothGatt g, BluetoothGattDescriptor d, int status) {
                    if (Build.VERSION.SDK_INT < 33) readDescriptor(d, d.getValue(), status);
                }

                @Override
                public void onDescriptorRead(
                        BluetoothGatt g, BluetoothGattDescriptor d, int status, byte[] value) {
                    readDescriptor(d, value, status);
                }

                void readDescriptor(BluetoothGattDescriptor d, byte[] value, int status) {
                    event(
                            "onDescriptorRead",
                            "descriptor",
                            descriptorEvent(d),
                            "status",
                            status,
                            "value",
                            value == null ? null : value.clone());
                }

                @Override
                public void onDescriptorWrite(
                        BluetoothGatt g, BluetoothGattDescriptor d, int status) {
                    event("onDescriptorWrite", "descriptor", descriptorEvent(d), "status", status);
                }

                @Override
                public void onReadRemoteRssi(BluetoothGatt g, int rssi, int status) {
                    event("onReadRemoteRssi", "rssi", rssi, "status", status);
                }

                @Override
                public void onMtuChanged(BluetoothGatt g, int mtu, int status) {
                    event("onMtuChanged", "mtu", mtu, "status", status);
                }

                @Override
                public void onReliableWriteCompleted(BluetoothGatt g, int status) {
                    event("onReliableWriteCompleted", "status", status);
                }

                @Override
                public void onPhyRead(BluetoothGatt g, int tx, int rx, int status) {
                    event("onPhyRead", "txPhy", tx, "rxPhy", rx, "status", status);
                }

                @Override
                public void onPhyUpdate(BluetoothGatt g, int tx, int rx, int status) {
                    event("onPhyUpdate", "txPhy", tx, "rxPhy", rx, "status", status);
                }

                @Override
                public void onServiceChanged(BluetoothGatt g) {
                    if (!preserveAttributeHandles) invalidate();
                    event("onServiceChanged");
                }

                // Public in API 36.1. Compiling against 36 retains binary-compatible callback
                // dispatch.
                public void onSubrateChange(BluetoothGatt g, int mode, int status) {
                    event("onSubrateChange", "subrateMode", mode, "status", status);
                }
            };

    @android.annotation.SuppressLint("MissingPermission")
    void handle(String method, Map<String, Object> a, MethodChannel.Result r) throws Exception {
        BluetoothGatt g = this.gatt;
        Object value;
        switch (method) {
            case "getDevice":
                value = deviceMap(this.device);
                break;
            case "connect":
                value = g.connect();
                break;
            case "disconnect":
                p.deviceBridge.clearPairingPin(this.device);
                g.disconnect();
                value = null;
                break;
            case "close":
                this.close();
                value = null;
                break;
            case "discoverServices":
                value = g.discoverServices();
                break;
            case "getServices":
                value =
                        this.servicesValid
                                ? this.services(g.getServices())
                                : Collections.emptyList();
                break;
            case "readCharacteristic":
                value =
                        g.readCharacteristic(
                                this.get(string(a, "handle"), BluetoothGattCharacteristic.class));
                break;
            case "writeCharacteristic":
                {
                    BluetoothGattCharacteristic ch =
                            this.get(string(a, "handle"), BluetoothGattCharacteristic.class);
                    byte[] bytes = (byte[]) a.get("value");
                    int type = integer(a, "writeType", 2);
                    if (Build.VERSION.SDK_INT >= 33) value = g.writeCharacteristic(ch, bytes, type);
                    else {
                        ch.setValue(bytes);
                        ch.setWriteType(type);
                        value = g.writeCharacteristic(ch) ? 0 : Integer.MAX_VALUE;
                    }
                    break;
                }
            case "readDescriptor":
                value =
                        g.readDescriptor(
                                this.get(string(a, "handle"), BluetoothGattDescriptor.class));
                break;
            case "writeDescriptor":
                {
                    BluetoothGattDescriptor d =
                            this.get(string(a, "handle"), BluetoothGattDescriptor.class);
                    byte[] bytes = (byte[]) a.get("value");
                    if (Build.VERSION.SDK_INT >= 33) value = g.writeDescriptor(d, bytes);
                    else {
                        d.setValue(bytes);
                        value = g.writeDescriptor(d) ? 0 : Integer.MAX_VALUE;
                    }
                    break;
                }
            case "setCharacteristicNotification":
                value =
                        g.setCharacteristicNotification(
                                this.get(string(a, "handle"), BluetoothGattCharacteristic.class),
                                bool(a, "enable", false));
                break;
            case "requestMtu":
                value = g.requestMtu(integer(a, "mtu", 23));
                break;
            case "readRemoteRssi":
                value = g.readRemoteRssi();
                break;
            case "requestConnectionPriority":
                value = g.requestConnectionPriority(integer(a, "priority", 0));
                break;
            case "readPhy":
                if (Build.VERSION.SDK_INT < 26)
                    throw new UnsupportedOperationException("Requires Android API 26");
                g.readPhy();
                value = null;
                break;
            case "setPreferredPhy":
                if (Build.VERSION.SDK_INT < 26)
                    throw new UnsupportedOperationException("Requires Android API 26");
                g.setPreferredPhy(
                        integer(a, "txPhy", 1),
                        integer(a, "rxPhy", 1),
                        integer(a, "phyOptions", 0));
                value = null;
                break;
            case "requestSubrateMode":
                value =
                        optional(
                                g,
                                "requestSubrateMode",
                                new Class<?>[] {int.class},
                                integer(a, "subrateMode", 0));
                break;
            case "beginReliableWrite":
                value = g.beginReliableWrite();
                break;
            case "executeReliableWrite":
                value = g.executeReliableWrite();
                break;
            case "abortReliableWrite":
                g.abortReliableWrite();
                value = null;
                break;
            case "refresh":
                value = reflect(g, "refresh", new Class<?>[0]);
                if (Boolean.TRUE.equals(value) && !this.preserveAttributeHandles) this.invalidate();
                break;
            default:
                r.notImplemented();
                return;
        }
        r.success(value);
    }
}
