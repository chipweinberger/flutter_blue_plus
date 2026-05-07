package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.*;
import android.os.Looper;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.*;
import org.robolectric.annotation.Config;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class ServerCallbackLifecycleTest {
    static final class Fixture implements AutoCloseable {
        final AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        final GattBridge bridge = new GattBridge(p);
        final GattServer server = new GattServer(bridge.p, "server-callbacks");
        final BluetoothGattService service = GattTestSupport.service();
        final BluetoothGattService kept = GattTestSupport.service();
        final BluetoothGattCharacteristic characteristic = service.getCharacteristics().get(0);
        final BluetoothGattDescriptor descriptor = characteristic.getDescriptors().get(0);
        final PluginTestSupport.Sink sink = new PluginTestSupport.Sink();
        final BluetoothDevice peer = mock(BluetoothDevice.class);
        final String characteristicHandle, descriptorHandle;

        Fixture() {
            p.context = RuntimeEnvironment.getApplication();
            p.sink = sink;
            when(peer.getAddress()).thenReturn(PluginTestSupport.ADDRESS);
            server.server = mock(BluetoothGattServer.class);
            bridge.servers.put(server.id, server);
            server.services(Arrays.asList(service, kept));
            characteristicHandle = server.handle(characteristic);
            descriptorHandle = server.handle(descriptor);
        }

        void requestAllAttributes() {
            server.callback.onCharacteristicReadRequest(peer, 1, 3, characteristic);
            server.callback.onDescriptorReadRequest(peer, 2, 4, descriptor);
            server.callback.onCharacteristicWriteRequest(
                    peer, 3, characteristic, true, true, 5, new byte[] {7, 8});
            server.callback.onDescriptorWriteRequest(
                    peer, 4, descriptor, false, false, 6, new byte[] {9});
            Shadows.shadowOf(Looper.getMainLooper()).idle();
        }

        void assertRequestMetadataAndInvalidHandles() {
            assertEquals(4, sink.values.size());
            for (int i = 0; i < 4; i++) {
                Map<String, Object> event = object(sink.values.get(i));
                assertEquals(i + 1, event.get("requestId"));
                assertEquals(i + 3, event.get("offset"));
                boolean isCharacteristic = event.containsKey("characteristic");
                Map<String, Object> attribute =
                        object(event.get(isCharacteristic ? "characteristic" : "descriptor"));
                Class<?> attributeType =
                        isCharacteristic
                                ? BluetoothGattCharacteristic.class
                                : BluetoothGattDescriptor.class;
                assertEquals(
                        isCharacteristic
                                ? characteristic.getUuid().toString()
                                : descriptor.getUuid().toString(),
                        attribute.get("uuid"));
                assertThrows(
                        IllegalStateException.class,
                        () -> server.get((String) attribute.get("handle"), attributeType));
                if (isCharacteristic)
                    for (Object value : list(attribute.get("descriptors"))) {
                        assertThrows(
                                IllegalStateException.class,
                                () ->
                                        server.get(
                                                (String) object(value).get("handle"),
                                                BluetoothGattDescriptor.class));
                    }
            }
            assertArrayEquals(new byte[] {7, 8}, (byte[]) object(sink.values.get(2)).get("value"));
            assertEquals(true, object(sink.values.get(2)).get("preparedWrite"));
            assertEquals(true, object(sink.values.get(2)).get("responseNeeded"));
            assertArrayEquals(new byte[] {9}, (byte[]) object(sink.values.get(3)).get("value"));
            assertThrows(
                    IllegalStateException.class,
                    () -> server.get(characteristicHandle, BluetoothGattCharacteristic.class));
            assertThrows(
                    IllegalStateException.class,
                    () -> server.get(descriptorHandle, BluetoothGattDescriptor.class));
        }

        public void close() {
            p.io.shutdownNow();
        }
    }

    @Test
    public void removedServiceCallbacksPreserveRequestsWithoutRestoringHandles() {
        try (Fixture f = new Fixture()) {
            String keptHandle = f.server.handle(f.kept);
            when(f.server.server.removeService(f.service)).thenReturn(true);
            f.bridge.serverCall(
                    "removeService",
                    map("id", f.server.id, "handle", f.server.handle(f.service)),
                    new PluginTestSupport.Result());
            f.requestAllAttributes();
            f.assertRequestMetadataAndInvalidHandles();
            assertSame(f.kept, f.server.get(keptHandle, BluetoothGattService.class));
            assertFalse(f.server.handles.containsKey(f.characteristic));
            assertFalse(f.server.handles.containsKey(f.descriptor));
        }
    }

    @Test
    public void clearedServicesStayInvalidWhenReadAndWriteCallbacksArriveLate() {
        try (Fixture f = new Fixture()) {
            f.bridge.serverCall(
                    "clearServices", map("id", f.server.id), new PluginTestSupport.Result());
            verify(f.server.server).clearServices();
            f.requestAllAttributes();
            f.assertRequestMetadataAndInvalidHandles();
            assertTrue(f.server.attributes.isEmpty());
            assertTrue(f.server.handles.isEmpty());
        }
    }

    @Test
    public void activeServiceCallbacksKeepTheirUsableOriginalHandles() {
        try (Fixture f = new Fixture()) {
            f.requestAllAttributes();
            for (Object value : f.sink.values) {
                Map<String, Object> event = object(value);
                if (event.containsKey("characteristic")) {
                    assertEquals(
                            f.characteristicHandle,
                            object(event.get("characteristic")).get("handle"));
                    assertSame(
                            f.characteristic,
                            f.server.get(
                                    f.characteristicHandle, BluetoothGattCharacteristic.class));
                } else {
                    assertEquals(f.descriptorHandle, object(event.get("descriptor")).get("handle"));
                    assertSame(
                            f.descriptor,
                            f.server.get(f.descriptorHandle, BluetoothGattDescriptor.class));
                }
            }
        }
    }
}
