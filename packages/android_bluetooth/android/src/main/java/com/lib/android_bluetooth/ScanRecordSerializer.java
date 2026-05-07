package com.lib.android_bluetooth;

import android.bluetooth.le.ScanRecord;
import android.os.ParcelUuid;
import android.util.SparseArray;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public final class ScanRecordSerializer
{
    private ScanRecordSerializer() {}

    public static HashMap<String, Object> serialize(ScanRecord scanRecord)
    {
        HashMap<String, Object> map = new HashMap<>();
        if (scanRecord == null) {
            return map;
        }

        map.put("advertisingDataMap", serializeAdvertisingDataMap(scanRecord));

        Integer appearance = getAppearance(scanRecord);
        if (appearance != null) {
            map.put("appearance", appearance);
        }

        map.put("localName", scanRecord.getDeviceName());
        map.put("manufacturerData", serializeManufacturerData(scanRecord));
        map.put("rawBytes", scanRecord.getBytes());
        map.put("serviceData", serializeServiceData(scanRecord));
        map.put("serviceSolicitationUuids", serializeServiceSolicitationUuids(scanRecord));
        map.put("serviceUuids", serializeServiceUuids(scanRecord));

        int txPowerLevel = scanRecord.getTxPowerLevel();
        if (txPowerLevel != Integer.MIN_VALUE) {
            map.put("txPowerLevel", txPowerLevel);
        }

        return map;
    }

    private static HashMap<Integer, byte[]> serializeAdvertisingDataMap(ScanRecord scanRecord)
    {
        HashMap<Integer, byte[]> map = new HashMap<>();
        if (android.os.Build.VERSION.SDK_INT < 33) {
            return map;
        }

        Map<Integer, byte[]> advertisingDataMap = scanRecord.getAdvertisingDataMap();
        if (advertisingDataMap == null) {
            return map;
        }

        map.putAll(advertisingDataMap);
        return map;
    }

    private static Integer getAppearance(ScanRecord scanRecord)
    {
        if (android.os.Build.VERSION.SDK_INT < 31) {
            return null;
        }

        return scanRecord.getAppearance();
    }

    private static HashMap<Integer, byte[]> serializeManufacturerData(ScanRecord scanRecord)
    {
        HashMap<Integer, byte[]> map = new HashMap<>();
        SparseArray<byte[]> manufacturerData = scanRecord.getManufacturerSpecificData();
        for (int i = 0; i < manufacturerData.size(); i++) {
            map.put(manufacturerData.keyAt(i), manufacturerData.valueAt(i));
        }
        return map;
    }

    private static HashMap<String, byte[]> serializeServiceData(ScanRecord scanRecord)
    {
        HashMap<String, byte[]> map = new HashMap<>();
        Map<ParcelUuid, byte[]> serviceData = scanRecord.getServiceData();
        if (serviceData == null) {
            return map;
        }

        for (Map.Entry<ParcelUuid, byte[]> entry : serviceData.entrySet()) {
            map.put(entry.getKey().toString().toLowerCase(), entry.getValue());
        }
        return map;
    }

    private static List<String> serializeServiceUuids(ScanRecord scanRecord)
    {
        List<String> uuids = new ArrayList<>();
        List<ParcelUuid> serviceUuids = scanRecord.getServiceUuids();
        if (serviceUuids == null) {
            return uuids;
        }

        for (ParcelUuid serviceUuid : serviceUuids) {
            uuids.add(serviceUuid.toString().toLowerCase());
        }
        return uuids;
    }

    private static List<String> serializeServiceSolicitationUuids(ScanRecord scanRecord)
    {
        List<String> uuids = new ArrayList<>();
        if (android.os.Build.VERSION.SDK_INT < 29) {
            return uuids;
        }

        List<ParcelUuid> serviceSolicitationUuids = scanRecord.getServiceSolicitationUuids();
        if (serviceSolicitationUuids == null) {
            return uuids;
        }

        for (ParcelUuid serviceSolicitationUuid : serviceSolicitationUuids) {
            uuids.add(serviceSolicitationUuid.toString().toLowerCase());
        }
        return uuids;
    }
}
