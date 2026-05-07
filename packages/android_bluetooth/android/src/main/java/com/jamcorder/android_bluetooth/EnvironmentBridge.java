package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.Manifest;
import android.bluetooth.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.location.LocationManager;
import android.os.*;
import android.provider.Settings;

import io.flutter.plugin.common.MethodChannel;

import java.util.*;

/** Location state, explicit permissions, and foreground-service operations. */
final class EnvironmentBridge {
    final AndroidBluetoothPlugin p;

    EnvironmentBridge(AndroidBluetoothPlugin p) {
        this.p = p;
    }

    boolean isLocationEnabled() {
        if (Build.VERSION.SDK_INT >= 28) {
            LocationManager location =
                    (LocationManager) p.context.getSystemService(Context.LOCATION_SERVICE);
            return location != null && location.isLocationEnabled();
        }
        return Settings.Secure.getInt(
                        p.context.getContentResolver(),
                        Settings.Secure.LOCATION_MODE,
                        Settings.Secure.LOCATION_MODE_OFF)
                != Settings.Secure.LOCATION_MODE_OFF;
    }

    Map<String, Object> permissionStates(List<Object> permissions) {
        Map<String, Object> result = new LinkedHashMap<>();
        for (Object value : permissions) {
            String permission = (String) value;
            result.put(
                    permission,
                    p.context.checkCallingOrSelfPermission(permission)
                            == PackageManager.PERMISSION_GRANTED);
        }
        return result;
    }

    @android.annotation.SuppressLint("MissingPermission")
    void handle(String method, Map<String, Object> a, MethodChannel.Result result)
            throws Exception {
        Object value;
        switch (method) {
            case "environment.isLocationEnabled":
                value = isLocationEnabled();
                break;
            case "permissions.check":
                value = permissionStates(list(a.get("permissions")));
                break;
            case "permissions.request":
                {
                    if (Build.VERSION.SDK_INT >= 23) {
                        p.needActivity();
                        if (p.permissionResult != null)
                            throw new IllegalStateException(
                                    "Permission request already in progress");
                        p.requestedPermissions = list(a.get("permissions")).toArray(new String[0]);
                        p.permissionRequestCode = p.newRequestCode();
                        p.permissionResult = result;
                        p.activity.requestPermissions(
                                p.requestedPermissions, p.permissionRequestCode);
                        return;
                    }
                    value = permissionStates(list(a.get("permissions")));
                    break;
                }
            case "background.startService":
                {
                    p.needActivity();
                    if (Build.VERSION.SDK_INT >= 28
                            && p.context.checkSelfPermission(
                                            "android.permission.FOREGROUND_SERVICE")
                                    != PackageManager.PERMISSION_GRANTED)
                        throw new SecurityException(
                                "Declare android.permission.FOREGROUND_SERVICE in the"
                                        + " application manifest");
                    if (Build.VERSION.SDK_INT >= 34
                            && p.context.checkSelfPermission(
                                            "android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE")
                                    != PackageManager.PERMISSION_GRANTED)
                        throw new SecurityException(
                                "Declare android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE"
                                        + " in the application manifest");
                    if (Build.VERSION.SDK_INT >= 34
                            && p.context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                                    != PackageManager.PERMISSION_GRANTED
                            && p.context.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)
                                    != PackageManager.PERMISSION_GRANTED
                            && p.context.checkSelfPermission(
                                            Manifest.permission.BLUETOOTH_ADVERTISE)
                                    != PackageManager.PERMISSION_GRANTED)
                        throw new SecurityException(
                                "Grant a Bluetooth runtime permission before starting the"
                                        + " connectedDevice service");
                    int notificationId = integer(a, "notificationId", 51722);
                    if (notificationId <= 0)
                        throw new IllegalArgumentException("notificationId must be positive");
                    Intent service =
                            new Intent(p.context, BluetoothConnectionService.class)
                                    .putExtra("title", string(a, "title"))
                                    .putExtra("text", string(a, "text"))
                                    .putExtra("notificationId", notificationId);
                    if (Build.VERSION.SDK_INT >= 26) p.context.startForegroundService(service);
                    else p.context.startService(service);
                    value = null;
                    break;
                }
            case "background.stopService":
                p.context.stopService(new Intent(p.context, BluetoothConnectionService.class));
                value = null;
                break;
            default:
                result.notImplemented();
                return;
        }
        result.success(value);
    }
}
