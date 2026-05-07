package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;
import static com.jamcorder.android_bluetooth.PluginTestSupport.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.content.Intent;
import android.os.Looper;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import org.robolectric.util.ReflectionHelpers;
import org.robolectric.util.ReflectionHelpers.ClassParameter;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class ScanRecordTest {
    private static final byte[] MALFORMED = {2, (byte) 0xff, 0};
    private static final byte[] HEALTHY = {
        2,
        1,
        6,
        4,
        (byte) 0xff,
        0x34,
        0x12,
        0x55,
        4,
        0x16,
        0x0f,
        0x18,
        0x66,
        5,
        9,
        'T',
        'e',
        's',
        't',
        0
    };

    private void idle() {
        Shadows.shadowOf(Looper.getMainLooper()).idle();
    }

    private ScanRecord parse(byte[] bytes) {
        // Android's parser is hidden from the public SDK but used by real scan results.
        return ReflectionHelpers.callStaticMethod(
                ScanRecord.class, "parseFromBytes", ClassParameter.from(byte[].class, bytes));
    }

    private ScanResult result(byte[] bytes, int rssi) {
        BluetoothDevice device = mock(BluetoothDevice.class);
        when(device.getAddress()).thenReturn(ADDRESS);
        return new ScanResult(device, parse(bytes), rssi, 123);
    }

    private void assertMalformed(Map<String, Object> record, byte[] expected) {
        assertArrayEquals(expected, (byte[]) record.get("bytes"));
        assertTrue(object(record.get("manufacturerSpecificData")).isEmpty());
        assertTrue(object(record.get("serviceData")).isEmpty());
        assertTrue(list(record.get("serviceUuids")).isEmpty());
        assertTrue(list(record.get("serviceSolicitationUuids")).isEmpty());
    }

    private void assertResults(List<Object> results) {
        assertEquals(2, results.size());
        Map<String, Object> malformed = object(results.get(0)), healthy = object(results.get(1));
        assertEquals(-40, malformed.get("rssi"));
        assertEquals(123L, malformed.get("timestampNanos"));
        assertMalformed(object(malformed.get("scanRecord")), MALFORMED);
        Map<String, Object> record = object(healthy.get("scanRecord"));
        assertArrayEquals(HEALTHY, (byte[]) record.get("bytes"));
        assertEquals("Test", record.get("deviceName"));
        assertEquals(6, record.get("advertiseFlags"));
        assertArrayEquals(
                new byte[] {0x55},
                (byte[]) object(record.get("manufacturerSpecificData")).get("4660"));
        assertArrayEquals(
                new byte[] {0x66},
                (byte[])
                        object(record.get("serviceData"))
                                .get("0000180f-0000-1000-8000-00805f9b34fb"));
    }

    @Before
    public void clearBackgroundEvents() {
        idle();
        BackgroundEvents.pending.clear();
    }

    @Test
    public void parserFallbackRecordsPreserveRawBytesWithEmptyMetadata() {
        for (byte[] bytes : new byte[][] {MALFORMED, {5, 9, 'A'}}) {
            ScanRecord record = parse(bytes);
            assertNotNull(record);
            assertNull(record.getManufacturerSpecificData());
            assertMalformed(ScanBridge.recordMap(record), bytes);
        }
    }

    @Test
    public void singleAndBatchCallbacksKeepMalformedRecordsAndContinueWithHealthyOnes() {
        for (boolean batch : new boolean[] {false, true}) {
            try (Attached attached = new Attached()) {
                Sink sink = new Sink();
                attached.p.onListen(null, sink);
                ScanBridge.Registration scan =
                        attached.p.scans
                        .new Registration("scan-record-test", mock(BluetoothLeScanner.class));
                attached.p.scans.sessions.put(scan.id, scan);
                ScanResult malformed = result(MALFORMED, -40), healthy = result(HEALTHY, -41);
                if (batch) scan.callback.onBatchScanResults(Arrays.asList(malformed, healthy));
                else {
                    scan.callback.onScanResult(1, malformed);
                    scan.callback.onScanResult(1, healthy);
                }
                idle();
                assertEquals(batch ? 1 : 2, sink.values.size());
                List<Object> results = new ArrayList<>();
                for (Object value : sink.values) {
                    Map<String, Object> event = object(value);
                    assertEquals(batch ? "onBatchScanResults" : "onScanResult", event.get("type"));
                    results.addAll(list(event.get("results")));
                }
                assertResults(results);
            }
        }
    }

    @Test
    public void backgroundReceiverDeliversMalformedRecordsWithoutReportingTransportErrors() {
        try (Attached attached = new Attached()) {
            Sink sink = new Sink();
            attached.p.onListen(null, sink);
            Intent intent =
                    new Intent()
                            .putExtra("scanId", 7)
                            .putParcelableArrayListExtra(
                                    BluetoothLeScanner.EXTRA_LIST_SCAN_RESULT,
                                    new ArrayList<>(
                                            Arrays.asList(
                                                    result(MALFORMED, -40), result(HEALTHY, -41))));
            new ScanReceiver().onReceive(RuntimeEnvironment.getApplication(), intent);
            idle();
            assertEquals(1, sink.values.size());
            Map<String, Object> event = object(sink.values.get(0));
            assertEquals("onScanResult", event.get("type"));
            assertEquals(7, event.get("scanId"));
            assertResults(list(event.get("results")));
        }
    }
}
