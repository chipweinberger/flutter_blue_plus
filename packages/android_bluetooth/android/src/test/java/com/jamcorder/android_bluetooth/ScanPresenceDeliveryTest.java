package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.*;
import android.os.Looper;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import org.robolectric.util.ReflectionHelpers;
import org.robolectric.util.ReflectionHelpers.ClassParameter;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class ScanPresenceDeliveryTest {
    private static final class Fixture implements AutoCloseable {
        final PluginTestSupport.Attached attached = new PluginTestSupport.Attached();
        final PluginTestSupport.Sink sink = new PluginTestSupport.Sink();
        final BluetoothLeScanner scanner = mock(BluetoothLeScanner.class);
        final BluetoothDevice device = mock(BluetoothDevice.class);
        final ScanRecord record =
                ReflectionHelpers.callStaticMethod(
                        ScanRecord.class,
                        "parseFromBytes",
                        ClassParameter.from(byte[].class, new byte[] {3, 3, 15, 24, 0}));
        final ScanBridge.Registration scan;
        final String stopMethod;

        Fixture(boolean independent, Map<String, Object> options) throws Exception {
            BluetoothManager manager = mock(BluetoothManager.class);
            BluetoothAdapter adapter = mock(BluetoothAdapter.class);
            when(manager.getAdapter()).thenReturn(adapter);
            when(adapter.getBluetoothLeScanner()).thenReturn(scanner);
            attached.p.manager = manager;
            when(device.getAddress()).thenReturn(PluginTestSupport.ADDRESS);
            attached.p.onListen(null, sink);
            PluginTestSupport.Result reply = new PluginTestSupport.Result();
            attached.p.scans.handle(
                    independent ? "startSession" : "start",
                    map(
                            "deliveryOptions",
                            options,
                            "settings",
                            map(
                                    "callbackType",
                                    ScanSettings.CALLBACK_TYPE_FIRST_MATCH
                                            | ScanSettings.CALLBACK_TYPE_MATCH_LOST),
                            "filters",
                            Collections.singletonList(
                                    map("serviceUuid", "0000180f-0000-1000-8000-00805f9b34fb"))),
                    reply);
            scan = attached.p.scans.sessions.get(independent ? reply.value : "scanner");
            stopMethod = independent ? "stopSession" : "stop";
            assertNotNull(scan);
        }

        void transition(int type, int sequence) {
            scan.callback.onScanResult(
                    type, new ScanResult(device, record, -40 - sequence, sequence));
        }

        void roundTrip(int sequence) {
            transition(ScanSettings.CALLBACK_TYPE_FIRST_MATCH, sequence);
            transition(ScanSettings.CALLBACK_TYPE_MATCH_LOST, sequence + 1);
        }

        void assertTransitions(Integer... expected) {
            Shadows.shadowOf(Looper.getMainLooper()).idle();
            List<Integer> types = new ArrayList<>();
            List<Integer> rssi = new ArrayList<>();
            for (Object value : sink.values) {
                Map<String, Object> event = object(value);
                assertEquals(scan.id, event.get("owner"));
                assertEquals("onScanResult", event.get("type"));
                types.add((Integer) event.get("callbackType"));
                Map<String, Object> result = object(list(event.get("results")).get(0));
                assertEquals(
                        PluginTestSupport.ADDRESS, object(result.get("device")).get("address"));
                rssi.add((Integer) result.get("rssi"));
            }
            assertEquals(Arrays.asList(expected), types);
            for (int i = 0; i < expected.length; i++)
                assertEquals(Integer.valueOf(-40 - i), rssi.get(i));
        }

        public void close() {
            attached.close();
        }
    }

    @Test
    public void arrivalDisappearanceAndReappearanceBypassEveryDeliveryPolicy() throws Exception {
        for (boolean independent : new boolean[] {false, true}) {
            for (Map<String, Object> options :
                    Arrays.asList(
                            map(),
                            map("suppressDuplicates", true),
                            map("advertisementDivisor", 2),
                            map(
                                    "advertisementDivisor",
                                    3,
                                    "suppressDuplicates",
                                    true,
                                    "includeBatchResults",
                                    false))) {
                try (Fixture f = new Fixture(independent, options)) {
                    f.roundTrip(0);
                    f.roundTrip(2);
                    f.assertTransitions(2, 4, 2, 4);
                }
            }
        }
    }

    @Test
    public void deliveryPolicyUpdatesKeepEveryLaterPresenceTransition() throws Exception {
        try (Fixture f = new Fixture(true, map("suppressDuplicates", true))) {
            f.roundTrip(0);
            f.attached.p.scans.handle(
                    "setDeliveryOptions",
                    map(
                            "id",
                            f.scan.id,
                            "deliveryOptions",
                            map("advertisementDivisor", 2, "suppressDuplicates", true)),
                    new PluginTestSupport.Result());
            f.roundTrip(2);
            f.assertTransitions(2, 4, 2, 4);
            verify(f.scanner, times(1))
                    .startScan(anyList(), any(ScanSettings.class), same(f.scan.callback));
        }
    }

    @Test
    public void stoppedAndRestartedRegistrationsStillRejectLatePresenceCallbacks()
            throws Exception {
        for (boolean independent : new boolean[] {false, true}) {
            for (boolean restart : new boolean[] {false, true}) {
                try (Fixture f = new Fixture(independent, map("advertisementDivisor", 2))) {
                    if (restart) {
                        f.attached.p.resetSession();
                        f.attached.p.onListen(null, f.sink);
                    } else {
                        f.attached.p.scans.handle(
                                f.stopMethod, map("id", f.scan.id), new PluginTestSupport.Result());
                    }
                    f.roundTrip(0);
                    f.assertTransitions();
                }
            }
        }
    }
}
