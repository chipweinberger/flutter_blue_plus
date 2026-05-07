package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.ranging.*;
import android.ranging.ble.cs.*;
import android.ranging.ble.rssi.*;
import android.ranging.raw.*;

import io.flutter.plugin.common.MethodChannel;

import java.util.*;
import java.util.concurrent.Executor;

/** API 36 only. Deliberately exposes BLE raw ranging, not Wi-Fi/UWB/OOB selection. */
@android.annotation.TargetApi(36)
final class RangingBridge implements RangingApi {
    final AndroidBluetoothPlugin p;
    final RangingManager manager;
    final Executor executor;
    final Map<String, RangingSession> sessions = new HashMap<>();
    final Map<String, android.os.CancellationSignal> starts = new HashMap<>();
    final Set<String> opened = new HashSet<>();
    final Set<String> closing = new HashSet<>();
    boolean registered;
    final long generation;

    RangingBridge(AndroidBluetoothPlugin p) {
        this.p = p;
        generation = p.generation;
        manager = p.context.getSystemService(RangingManager.class);
        if (manager == null) throw new UnsupportedOperationException("Ranging service unavailable");
        executor = command -> p.main.post(command);
    }

    final RangingManager.RangingCapabilitiesCallback capabilities = this::onCapabilities;

    void onCapabilities(RangingCapabilities c) {
        if (p.generation != generation) return;
        Map<String, Object> availability = new LinkedHashMap<>();
        // Report BLE only. Other ranging technologies are outside this library's contract.
        for (Map.Entry<Integer, Integer> e : c.getTechnologyAvailability().entrySet())
            if (e.getKey() == RangingManager.BLE_CS || e.getKey() == RangingManager.BLE_RSSI)
                availability.put(e.getKey().toString(), e.getValue());
        p.emit(
                "ranging",
                "onRangingCapabilities",
                map(
                        "capabilities",
                        map(
                                "technologyAvailability",
                                availability,
                                "csSupportedSecurityLevels",
                                c.getCsCapabilities() == null
                                        ? Collections.emptyList()
                                        : new ArrayList<>(
                                                c.getCsCapabilities()
                                                        .getSupportedSecurityLevels()))));
    }

    static RangingDevice device(String uuid) {
        return new RangingDevice.Builder().setUuid(UUID.fromString(uuid)).build();
    }

    static RawRangingDevice rawDevice(Map<String, Object> a) {
        RawRangingDevice.Builder b =
                new RawRangingDevice.Builder().setRangingDevice(device(string(a, "uuid")));
        if (a.get("csRangingParams") != null) {
            Map<String, Object> cs = object(a.get("csRangingParams"));
            BleCsRangingParams.Builder params =
                    new BleCsRangingParams.Builder(string(cs, "peerBluetoothAddress"));
            if (cs.get("rangingUpdateRate") != null)
                params.setRangingUpdateRate(integer(cs, "rangingUpdateRate", 1));
            if (cs.get("securityLevel") != null)
                params.setSecurityLevel(integer(cs, "securityLevel", 1));
            if (cs.get("locationType") != null)
                params.setLocationType(integer(cs, "locationType", 0));
            if (cs.get("sightType") != null) params.setSightType(integer(cs, "sightType", 0));
            b.setCsRangingParams(params.build());
        }
        if (a.get("bleRssiRangingParams") != null) {
            Map<String, Object> rssi = object(a.get("bleRssiRangingParams"));
            BleRssiRangingParams.Builder params =
                    new BleRssiRangingParams.Builder(string(rssi, "peerBluetoothAddress"));
            if (rssi.get("rangingUpdateRate") != null)
                params.setRangingUpdateRate(integer(rssi, "rangingUpdateRate", 1));
            b.setBleRssiRangingParams(params.build());
        }
        if (a.get("csRangingParams") == null && a.get("bleRssiRangingParams") == null)
            throw new IllegalArgumentException("Provide at least one BLE ranging technology");
        return b.build();
    }

    static SessionConfig sessionConfig(Map<String, Object> a) {
        SessionConfig.Builder b =
                new SessionConfig.Builder()
                        .setAngleOfArrivalNeeded(bool(a, "angleOfArrivalNeeded", false));
        if (a.get("rangingMeasurementsLimit") != null)
            b.setRangingMeasurementsLimit(integer(a, "rangingMeasurementsLimit", 0));
        if (a.get("sensorFusionEnabled") != null)
            b.setSensorFusionParams(
                    new SensorFusionParams.Builder()
                            .setSensorFusionEnabled(bool(a, "sensorFusionEnabled", false))
                            .build());
        if (a.get("notificationConfigType") != null
                || a.get("proximityNearCm") != null
                || a.get("proximityFarCm") != null) {
            DataNotificationConfig.Builder n = new DataNotificationConfig.Builder();
            if (a.get("notificationConfigType") != null)
                n.setNotificationConfigType(integer(a, "notificationConfigType", 1));
            if (a.get("proximityNearCm") != null)
                n.setProximityNearCm(integer(a, "proximityNearCm", 0));
            if (a.get("proximityFarCm") != null)
                n.setProximityFarCm(integer(a, "proximityFarCm", 0));
            b.setDataNotificationConfig(n.build());
        }
        return b.build();
    }

    static RangingPreference preference(Map<String, Object> a) {
        int role = integer(a, "deviceRole", RangingPreference.DEVICE_ROLE_INITIATOR);
        List<Object> devices = list(a.get("devices"));
        if (devices.isEmpty())
            throw new IllegalArgumentException("At least one ranging peer is required");
        RangingConfig config;
        if (role == RangingPreference.DEVICE_ROLE_INITIATOR) {
            RawInitiatorRangingConfig.Builder b = new RawInitiatorRangingConfig.Builder();
            for (Object value : devices) b.addRawRangingDevice(rawDevice(object(value)));
            config = b.build();
        } else if (role == RangingPreference.DEVICE_ROLE_RESPONDER) {
            if (devices.size() != 1)
                throw new IllegalArgumentException("A responder supports exactly one peer");
            config =
                    new RawResponderRangingConfig.Builder()
                            .setRawRangingDevice(rawDevice(object(devices.get(0))))
                            .build();
        } else throw new IllegalArgumentException("Invalid BLE ranging device role");
        return new RangingPreference.Builder(role, config)
                .setSessionConfig(sessionConfig(object(a.get("sessionConfig"))))
                .build();
    }

    static Object measurement(RangingMeasurement m) {
        return m == null
                ? null
                : map("measurement", m.getMeasurement(), "confidence", m.getConfidence());
    }

    @android.annotation.SuppressLint(
            "MissingPermission") // Cleanup still runs after permissions have been revoked.
    public void closeAll() {
        for (RangingSession s : new ArrayList<>(sessions.values()))
            try {
                s.close();
            } catch (Exception ignored) {
            }
        sessions.clear();
        starts.clear();
        opened.clear();
        closing.clear();
        if (registered)
            try {
                manager.unregisterCapabilitiesCallback(capabilities);
            } catch (Exception ignored) {
            }
        registered = false;
    }

    @android.annotation.SuppressLint(
            "MissingPermission") // The caller grants RANGING; Android enforces it and errors are
    // returned.
    public void handle(String method, Map<String, Object> a, MethodChannel.Result r) {
        switch (method) {
            case "registerCapabilities":
                if (!registered) {
                    manager.registerCapabilitiesCallback(executor, capabilities);
                    registered = true;
                }
                r.success(null);
                return;
            case "unregisterCapabilities":
                if (registered) {
                    manager.unregisterCapabilitiesCallback(capabilities);
                    registered = false;
                }
                r.success(null);
                return;
            case "create":
                {
                    String id = id("ranging");
                    RangingSession.Callback callback =
                            new RangingSession.Callback() {
                                void event(String type, Object... entries) {
                                    if (p.generation != generation) return;
                                    p.emit(id, type, map(entries));
                                }

                                @Override
                                public void onOpened() {
                                    if (p.generation != generation) return;
                                    if (sessions.containsKey(id) || closing.contains(id))
                                        opened.add(id);
                                    event("onOpened");
                                }

                                @Override
                                public void onOpenFailed(int reason) {
                                    if (p.generation != generation) return;
                                    // Peer-addition failures can use this callback during an open
                                    // session. Only an initial open failure ends its pending start.
                                    boolean complete = false;
                                    if (!opened.contains(id)) {
                                        starts.remove(id);
                                        complete = closing.remove(id);
                                    }
                                    event("onOpenFailed", "reason", reason, "isComplete", complete);
                                }

                                @Override
                                public void onClosed(int reason) {
                                    if (p.generation != generation) return;
                                    sessions.remove(id);
                                    starts.remove(id);
                                    opened.remove(id);
                                    closing.remove(id);
                                    event("onClosed", "reason", reason);
                                }

                                @Override
                                public void onStarted(RangingDevice peer, int technology) {
                                    event(
                                            "onStarted",
                                            "peerUuid",
                                            peer.getUuid().toString(),
                                            "technology",
                                            technology);
                                }

                                @Override
                                public void onStopped(RangingDevice peer, int technology) {
                                    event(
                                            "onStopped",
                                            "peerUuid",
                                            peer.getUuid().toString(),
                                            "technology",
                                            technology);
                                }

                                @Override
                                public void onResults(RangingDevice peer, RangingData d) {
                                    event(
                                            "onResults",
                                            "peerUuid",
                                            peer.getUuid().toString(),
                                            "result",
                                            map(
                                                    "rangingTechnology",
                                                    d.getRangingTechnology(),
                                                    "timestampMillis",
                                                    d.getTimestampMillis(),
                                                    "distance",
                                                    measurement(d.getDistance()),
                                                    "azimuth",
                                                    measurement(d.getAzimuth()),
                                                    "elevation",
                                                    measurement(d.getElevation()),
                                                    "rssi",
                                                    d.hasRssi() ? d.getRssi() : null));
                                }
                            };
                    RangingSession session = manager.createRangingSession(executor, callback);
                    if (session == null)
                        throw new IllegalStateException("Ranging registration failed");
                    sessions.put(id, session);
                    r.success(id);
                    return;
                }
        }
        String id = string(a, "id");
        RangingSession session = sessions.get(id);
        if (session == null) {
            if (method.equals("close")) {
                r.success(false);
                return;
            }
            throw new IllegalStateException("Ranging session closed or unknown");
        }
        switch (method) {
            case "start":
                starts.put(id, session.start(preference(object(a.get("preference")))));
                break;
            case "cancelStart":
                android.os.CancellationSignal signal = starts.get(id);
                if (signal == null) throw new IllegalStateException("No ranging start to cancel");
                signal.cancel();
                break;
            case "stop":
                session.stop();
                break;
            case "close":
                // Android does not send a final callback when no start is outstanding.
                boolean awaitCallback = starts.containsKey(id);
                session.close();
                sessions.remove(id);
                starts.remove(id);
                if (awaitCallback) closing.add(id);
                else opened.remove(id);
                r.success(awaitCallback);
                return;
            case "reconfigure":
                session.reconfigureRangingInterval(integer(a, "interval", 1));
                break;
            case "addDevice":
                session.addDeviceToRangingSession(
                        new RawResponderRangingConfig.Builder()
                                .setRawRangingDevice(rawDevice(object(a.get("device"))))
                                .build());
                break;
            case "removeDevice":
                throw new UnsupportedOperationException(
                        "Android raw peer removal supports UWB multicast only; create a new BLE"
                                + " ranging session with the desired peers");
            default:
                r.notImplemented();
                return;
        }
        r.success(null);
    }
}
