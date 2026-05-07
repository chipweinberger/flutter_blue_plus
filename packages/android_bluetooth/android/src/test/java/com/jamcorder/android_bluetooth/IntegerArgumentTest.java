package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanSettings;

import io.flutter.plugin.common.MethodCall;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

import java.util.Arrays;
import java.util.Collections;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class IntegerArgumentTest {
    @Test
    public void nativeIntBoundariesAndDefaultsRemainUnchanged() {
        for (long value : new long[] {Integer.MIN_VALUE, -1, 0, 1, Integer.MAX_VALUE}) {
            assertEquals((int) value, integer(map("value", value), "value", 7));
            assertEquals((int) value, integer(map("value", (int) value), "value", 7));
        }
        assertEquals(7, integer(map(), "value", 7));
        assertEquals(-1, integer(map("value", null), "value", -1));
    }

    @Test
    public void nativeIntsRejectOverflowAndNonIntegerValues() {
        for (Object value :
                new Object[] {
                    Long.MIN_VALUE,
                    Long.MAX_VALUE,
                    (long) Integer.MIN_VALUE - 1,
                    (long) Integer.MAX_VALUE + 1,
                    4294967295L,
                    4294967298L,
                    -4294967294L,
                    1.5d,
                    Double.NaN,
                    Double.NEGATIVE_INFINITY,
                    Double.POSITIVE_INFINITY,
                    "1",
                    true
                }) {
            IllegalArgumentException error =
                    assertThrows(
                            IllegalArgumentException.class,
                            () -> integer(map("scanMode", value), "scanMode", 0));
            assertTrue(error.getMessage().contains("scanMode"));
        }
    }

    @Test
    public void oversizedScanModesCannotBecomeValidNativeModes() throws Exception {
        for (long mode : new long[] {4294967295L, 4294967298L, -4294967294L}) {
            assertThrows(
                    IllegalArgumentException.class,
                    () -> ScanBridge.settings(map("scanMode", mode)));
        }
        for (int mode : new int[] {-1, 0, 1, 2}) {
            assertEquals(mode, ScanBridge.settings(map("scanMode", mode)).getScanMode());
        }
    }

    @Test
    public void nativeLongReportDelaysRemainUnchanged() throws Exception {
        for (long delay :
                new long[] {0, (long) Integer.MAX_VALUE + 1, 4294967297L, Long.MAX_VALUE}) {
            assertEquals(
                    delay,
                    ScanBridge.settings(map("reportDelayMillis", delay)).getReportDelayMillis());
        }
    }

    @Test
    public void rejectedScanSettingsDoNotStartOrRetainAScanAndPermitRetry() throws Exception {
        try (PluginTestSupport.Attached attached = new PluginTestSupport.Attached()) {
            BluetoothManager manager = mock(BluetoothManager.class);
            BluetoothAdapter adapter = mock(BluetoothAdapter.class);
            BluetoothLeScanner scanner = mock(BluetoothLeScanner.class);
            attached.p.manager = manager;
            when(manager.getAdapter()).thenReturn(adapter);
            when(adapter.getBluetoothLeScanner()).thenReturn(scanner);
            PluginTestSupport.Result invalid = new PluginTestSupport.Result();
            attached.p.onMethodCall(
                    new MethodCall(
                            "scan.startSession", map("settings", map("scanMode", 4294967295L))),
                    invalid);
            invalid.await();
            assertEquals("invalid_argument", invalid.error);
            assertTrue(attached.p.scans.sessions.isEmpty());
            verify(scanner, never())
                    .startScan(anyList(), any(ScanSettings.class), any(ScanCallback.class));
            PluginTestSupport.Result valid = new PluginTestSupport.Result();
            attached.p.onMethodCall(
                    new MethodCall("scan.startSession", map("settings", map("scanMode", 2))),
                    valid);
            valid.await();
            assertNull(valid.error);
            assertTrue(attached.p.scans.sessions.containsKey(valid.value));
            verify(scanner).startScan(anyList(), any(ScanSettings.class), any(ScanCallback.class));
        }
    }

    @Test
    public void connectionStateArraysRejectOverflowBeforeNativeQueriesAndPermitRetry()
            throws Exception {
        try (PluginTestSupport.Attached attached = new PluginTestSupport.Attached()) {
            BluetoothManager manager = mock(BluetoothManager.class);
            attached.p.manager = manager;
            when(manager.getDevicesMatchingConnectionStates(anyInt(), any(int[].class)))
                    .thenReturn(Collections.emptyList());
            PluginTestSupport.Result invalid = new PluginTestSupport.Result();
            attached.p.onMethodCall(
                    new MethodCall(
                            "manager.matchingDevices",
                            map("states", Arrays.asList(0, 4294967298L))),
                    invalid);
            invalid.await();
            assertEquals("invalid_argument", invalid.error);
            verify(manager, never()).getDevicesMatchingConnectionStates(anyInt(), any(int[].class));
            PluginTestSupport.Result valid = new PluginTestSupport.Result();
            attached.p.onMethodCall(
                    new MethodCall(
                            "manager.matchingDevices", map("states", Arrays.asList(0, 2, 3))),
                    valid);
            valid.await();
            assertNull(valid.error);
            assertEquals(Collections.emptyList(), valid.value);
            verify(manager).getDevicesMatchingConnectionStates(7, new int[] {0, 2, 3});
        }
    }
}
