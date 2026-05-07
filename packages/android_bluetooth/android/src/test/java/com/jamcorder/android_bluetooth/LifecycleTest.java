package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;
import static com.jamcorder.android_bluetooth.PluginTestSupport.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.app.Activity;
import android.bluetooth.*;
import android.bluetooth.le.*;
import android.os.Looper;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.*;

import org.junit.*;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.robolectric.*;
import org.robolectric.annotation.Config;

import java.io.*;
import java.util.*;
import java.util.concurrent.*;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class LifecycleTest {
    @Before
    public void clearBackgroundEvents() {
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        BackgroundEvents.pending.clear();
    }

    @After
    public void flushMainQueue() {
        Shadows.shadowOf(Looper.getMainLooper()).idle();
    }

    @Test
    public void failedScanStopKeepsRegistrationForRetry() throws Exception {
        try (Attached a = new Attached()) {
            BluetoothLeScanner scanner = mock(BluetoothLeScanner.class);
            ScanBridge.Registration registration =
                    a.p.scans.new Registration("scan-retry", scanner);
            a.p.scans.sessions.put(registration.id, registration);
            doThrow(new SecurityException("revoked"))
                    .doNothing()
                    .when(scanner)
                    .stopScan(registration.callback);
            assertThrows(
                    SecurityException.class,
                    () ->
                            a.p.scans.handle(
                                    "stopSession", map("id", registration.id), new Result()));
            assertSame(registration, a.p.scans.sessions.get(registration.id));
            assertFalse(registration.stopped);
            a.p.scans.handle("stopSession", map("id", registration.id), new Result());
            verify(scanner, times(2)).stopScan(registration.callback);
            assertTrue(registration.stopped);
            assertFalse(a.p.scans.sessions.containsKey(registration.id));
        }
    }

    @Test
    public void nativeStartupQueueHasNoEventCountLimit() {
        try (Attached a = new Attached()) {
            for (int i = 0; i < 500; i++) a.p.emit("adapter", "state", map("sequence", i));
            Shadows.shadowOf(Looper.getMainLooper()).idle();
            Sink sink = new Sink();
            a.p.onListen(null, sink);
            assertEquals(500, sink.values.size());
            for (int i = 0; i < 500; i++)
                assertEquals(i, object(sink.values.get(i)).get("sequence"));
        }
    }

    @Test
    public void hotRestartClosesRegistrationsDropsOldCallbacksAndAllowsScanningAgain()
            throws Exception {
        try (Attached a = new Attached()) {
            AndroidBluetoothPlugin p = a.p;
            BluetoothManager manager = mock(BluetoothManager.class);
            BluetoothAdapter adapter = mock(BluetoothAdapter.class);
            BluetoothLeScanner scanner = mock(BluetoothLeScanner.class);
            when(manager.getAdapter()).thenReturn(adapter);
            when(adapter.getBluetoothLeScanner()).thenReturn(scanner);
            p.manager = manager;
            GattClient client = new GattClient(p, "gatt-old", mock(BluetoothDevice.class));
            client.gatt = mock(BluetoothGatt.class);
            p.gatts.clients.put(client.id, client);
            BluetoothSocket socket = mock(BluetoothSocket.class);
            p.sockets.sockets.put("socket-old", new SocketBridge.SocketEntry(socket, p.generation));
            ScanBridge.Registration registration = p.scans.new Registration("scanner", scanner);
            p.scans.sessions.put("scanner", registration);
            Sink old = new Sink();
            p.sink = old;
            p.emit("gatt-old", "onConnectionStateChange", map("status", 0));
            ArgumentCaptor<FlutterEngine.EngineLifecycleListener> callback =
                    ArgumentCaptor.forClass(FlutterEngine.EngineLifecycleListener.class);
            verify(a.engine).addEngineLifecycleListener(callback.capture());
            callback.getValue().onPreEngineRestart();
            client.callback.onConnectionStateChange(client.gatt, 0, 2);
            Sink fresh = new Sink();
            p.sink = fresh;
            Shadows.shadowOf(Looper.getMainLooper()).idle();
            verify(client.gatt).close();
            verify(socket).close();
            verify(scanner).stopScan(registration.callback);
            assertTrue(old.values.isEmpty());
            assertTrue(fresh.values.isEmpty());
            assertTrue(p.gatts.clients.isEmpty());
            assertTrue(p.sockets.sockets.isEmpty());
            assertTrue(p.scans.sessions.isEmpty());
            Result result = new Result();
            p.scans.handle("start", map("settings", map()), result);
            assertNull(result.error);
            assertTrue(p.scans.sessions.containsKey("scanner"));
        }
    }

    @Test
    public void closingSocketUnblocksPendingReadAndConnect() throws Exception {
        try (Attached a = new Attached()) {
            for (String operation : Arrays.asList("read", "connect")) {
                BluetoothSocket socket = mock(BluetoothSocket.class);
                CountDownLatch entered = new CountDownLatch(1), closed = new CountDownLatch(1);
                when(socket.getInputStream())
                        .thenReturn(
                                new InputStream() {
                                    public int read() {
                                        return -1;
                                    }

                                    public int read(byte[] buffer) throws IOException {
                                        entered.countDown();
                                        try {
                                            if (!closed.await(3, TimeUnit.SECONDS))
                                                throw new IOException("close timeout");
                                        } catch (InterruptedException e) {
                                            throw new IOException(e);
                                        }
                                        throw new IOException("closed");
                                    }
                                });
                doAnswer(
                                call -> {
                                    entered.countDown();
                                    closed.await(3, TimeUnit.SECONDS);
                                    throw new IOException("closed");
                                })
                        .when(socket)
                        .connect();
                doAnswer(
                                call -> {
                                    closed.countDown();
                                    return null;
                                })
                        .when(socket)
                        .close();
                String id = "socket-" + operation;
                a.p.sockets.sockets.put(id, new SocketBridge.SocketEntry(socket, a.p.generation));
                Result pending = new Result();
                a.p.sockets.handle(operation, map("id", id), pending);
                assertTrue(entered.await(3, TimeUnit.SECONDS));
                a.p.sockets.handle("close", map("id", id), new Result());
                pending.await();
                assertEquals("io_error", pending.error);
                a.p.sockets.handle("close", map("id", id), new Result());
                assertFalse(a.p.sockets.sockets.containsKey(id));
            }
        }
    }

    @Test
    public void closingListenerUnblocksAcceptAndRestartRejectsALateAcceptedSocket()
            throws Exception {
        try (Attached a = new Attached()) {
            BluetoothServerSocket listener = mock(BluetoothServerSocket.class);
            BluetoothSocket accepted = mock(BluetoothSocket.class);
            CountDownLatch entered = new CountDownLatch(1), closed = new CountDownLatch(1);
            when(listener.accept(-1))
                    .thenAnswer(
                            call -> {
                                entered.countDown();
                                closed.await(3, TimeUnit.SECONDS);
                                return accepted;
                            });
            doAnswer(
                            call -> {
                                closed.countDown();
                                return null;
                            })
                    .when(listener)
                    .close();
            a.p.sockets.listeners.put(
                    "listener-old", new SocketBridge.ListenerEntry(listener, a.p.generation));
            Result result = new Result();
            a.p.sockets.handle("accept", map("id", "listener-old"), result);
            assertTrue(entered.await(3, TimeUnit.SECONDS));
            a.p.engineLifecycle.onPreEngineRestart();
            result.await();
            assertEquals("io_error", result.error);
            verify(accepted).close();
            assertTrue(a.p.sockets.sockets.isEmpty());
        }
    }

    @Test
    public void failedCloseRetainsHandleForRetry() throws Exception {
        try (Attached a = new Attached()) {
            BluetoothSocket socket = mock(BluetoothSocket.class);
            doThrow(new IOException("temporary close failure")).doNothing().when(socket).close();
            a.p.sockets.sockets.put(
                    "socket-retry", new SocketBridge.SocketEntry(socket, a.p.generation));
            assertThrows(
                    IOException.class,
                    () -> a.p.sockets.handle("close", map("id", "socket-retry"), new Result()));
            assertTrue(a.p.sockets.sockets.containsKey("socket-retry"));
            a.p.sockets.handle("close", map("id", "socket-retry"), new Result());
            assertFalse(a.p.sockets.sockets.containsKey("socket-retry"));
        }
    }

    @Test
    public void permissionRevocationIsReportedThroughTheMethodResult() throws Exception {
        try (Attached a = new Attached()) {
            GattClient client = new GattClient(a.p, "gatt-permission", mock(BluetoothDevice.class));
            client.gatt = mock(BluetoothGatt.class);
            when(client.gatt.readRemoteRssi()).thenThrow(new SecurityException("CONNECT revoked"));
            a.p.gatts.clients.put(client.id, client);
            Result result = new Result();
            a.p.onMethodCall(new MethodCall("gatt.readRemoteRssi", map("id", client.id)), result);
            result.await();
            assertEquals("permission_denied", result.error);
            assertEquals(true, a.p.adapterBridge.capabilities().get("permissionRequired"));
        }
    }

    @Test
    public void configurationChangePreservesPendingPermissionRequestAndPermanentDetachResolvesIt() {
        try (Attached a = new Attached()) {
            ActivityPluginBinding binding = mock(ActivityPluginBinding.class);
            when(binding.getActivity()).thenReturn(Robolectric.buildActivity(Activity.class).get());
            a.p.onAttachedToActivity(binding);
            Result result = new Result();
            a.p.permissionResult = result;
            a.p.permissionRequestCode = a.p.newRequestCode();
            a.p.requestedPermissions = new String[] {"android.permission.BLUETOOTH_CONNECT"};
            a.p.onDetachedFromActivityForConfigChanges();
            assertSame(result, a.p.permissionResult);
            assertEquals(1, result.done.getCount());
            a.p.onReattachedToActivityForConfigChanges(binding);
            assertTrue(
                    a.p.onRequestPermissionsResult(
                            a.p.permissionRequestCode,
                            new String[] {"android.permission.BLUETOOTH_CONNECT"},
                            new int[] {-1}));
            assertNotNull(result.value);
            assertNull(result.error);
            Result next = new Result();
            a.p.enableResult = next;
            a.p.enableRequestCode = a.p.newRequestCode();
            a.p.onDetachedFromActivity();
            assertEquals("activity_detached", next.error);
        }
    }

    @Test
    public void rejectingDuplicatePermissionRequestPreservesTheOriginal() throws Exception {
        try (Attached a = new Attached()) {
            a.p.activity = Robolectric.buildActivity(Activity.class).get();
            Result original = new Result();
            a.p.permissionResult = original;
            a.p.permissionRequestCode = a.p.newRequestCode();
            a.p.requestedPermissions = new String[] {"android.permission.BLUETOOTH_CONNECT"};
            Result duplicate = new Result();
            a.p.onMethodCall(
                    new MethodCall(
                            "permissions.request",
                            map(
                                    "permissions",
                                    Collections.singletonList(
                                            "android.permission.BLUETOOTH_SCAN"))),
                    duplicate);
            duplicate.await();
            assertEquals("invalid_state", duplicate.error);
            assertSame(original, a.p.permissionResult);
            assertTrue(
                    a.p.onRequestPermissionsResult(
                            a.p.permissionRequestCode, a.p.requestedPermissions, new int[] {-1}));
            assertNotNull(original.value);
        }
    }

    @Test
    public void callbackAlreadyRunningBeforeRestartCannotReachTheNewSession() throws Exception {
        try (Attached a = new Attached()) {
            BluetoothDevice device = mock(BluetoothDevice.class);
            when(device.getAddress()).thenReturn(ADDRESS);
            CountDownLatch entered = new CountDownLatch(1), release = new CountDownLatch(1);
            when(device.getName())
                    .thenAnswer(
                            call -> {
                                entered.countDown();
                                release.await(3, TimeUnit.SECONDS);
                                return "old";
                            });
            GattClient client = new GattClient(a.p, "gatt-running", device);
            client.gatt = mock(BluetoothGatt.class);
            a.p.gatts.clients.put(client.id, client);
            ExecutorService binder = Executors.newSingleThreadExecutor();
            try {
                Future<?> callback =
                        binder.submit(
                                () -> client.callback.onConnectionStateChange(client.gatt, 0, 2));
                assertTrue(entered.await(3, TimeUnit.SECONDS));
                a.p.engineLifecycle.onPreEngineRestart();
                Sink fresh = new Sink();
                a.p.sink = fresh;
                release.countDown();
                callback.get(3, TimeUnit.SECONDS);
                Shadows.shadowOf(Looper.getMainLooper()).idle();
                assertTrue(fresh.values.isEmpty());
            } finally {
                release.countDown();
                binder.shutdownNow();
            }
        }
    }
}
