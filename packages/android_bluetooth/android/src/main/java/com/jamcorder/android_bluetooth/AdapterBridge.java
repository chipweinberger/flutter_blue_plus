package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.Manifest;
import android.bluetooth.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.os.*;
import android.provider.Settings;

import io.flutter.plugin.common.MethodChannel;

import java.util.*;

/** Adapter and manager operations; engine lifecycle remains with the plugin. */
final class AdapterBridge {
    final AndroidBluetoothPlugin p;

    AdapterBridge(AndroidBluetoothPlugin p) {
        this.p = p;
    }

    BluetoothAdapter adapter() {
        BluetoothAdapter adapter = p.manager == null ? null : p.manager.getAdapter();
        if (adapter == null)
            throw new UnsupportedOperationException("Bluetooth adapter unavailable");
        return adapter;
    }

    Map<String, Object> capabilities() {
        BluetoothAdapter a = p.manager == null ? null : p.manager.getAdapter();
        Map<String, Object> m =
                map(
                        "apiLevel",
                        Build.VERSION.SDK_INT,
                        "hasAdapter",
                        a != null,
                        "isSupported",
                        a != null
                                && p.context
                                        .getPackageManager()
                                        .hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE));
        if (a == null) {
            m.put("isEnabled", false);
            return m;
        }
        // API level must be available before Dart knows which runtime permissions to request.
        if (Build.VERSION.SDK_INT >= 31
                && p.context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                        != PackageManager.PERMISSION_GRANTED) {
            m.put("permissionRequired", true);
            return m;
        }
        try {
            m.put("isEnabled", a.isEnabled());
            m.put("isMultipleAdvertisementSupported", a.isMultipleAdvertisementSupported());
            m.put("isOffloadedFilteringSupported", a.isOffloadedFilteringSupported());
            m.put("isOffloadedScanBatchingSupported", a.isOffloadedScanBatchingSupported());
            if (Build.VERSION.SDK_INT >= 26) {
                m.put("isLe2MPhySupported", a.isLe2MPhySupported());
                m.put("isLeCodedPhySupported", a.isLeCodedPhySupported());
                m.put("isLeExtendedAdvertisingSupported", a.isLeExtendedAdvertisingSupported());
                m.put("isLePeriodicAdvertisingSupported", a.isLePeriodicAdvertisingSupported());
                m.put("leMaximumAdvertisingDataLength", a.getLeMaximumAdvertisingDataLength());
            } else m.put("leMaximumAdvertisingDataLength", 31);
        } catch (SecurityException denied) {
            m.put("permissionRequired", true);
        }
        return m;
    }

    @android.annotation.SuppressLint("MissingPermission")
    void handle(String method, Map<String, Object> a, MethodChannel.Result result)
            throws Exception {
        Object value;
        switch (method) {
            case "adapter.capabilities":
                value = capabilities();
                break;
            case "adapter.state":
                value = adapter().getState();
                break;
            case "adapter.isEnabled":
                value = adapter().isEnabled();
                break;
            case "adapter.isDiscovering":
                value = adapter().isDiscovering();
                break;
            case "adapter.isLe2MPhySupported":
                if (Build.VERSION.SDK_INT < 26)
                    throw new UnsupportedOperationException("Requires Android API 26");
                value = adapter().isLe2MPhySupported();
                break;
            case "adapter.isLeCodedPhySupported":
                if (Build.VERSION.SDK_INT < 26)
                    throw new UnsupportedOperationException("Requires Android API 26");
                value = adapter().isLeCodedPhySupported();
                break;
            case "adapter.cancelDiscovery":
                value = adapter().cancelDiscovery();
                break;
            case "adapter.enable":
                value = adapter().enable();
                break;
            case "adapter.disable":
                value = adapter().disable();
                break;
            case "adapter.name":
                value = adapter().getName();
                break;
            case "adapter.setName":
                value = adapter().setName(string(a, "name"));
                break;
            case "adapter.bondedDevices":
                value = devices(new ArrayList<>(adapter().getBondedDevices()));
                break;
            case "adapter.remoteLeDevice":
                {
                    if (Build.VERSION.SDK_INT < 33)
                        throw new UnsupportedOperationException("Requires Android API 33");
                    Map<String, Object> remote =
                            deviceMap(
                                    adapter()
                                            .getRemoteLeDevice(
                                                    string(a, "address"),
                                                    integer(a, "addressType", 0)));
                    remote.put("addressType", integer(a, "addressType", 0));
                    value = remote;
                    break;
                }
            case "adapter.requestEnable":
                p.needActivity();
                boolean waitForResult = bool(a, "waitForResult", true);
                if (!waitForResult) {
                    int code = p.newRequestCode();
                    p.enableEvents.put(code, p.enableEventResult());
                    try {
                        p.activity.startActivityForResult(
                                new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), code);
                    } catch (RuntimeException failure) {
                        p.enableEvents.remove(code);
                        p.releaseRequestCode(code);
                        throw failure;
                    }
                    result.success(true);
                    return;
                }
                if (p.enableResult != null)
                    throw new IllegalStateException("Enable request already in progress");
                p.enableRequestCode = p.newRequestCode();
                p.enableResult = result;
                try {
                    p.activity.startActivityForResult(
                            new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
                            p.enableRequestCode);
                } catch (RuntimeException failure) {
                    p.releaseRequestCode(p.enableRequestCode);
                    p.enableRequestCode = -1;
                    p.enableResult = null;
                    throw failure;
                }
                return;
            case "adapter.openSettings":
                p.context.startActivity(
                        new Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                value = null;
                break;
            case "manager.connectedDevices":
                value =
                        devices(
                                p.manager.getConnectedDevices(
                                        integer(a, "profile", BluetoothProfile.GATT)));
                break;
            case "manager.matchingDevices":
                {
                    List<Object> rawStates = list(a.get("states"));
                    int[] states = new int[rawStates.size()];
                    for (int i = 0; i < states.length; i++)
                        states[i] = integer(rawStates.get(i), "states[" + i + "]");
                    value =
                            devices(
                                    p.manager.getDevicesMatchingConnectionStates(
                                            integer(a, "profile", BluetoothProfile.GATT), states));
                    break;
                }
            case "manager.connectionState":
                value =
                        p.manager.getConnectionState(
                                p.deviceBridge.device(a),
                                integer(a, "profile", BluetoothProfile.GATT));
                break;
            default:
                result.notImplemented();
                return;
        }
        result.success(value);
    }
}
