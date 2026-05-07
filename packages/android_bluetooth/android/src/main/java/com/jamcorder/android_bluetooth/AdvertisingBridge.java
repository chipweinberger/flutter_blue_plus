package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.bluetooth.le.*;
import android.os.Build;

import io.flutter.plugin.common.MethodChannel;

import java.util.*;

final class AdvertisingBridge {
    final AndroidBluetoothPlugin p;
    final Map<String, AdvertiseCallback> legacy = new HashMap<>();
    // The API 26 implementation is only instantiated after its version gate.
    Sets sets;

    AdvertisingBridge(AndroidBluetoothPlugin p) {
        this.p = p;
    }

    BluetoothLeAdvertiser advertiser() {
        BluetoothLeAdvertiser a = p.adapterBridge.adapter().getBluetoothLeAdvertiser();
        if (a == null)
            throw new UnsupportedOperationException(
                    "BLE advertising unavailable; check Bluetooth state and hardware support");
        return a;
    }

    static AdvertiseData data(Object value) {
        if (value == null) return null;
        Map<String, Object> a = object(value);
        AdvertiseData.Builder b =
                new AdvertiseData.Builder()
                        .setIncludeDeviceName(bool(a, "includeDeviceName", false))
                        .setIncludeTxPowerLevel(bool(a, "includeTxPowerLevel", false));
        for (Object u : list(a.get("serviceUuids"))) b.addServiceUuid(ScanBridge.uuid(u));
        for (Object u : list(a.get("serviceSolicitationUuids"))) {
            if (Build.VERSION.SDK_INT < 31)
                throw new UnsupportedOperationException("Requires Android API 31");
            b.addServiceSolicitationUuid(ScanBridge.uuid(u));
        }
        for (Map.Entry<String, Object> e : object(a.get("serviceData")).entrySet())
            b.addServiceData(ScanBridge.uuid(e.getKey()), (byte[]) e.getValue());
        for (Map.Entry<String, Object> e : object(a.get("manufacturerData")).entrySet())
            b.addManufacturerData(Integer.parseInt(e.getKey()), (byte[]) e.getValue());
        return b.build();
    }

    // App-owned ADVERTISE grants may already be revoked during cleanup; failures are caught.
    @android.annotation.SuppressLint("MissingPermission")
    void closeAll() {
        for (AdvertiseCallback c : legacy.values())
            try {
                advertiser().stopAdvertising(c);
            } catch (SecurityException ignored) {
                // The OS may already have revoked permission and torn down the registration.
            } catch (Exception ignored) {
            }
        legacy.clear();
        if (sets != null) sets.closeAll();
    }

    // BLUETOOTH_ADVERTISE grants belong to the app; Android enforces them and errors propagate.
    @android.annotation.SuppressLint("MissingPermission")
    void handle(String method, Map<String, Object> a, MethodChannel.Result r) {
        if (method.equals("start")) {
            Map<String, Object> settings = object(a.get("settings"));
            AdvertiseSettings s =
                    new AdvertiseSettings.Builder()
                            .setAdvertiseMode(integer(settings, "mode", 0))
                            .setTxPowerLevel(integer(settings, "txPowerLevel", 2))
                            .setConnectable(bool(settings, "connectable", true))
                            .setTimeout(integer(settings, "timeoutMillis", 0))
                            .build();
            String id = id("advertisement");
            long expectedGeneration = p.generation;
            AdvertiseCallback c =
                    new AdvertiseCallback() {
                        @Override
                        public void onStartSuccess(AdvertiseSettings s) {
                            if (p.generation != expectedGeneration || !legacy.containsKey(id))
                                return;
                            p.emit(
                                    id,
                                    "onStartSuccess",
                                    map(
                                            "settings",
                                            map(
                                                    "mode",
                                                    s.getMode(),
                                                    "txPowerLevel",
                                                    s.getTxPowerLevel(),
                                                    "connectable",
                                                    s.isConnectable(),
                                                    "timeoutMillis",
                                                    s.getTimeout())));
                        }

                        @Override
                        public void onStartFailure(int code) {
                            if (p.generation != expectedGeneration || !legacy.containsKey(id))
                                return;
                            p.main.post(() -> legacy.remove(id));
                            p.emit(id, "onStartFailure", map("errorCode", code));
                        }
                    };
            legacy.put(id, c);
            try {
                advertiser()
                        .startAdvertising(s, data(a.get("data")), data(a.get("scanResponse")), c);
            } catch (RuntimeException e) {
                legacy.remove(id);
                throw e;
            }
            r.success(id);
            return;
        }
        if (method.equals("stop")) {
            AdvertiseCallback c = legacy.get(string(a, "id"));
            if (c == null) {
                r.success(null);
                return;
            }
            advertiser().stopAdvertising(c);
            legacy.remove(string(a, "id"));
            r.success(null);
            return;
        }
        if (Build.VERSION.SDK_INT < 26)
            throw new UnsupportedOperationException("Requires Android API 26");
        if (sets == null) sets = new Sets();
        sets.handle(method, a, r);
    }

    @android.annotation.TargetApi(26)
    final class Sets {
        final Map<String, AdvertisingSetCallback> callbacks = new HashMap<>();
        final Map<String, AdvertisingSet> active = new HashMap<>();

        AdvertisingSetParameters parameters(Object value) {
            Map<String, Object> a = object(value);
            return new AdvertisingSetParameters.Builder()
                    .setConnectable(bool(a, "connectable", false))
                    .setScannable(bool(a, "scannable", false))
                    .setLegacyMode(bool(a, "legacy", false))
                    .setAnonymous(bool(a, "anonymous", false))
                    .setIncludeTxPower(bool(a, "includeTxPower", false))
                    .setPrimaryPhy(integer(a, "primaryPhy", 1))
                    .setSecondaryPhy(integer(a, "secondaryPhy", 1))
                    .setInterval(integer(a, "interval", 160))
                    .setTxPowerLevel(integer(a, "txPowerLevel", -7))
                    .build();
        }

        PeriodicAdvertisingParameters periodic(Object value) {
            if (value == null) return null;
            Map<String, Object> a = object(value);
            return new PeriodicAdvertisingParameters.Builder()
                    .setIncludeTxPower(bool(a, "includeTxPower", false))
                    .setInterval(integer(a, "interval", 80))
                    .build();
        }

        // App-owned ADVERTISE grants may already be revoked during cleanup; failures are caught.
        @android.annotation.SuppressLint("MissingPermission")
        void closeAll() {
            for (AdvertisingSetCallback c : callbacks.values())
                try {
                    advertiser().stopAdvertisingSet(c);
                } catch (SecurityException ignored) {
                    // The OS may already have revoked permission and torn down the registration.
                } catch (Exception ignored) {
                }
            callbacks.clear();
            active.clear();
        }

        // BLUETOOTH_ADVERTISE grants belong to the app; Android enforces them and errors propagate.
        @android.annotation.SuppressLint("MissingPermission")
        void handle(String method, Map<String, Object> a, MethodChannel.Result r) {
            if (method.equals("startSet")) {
                String id = id("advertising-set");
                long expectedGeneration = p.generation;
                AdvertisingSetCallback callback =
                        new AdvertisingSetCallback() {
                            void event(String type, AdvertisingSet set, Object... data) {
                                if (p.generation != expectedGeneration
                                        || !callbacks.containsKey(id)) return;
                                Map<String, Object> m = map(data);
                                p.emit(id, type, m);
                            }

                            @Override
                            public void onAdvertisingSetStarted(
                                    AdvertisingSet set, int power, int status) {
                                if (p.generation != expectedGeneration
                                        || !callbacks.containsKey(id)) return;
                                if (status == 0) active.put(id, set);
                                event(
                                        "onAdvertisingSetStarted",
                                        set,
                                        "txPower",
                                        power,
                                        "status",
                                        status);
                                if (status != 0) callbacks.remove(id);
                            }

                            @Override
                            public void onAdvertisingSetStopped(AdvertisingSet set) {
                                if (p.generation != expectedGeneration
                                        || !callbacks.containsKey(id)) return;
                                event("onAdvertisingSetStopped", set);
                                active.remove(id);
                                callbacks.remove(id);
                            }

                            @Override
                            public void onAdvertisingEnabled(
                                    AdvertisingSet set, boolean enabled, int status) {
                                event(
                                        "onAdvertisingEnabled",
                                        set,
                                        "enabled",
                                        enabled,
                                        "status",
                                        status);
                            }

                            @Override
                            public void onAdvertisingDataSet(AdvertisingSet set, int status) {
                                event("onAdvertisingDataSet", set, "status", status);
                            }

                            @Override
                            public void onScanResponseDataSet(AdvertisingSet set, int status) {
                                event("onScanResponseDataSet", set, "status", status);
                            }

                            @Override
                            public void onAdvertisingParametersUpdated(
                                    AdvertisingSet set, int power, int status) {
                                event(
                                        "onAdvertisingParametersUpdated",
                                        set,
                                        "txPower",
                                        power,
                                        "status",
                                        status);
                            }

                            @Override
                            public void onPeriodicAdvertisingParametersUpdated(
                                    AdvertisingSet set, int status) {
                                event(
                                        "onPeriodicAdvertisingParametersUpdated",
                                        set,
                                        "status",
                                        status);
                            }

                            @Override
                            public void onPeriodicAdvertisingDataSet(
                                    AdvertisingSet set, int status) {
                                event("onPeriodicAdvertisingDataSet", set, "status", status);
                            }

                            @Override
                            public void onPeriodicAdvertisingEnabled(
                                    AdvertisingSet set, boolean enabled, int status) {
                                event(
                                        "onPeriodicAdvertisingEnabled",
                                        set,
                                        "enabled",
                                        enabled,
                                        "status",
                                        status);
                            }
                        };
                callbacks.put(id, callback);
                try {
                    advertiser()
                            .startAdvertisingSet(
                                    parameters(a.get("parameters")),
                                    data(a.get("data")),
                                    data(a.get("scanResponse")),
                                    periodic(a.get("periodicParameters")),
                                    data(a.get("periodicData")),
                                    integer(a, "duration", 0),
                                    integer(a, "maxEvents", 0),
                                    callback,
                                    p.main);
                } catch (RuntimeException e) {
                    callbacks.remove(id);
                    throw e;
                }
                r.success(id);
                return;
            }
            String id = string(a, "id");
            if (method.equals("stopSet")) {
                AdvertisingSetCallback c = callbacks.get(id);
                if (c == null) {
                    r.success(false);
                    return;
                }
                boolean awaitCallback = active.containsKey(id);
                advertiser().stopAdvertisingSet(c);
                // Android cancels pending registrations without a terminal callback.
                if (!awaitCallback) {
                    callbacks.remove(id);
                    active.remove(id);
                }
                r.success(awaitCallback);
                return;
            }
            AdvertisingSet set = active.get(id);
            if (set == null)
                throw new IllegalStateException("Advertising set has not started or is closed");
            switch (method) {
                case "enable":
                    set.enableAdvertising(
                            bool(a, "enable", true),
                            integer(a, "duration", 0),
                            integer(a, "maxEvents", 0));
                    break;
                case "setData":
                    set.setAdvertisingData(data(a.get("data")));
                    break;
                case "setScanResponse":
                    set.setScanResponseData(data(a.get("data")));
                    break;
                case "setParameters":
                    set.setAdvertisingParameters(parameters(a.get("parameters")));
                    break;
                case "setPeriodicParameters":
                    set.setPeriodicAdvertisingParameters(periodic(a.get("parameters")));
                    break;
                case "setPeriodicData":
                    set.setPeriodicAdvertisingData(data(a.get("data")));
                    break;
                case "setPeriodicEnabled":
                    set.setPeriodicAdvertisingEnabled(bool(a, "enable", true));
                    break;
                default:
                    r.notImplemented();
                    return;
            }
            r.success(null);
        }
    }
}
