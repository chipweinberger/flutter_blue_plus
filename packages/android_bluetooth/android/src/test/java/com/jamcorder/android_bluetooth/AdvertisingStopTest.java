package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.*;
import android.os.Looper;

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
public class AdvertisingStopTest {
    private static final class Fixture implements AutoCloseable {
        final PluginTestSupport.Attached attached = new PluginTestSupport.Attached();
        final BluetoothLeAdvertiser advertiser = mock(BluetoothLeAdvertiser.class);
        final PluginTestSupport.Sink sink = new PluginTestSupport.Sink();
        final AdvertisingBridge bridge = attached.p.advertisements;

        Fixture() {
            BluetoothManager manager = mock(BluetoothManager.class);
            BluetoothAdapter adapter = mock(BluetoothAdapter.class);
            when(manager.getAdapter()).thenReturn(adapter);
            when(adapter.getBluetoothLeAdvertiser()).thenReturn(advertiser);
            attached.p.manager = manager;
            attached.p.onListen(null, sink);
        }

        String start() {
            PluginTestSupport.Result result = new PluginTestSupport.Result();
            bridge.handle("startSet", map("parameters", map("legacy", true)), result);
            return (String) result.value;
        }

        Object stop(String id) {
            PluginTestSupport.Result result = new PluginTestSupport.Result();
            bridge.handle("stopSet", map("id", id), result);
            return result.value;
        }

        List<String> types() {
            Shadows.shadowOf(Looper.getMainLooper()).idle();
            List<String> types = new ArrayList<>();
            for (Object event : sink.values) types.add((String) object(event).get("type"));
            return types;
        }

        public void close() {
            attached.close();
        }
    }

    private static void lateCallbacks(AdvertisingSetCallback callback, AdvertisingSet set) {
        callback.onAdvertisingSetStarted(set, -7, 0);
        callback.onAdvertisingEnabled(set, true, 0);
        callback.onAdvertisingDataSet(set, 0);
        callback.onScanResponseDataSet(set, 0);
        callback.onAdvertisingParametersUpdated(set, -7, 0);
        callback.onPeriodicAdvertisingParametersUpdated(set, 0);
        callback.onPeriodicAdvertisingDataSet(set, 0);
        callback.onPeriodicAdvertisingEnabled(set, true, 0);
        callback.onAdvertisingSetStopped(set);
    }

    @Test
    public void pendingCancellationFinishesWithoutACallbackAndRejectsQueuedCallbacks() {
        try (Fixture f = new Fixture()) {
            String id = f.start();
            AdvertisingSetCallback callback = f.bridge.sets.callbacks.get(id);
            AdvertisingSet set = mock(AdvertisingSet.class);
            f.attached.p.main.post(() -> lateCallbacks(callback, set));
            assertEquals(false, f.stop(id));
            assertFalse(f.bridge.sets.callbacks.containsKey(id));
            assertFalse(f.bridge.sets.active.containsKey(id));
            assertTrue(f.types().isEmpty());
            assertEquals(false, f.stop(id));
            verify(f.advertiser, times(1)).stopAdvertisingSet(callback);
            assertThrows(
                    IllegalStateException.class,
                    () ->
                            f.bridge.handle(
                                    "enable",
                                    map("id", id, "enable", true),
                                    new PluginTestSupport.Result()));
        }
    }

    @Test
    public void startedStopKeepsTerminalCallbackAndRetiresLaterCallbacks() {
        try (Fixture f = new Fixture()) {
            String id = f.start();
            AdvertisingSetCallback callback = f.bridge.sets.callbacks.get(id);
            AdvertisingSet set = mock(AdvertisingSet.class);
            callback.onAdvertisingSetStarted(set, -7, 0);
            assertEquals(true, f.stop(id));
            assertSame(callback, f.bridge.sets.callbacks.get(id));
            assertSame(set, f.bridge.sets.active.get(id));
            callback.onAdvertisingEnabled(set, false, 0);
            callback.onAdvertisingSetStopped(set);
            lateCallbacks(callback, set);
            assertEquals(
                    Arrays.asList(
                            "onAdvertisingSetStarted",
                            "onAdvertisingEnabled",
                            "onAdvertisingSetStopped"),
                    f.types());
            assertEquals(false, object(f.sink.values.get(1)).get("enabled"));
            assertEquals(0, object(f.sink.values.get(1)).get("status"));
            assertFalse(f.bridge.sets.callbacks.containsKey(id));
            assertFalse(f.bridge.sets.active.containsKey(id));
            assertEquals(false, f.stop(id));
            verify(f.advertiser, times(1)).stopAdvertisingSet(callback);
        }
    }

    @Test
    public void failedStopsKeepPendingAndStartedRegistrationsForRetry() {
        for (boolean started : new boolean[] {false, true}) {
            try (Fixture f = new Fixture()) {
                String id = f.start();
                AdvertisingSetCallback callback = f.bridge.sets.callbacks.get(id);
                AdvertisingSet set = mock(AdvertisingSet.class);
                if (started) callback.onAdvertisingSetStarted(set, -7, 0);
                doThrow(new SecurityException("ADVERTISE denied"))
                        .doNothing()
                        .when(f.advertiser)
                        .stopAdvertisingSet(callback);
                assertThrows(SecurityException.class, () -> f.stop(id));
                assertSame(callback, f.bridge.sets.callbacks.get(id));
                assertEquals(started, f.bridge.sets.active.containsKey(id));
                assertEquals(started, f.stop(id));
                if (started) callback.onAdvertisingSetStopped(set);
                assertFalse(f.bridge.sets.callbacks.containsKey(id));
                assertFalse(f.bridge.sets.active.containsKey(id));
                verify(f.advertiser, times(2)).stopAdvertisingSet(callback);
            }
        }
    }

    @Test
    public void failedStartsStillDeliverTheirFailureBeforeRetirement() {
        try (Fixture f = new Fixture()) {
            String id = f.start();
            AdvertisingSetCallback callback = f.bridge.sets.callbacks.get(id);
            callback.onAdvertisingSetStarted(
                    null, 0, AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS);
            lateCallbacks(callback, mock(AdvertisingSet.class));
            assertEquals(Collections.singletonList("onAdvertisingSetStarted"), f.types());
            assertEquals(
                    AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS,
                    object(f.sink.values.get(0)).get("status"));
            assertEquals(false, f.stop(id));
            verify(f.advertiser, never()).stopAdvertisingSet(callback);
        }
    }

    @Test
    public void cancelingOnePendingSetPreservesAnotherStartedSet() {
        try (Fixture f = new Fixture()) {
            String pending = f.start(), started = f.start();
            AdvertisingSetCallback callback = f.bridge.sets.callbacks.get(started);
            AdvertisingSet set = mock(AdvertisingSet.class);
            callback.onAdvertisingSetStarted(set, -7, 0);
            assertEquals(false, f.stop(pending));
            callback.onAdvertisingDataSet(set, 0);
            assertSame(callback, f.bridge.sets.callbacks.get(started));
            assertSame(set, f.bridge.sets.active.get(started));
            assertEquals(true, f.stop(started));
            callback.onAdvertisingSetStopped(set);
            assertEquals(
                    Arrays.asList(
                            "onAdvertisingSetStarted",
                            "onAdvertisingDataSet",
                            "onAdvertisingSetStopped"),
                    f.types());
            assertTrue(f.bridge.sets.callbacks.isEmpty());
            assertTrue(f.bridge.sets.active.isEmpty());
        }
    }
}
