package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;

import java.util.*;

/** Per-registration delivery state. Rejected results never become channel payloads. */
final class ScanDelivery {
    final int advertisementDivisor;
    final boolean suppressDuplicates;
    final boolean includeBatchResults;
    final Map<String, byte[]> advertisements = new HashMap<>();
    final Map<String, Integer> counts = new HashMap<>();

    ScanDelivery(Map<String, Object> options) {
        Number number = (Number) options.get("advertisementDivisor");
        double divisor = number == null ? 1 : number.doubleValue();
        if (divisor < 1 || divisor > Integer.MAX_VALUE || divisor != Math.rint(divisor))
            throw new IllegalArgumentException(
                    "advertisementDivisor must be between 1 and 2147483647");
        advertisementDivisor = (int) divisor;
        suppressDuplicates = bool(options, "suppressDuplicates", false);
        includeBatchResults = bool(options, "includeBatchResults", true);
    }

    synchronized boolean accepts(ScanResult result) {
        if (!suppressDuplicates && advertisementDivisor == 1) return true;
        String address = result.getDevice().getAddress();
        if (suppressDuplicates) {
            ScanRecord record = result.getScanRecord();
            byte[] bytes = record == null ? new byte[0] : record.getBytes();
            byte[] previous = advertisements.put(address, bytes.clone());
            if (previous != null && Arrays.equals(previous, bytes)) return false;
        }
        if (advertisementDivisor == 1) return true;
        int count = counts.containsKey(address) ? counts.get(address) : 0;
        counts.put(address, count == advertisementDivisor - 1 ? 0 : count + 1);
        return count == 0;
    }
}
