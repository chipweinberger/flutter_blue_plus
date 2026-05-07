package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.*;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class GattCloseFailureTest {
    @Test
    public void failedClientCloseRejectsWorkButAllowsCleanupRetry() throws Exception {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            GattClient client =
                    new GattClient(a.p, "gatt-close-failure", mock(BluetoothDevice.class));
            client.gatt = mock(BluetoothGatt.class);
            doThrow(new SecurityException("CONNECT revoked")).doNothing().when(client.gatt).close();
            a.p.gatts.clients.put(client.id, client);
            assertThrows(
                    SecurityException.class,
                    () ->
                            a.p.gatts.handle(
                                    "gatt.close",
                                    map("id", client.id),
                                    new PluginTestSupport.Result()));
            assertSame(client, a.p.gatts.clients.get(client.id));
            for (String method :
                    new String[] {
                        "discoverServices", "readRemoteRssi", "connect", "requestMtu", "getServices"
                    })
                assertThrows(
                        IllegalStateException.class,
                        () ->
                                a.p.gatts.handle(
                                        "gatt." + method,
                                        map("id", client.id),
                                        new PluginTestSupport.Result()));
            verify(client.gatt, never()).discoverServices();
            verify(client.gatt, never()).readRemoteRssi();
            verify(client.gatt, never()).connect();
            a.p.gatts.handle("gatt.close", map("id", client.id), new PluginTestSupport.Result());
            verify(client.gatt, times(2)).close();
            assertFalse(a.p.gatts.clients.containsKey(client.id));
        }
    }

    @Test
    public void failedServerCloseCannotAcceptServicesOrResponsesAndRemainsRetryable() {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            GattServer server = new GattServer(a.p, "server-close-failure");
            server.server = mock(BluetoothGattServer.class);
            doThrow(new SecurityException("CONNECT revoked"))
                    .doNothing()
                    .when(server.server)
                    .close();
            a.p.gatts.servers.put(server.id, server);
            assertThrows(
                    SecurityException.class,
                    () ->
                            a.p.gatts.serverCall(
                                    "close", map("id", server.id), new PluginTestSupport.Result()));
            assertSame(server, a.p.gatts.servers.get(server.id));
            for (String method :
                    new String[] {
                        "addService",
                        "sendResponse",
                        "connect",
                        "getServices",
                        "notifyCharacteristicChanged"
                    })
                assertThrows(
                        IllegalStateException.class,
                        () ->
                                a.p.gatts.serverCall(
                                        method,
                                        map("id", server.id),
                                        new PluginTestSupport.Result()));
            verify(server.server, never()).addService(any());
            verify(server.server, never()).getServices();
            a.p.gatts.serverCall("close", map("id", server.id), new PluginTestSupport.Result());
            verify(server.server, times(2)).close();
            assertFalse(a.p.gatts.servers.containsKey(server.id));
        }
    }
}
