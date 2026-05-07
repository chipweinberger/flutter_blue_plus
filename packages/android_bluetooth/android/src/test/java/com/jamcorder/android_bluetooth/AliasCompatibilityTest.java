package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.junit.Assume.*;
import static org.mockito.Mockito.*;

import android.bluetooth.BluetoothDevice;
import android.os.Build;

import io.flutter.plugin.common.MethodCall;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {30, 31, 32, 33, 36},
        manifest = Config.NONE)
public class AliasCompatibilityTest {
    static final String ADDRESS = "AA:BB:CC:DD:EE:FF";

    static PluginTestSupport.Result setAlias(AndroidBluetoothPlugin p, String alias)
            throws Exception {
        PluginTestSupport.Result result = new PluginTestSupport.Result();
        p.onMethodCall(
                new MethodCall("device.setAlias", map("address", ADDRESS, "alias", alias)), result);
        result.await();
        return result;
    }

    @Test
    public void aliasIsVersionGatedAndPreservesNativeStatus() throws Exception {
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            BluetoothDevice device = mock(BluetoothDevice.class);
            p.knownDevices.put(ADDRESS, device);
            for (String alias : new String[] {"sensor", null}) {
                if (Build.VERSION.SDK_INT >= 31) when(device.setAlias(alias)).thenReturn(123);
                PluginTestSupport.Result result = setAlias(p, alias);
                if (Build.VERSION.SDK_INT >= 31) {
                    assertNull(result.error);
                    assertEquals(123, result.value);
                    verify(device).setAlias(alias);
                } else {
                    assertEquals("unsupported", result.error);
                    verifyNoInteractions(device);
                }
            }
        } finally {
            p.io.shutdownNow();
        }
    }

    @Test
    public void aliasPermissionErrorsAreNotReportedAsUnsupported() throws Exception {
        assumeTrue(Build.VERSION.SDK_INT >= 31);
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            BluetoothDevice device = mock(BluetoothDevice.class);
            p.knownDevices.put(ADDRESS, device);
            for (String alias : new String[] {"sensor", null}) {
                when(device.setAlias(alias)).thenThrow(new SecurityException("restricted"));
                assertEquals("permission_denied", setAlias(p, alias).error);
                verify(device).setAlias(alias);
            }
        } finally {
            p.io.shutdownNow();
        }
    }
}
