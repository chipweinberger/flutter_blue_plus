package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;
import static com.jamcorder.android_bluetooth.PluginTestSupport.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.*;
import android.os.Looper;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;

import java.util.Collections;
import java.util.Map;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class ReliableWriteTest {
    @Test
    public void writeCallbacksPreserveNativeResponseBytesAndStatusAtCallbackTime()
            throws Exception {
        try (Attached attached = new Attached()) {
            Sink sink = new Sink();
            attached.p.onListen(null, sink);
            BluetoothDevice peer = mock(BluetoothDevice.class);
            when(peer.getAddress()).thenReturn(ADDRESS);
            GattClient client = new GattClient(attached.p, "gatt-reliable-write", peer);
            client.gatt = mock(BluetoothGatt.class);
            attached.p.gatts.clients.put(client.id, client);
            when(client.gatt.beginReliableWrite()).thenReturn(true);
            BluetoothGattService service =
                    new BluetoothGattService(GattTestSupport.UUID_SERVICE, 0);
            BluetoothGattCharacteristic characteristic =
                    new BluetoothGattCharacteristic(
                            GattTestSupport.UUID_CHARACTERISTIC,
                            BluetoothGattCharacteristic.PROPERTY_WRITE,
                            BluetoothGattCharacteristic.PERMISSION_WRITE);
            service.addCharacteristic(characteristic);
            client.services(Collections.singletonList(service));
            client.servicesValid = true;
            String handle = client.handle(characteristic);
            Result started = new Result();
            client.handle("beginReliableWrite", map(), started);
            assertEquals(true, started.value);
            byte[] desired = {1, 2};
            client.handle(
                    "writeCharacteristic",
                    map("handle", handle, "value", desired, "writeType", 2),
                    new Result());
            byte[] mismatched = {9, 8};
            byte[][] responses = {mismatched, desired, null, new byte[0]};
            int[] statuses = {0, 0, BluetoothGatt.GATT_FAILURE, 0};
            for (int i = 0; i < responses.length; i++) {
                characteristic.setValue(responses[i]);
                client.callback.onCharacteristicWrite(client.gatt, characteristic, statuses[i]);
            }
            // Neither a later callback nor mutation of Android's array may change a queued result.
            mismatched[0] = 7;
            desired[0] = 6;
            characteristic.setValue(new byte[] {5});
            Shadows.shadowOf(Looper.getMainLooper()).idle();
            assertEquals(4, sink.values.size());
            byte[][] expected = {{9, 8}, {1, 2}, null, new byte[0]};
            for (int i = 0; i < expected.length; i++) {
                Map<String, Object> event = object(sink.values.get(i));
                assertEquals(client.id, event.get("owner"));
                assertEquals("onCharacteristicWrite", event.get("type"));
                assertEquals(statuses[i], event.get("status"));
                assertEquals(handle, object(event.get("characteristic")).get("handle"));
                assertTrue(event.containsKey("value"));
                assertArrayEquals(expected[i], (byte[]) event.get("value"));
            }
            // The application decides whether to abort or commit after comparing the response.
            verify(client.gatt, never()).executeReliableWrite();
            verify(client.gatt, never()).abortReliableWrite();
        }
    }
}
