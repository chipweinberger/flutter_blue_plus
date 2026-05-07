package com.lib.android_bluetooth;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

public final class ManagerController
{
    public List<HashMap<String, Object>> getConnectedDevices(BluetoothManager bluetoothManager, int profile)
    {
        if (bluetoothManager == null) {
            return new ArrayList<>();
        }

        List<BluetoothDevice> devices = bluetoothManager.getConnectedDevices(profile);
        List<HashMap<String, Object>> serializedDevices = new ArrayList<>();
        for (BluetoothDevice device : devices) {
            serializedDevices.add(BluetoothDeviceSerializer.serialize(device));
        }
        return serializedDevices;
    }

    public List<HashMap<String, Object>> getDevicesMatchingConnectionStates(
        BluetoothManager bluetoothManager,
        int profile,
        int[] states
    )
    {
        if (bluetoothManager == null) {
            return new ArrayList<>();
        }

        List<BluetoothDevice> devices = bluetoothManager.getDevicesMatchingConnectionStates(profile, states);
        List<HashMap<String, Object>> serializedDevices = new ArrayList<>();
        for (BluetoothDevice device : devices) {
            serializedDevices.add(BluetoothDeviceSerializer.serialize(device));
        }
        return serializedDevices;
    }

    public String getConnectionState(BluetoothManager bluetoothManager, BluetoothDevice bluetoothDevice, int profile)
    {
        if (bluetoothManager == null || bluetoothDevice == null) {
            return "unknown";
        }

        int state = bluetoothManager.getConnectionState(bluetoothDevice, profile);
        switch (state) {
            case BluetoothProfile.STATE_DISCONNECTED:
                return "disconnected";
            case BluetoothProfile.STATE_CONNECTING:
                return "connecting";
            case BluetoothProfile.STATE_CONNECTED:
                return "connected";
            case BluetoothProfile.STATE_DISCONNECTING:
                return "disconnecting";
            default:
                return "unknown";
        }
    }

    public String getGattConnectionState(BluetoothManager bluetoothManager, BluetoothDevice bluetoothDevice)
    {
        return getConnectionState(bluetoothManager, bluetoothDevice, BluetoothProfile.GATT);
    }
}
