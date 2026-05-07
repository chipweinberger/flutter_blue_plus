package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.app.Activity;
import android.companion.*;
import android.content.*;
import android.os.*;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.robolectric.*;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class CompanionLifecycleTest {
    static final class Request {
        final String id;
        final CompanionDeviceManager.Callback callback;

        Request(String id, CompanionDeviceManager.Callback callback) {
            this.id = id;
            this.callback = callback;
        }
    }

    static final class Fixture implements AutoCloseable {
        final AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        final CompanionDeviceManager manager = mock(CompanionDeviceManager.class);
        final Activity activity = mock(Activity.class);
        final CompanionBridge bridge = new CompanionBridge(p);
        final PluginTestSupport.Sink sink = new PluginTestSupport.Sink();
        final ArgumentCaptor<CompanionDeviceManager.Callback> callbacks =
                ArgumentCaptor.forClass(CompanionDeviceManager.Callback.class);
        int requests;

        Fixture() {
            p.context = mock(Context.class);
            when(p.context.getSystemService(Context.COMPANION_DEVICE_SERVICE)).thenReturn(manager);
            p.activity = activity;
            p.companions = bridge;
            p.sink = sink;
        }

        Request request() throws Exception {
            PluginTestSupport.Result result = new PluginTestSupport.Result();
            bridge.handle("associate", map(), result);
            verify(manager, times(++requests))
                    .associate(
                            any(AssociationRequest.class), callbacks.capture(), any(Handler.class));
            return new Request((String) result.value, callbacks.getValue());
        }

        public void close() {
            bridge.reset();
            p.io.shutdownNow();
        }
    }

    static AssociationInfo info() {
        AssociationInfo info = mock(AssociationInfo.class);
        when(info.getId()).thenReturn(42);
        return info;
    }

    static void idle() {
        Shadows.shadowOf(Looper.getMainLooper()).idle();
    }

    @Test
    public void automaticApprovalReleasesRequestAndLateSuccessCannotClearANewerRequest()
            throws Exception {
        try (Fixture f = new Fixture()) {
            Request first = f.request();
            first.callback.onAssociationCreated(info());
            idle();
            assertNull(f.bridge.pending);
            assertEquals(first.id, object(f.sink.values.get(0)).get("owner"));
            assertEquals("onAssociationCreated", object(f.sink.values.get(0)).get("type"));
            assertEquals(true, object(f.sink.values.get(0)).get("isComplete"));
            Request second = f.request();
            first.callback.onAssociationCreated(info());
            idle();
            assertEquals(second.id, f.bridge.pending.id);
            assertEquals(1, f.sink.values.size());
        }
    }

    @Test
    public void chooserSuccessKeepsTheRequestIdUntilItsActivityResult() throws Exception {
        try (Fixture f = new Fixture()) {
            Request request = f.request();
            IntentSender sender = mock(IntentSender.class);
            request.callback.onAssociationPending(sender);
            idle();
            int code = f.bridge.pending.requestCode;
            verify(f.activity).startIntentSenderForResult(sender, code, null, 0, 0, 0);
            request.callback.onAssociationCreated(info());
            idle();
            assertEquals(request.id, f.bridge.pending.id);
            assertTrue(f.bridge.pending.chooserLaunched);
            assertTrue(f.bridge.onActivityResult(code, Activity.RESULT_OK, new Intent()));
            idle();
            assertNull(f.bridge.pending);
            assertEquals("onAssociationResult", object(f.sink.values.get(2)).get("type"));
            assertEquals(request.id, object(f.sink.values.get(2)).get("owner"));
            assertEquals(false, object(f.sink.values.get(1)).get("isComplete"));
            assertEquals(true, object(f.sink.values.get(2)).get("isComplete"));
        }
    }

    @Test
    public void successQueuedBeforeRestartCannotChangeOrNotifyTheNewRequest() throws Exception {
        try (Fixture f = new Fixture()) {
            Request first = f.request();
            first.callback.onAssociationCreated(info());
            f.p.generation++;
            f.bridge.reset();
            Request second = f.request();
            idle();
            assertEquals(second.id, f.bridge.pending.id);
            assertTrue(f.sink.values.isEmpty());
        }
    }

    @Test
    public void chooserSuccessPreservesBothCallbacksInEitherOrderBeforeCompleting()
            throws Exception {
        for (boolean createdFirst : new boolean[] {false, true}) {
            try (Fixture f = new Fixture()) {
                Request request = f.request();
                request.callback.onAssociationPending(mock(IntentSender.class));
                idle();
                int code = f.bridge.pending.requestCode;
                if (createdFirst) {
                    request.callback.onAssociationCreated(info());
                    idle();
                }
                assertTrue(f.p.onActivityResult(code, Activity.RESULT_OK, new Intent()));
                idle();
                if (!createdFirst) {
                    assertEquals(request.id, f.bridge.pending.id);
                    assertThrows(IllegalStateException.class, () -> f.request());
                    request.callback.onAssociationCreated(info());
                    idle();
                }
                assertNull(f.bridge.pending);
                assertEquals(3, f.sink.values.size());
                assertEquals(
                        createdFirst ? "onAssociationCreated" : "onAssociationResult",
                        object(f.sink.values.get(1)).get("type"));
                assertEquals(false, object(f.sink.values.get(1)).get("isComplete"));
                assertEquals(
                        createdFirst ? "onAssociationResult" : "onAssociationCreated",
                        object(f.sink.values.get(2)).get("type"));
                assertEquals(true, object(f.sink.values.get(2)).get("isComplete"));
                f.request();
            }
        }
    }

    @Test
    @Config(sdk = 31)
    public void legacyChooserSuccessCompletesWithoutANewerCreationCallback() throws Exception {
        try (Fixture f = new Fixture()) {
            Request request = f.request();
            request.callback.onDeviceFound(mock(IntentSender.class));
            idle();
            int code = f.bridge.pending.requestCode;
            assertTrue(f.p.onActivityResult(code, Activity.RESULT_OK, new Intent()));
            idle();
            assertNull(f.bridge.pending);
            assertEquals("onAssociationResult", object(f.sink.values.get(1)).get("type"));
            assertEquals(true, object(f.sink.values.get(1)).get("isComplete"));
        }
    }

    @Test
    public void anOldChooserResultAndCallbackCannotCompleteTheNewRequestAfterRestart()
            throws Exception {
        try (Fixture f = new Fixture()) {
            Request old = f.request();
            old.callback.onAssociationPending(mock(IntentSender.class));
            idle();
            int oldCode = f.bridge.pending.requestCode;
            f.p.resetSession();
            f.p.sink = f.sink;
            f.sink.values.clear();
            Request fresh = f.request();
            fresh.callback.onAssociationPending(mock(IntentSender.class));
            idle();
            int freshCode = f.bridge.pending.requestCode;
            assertNotEquals(oldCode, freshCode);
            assertTrue(f.p.onActivityResult(oldCode, Activity.RESULT_CANCELED, null));
            old.callback.onAssociationCreated(info());
            idle();
            assertEquals(fresh.id, f.bridge.pending.id);
            assertEquals(1, f.sink.values.size());
            assertTrue(f.p.onActivityResult(freshCode, Activity.RESULT_OK, new Intent()));
            fresh.callback.onAssociationCreated(info());
            idle();
            assertNull(f.bridge.pending);
            assertEquals(fresh.id, object(f.sink.values.get(2)).get("owner"));
            assertEquals(true, object(f.sink.values.get(2)).get("isComplete"));
        }
    }

    @Test
    public void failureRetiresTheChooserCodeBeforeAnotherRequestCanUseIt() throws Exception {
        try (Fixture f = new Fixture()) {
            Request old = f.request();
            old.callback.onAssociationPending(mock(IntentSender.class));
            idle();
            int oldCode = f.bridge.pending.requestCode;
            old.callback.onFailure("cancelled");
            idle();
            assertNull(f.bridge.pending);
            assertEquals(true, object(f.sink.values.get(1)).get("isComplete"));
            Request fresh = f.request();
            assertTrue(f.p.onActivityResult(oldCode, Activity.RESULT_CANCELED, null));
            idle();
            assertEquals(fresh.id, f.bridge.pending.id);
            assertEquals(2, f.sink.values.size());
        }
    }

    @Test
    public void completedChooserStillDeliversCreationAfterTheActivityDetaches() throws Exception {
        try (Fixture f = new Fixture()) {
            Request request = f.request();
            request.callback.onAssociationPending(mock(IntentSender.class));
            idle();
            int code = f.bridge.pending.requestCode;
            assertTrue(f.p.onActivityResult(code, Activity.RESULT_OK, new Intent()));
            f.p.onDetachedFromActivity();
            idle();
            assertEquals(request.id, f.bridge.pending.id);
            request.callback.onAssociationCreated(info());
            idle();
            assertNull(f.bridge.pending);
            assertEquals(3, f.sink.values.size());
            assertEquals("onAssociationCreated", object(f.sink.values.get(2)).get("type"));
            assertEquals(true, object(f.sink.values.get(2)).get("isComplete"));
        }
    }
}
