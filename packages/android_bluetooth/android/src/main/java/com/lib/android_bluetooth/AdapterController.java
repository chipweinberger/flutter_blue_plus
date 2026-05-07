package com.lib.android_bluetooth;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.le.BluetoothLeScanner;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.core.content.ContextCompat;

public final class AdapterController
{
    private final Context context;

    public AdapterController(Context context)
    {
        this.context = context;
    }

    public boolean isEnabled(BluetoothAdapter bluetoothAdapter)
    {
        return bluetoothAdapter != null && bluetoothAdapter.getState() == BluetoothAdapter.STATE_ON;
    }

    @SuppressWarnings("deprecation")
    public boolean enable(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return false;
        }

        try {
            return bluetoothAdapter.enable();
        } catch (SecurityException exception) {
            return false;
        }
    }

    @SuppressWarnings("deprecation")
    public boolean disable(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return false;
        }

        try {
            return bluetoothAdapter.disable();
        } catch (SecurityException exception) {
            return false;
        }
    }

    public String getAdapterName(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return null;
        }

        try {
            return bluetoothAdapter.getName();
        } catch (SecurityException exception) {
            return null;
        }
    }

    public String getAdapterAddress(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return null;
        }

        try {
            return bluetoothAdapter.getAddress();
        } catch (SecurityException exception) {
            return null;
        }
    }

    public boolean setAdapterName(BluetoothAdapter bluetoothAdapter, String name)
    {
        if (bluetoothAdapter == null) {
            return false;
        }

        try {
            return bluetoothAdapter.setName(name);
        } catch (SecurityException exception) {
            return false;
        }
    }

    public boolean hasBluetoothLeScanner(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return false;
        }

        try {
            BluetoothLeScanner bluetoothLeScanner = bluetoothAdapter.getBluetoothLeScanner();
            return bluetoothLeScanner != null;
        } catch (SecurityException exception) {
            return false;
        }
    }

    public boolean isOffloadedFilteringSupported(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return false;
        }

        try {
            return bluetoothAdapter.isOffloadedFilteringSupported();
        } catch (SecurityException exception) {
            return false;
        }
    }

    public boolean isOffloadedScanBatchingSupported(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return false;
        }

        try {
            return bluetoothAdapter.isOffloadedScanBatchingSupported();
        } catch (SecurityException exception) {
            return false;
        }
    }

    public boolean isLe2MPhySupported(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return false;
        }

        try {
            return bluetoothAdapter.isLe2MPhySupported();
        } catch (SecurityException exception) {
            return false;
        }
    }

    public boolean isLeCodedPhySupported(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return false;
        }

        try {
            return bluetoothAdapter.isLeCodedPhySupported();
        } catch (SecurityException exception) {
            return false;
        }
    }

    public String getAdapterState(BluetoothAdapter bluetoothAdapter)
    {
        if (bluetoothAdapter == null) {
            return "unknown";
        }

        return mapAdapterState(bluetoothAdapter.getState());
    }

    public boolean isSupported(BluetoothAdapter bluetoothAdapter)
    {
        if (context == null) {
            return false;
        }

        if (!context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_BLUETOOTH)) {
            return false;
        }

        return bluetoothAdapter != null;
    }

    public boolean checkBluetoothAddress(String address)
    {
        return address != null && BluetoothAdapter.checkBluetoothAddress(address);
    }

    public boolean hasBluetoothConnectPermission()
    {
        return getMissingBluetoothConnectPermission() == null;
    }

    public boolean hasBluetoothScanPermission()
    {
        return getMissingBluetoothScanPermission() == null;
    }

    public String getMissingBluetoothConnectPermission()
    {
        if (context == null) {
            return Build.VERSION.SDK_INT >= 31 ? Manifest.permission.BLUETOOTH_CONNECT : null;
        }

        if (Build.VERSION.SDK_INT >= 31) {
            boolean granted = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) ==
                PackageManager.PERMISSION_GRANTED;
            return granted ? null : Manifest.permission.BLUETOOTH_CONNECT;
        }

        return null;
    }

    public String getMissingBluetoothScanPermission()
    {
        if (context == null) {
            return Build.VERSION.SDK_INT >= 31 ? Manifest.permission.BLUETOOTH_SCAN : Manifest.permission.ACCESS_FINE_LOCATION;
        }

        if (Build.VERSION.SDK_INT >= 31) {
            boolean granted = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) ==
                PackageManager.PERMISSION_GRANTED;
            return granted ? null : Manifest.permission.BLUETOOTH_SCAN;
        }

        boolean granted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED;
        return granted ? null : Manifest.permission.ACCESS_FINE_LOCATION;
    }

    public String mapAdapterState(int adapterState)
    {
        switch (adapterState) {
            case BluetoothAdapter.STATE_OFF:
                return "off";
            case BluetoothAdapter.STATE_TURNING_ON:
                return "turningOn";
            case BluetoothAdapter.STATE_ON:
                return "on";
            case BluetoothAdapter.STATE_TURNING_OFF:
                return "turningOff";
            default:
                return "unknown";
        }
    }
}
