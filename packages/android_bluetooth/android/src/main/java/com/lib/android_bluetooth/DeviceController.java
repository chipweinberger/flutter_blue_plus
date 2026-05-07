package com.lib.android_bluetooth;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Set;

public final class DeviceController
{
    public boolean createBond(BluetoothAdapter bluetoothAdapter, String address)
    {
        BluetoothDevice device = getBluetoothDevice(bluetoothAdapter, address);
        if (device == null) {
            return false;
        }

        if (device.getBondState() == BluetoothDevice.BOND_BONDED) {
            return false;
        }

        if (device.getBondState() == BluetoothDevice.BOND_BONDING) {
            return true;
        }

        try {
            return device.createBond();
        } catch (SecurityException exception) {
            return false;
        }
    }

    public boolean setPin(BluetoothAdapter bluetoothAdapter, String address, byte[] pin)
    {
        BluetoothDevice device = getBluetoothDevice(bluetoothAdapter, address);
        if (device == null || pin == null) {
            return false;
        }

        try {
            return device.setPin(pin);
        } catch (SecurityException exception) {
            return false;
        }
    }

    public boolean setPairingConfirmation(BluetoothAdapter bluetoothAdapter, String address, boolean confirm)
    {
        BluetoothDevice device = getBluetoothDevice(bluetoothAdapter, address);
        if (device == null) {
            return false;
        }

        try {
            return device.setPairingConfirmation(confirm);
        } catch (SecurityException exception) {
            return false;
        }
    }

    public String getBondState(BluetoothAdapter bluetoothAdapter, String address)
    {
        BluetoothDevice device = getBluetoothDevice(bluetoothAdapter, address);
        if (device == null) {
            return "unknown";
        }

        return BluetoothDeviceSerializer.mapBondState(device.getBondState());
    }

    public String getAddress(BluetoothAdapter bluetoothAdapter, String address)
    {
        BluetoothDevice device = getBluetoothDevice(bluetoothAdapter, address);
        if (device == null) {
            return null;
        }

        return device.getAddress();
    }

    public String getDeviceType(BluetoothAdapter bluetoothAdapter, String address)
    {
        BluetoothDevice device = getBluetoothDevice(bluetoothAdapter, address);
        if (device == null) {
            return "unknown";
        }

        return BluetoothDeviceSerializer.mapDeviceType(device.getType());
    }

    public String getName(BluetoothAdapter bluetoothAdapter, String address)
    {
        BluetoothDevice device = getBluetoothDevice(bluetoothAdapter, address);
        if (device == null) {
            return null;
        }

        return device.getName();
    }

    public HashMap<String, Object> getRemoteLeDevice(BluetoothAdapter bluetoothAdapter, String address, Integer addressType)
    {
        if (bluetoothAdapter == null || address == null || addressType == null) {
            return null;
        }

        try {
            BluetoothDevice device = bluetoothAdapter.getRemoteLeDevice(address, addressType);
            return device == null ? null : BluetoothDeviceSerializer.serialize(device);
        } catch (IllegalArgumentException | SecurityException exception) {
            return null;
        }
    }

    public boolean removeBond(BluetoothAdapter bluetoothAdapter, String address)
    {
        BluetoothDevice device = getBluetoothDevice(bluetoothAdapter, address);
        if (device == null) {
            return false;
        }

        if (device.getBondState() == BluetoothDevice.BOND_NONE) {
            return false;
        }

        try {
            Method removeBondMethod = device.getClass().getMethod("removeBond");
            return (boolean) removeBondMethod.invoke(device);
        } catch (Exception exception) {
            return false;
        }
    }

    public List<String> getUuids(BluetoothAdapter bluetoothAdapter, String address)
    {
        BluetoothDevice device = getBluetoothDevice(bluetoothAdapter, address);
        if (device == null) {
            return new ArrayList<>();
        }

        return BluetoothDeviceSerializer.getUuids(device);
    }

    public BluetoothDevice getBluetoothDevice(BluetoothAdapter bluetoothAdapter, String address)
    {
        if (bluetoothAdapter == null || address == null) {
            return null;
        }

        try {
            return bluetoothAdapter.getRemoteDevice(address);
        } catch (IllegalArgumentException exception) {
            return null;
        }
    }
}
