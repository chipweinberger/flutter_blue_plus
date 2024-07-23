package com.lib.flutter_blue_plus.permission;

import android.Manifest;
import android.os.Build;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public class PermissionUtil {

    public static List<String> permissionForBleConnection() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return Collections.singletonList(Manifest.permission.BLUETOOTH_CONNECT);
        }
        return Collections.emptyList();
    }
}
