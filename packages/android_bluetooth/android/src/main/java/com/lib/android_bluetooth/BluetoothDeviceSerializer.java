package com.lib.android_bluetooth;

import android.bluetooth.BluetoothDevice;
import android.os.ParcelUuid;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

public final class BluetoothDeviceSerializer
{
    private BluetoothDeviceSerializer() {}

    public static HashMap<String, Object> serialize(BluetoothDevice device)
    {
        HashMap<String, Object> map = new HashMap<>();
        map.put("address", device.getAddress());
        map.put("bondState", mapBondState(device.getBondState()));
        map.put("platformName", device.getName());
        map.put("type", mapDeviceType(device.getType()));
        map.put("uuids", getUuids(device));
        return map;
    }

    public static List<String> getUuids(BluetoothDevice device)
    {
        List<String> uuids = new ArrayList<>();
        ParcelUuid[] parcelUuids = device.getUuids();
        if (parcelUuids == null) {
            return uuids;
        }

        for (ParcelUuid parcelUuid : parcelUuids) {
            uuids.add(parcelUuid.toString().toLowerCase());
        }

        return uuids;
    }

    public static String mapBondState(int bondState)
    {
        switch (bondState) {
            case BluetoothDevice.BOND_NONE:
                return "none";
            case BluetoothDevice.BOND_BONDING:
                return "bonding";
            case BluetoothDevice.BOND_BONDED:
                return "bonded";
            default:
                return "unknown";
        }
    }

    public static String mapDeviceType(int deviceType)
    {
        switch (deviceType) {
            case BluetoothDevice.DEVICE_TYPE_CLASSIC:
                return "classic";
            case BluetoothDevice.DEVICE_TYPE_LE:
                return "le";
            case BluetoothDevice.DEVICE_TYPE_DUAL:
                return "dual";
            case BluetoothDevice.DEVICE_TYPE_UNKNOWN:
            default:
                return "unknown";
        }
    }
}
