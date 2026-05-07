package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.bluetooth.le.*;
import android.content.*;
import android.os.Build;

import java.util.*;

public final class ScanReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context c, Intent intent) {
        if (Build.VERSION.SDK_INT < 26) return;
        String type = "onScanResult";
        try {
            int error = intent.getIntExtra(BluetoothLeScanner.EXTRA_ERROR_CODE, 0);
            type = error == 0 ? "onScanResult" : "onScanFailed";
            ArrayList<ScanResult> results =
                    intent.getParcelableArrayListExtra(BluetoothLeScanner.EXTRA_LIST_SCAN_RESULT);
            Map<String, Object> data =
                    map(
                            "scanId", intent.getIntExtra("scanId", 0),
                            "callbackType",
                                    intent.getIntExtra(BluetoothLeScanner.EXTRA_CALLBACK_TYPE, 1),
                            "results",
                                    results == null
                                            ? Collections.emptyList()
                                            : ScanBridge.resultMaps(results));
            if (error != 0) data.put("errorCode", error);
            BackgroundEvents.publish("scanner", type, data);
        } catch (RuntimeException failure) {
            BackgroundEvents.reportFailure("scanner", type, "receive", failure);
        }
    }
}
