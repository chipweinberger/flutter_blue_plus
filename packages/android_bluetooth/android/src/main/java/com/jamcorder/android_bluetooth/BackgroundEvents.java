package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.AndroidBluetoothPlugin.ACTIVE;
import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.os.*;
import android.util.Log;

import java.util.*;

/** Process-local background callbacks. Queue access and delivery run on the main thread. */
final class BackgroundEvents {
    static final Handler MAIN = new Handler(Looper.getMainLooper());
    static final ArrayDeque<Map<String, Object>> pending = new ArrayDeque<>();

    static void reportFailure(
            String owner, String type, String operation, RuntimeException failure) {
        Log.e(
                "AndroidBluetooth",
                "Background event " + operation + " failed (" + owner + "/" + type + ")",
                failure);
        Map<String, Object> details =
                map(
                        "owner",
                        owner,
                        "type",
                        type,
                        "operation",
                        operation,
                        "exception",
                        failure.getClass().getName(),
                        "apiLevel",
                        Build.VERSION.SDK_INT);
        for (AndroidBluetoothPlugin p : ACTIVE) p.emitBackgroundError(failure.toString(), details);
    }

    static void flush() {
        while (!pending.isEmpty()) {
            Map<String, Object> event = pending.peekFirst();
            boolean delivered = false;
            for (AndroidBluetoothPlugin p : ACTIVE) {
                if (!p.detached && p.sink != null) {
                    p.sink.success(event);
                    delivered = true;
                }
            }
            if (!delivered) return;
            pending.removeFirst();
        }
    }

    static void publish(String owner, String type, Map<String, Object> data) {
        Map<String, Object> event = new LinkedHashMap<>(data);
        event.put("owner", owner);
        event.put("type", type);
        event.put("receivedAtMillis", System.currentTimeMillis());
        MAIN.post(
                () -> {
                    pending.addLast(event);
                    flush();
                });
    }
}
