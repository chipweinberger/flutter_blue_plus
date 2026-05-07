package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.content.Context;
import android.os.CancellationSignal;
import android.os.Looper;
import android.ranging.*;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.robolectric.*;
import org.robolectric.annotation.Config;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 36, manifest = Config.NONE)
public class RangingLifecycleTest {
    static final class Fixture implements AutoCloseable {
        final PluginTestSupport.Attached attached = new PluginTestSupport.Attached();
        final RangingManager manager = mock(RangingManager.class);
        final RangingSession session = mock(RangingSession.class);
        final PluginTestSupport.Sink sink = new PluginTestSupport.Sink();
        final RangingBridge bridge;
        final RangingSession.Callback callback;
        final String id;

        Fixture() {
            Context context = mock(Context.class);
            when(context.getSystemService(RangingManager.class)).thenReturn(manager);
            attached.p.context = context;
            bridge = new RangingBridge(attached.p);
            attached.p.ranging = bridge;
            attached.p.context = RuntimeEnvironment.getApplication();
            attached.p.sink = sink;
            when(manager.createRangingSession(any(), any())).thenReturn(session);
            when(session.start(any())).thenReturn(new CancellationSignal());
            PluginTestSupport.Result result = call("create");
            id = (String) result.value;
            ArgumentCaptor<RangingSession.Callback> callbacks =
                    ArgumentCaptor.forClass(RangingSession.Callback.class);
            verify(manager).createRangingSession(any(), callbacks.capture());
            callback = callbacks.getValue();
        }

        PluginTestSupport.Result call(String method) {
            PluginTestSupport.Result result = new PluginTestSupport.Result();
            bridge.handle(method, map("id", id), result);
            return result;
        }

        void start() {
            bridge.handle(
                    "start",
                    map(
                            "id",
                            id,
                            "preference",
                            map(
                                    "deviceRole",
                                    1,
                                    "devices",
                                    Collections.singletonList(
                                            map(
                                                    "uuid",
                                                    "12345678-1234-5678-1234-567812345678",
                                                    "bleRssiRangingParams",
                                                    map(
                                                            "peerBluetoothAddress",
                                                            PluginTestSupport.ADDRESS))))),
                    new PluginTestSupport.Result());
        }

        void idle() {
            Shadows.shadowOf(Looper.getMainLooper()).idle();
        }

        public void close() {
            attached.close();
        }
    }

    @Test
    public void stoppedCallbackCarriesTechnologyInsteadOfAReason() {
        try (Fixture f = new Fixture()) {
            String uuid = "12345678-1234-5678-1234-567812345678";
            f.callback.onStopped(RangingBridge.device(uuid), RangingManager.BLE_RSSI);
            f.idle();
            Map<String, Object> event = object(f.sink.values.get(0));
            assertEquals("onStopped", event.get("type"));
            assertEquals(uuid, event.get("peerUuid"));
            assertEquals(RangingManager.BLE_RSSI, event.get("technology"));
            assertFalse(event.containsKey("reason"));
        }
    }

    @Test
    public void neverStartedCloseDoesNotWaitForANativeCallback() {
        try (Fixture f = new Fixture()) {
            assertEquals(false, f.call("close").value);
            assertEquals(false, f.call("close").value);
            f.idle();
            verify(f.session).close();
            assertTrue(f.sink.values.isEmpty());
            assertTrue(f.bridge.sessions.isEmpty());
        }
    }

    @Test
    public void failedInitialStartCanRetryAndThenCloseWithoutWaitingAfterAnotherFailure() {
        try (Fixture f = new Fixture()) {
            for (int i = 0; i < 2; i++) {
                f.start();
                assertTrue(f.bridge.starts.containsKey(f.id));
                f.callback.onOpenFailed(RangingSession.Callback.REASON_UNSUPPORTED);
                f.idle();
                assertFalse(f.bridge.starts.containsKey(f.id));
                assertTrue(f.bridge.sessions.containsKey(f.id));
            }
            verify(f.session, times(2)).start(any());
            assertEquals(false, f.call("close").value);
            assertEquals(2, f.sink.values.size());
        }
    }

    @Test
    public void pendingStartClosePreservesTheFinalOpenFailure() {
        try (Fixture f = new Fixture()) {
            f.start();
            assertEquals(true, f.call("close").value);
            f.callback.onOpenFailed(RangingSession.Callback.REASON_LOCAL_REQUEST);
            f.idle();
            Map<String, Object> event = object(f.sink.values.get(0));
            assertEquals("onOpenFailed", event.get("type"));
            assertEquals(RangingSession.Callback.REASON_LOCAL_REQUEST, event.get("reason"));
            assertEquals(true, event.get("isComplete"));
            assertTrue(f.bridge.sessions.isEmpty());
            assertTrue(f.bridge.starts.isEmpty());
            assertTrue(f.bridge.closing.isEmpty());
        }
    }

    @Test
    public void peerAdditionFailureDoesNotDiscardAnOpenSessionsStart() {
        try (Fixture f = new Fixture()) {
            f.start();
            f.callback.onOpened();
            f.callback.onOpenFailed(RangingSession.Callback.REASON_UNSUPPORTED);
            f.idle();
            assertTrue(f.bridge.starts.containsKey(f.id));
            assertEquals(true, f.call("close").value);
            f.callback.onOpenFailed(RangingSession.Callback.REASON_UNSUPPORTED);
            f.idle();
            assertEquals(false, object(f.sink.values.get(2)).get("isComplete"));
            assertTrue(f.bridge.closing.contains(f.id));
            f.callback.onClosed(RangingSession.Callback.REASON_LOCAL_REQUEST);
            f.idle();
            assertEquals("onClosed", object(f.sink.values.get(3)).get("type"));
            assertTrue(f.bridge.opened.isEmpty());
            assertTrue(f.bridge.closing.isEmpty());
        }
    }

    @Test
    public void openingAfterCloseWasRequestedStillDistinguishesAnOperationFailure() {
        try (Fixture f = new Fixture()) {
            f.start();
            assertEquals(true, f.call("close").value);
            f.callback.onOpened();
            f.callback.onOpenFailed(RangingSession.Callback.REASON_UNSUPPORTED);
            f.idle();
            assertEquals(false, object(f.sink.values.get(1)).get("isComplete"));
            assertTrue(f.bridge.closing.contains(f.id));
            f.callback.onClosed(RangingSession.Callback.REASON_LOCAL_REQUEST);
            f.idle();
            assertTrue(f.bridge.opened.isEmpty());
            assertTrue(f.bridge.closing.isEmpty());
        }
    }

    @Test
    public void failedNativeCloseKeepsTheStartForCleanupRetry() {
        try (Fixture f = new Fixture()) {
            f.start();
            doThrow(new SecurityException("RANGING revoked")).doNothing().when(f.session).close();
            assertThrows(SecurityException.class, () -> f.call("close"));
            assertTrue(f.bridge.sessions.containsKey(f.id));
            assertTrue(f.bridge.starts.containsKey(f.id));
            assertEquals(true, f.call("close").value);
        }
    }
}
