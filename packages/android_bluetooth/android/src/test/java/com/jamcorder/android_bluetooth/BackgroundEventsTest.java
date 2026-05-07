package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.AndroidBluetoothPlugin.ACTIVE;
import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.le.BluetoothLeScanner;
import android.content.*;
import android.os.*;
import android.util.Log;

import io.flutter.plugin.common.EventChannel;

import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.*;
import org.robolectric.annotation.Config;
import org.robolectric.shadows.ShadowLog;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class BackgroundEventsTest {
    static class Sink implements EventChannel.EventSink {
        final List<Object> values = new ArrayList<>();
        final List<Map<String, Object>> errors = new ArrayList<>();

        public void success(Object value) {
            values.add(value);
        }

        public void error(String code, String message, Object details) {
            errors.add(map("code", code, "message", message, "details", details));
        }

        public void endOfStream() {}
    }

    static void idle() {
        Shadows.shadowOf(Looper.getMainLooper()).idle();
    }

    static Intent malformedPayload() {
        Intent intent = mock(Intent.class);
        when(intent.getIntExtra(BluetoothLeScanner.EXTRA_ERROR_CODE, 0))
                .thenThrow(new BadParcelableException("malformed scan"));
        return intent;
    }

    @Before
    public void reset() {
        idle();
        BackgroundEvents.pending.clear();
        ShadowLog.clear();
    }

    @After
    public void flushMainQueue() {
        idle();
    }

    @Test
    public void buffersEveryEventInOrderUntilAnEngineListensAndThenConsumesOnce() {
        assertTrue(ACTIVE.isEmpty());
        for (int i = 0; i < 400; i++)
            BackgroundEvents.publish(
                    "scanner",
                    "onScanResult",
                    map("sequence", i, "bytes", new byte[] {(byte) 255, (byte) 128}));
        idle();
        assertEquals(400, BackgroundEvents.pending.size());
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            Sink sink = new Sink();
            a.p.onListen(null, sink);
            assertEquals(400, sink.values.size());
            assertTrue(BackgroundEvents.pending.isEmpty());
            for (int i = 0; i < 400; i++) {
                Map<String, Object> event = object(sink.values.get(i));
                assertEquals(i, event.get("sequence"));
                assertArrayEquals(new byte[] {(byte) 255, (byte) 128}, (byte[]) event.get("bytes"));
                assertNotNull(event.get("receivedAtMillis"));
            }
            a.p.onCancel(null);
            Sink next = new Sink();
            a.p.onListen(null, next);
            assertTrue(next.values.isEmpty());
        }
    }

    @Test
    public void detachingBeforeQueuedDispatchLeavesTheEventForTheNextEngine() {
        Sink old = new Sink();
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            a.p.onListen(null, old);
            BackgroundEvents.publish(
                    "companion", "onDeviceAppeared", map("address", PluginTestSupport.ADDRESS));
        }
        idle();
        assertEquals(1, old.values.size());
        assertEquals("onDetachedFromEngine", object(old.values.get(0)).get("type"));
        assertEquals(1, BackgroundEvents.pending.size());
        try (PluginTestSupport.Attached b = new PluginTestSupport.Attached()) {
            Sink fresh = new Sink();
            b.p.onListen(null, fresh);
            assertEquals(1, fresh.values.size());
            assertEquals("onDeviceAppeared", object(fresh.values.get(0)).get("type"));
            assertTrue(BackgroundEvents.pending.isEmpty());
        }
    }

    @Test
    public void hotRestartKeepsProcessLocalBackgroundEvents() {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            Sink old = new Sink(), fresh = new Sink();
            a.p.onListen(null, old);
            BackgroundEvents.publish("companion", "onDeviceDisappeared", map());
            a.p.resetSession();
            idle();
            assertTrue(old.values.isEmpty());
            assertEquals(1, BackgroundEvents.pending.size());
            a.p.onListen(null, fresh);
            assertEquals(1, fresh.values.size());
            assertTrue(BackgroundEvents.pending.isEmpty());
        }
    }

    @Test
    public void liveEventsReachEveryCurrentlyListeningEngine() {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached();
                PluginTestSupport.Attached b = new PluginTestSupport.Attached()) {
            Sink one = new Sink(), two = new Sink();
            a.p.onListen(null, one);
            b.p.onListen(null, two);
            BackgroundEvents.publish("companion", "onDeviceAppeared", map());
            idle();
            assertEquals(1, one.values.size());
            assertEquals(1, two.values.size());
            assertTrue(BackgroundEvents.pending.isEmpty());
        }
    }

    @Test
    public void cancelingDuringAFlushKeepsTheUndeliveredRemainder() {
        for (int i = 0; i < 3; i++)
            BackgroundEvents.publish("companion", "onDeviceAppeared", map("sequence", i));
        idle();
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            Sink first =
                    new Sink() {
                        @Override
                        public void success(Object value) {
                            super.success(value);
                            a.p.onCancel(null);
                        }
                    };
            a.p.onListen(null, first);
            assertEquals(1, first.values.size());
            assertEquals(2, BackgroundEvents.pending.size());
            Sink second = new Sink();
            a.p.onListen(null, second);
            assertEquals(2, second.values.size());
            assertEquals(1, object(second.values.get(0)).get("sequence"));
            assertEquals(2, object(second.values.get(1)).get("sequence"));
            assertTrue(BackgroundEvents.pending.isEmpty());
        }
    }

    @Test
    public void receiversAndCompanionPresenceBufferWithoutAnEngine() {
        Context app = RuntimeEnvironment.getApplication();
        new ScanReceiver().onReceive(app, new Intent().putExtra("scanId", 7));
        BluetoothCompanionService service =
                Robolectric.buildService(BluetoothCompanionService.class).create().get();
        service.onDeviceAppeared(PluginTestSupport.ADDRESS);
        service.onDeviceDisappeared(PluginTestSupport.ADDRESS);
        idle();
        assertEquals(3, BackgroundEvents.pending.size());
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            Sink sink = new Sink();
            a.p.onListen(null, sink);
            assertEquals(3, sink.values.size());
            assertEquals(7, object(sink.values.get(0)).get("scanId"));
            assertEquals("onDeviceAppeared", object(sink.values.get(1)).get("type"));
            assertEquals("onDeviceDisappeared", object(sink.values.get(2)).get("type"));
        }
    }

    @Test
    public void malformedScanPayloadIsLoggedReportedAndDoesNotPreventLaterEvents() {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            Sink sink = new Sink();
            a.p.onListen(null, sink);
            new ScanReceiver().onReceive(a.p.context, malformedPayload());
            idle();
            assertEquals(1, sink.errors.size());
            Map<String, Object> error = sink.errors.get(0);
            assertEquals("background_error", error.get("code"));
            Map<String, Object> details = object(error.get("details"));
            assertEquals("scanner", details.get("owner"));
            assertEquals("receive", details.get("operation"));
            assertEquals(BadParcelableException.class.getName(), details.get("exception"));
            List<ShadowLog.LogItem> logs = ShadowLog.getLogsForTag("AndroidBluetooth");
            assertEquals(1, logs.size());
            assertEquals(Log.ERROR, logs.get(0).type);
            new ScanReceiver().onReceive(a.p.context, new Intent().putExtra("scanId", 8));
            idle();
            assertEquals(1, sink.values.size());
            assertEquals(8, object(sink.values.get(0)).get("scanId"));
        }
    }

    @Test
    public void malformedPayloadIsLoggedWithoutAnEngineAndQueuedErrorsStayWithTheirSession() {
        new ScanReceiver().onReceive(RuntimeEnvironment.getApplication(), malformedPayload());
        assertEquals(1, ShadowLog.getLogsForTag("AndroidBluetooth").size());
        assertTrue(BackgroundEvents.pending.isEmpty());
        for (int mode = 0; mode < 3; mode++) {
            try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
                Sink old = new Sink(), fresh = new Sink();
                a.p.onListen(null, old);
                new ScanReceiver().onReceive(a.p.context, malformedPayload());
                if (mode == 1) a.p.resetSession();
                if (mode == 2) a.close();
                a.p.sink = fresh;
                idle();
                assertTrue(old.errors.isEmpty());
                assertTrue(fresh.errors.isEmpty());
            }
        }
    }
}
