package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.AndroidBluetoothPlugin.ACTIVE;

import android.bluetooth.*;
import android.os.*;

import java.lang.reflect.InvocationTargetException;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;

/** Method-channel values, identifiers, and native device snapshots. */
final class BluetoothCodec {
    private static final AtomicLong NEXT = new AtomicLong();

    static Map<String, Object> map(Object... entries) {
        Map<String, Object> result = new LinkedHashMap<>();
        for (int i = 0; i < entries.length; i += 2) result.put((String) entries[i], entries[i + 1]);
        return result;
    }

    @SuppressWarnings("unchecked")
    static Map<String, Object> object(Object value) {
        return value == null ? new HashMap<>() : (Map<String, Object>) value;
    }

    @SuppressWarnings("unchecked")
    static List<Object> list(Object value) {
        return value == null ? Collections.emptyList() : (List<Object>) value;
    }

    static int integer(Object value, String name) {
        if (value instanceof Number) {
            double number = ((Number) value).doubleValue();
            if (number >= Integer.MIN_VALUE
                    && number <= Integer.MAX_VALUE
                    && number == Math.rint(number)) return (int) number;
        }
        throw new IllegalArgumentException(
                name + " must be an integer between -2147483648 and 2147483647");
    }

    static int integer(Map<String, Object> a, String key, int fallback) {
        Object value = a.get(key);
        return value == null ? fallback : integer(value, key);
    }

    static boolean bool(Map<String, Object> a, String key, boolean fallback) {
        return a.get(key) == null ? fallback : (Boolean) a.get(key);
    }

    static String string(Map<String, Object> a, String key) {
        Object value = a.get(key);
        if (!(value instanceof String))
            throw new IllegalArgumentException("Missing string: " + key);
        return (String) value;
    }

    static String id(String prefix) {
        return prefix + "-" + NEXT.incrementAndGet();
    }

    static Object reflect(Object target, String method, Class<?>[] types, Object... args)
            throws Exception {
        try {
            return target.getClass().getMethod(method, types).invoke(target, args);
        } catch (InvocationTargetException e) {
            Throwable cause = e.getCause();
            if (cause instanceof Exception) throw (Exception) cause;
            throw e;
        }
    }

    static Object optional(Object target, String method, Class<?>[] types, Object... args)
            throws Exception {
        try {
            return reflect(target, method, types, args);
        } catch (NoSuchMethodException e) {
            throw new UnsupportedOperationException(
                    "Public Android method unavailable on this OS: " + method, e);
        }
    }

    // CONNECT-protected metadata is optional; revoked/absent grants are caught below.
    @android.annotation.SuppressLint("MissingPermission")
    static Map<String, Object> deviceMap(BluetoothDevice device) {
        // Retain scanned native devices on API 21–34, which cannot publicly read address type.
        for (AndroidBluetoothPlugin p : ACTIVE) p.knownDevices.put(device.getAddress(), device);
        Map<String, Object> result = map("address", device.getAddress());
        if (Build.VERSION.SDK_INT >= 35) {
            try {
                result.put("addressType", optional(device, "getAddressType", new Class<?>[0]));
            } catch (Exception unavailable) {
                // Optional metadata must not break callbacks if an OEM restricts this method.
            }
        }
        try {
            result.put("name", device.getName());
            result.put("deviceType", device.getType());
            result.put("bondState", device.getBondState());
            if (Build.VERSION.SDK_INT >= 30) result.put("alias", device.getAlias());
            List<Object> uuids = new ArrayList<>();
            ParcelUuid[] cached = device.getUuids();
            if (cached != null) for (ParcelUuid uuid : cached) uuids.add(uuid.toString());
            result.put("uuids", cached == null ? null : uuids);
        } catch (SecurityException ignored) {
            /* Scan permission need not imply CONNECT permission. */
        }
        return result;
    }

    static List<Object> devices(List<BluetoothDevice> devices) {
        List<Object> result = new ArrayList<>();
        for (BluetoothDevice d : devices) result.add(deviceMap(d));
        return result;
    }
}
