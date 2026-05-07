package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;
import static com.jamcorder.android_bluetooth.PluginTestSupport.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.*;
import android.bluetooth.le.*;
import android.os.Looper;
import android.util.SparseArray;

import io.flutter.plugin.common.MethodCall;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class ScanDeliveryTest {
    private BluetoothDevice device(String address) {
        BluetoothDevice device = mock(BluetoothDevice.class);
        when(device.getAddress()).thenReturn(address);
        return device;
    }

    private ScanResult result(BluetoothDevice device, byte[] bytes, String name, int rssi) {
        ScanRecord record = mock(ScanRecord.class);
        when(record.getBytes()).thenReturn(bytes);
        when(record.getDeviceName()).thenReturn(name);
        when(record.getManufacturerSpecificData()).thenReturn(new SparseArray<>());
        when(record.getServiceData()).thenReturn(Collections.emptyMap());
        ScanResult result = mock(ScanResult.class);
        when(result.getDevice()).thenReturn(device);
        when(result.getScanRecord()).thenReturn(record);
        when(result.getRssi()).thenReturn(rssi);
        return result;
    }

    private ScanBridge.Registration start(AndroidBluetoothPlugin p, Map<String, Object> options)
            throws Exception {
        BluetoothManager manager = mock(BluetoothManager.class);
        BluetoothAdapter adapter = mock(BluetoothAdapter.class);
        when(manager.getAdapter()).thenReturn(adapter);
        when(adapter.getBluetoothLeScanner()).thenReturn(mock(BluetoothLeScanner.class));
        p.manager = manager;
        Result reply = new Result();
        p.scans.handle("startSession", map("deliveryOptions", options), reply);
        assertNull(reply.error);
        return p.scans.sessions.get(reply.value);
    }

    private List<Integer> delivered(Sink sink) {
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        List<Integer> result = new ArrayList<>();
        for (Object event : sink.values)
            for (Object entry : list(object(event).get("results")))
                result.add((Integer) object(entry).get("rssi"));
        return result;
    }

    @Test
    public void divisorDropsBeforeSerializationAndResetsWithEachRegistration() throws Exception {
        try (Attached attached = new Attached()) {
            AndroidBluetoothPlugin p = attached.p;
            Sink sink = new Sink();
            p.onListen(null, sink);
            ScanBridge.Registration scan = start(p, map("advertisementDivisor", 10));
            BluetoothDevice device = device(ADDRESS);
            ScanResult result = result(device, new byte[] {1}, "Heart", 1);
            for (int i = 0; i < 1000; i++) scan.callback.onScanResult(1, result);
            assertEquals(100, delivered(sink).size());
            verify(device, times(100)).getName();
            assertEquals(100, sink.values.size());
            p.scans.handle("stopSession", map("id", scan.id), new Result());
            scan = start(p, map("advertisementDivisor", 10));
            scan.callback.onScanResult(1, result);
            assertEquals(101, delivered(sink).size());
            p.scans.handle(
                    "setDeliveryOptions",
                    map("id", scan.id, "deliveryOptions", map()),
                    new Result());
            for (int i = 0; i < 3; i++) scan.callback.onScanResult(1, result);
            assertEquals(104, delivered(sink).size());
        }
    }

    @Test
    public void allAdvertisementsAdvanceIndependentPerDeviceCounters() throws Exception {
        try (Attached attached = new Attached()) {
            Sink sink = new Sink();
            attached.p.onListen(null, sink);
            ScanBridge.Registration scan = start(attached.p, map("advertisementDivisor", 3));
            BluetoothDevice a = device(ADDRESS), b = device("11:22:33:44:55:66");
            scan.callback.onScanResult(1, result(a, new byte[] {1}, "heart", 0));
            scan.callback.onScanResult(1, result(a, new byte[] {2}, "Heart", 1));
            scan.callback.onScanResult(1, result(a, new byte[] {3}, null, 2));
            scan.callback.onScanResult(1, result(b, new byte[] {2}, "Heart", 3));
            scan.callback.onScanResult(1, result(a, new byte[] {2}, "Heart", 4));
            scan.callback.onScanResult(1, result(a, new byte[] {2}, "Heart", 5));
            scan.callback.onScanResult(1, result(a, new byte[] {2}, "Heart", 6));
            assertEquals(Arrays.asList(0, 3, 4), delivered(sink));
            verify(a, times(2)).getName();
            verify(b, times(1)).getName();
            ScanBridge.Registration other = start(attached.p, map("advertisementDivisor", 3));
            other.callback.onScanResult(1, result(a, new byte[] {2}, "Heart", 7));
            assertEquals(Arrays.asList(0, 3, 4, 7), delivered(sink));
        }
    }

    @Test
    public void duplicatePayloadsIgnoreRssiAndRememberTheLastPayload() throws Exception {
        try (Attached attached = new Attached()) {
            Sink sink = new Sink();
            attached.p.onListen(null, sink);
            ScanBridge.Registration scan = start(attached.p, map("suppressDuplicates", true));
            BluetoothDevice a = device(ADDRESS);
            scan.callback.onScanResult(1, result(a, new byte[] {1}, "Heart", 1));
            scan.callback.onScanResult(1, result(a, new byte[] {1}, "Heart", 2));
            scan.callback.onScanResult(1, result(a, new byte[] {2}, "Heart", 3));
            scan.callback.onScanResult(1, result(a, new byte[] {1}, "Heart", 4));
            scan.callback.onScanResult(1, result(a, new byte[] {3}, "other", 5));
            assertEquals(Arrays.asList(1, 3, 4, 5), delivered(sink));
            assertArrayEquals(new byte[] {3}, scan.delivery.advertisements.get(ADDRESS));
            verify(a, times(4)).getName();
        }
    }

    @Test
    public void batchesCanBeExcludedWithoutAdvancingTheCounter() throws Exception {
        try (Attached attached = new Attached()) {
            Sink sink = new Sink();
            attached.p.onListen(null, sink);
            ScanBridge.Registration scan =
                    start(attached.p, map("advertisementDivisor", 2, "includeBatchResults", false));
            ScanResult result = result(device(ADDRESS), new byte[] {1}, "Heart", 1);
            scan.callback.onBatchScanResults(Arrays.asList(result, result, result));
            assertTrue(delivered(sink).isEmpty());
            scan.callback.onScanResult(1, result);
            assertEquals(Arrays.asList(1), delivered(sink));
            scan = start(attached.p, map("advertisementDivisor", 2));
            scan.callback.onBatchScanResults(Arrays.asList(result, result, result));
            assertEquals(Arrays.asList(1, 1, 1), delivered(sink));
            assertEquals(
                    2, sink.values.size()); // One single-result frame, one filtered batch frame.
        }
    }

    @Test
    public void defaultsPreserveCallbacksAndInvalidOptionsLeaveHistoryUntouched() throws Exception {
        try (Attached attached = new Attached()) {
            Sink sink = new Sink();
            attached.p.onListen(null, sink);
            ScanBridge.Registration scan = start(attached.p, map());
            ScanResult result = result(device(ADDRESS), new byte[] {1}, "Heart", 1);
            for (int i = 0; i < 3; i++) scan.callback.onScanResult(1, result);
            assertEquals(3, delivered(sink).size());
            attached.p.scans.handle(
                    "setDeliveryOptions",
                    map("id", scan.id, "deliveryOptions", map("advertisementDivisor", 3)),
                    new Result());
            scan.callback.onScanResult(1, result);
            for (double divisor :
                    new double[] {0, -1, 1.5, Double.NaN, Double.POSITIVE_INFINITY, 2147483648d}) {
                Result reply = new Result();
                attached.p.onMethodCall(
                        new MethodCall(
                                "scan.setDeliveryOptions",
                                map(
                                        "id",
                                        scan.id,
                                        "deliveryOptions",
                                        map("advertisementDivisor", divisor))),
                        reply);
                reply.await();
                assertEquals("invalid_argument", reply.error);
            }
            scan.callback.onScanResult(1, result);
            assertEquals(4, delivered(sink).size());
        }
    }
}
