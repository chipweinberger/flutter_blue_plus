package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.app.PendingIntent;
import android.bluetooth.le.*;
import android.content.*;
import android.os.*;

import io.flutter.plugin.common.MethodChannel;

import java.util.*;

final class ScanBridge {
    final AndroidBluetoothPlugin p;
    final Map<String, Registration> sessions = new HashMap<>();

    final class Registration {
        final String id;
        final BluetoothLeScanner scanner;
        volatile boolean stopped;
        final long generation = p.generation;

        Registration(String id, BluetoothLeScanner scanner) {
            this.id = id;
            this.scanner = scanner;
        }

        final ScanCallback callback =
                new ScanCallback() {
                    @Override
                    public void onScanResult(int type, ScanResult result) {
                        if (!stopped && p.generation == generation)
                            event(
                                    "onScanResult",
                                    map(
                                            "callbackType",
                                            type,
                                            "results",
                                            Collections.singletonList(resultMap(result))));
                    }

                    @Override
                    public void onBatchScanResults(List<ScanResult> results) {
                        if (!stopped && p.generation == generation)
                            event("onBatchScanResults", map("results", resultMaps(results)));
                    }

                    @Override
                    public void onScanFailed(int error) {
                        p.main.post(
                                () -> {
                                    if (sessions.get(id) == Registration.this) sessions.remove(id);
                                });
                        if (!stopped && p.generation == generation)
                            event("onScanFailed", map("errorCode", error));
                    }
                };

        void event(String type, Map<String, Object> data) {
            p.emit(id, type, data, generation);
        }

        // BLUETOOTH_SCAN grants belong to the app; Android enforces them and errors propagate.
        @android.annotation.SuppressLint("MissingPermission")
        void stop() {
            scanner.stopScan(callback);
            stopped = true;
        }
    }

    ScanBridge(AndroidBluetoothPlugin p) {
        this.p = p;
    }

    BluetoothLeScanner scanner() {
        BluetoothLeScanner scanner = p.adapterBridge.adapter().getBluetoothLeScanner();
        if (scanner == null)
            throw new IllegalStateException("Bluetooth must be enabled before scanning");
        return scanner;
    }

    static ParcelUuid uuid(Object value) {
        return value == null ? null : ParcelUuid.fromString((String) value);
    }

    static void checkMask(Object data, Object mask) {
        if (mask != null && (data == null || ((byte[]) data).length != ((byte[]) mask).length))
            throw new IllegalArgumentException("Scan data and mask lengths must match");
    }

    static ScanFilter filter(Map<String, Object> a) {
        if (a.get("serviceDataUuid") != null)
            checkMask(a.get("serviceData"), a.get("serviceDataMask"));
        if (a.get("manufacturerId") != null)
            checkMask(a.get("manufacturerData"), a.get("manufacturerDataMask"));
        ScanFilter.Builder b = new ScanFilter.Builder();
        if (a.get("deviceName") != null) b.setDeviceName(string(a, "deviceName"));
        if (a.get("deviceAddress") != null) b.setDeviceAddress(string(a, "deviceAddress"));
        if (a.get("serviceUuid") != null)
            b.setServiceUuid(uuid(a.get("serviceUuid")), uuid(a.get("serviceUuidMask")));
        if (a.get("serviceDataUuid") != null)
            b.setServiceData(
                    uuid(a.get("serviceDataUuid")),
                    (byte[]) a.get("serviceData"),
                    (byte[]) a.get("serviceDataMask"));
        if (a.get("manufacturerId") != null)
            b.setManufacturerData(
                    integer(a, "manufacturerId", 0),
                    (byte[]) a.get("manufacturerData"),
                    (byte[]) a.get("manufacturerDataMask"));
        if (a.get("serviceSolicitationUuid") != null) {
            if (Build.VERSION.SDK_INT < 29)
                throw new UnsupportedOperationException("Requires Android API 29");
            b.setServiceSolicitationUuid(
                    uuid(a.get("serviceSolicitationUuid")),
                    uuid(a.get("serviceSolicitationUuidMask")));
        }
        if (a.get("advertisingDataType") != null) {
            if (Build.VERSION.SDK_INT < 33)
                throw new UnsupportedOperationException("Requires Android API 33");
            if (a.get("advertisingData") == null)
                b.setAdvertisingDataType(integer(a, "advertisingDataType", 0));
            else
                b.setAdvertisingDataTypeWithData(
                        integer(a, "advertisingDataType", 0),
                        (byte[]) a.get("advertisingData"),
                        (byte[]) a.get("advertisingDataMask"));
        }
        return b.build();
    }

    static List<ScanFilter> filters(Object value) {
        List<ScanFilter> result = new ArrayList<>();
        for (Object f : list(value)) result.add(filter(object(f)));
        return result;
    }

    static ScanSettings settings(Map<String, Object> a) throws Exception {
        ScanSettings.Builder b =
                new ScanSettings.Builder()
                        .setScanMode(integer(a, "scanMode", 0))
                        .setReportDelay(
                                a.get("reportDelayMillis") == null
                                        ? 0L
                                        : ((Number) a.get("reportDelayMillis")).longValue());
        if (Build.VERSION.SDK_INT >= 23) {
            b.setCallbackType(integer(a, "callbackType", 1));
            if (a.get("matchMode") != null) b.setMatchMode(integer(a, "matchMode", 1));
            if (a.get("numOfMatches") != null) b.setNumOfMatches(integer(a, "numOfMatches", 3));
        } else if (integer(a, "callbackType", 1) != 1
                || a.get("matchMode") != null
                || a.get("numOfMatches") != null)
            if (Build.VERSION.SDK_INT < 23)
                throw new UnsupportedOperationException("Requires Android API 23");
        if (a.get("legacy") != null) {
            if (Build.VERSION.SDK_INT < 26)
                throw new UnsupportedOperationException("Requires Android API 26");
            b.setLegacy(bool(a, "legacy", true));
        }
        if (a.get("phy") != null) {
            if (Build.VERSION.SDK_INT < 26)
                throw new UnsupportedOperationException("Requires Android API 26");
            b.setPhy(integer(a, "phy", 1));
        }
        if (a.get("scanType") != null)
            optional(b, "setScanType", new Class<?>[] {int.class}, integer(a, "scanType", 0));
        if (a.get("rssiThreshold") != null)
            optional(
                    b,
                    "setRssiThreshold",
                    new Class<?>[] {int.class},
                    integer(a, "rssiThreshold", -127));
        return b.build();
    }

    static Map<String, Object> recordMap(ScanRecord record) {
        Map<String, Object> manufacturers = new LinkedHashMap<>(), services = new LinkedHashMap<>();
        android.util.SparseArray<byte[]> data = record.getManufacturerSpecificData();
        for (int i = 0; i < data.size(); i++)
            manufacturers.put(Integer.toString(data.keyAt(i)), data.valueAt(i));
        if (record.getServiceData() != null)
            for (Map.Entry<ParcelUuid, byte[]> e : record.getServiceData().entrySet())
                services.put(e.getKey().toString(), e.getValue());
        List<Object> uuids = new ArrayList<>(), solicitation = new ArrayList<>();
        if (record.getServiceUuids() != null)
            for (ParcelUuid u : record.getServiceUuids()) uuids.add(u.toString());
        if (Build.VERSION.SDK_INT >= 29 && record.getServiceSolicitationUuids() != null)
            for (ParcelUuid u : record.getServiceSolicitationUuids())
                solicitation.add(u.toString());
        return map(
                "bytes",
                record.getBytes(),
                "deviceName",
                record.getDeviceName(),
                "advertiseFlags",
                record.getAdvertiseFlags(),
                "txPowerLevel",
                record.getTxPowerLevel(),
                "serviceUuids",
                uuids,
                "serviceSolicitationUuids",
                solicitation,
                "manufacturerSpecificData",
                manufacturers,
                "serviceData",
                services);
    }

    static Map<String, Object> resultMap(ScanResult r) {
        Map<String, Object> m =
                map(
                        "device",
                        deviceMap(r.getDevice()),
                        "rssi",
                        r.getRssi(),
                        "timestampNanos",
                        r.getTimestampNanos(),
                        "scanRecord",
                        r.getScanRecord() == null ? null : recordMap(r.getScanRecord()));
        if (Build.VERSION.SDK_INT >= 26)
            m.putAll(
                    map(
                            "isConnectable",
                            r.isConnectable(),
                            "isLegacy",
                            r.isLegacy(),
                            "primaryPhy",
                            r.getPrimaryPhy(),
                            "secondaryPhy",
                            r.getSecondaryPhy(),
                            "advertisingSid",
                            r.getAdvertisingSid(),
                            "txPower",
                            r.getTxPower(),
                            "periodicAdvertisingInterval",
                            r.getPeriodicAdvertisingInterval(),
                            "dataStatus",
                            r.getDataStatus()));
        return m;
    }

    static List<Object> resultMaps(List<ScanResult> results) {
        List<Object> out = new ArrayList<>();
        for (ScanResult r : results) out.add(resultMap(r));
        return out;
    }

    static PendingIntent pending(Context c, int id) {
        // Mutable is required so Android Bluetooth can attach scan extras. Explicit target is
        // mandatory.
        Intent intent =
                new Intent(c, ScanReceiver.class)
                        .setAction("dev.android_bluetooth.SCAN." + id)
                        .putExtra("scanId", id);
        return PendingIntent.getBroadcast(
                c,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT
                        | (Build.VERSION.SDK_INT >= 31 ? PendingIntent.FLAG_MUTABLE : 0));
    }

    void closeAll() {
        for (Registration registration : sessions.values())
            try {
                registration.stop();
            } catch (SecurityException ignored) {
                // The OS may already have revoked permission and torn down the registration.
            } catch (Exception ignored) {
            }
        sessions.clear();
        // PendingIntent scans intentionally outlive this engine; stop them explicitly by id.
    }

    // BLUETOOTH_SCAN grants belong to the app; Android enforces them and errors propagate.
    @android.annotation.SuppressLint("MissingPermission")
    void handle(String method, Map<String, Object> a, MethodChannel.Result r) throws Exception {
        switch (method) {
            case "start":
            case "startSession":
                {
                    String id = method.equals("start") ? "scanner" : id("scan");
                    if (sessions.containsKey(id))
                        throw new IllegalStateException(
                                "A default callback scan is already active");
                    Registration registration = new Registration(id, scanner());
                    sessions.put(id, registration);
                    try {
                        registration.scanner.startScan(
                                filters(a.get("filters")),
                                settings(object(a.get("settings"))),
                                registration.callback);
                    } catch (Exception e) {
                        sessions.remove(id);
                        throw e;
                    }
                    r.success(method.equals("start") ? null : id);
                    return;
                }
            case "stop":
            case "stopSession":
                {
                    String id = method.equals("stop") ? "scanner" : string(a, "id");
                    Registration registration = sessions.get(id);
                    if (registration != null) {
                        registration.stop();
                        sessions.remove(id);
                    }
                    r.success(null);
                    return;
                }
            case "flush":
            case "flushSession":
                {
                    Registration registration =
                            sessions.get(method.equals("flush") ? "scanner" : string(a, "id"));
                    if (registration == null)
                        throw new IllegalStateException("No active callback scan");
                    registration.scanner.flushPendingScanResults(registration.callback);
                    r.success(null);
                    return;
                }
            case "backgroundStart":
                if (Build.VERSION.SDK_INT < 26)
                    throw new UnsupportedOperationException("Requires Android API 26");
                if (list(a.get("filters")).isEmpty())
                    throw new IllegalArgumentException(
                            "Background scanning requires at least one filter");
                r.success(
                        scanner()
                                .startScan(
                                        filters(a.get("filters")),
                                        settings(object(a.get("settings"))),
                                        pending(p.context, integer(a, "id", 0))));
                return;
            case "backgroundStop":
                if (Build.VERSION.SDK_INT < 26)
                    throw new UnsupportedOperationException("Requires Android API 26");
                scanner().stopScan(pending(p.context, integer(a, "id", 0)));
                r.success(null);
                return;
            default:
                r.notImplemented();
        }
    }
}
