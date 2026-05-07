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
import org.robolectric.annotation.*;
import org.robolectric.shadow.api.Shadow;
import org.robolectric.shadows.ShadowBluetoothGattServer;
import org.robolectric.util.ReflectionHelpers;
import org.robolectric.util.ReflectionHelpers.ClassParameter;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE,
        shadows = GattServerAddTest.FrameworkServer.class)
public class GattServerAddTest {
    // Exercise Android's real pending-service, callback and service-list implementation.
    // The default Robolectric shadow keeps a separate list that cannot reproduce failed adds.
    @Implements(BluetoothGattServer.class)
    public static class FrameworkServer extends ShadowBluetoothGattServer {
        @RealObject BluetoothGattServer real;

        @Implementation
        protected boolean addService(BluetoothGattService service) {
            return Shadow.directlyOn(
                    real,
                    BluetoothGattServer.class,
                    "addService",
                    ClassParameter.from(BluetoothGattService.class, service));
        }

        @Implementation
        protected boolean removeService(BluetoothGattService service) {
            return Shadow.directlyOn(
                    real,
                    BluetoothGattServer.class,
                    "removeService",
                    ClassParameter.from(BluetoothGattService.class, service));
        }

        @Implementation
        protected void clearServices() {
            Shadow.directlyOn(real, BluetoothGattServer.class, "clearServices");
        }

        @Implementation
        protected List<BluetoothGattService> getServices() {
            return Shadow.directlyOn(real, BluetoothGattServer.class, "getServices");
        }
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static BluetoothGattServer nativeServer(BluetoothGattServerCallback callback)
            throws Exception {
        Class binderClass = Class.forName("android.bluetooth.IBluetoothGatt");
        Object binder =
                mock(
                        binderClass,
                        invocation -> {
                            // API 33 waits for an acknowledgement; API 36 sends these Binder calls
                            // directly.
                            for (Object argument : invocation.getArguments())
                                if (argument != null
                                        && argument.getClass()
                                                .getName()
                                                .endsWith("SynchronousResultReceiver"))
                                    ReflectionHelpers.callInstanceMethod(
                                            argument,
                                            "send",
                                            ClassParameter.from(Object.class, null));
                            return RETURNS_DEFAULTS.answer(invocation);
                        });
        BluetoothGattServer server =
                ReflectionHelpers.callConstructor(
                        BluetoothGattServer.class,
                        ClassParameter.from(binderClass, binder),
                        ClassParameter.from(int.class, BluetoothDevice.TRANSPORT_LE),
                        ClassParameter.from(BluetoothAdapter.class, mock(BluetoothAdapter.class)));
        ReflectionHelpers.setField(server, "mServerIf", 1);
        ReflectionHelpers.setField(server, "mCallback", callback);
        return server;
    }

    private static Map<String, Object> definition(String id) {
        return map(
                "handle",
                id,
                "uuid",
                GattTestSupport.UUID_SERVICE.toString(),
                "serviceType",
                0,
                "characteristics",
                Collections.singletonList(
                        map(
                                "handle",
                                id + "-c",
                                "uuid",
                                GattTestSupport.UUID_CHARACTERISTIC.toString(),
                                "properties",
                                8,
                                "permissions",
                                16,
                                "descriptors",
                                Collections.singletonList(
                                        map(
                                                "handle",
                                                id + "-d",
                                                "uuid",
                                                "00002901-0000-1000-8000-00805f9b34fb",
                                                "permissions",
                                                1)))));
    }

    private static void assertUsable(
            GattServer server, Map<String, Object> snapshot, BluetoothGattService expected) {
        assertSame(
                expected, server.get((String) snapshot.get("handle"), BluetoothGattService.class));
        Map<String, Object> characteristic = object(list(snapshot.get("characteristics")).get(0));
        assertSame(
                expected.getCharacteristics().get(0),
                server.get(
                        (String) characteristic.get("handle"), BluetoothGattCharacteristic.class));
        Map<String, Object> descriptor = object(list(characteristic.get("descriptors")).get(0));
        assertSame(
                expected.getCharacteristics().get(0).getDescriptors().get(0),
                server.get((String) descriptor.get("handle"), BluetoothGattDescriptor.class));
    }

    private static void assertRetired(
            GattServer server, Map<String, Object> snapshot, BluetoothGattService expected) {
        assertThrows(
                IllegalStateException.class,
                () -> server.get((String) snapshot.get("handle"), BluetoothGattService.class));
        Map<String, Object> characteristic = object(list(snapshot.get("characteristics")).get(0));
        assertThrows(
                IllegalStateException.class,
                () ->
                        server.get(
                                (String) characteristic.get("handle"),
                                BluetoothGattCharacteristic.class));
        Map<String, Object> descriptor = object(list(characteristic.get("descriptors")).get(0));
        assertThrows(
                IllegalStateException.class,
                () -> server.get((String) descriptor.get("handle"), BluetoothGattDescriptor.class));
        assertFalse(server.handles.containsKey(expected));
        assertFalse(server.handles.containsKey(expected.getCharacteristics().get(0)));
        assertFalse(
                server.handles.containsKey(
                        expected.getCharacteristics().get(0).getDescriptors().get(0)));
    }

    private static final class Fixture implements AutoCloseable {
        final Attached attached = new Attached();
        final GattServer server = new GattServer(attached.p, "server-add-test");
        final Sink sink = new Sink();
        int nextInstanceId = 10;

        Fixture() throws Exception {
            server.server = nativeServer(server.callback);
            attached.p.gatts.servers.put(server.id, server);
            attached.p.onListen(null, sink);
        }

        Result call(String method, Map<String, Object> arguments) {
            Result result = new Result();
            Map<String, Object> request = new LinkedHashMap<>(arguments);
            request.put("id", server.id);
            attached.p.gatts.serverCall(method, request, result);
            return result;
        }

        List<Object> services() {
            return list(call("getServices", map()).value);
        }

        BluetoothGattService add(String id, int status, String... includedHandles) {
            Map<String, Object> definition = definition(id);
            List<Object> included = new ArrayList<>();
            for (String handle : includedHandles) included.add(map("handle", handle));
            definition.put("includedServices", included);
            assertEquals(true, call("addService", map("service", definition)).value);
            BluetoothGattService pending =
                    ReflectionHelpers.getField(server.server, "mPendingService");
            assertSame(server.adding, pending);
            BluetoothGattService response =
                    new BluetoothGattService(pending.getUuid(), pending.getType());
            ReflectionHelpers.callInstanceMethod(
                    response, "setInstanceId", ClassParameter.from(int.class, nextInstanceId++));
            for (BluetoothGattCharacteristic original : pending.getCharacteristics()) {
                BluetoothGattCharacteristic characteristic =
                        new BluetoothGattCharacteristic(
                                original.getUuid(),
                                original.getProperties(),
                                original.getPermissions());
                ReflectionHelpers.callInstanceMethod(
                        characteristic,
                        "setInstanceId",
                        ClassParameter.from(int.class, nextInstanceId++));
                for (BluetoothGattDescriptor descriptor : original.getDescriptors()) {
                    BluetoothGattDescriptor copy =
                            new BluetoothGattDescriptor(
                                    descriptor.getUuid(), descriptor.getPermissions());
                    ReflectionHelpers.callInstanceMethod(
                            copy,
                            "setInstanceId",
                            ClassParameter.from(int.class, nextInstanceId++));
                    characteristic.addDescriptor(copy);
                }
                response.addCharacteristic(characteristic);
            }
            Object dispatcher =
                    ReflectionHelpers.getField(server.server, "mBluetoothGattServerCallback");
            ReflectionHelpers.callInstanceMethod(
                    dispatcher,
                    "onServiceAdded",
                    ClassParameter.from(int.class, status),
                    ClassParameter.from(BluetoothGattService.class, response));
            Shadows.shadowOf(Looper.getMainLooper()).idle();
            assertNull(server.adding);
            assertEquals(status, object(sink.values.get(sink.values.size() - 1)).get("status"));
            return pending;
        }

        public void close() {
            attached.close();
        }
    }

    @Test
    public void removedIncludedServicesStayRetiredAcrossRepeatedQueries() throws Exception {
        try (Fixture fixture = new Fixture()) {
            BluetoothGattService leaf = fixture.add("leaf", BluetoothGatt.GATT_SUCCESS);
            BluetoothGattService child = fixture.add("child", BluetoothGatt.GATT_SUCCESS, "leaf");
            Map<String, Object> childSnapshot =
                    object(object(fixture.sink.values.get(1)).get("service"));
            BluetoothGattService first = fixture.add("first", BluetoothGatt.GATT_SUCCESS, "child");
            BluetoothGattService second =
                    fixture.add("second", BluetoothGatt.GATT_SUCCESS, "child");
            assertEquals(true, fixture.call("removeService", map("handle", "child")).value);
            assertEquals(Arrays.asList(leaf, first, second), fixture.server.server.getServices());
            // Android leaves references to the removed object in its parents.
            assertSame(child, first.getIncludedServices().get(0));
            assertSame(child, second.getIncludedServices().get(0));
            assertRetired(fixture.server, childSnapshot, child);
            Map<String, Object> active = new HashMap<>(fixture.server.attributes);
            for (int i = 0; i < 3; i++) {
                List<Object> services = fixture.services();
                assertEquals(3, services.size());
                assertUsable(fixture.server, object(services.get(0)), leaf);
                for (int parentIndex = 1; parentIndex <= 2; parentIndex++) {
                    Map<String, Object> parent = object(services.get(parentIndex));
                    assertUsable(fixture.server, parent, parentIndex == 1 ? first : second);
                    Map<String, Object> removed =
                            object(list(parent.get("includedServices")).get(0));
                    assertEquals(childSnapshot, removed);
                    assertRetired(fixture.server, removed, child);
                    assertUsable(
                            fixture.server,
                            object(list(removed.get("includedServices")).get(0)),
                            leaf);
                }
                assertEquals(active, fixture.server.attributes);
            }
        }
    }

    @Test
    public void laterAddCallbacksDoNotReactivateRemovedIncludedServices() throws Exception {
        for (int status : new int[] {BluetoothGatt.GATT_SUCCESS, BluetoothGatt.GATT_FAILURE}) {
            try (Fixture fixture = new Fixture()) {
                BluetoothGattService child = fixture.add("child", BluetoothGatt.GATT_SUCCESS);
                Map<String, Object> childSnapshot =
                        object(object(fixture.sink.values.get(0)).get("service"));
                BluetoothGattService parent =
                        fixture.add("parent", BluetoothGatt.GATT_SUCCESS, "child");
                assertEquals(true, fixture.call("removeService", map("handle", "child")).value);
                assertRetired(fixture.server, childSnapshot, child);
                BluetoothGattService added = fixture.add("added", status, "parent");
                Map<String, Object> snapshot =
                        object(object(fixture.sink.values.get(2)).get("service"));
                Map<String, Object> includedParent =
                        object(list(snapshot.get("includedServices")).get(0));
                assertUsable(fixture.server, includedParent, parent);
                Map<String, Object> removed =
                        object(list(includedParent.get("includedServices")).get(0));
                assertEquals(childSnapshot, removed);
                assertRetired(fixture.server, removed, child);
                if (status == BluetoothGatt.GATT_SUCCESS)
                    assertUsable(fixture.server, snapshot, added);
                else assertRetired(fixture.server, snapshot, added);
            }
        }
    }

    @Test
    public void failedAdditionRemainsRetiredAcrossRepeatedServiceQueries() throws Exception {
        try (Fixture fixture = new Fixture()) {
            BluetoothGattService failed = fixture.add("failed", BluetoothGatt.GATT_FAILURE);
            // Android retains this exact failed object; the wrapper must not serialize it back into
            // ownership.
            assertSame(failed, fixture.server.server.getServices().get(0));
            Map<String, Object> snapshot =
                    object(object(fixture.sink.values.get(0)).get("service"));
            Map<String, Object> characteristic =
                    object(list(snapshot.get("characteristics")).get(0));
            Map<String, Object> descriptor = object(list(characteristic.get("descriptors")).get(0));
            for (int i = 0; i < 3; i++) {
                assertTrue(fixture.services().isEmpty());
                assertTrue(fixture.server.attributes.isEmpty());
                assertTrue(fixture.server.handles.isEmpty());
                assertThrows(
                        IllegalStateException.class,
                        () ->
                                fixture.server.get(
                                        (String) snapshot.get("handle"),
                                        BluetoothGattService.class));
                assertThrows(
                        IllegalStateException.class,
                        () ->
                                fixture.server.get(
                                        (String) characteristic.get("handle"),
                                        BluetoothGattCharacteristic.class));
                assertThrows(
                        IllegalStateException.class,
                        () ->
                                fixture.server.get(
                                        (String) descriptor.get("handle"),
                                        BluetoothGattDescriptor.class));
            }
        }
    }

    @Test
    public void successfulServicesAndRetriesRemainUsableWithoutFailedEntries() throws Exception {
        try (Fixture fixture = new Fixture()) {
            BluetoothGattService kept = fixture.add("kept", BluetoothGatt.GATT_SUCCESS);
            Map<String, Object> keptSnapshot = object(fixture.services().get(0));
            BluetoothGattService failed = fixture.add("retry", BluetoothGatt.GATT_FAILURE);
            assertEquals(2, fixture.server.server.getServices().size());
            assertEquals(1, fixture.services().size());
            assertEquals(keptSnapshot, fixture.services().get(0));
            assertUsable(fixture.server, keptSnapshot, kept);
            BluetoothGattService retried = fixture.add("retry", BluetoothGatt.GATT_SUCCESS);
            assertNotSame(failed, retried);
            assertEquals(3, fixture.server.server.getServices().size());
            List<Object> published = fixture.services();
            assertEquals(2, published.size());
            assertEquals(keptSnapshot, published.get(0));
            assertUsable(fixture.server, object(published.get(0)), kept);
            assertUsable(fixture.server, object(published.get(1)), retried);
            assertFalse(fixture.server.handles.containsKey(failed));
            assertFalse(fixture.server.handles.containsKey(failed.getCharacteristics().get(0)));
            assertEquals(
                    true,
                    fixture.call("removeService", map("handle", keptSnapshot.get("handle"))).value);
            published = fixture.services();
            assertEquals(1, published.size());
            assertUsable(fixture.server, object(published.get(0)), retried);
            fixture.call("clearServices", map());
            assertTrue(fixture.services().isEmpty());
            assertTrue(fixture.server.attributes.isEmpty());
        }
    }
}
