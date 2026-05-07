package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.AndroidBluetoothPlugin.REQUEST_OWNERS;
import static com.jamcorder.android_bluetooth.AndroidBluetoothPlugin.nextRequestCode;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.app.Activity;
import android.os.Looper;

import io.flutter.plugin.common.*;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.*;
import org.robolectric.annotation.Config;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class RequestLifecycleTest {
    static final class Reply implements MethodChannel.Result {
        final List<Object> values = new ArrayList<>();
        final List<String> errors = new ArrayList<>();

        public void success(Object value) {
            values.add(value);
        }

        public void error(String code, String message, Object details) {
            errors.add(code);
        }

        public void notImplemented() {
            errors.add("not_implemented");
        }

        void assertPending() {
            assertTrue(values.isEmpty());
            assertTrue(errors.isEmpty());
        }
    }

    static void idle() {
        Shadows.shadowOf(Looper.getMainLooper()).idle();
    }

    static Reply enable(AndroidBluetoothPlugin p) {
        p.activity = mock(Activity.class);
        Reply result = new Reply();
        p.onMethodCall(new MethodCall("adapter.requestEnable", map()), result);
        return result;
    }

    static Reply permissions(AndroidBluetoothPlugin p, String name) {
        p.activity = mock(Activity.class);
        Reply result = new Reply();
        p.onMethodCall(
                new MethodCall("permissions.request", map("permissions", Arrays.asList(name))),
                result);
        return result;
    }

    @Test
    public void engineDetachCompletesPendingEnableAndPermissionsWithAnError() {
        for (boolean permission : new boolean[] {false, true}) {
            try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
                Reply result =
                        permission
                                ? permissions(a.p, "android.permission.BLUETOOTH_SCAN")
                                : enable(a.p);
                result.assertPending();
                a.p.onDetachedFromEngine(a.binding);
                idle();
                assertEquals(Collections.singletonList("engine_detached"), result.errors);
                assertTrue(result.values.isEmpty());
                assertTrue(a.p.pendingResults.isEmpty());
            }
        }
    }

    @Test
    public void callsDeliveredAfterDetachCannotCreateNewNativeResources() {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            a.p.onDetachedFromEngine(a.binding);
            android.bluetooth.BluetoothDevice device =
                    mock(android.bluetooth.BluetoothDevice.class);
            when(device.getAddress()).thenReturn(PluginTestSupport.ADDRESS);
            a.p.knownDevices.put(device.getAddress(), device);
            Reply result = new Reply();
            a.p.onMethodCall(
                    new MethodCall("device.createBond", map("address", device.getAddress())),
                    result);
            idle();
            verify(device, never()).createBond();
            assertEquals(Collections.singletonList("engine_detached"), result.errors);
            assertTrue(a.p.pendingResults.isEmpty());
        }
    }

    @Test
    public void queuedAndLateWorkerRepliesCannotDoubleCompleteAfterReset() throws Exception {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            Reply queued = new Reply(), worker = new Reply();
            MethodChannel.Result queuedResult = a.p.onMain(queued),
                    workerResult = a.p.onMain(worker);
            queuedResult.success("queued");
            a.p.resetSession();
            Thread late =
                    new Thread(
                            () -> {
                                workerResult.success("late");
                                workerResult.error("late_error", "late", null);
                            });
            late.start();
            late.join();
            idle();
            for (Reply result : Arrays.asList(queued, worker)) {
                assertEquals(Collections.singletonList("engine_restarted"), result.errors);
                assertTrue(result.values.isEmpty());
            }
            Reply fresh = new Reply();
            a.p.onMain(fresh).success("fresh");
            idle();
            assertEquals(Collections.singletonList("fresh"), fresh.values);
            assertTrue(a.p.pendingResults.isEmpty());
        }
    }

    @Test
    public void staleEnableResultCannotAnswerANewerDialogAfterRestart() {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            Reply old = enable(a.p);
            int oldCode = a.p.enableRequestCode;
            a.p.resetSession();
            Reply fresh = enable(a.p);
            int freshCode = a.p.enableRequestCode;
            assertNotEquals(oldCode, freshCode);
            assertTrue(a.p.onActivityResult(oldCode, Activity.RESULT_CANCELED, null));
            idle();
            assertEquals(Collections.singletonList("engine_restarted"), old.errors);
            fresh.assertPending();
            assertEquals(freshCode, a.p.enableRequestCode);
            assertTrue(a.p.onActivityResult(freshCode, Activity.RESULT_OK, null));
            idle();
            assertEquals(Collections.singletonList(true), fresh.values);
        }
    }

    @Test
    public void stalePermissionResultCannotAnswerANewerRequestAfterRestart() {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            permissions(a.p, "android.permission.BLUETOOTH_SCAN");
            int oldCode = a.p.permissionRequestCode;
            a.p.resetSession();
            Reply fresh = permissions(a.p, "android.permission.BLUETOOTH_CONNECT");
            int freshCode = a.p.permissionRequestCode;
            assertNotEquals(oldCode, freshCode);
            assertTrue(a.p.onRequestPermissionsResult(oldCode, new String[0], new int[0]));
            idle();
            fresh.assertPending();
            assertEquals(freshCode, a.p.permissionRequestCode);
            assertTrue(a.p.onRequestPermissionsResult(freshCode, new String[0], new int[0]));
            idle();
            assertEquals(1, fresh.values.size());
        }
    }

    @Test
    public void retiredDialogsCannotAnswerRequestsInAReplacementEngine() {
        try (PluginTestSupport.Attached old = new PluginTestSupport.Attached()) {
            enable(old.p);
            int oldCode = old.p.enableRequestCode;
            old.p.onDetachedFromEngine(old.binding);
            synchronized (REQUEST_OWNERS) {
                assertNull(REQUEST_OWNERS.get(oldCode));
            }
            try (PluginTestSupport.Attached fresh = new PluginTestSupport.Attached()) {
                Reply result = enable(fresh.p);
                int code = fresh.p.enableRequestCode;
                assertTrue(fresh.p.onActivityResult(oldCode, Activity.RESULT_CANCELED, null));
                idle();
                result.assertPending();
                assertTrue(fresh.p.onActivityResult(code, Activity.RESULT_OK, null));
                idle();
                assertEquals(Collections.singletonList(true), result.values);
            }
        }
    }

    @Test
    public void codesStayReservedUntilConsumedAndDoNotStealAnotherEnginesResult() {
        try (PluginTestSupport.Attached first = new PluginTestSupport.Attached();
                PluginTestSupport.Attached second = new PluginTestSupport.Attached()) {
            int oldCode = first.p.newRequestCode();
            first.p.retireRequestCode(oldCode);
            synchronized (REQUEST_OWNERS) {
                nextRequestCode = oldCode;
            }
            Reply result = enable(second.p);
            int freshCode = second.p.enableRequestCode;
            assertNotEquals(oldCode, freshCode);
            assertFalse(first.p.onActivityResult(freshCode, Activity.RESULT_CANCELED, null));
            assertTrue(second.p.consumeRetiredRequestCode(oldCode));
            assertFalse(second.p.consumeRetiredRequestCode(oldCode));
            assertTrue(second.p.onActivityResult(freshCode, Activity.RESULT_OK, null));
            idle();
            assertEquals(Collections.singletonList(true), result.values);
        }
    }
}
