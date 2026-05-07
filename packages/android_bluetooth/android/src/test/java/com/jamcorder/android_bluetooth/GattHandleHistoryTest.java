package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;

import android.bluetooth.*;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

import java.lang.ref.WeakReference;
import java.util.*;
import java.util.concurrent.TimeUnit;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class GattHandleHistoryTest {
    private static final class EqualObjects {
        @Override
        public int hashCode() {
            return 1;
        }

        @Override
        public boolean equals(Object other) {
            return other instanceof EqualObjects;
        }
    }

    private static boolean collected(List<WeakReference<Object>> references) {
        for (WeakReference<Object> reference : references)
            if (reference.get() != null) return false;
        return true;
    }

    private static void awaitCollection(List<WeakReference<Object>> references) throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (!collected(references) && System.nanoTime() < deadline) {
            System.gc();
            System.runFinalization();
            Thread.sleep(10);
        }
        assertTrue(
                "retired GATT graphs must be collectible while the registration remains open",
                collected(references));
    }

    private static List<WeakReference<Object>> retireGraphs(
            GattAttributes registry, boolean remove) {
        List<WeakReference<Object>> references = new ArrayList<>();
        for (int i = 0; i < 100; i++) {
            BluetoothGattService service = GattTestSupport.service();
            BluetoothGattCharacteristic characteristic = service.getCharacteristics().get(0);
            BluetoothGattDescriptor descriptor = characteristic.getDescriptors().get(0);
            references.add(new WeakReference<>(service));
            references.add(new WeakReference<>(characteristic));
            references.add(new WeakReference<>(descriptor));
            registry.services(Collections.singletonList(service));
            if (remove) registry.remove(service);
            else registry.clear();
        }
        return references;
    }

    private static void assertCollectedHistory(GattAttributes registry) {
        IdentityHashMap<Object, String> snapshot = new IdentityHashMap<>();
        registry.retiredHandles.copyTo(snapshot);
        assertTrue(snapshot.isEmpty());
        assertTrue(registry.retiredHandles.isEmpty());
        assertTrue(registry.handles.isEmpty());
        assertTrue(registry.attributes.isEmpty());
    }

    @Test
    public void repeatedInvalidationDoesNotRetainOldGraphs() throws Exception {
        GattAttributes registry = new GattAttributes();
        awaitCollection(retireGraphs(registry, false));
        assertCollectedHistory(registry);
    }

    @Test
    public void repeatedServiceRemovalDoesNotRetainOldGraphs() throws Exception {
        GattAttributes registry = new GattAttributes();
        awaitCollection(retireGraphs(registry, true));
        assertCollectedHistory(registry);
    }

    @Test
    public void liveCallbacksKeepParentIdentitiesAfterOtherHistoryIsCollected() throws Exception {
        GattAttributes registry = new GattAttributes();
        BluetoothGattService service = GattTestSupport.service();
        BluetoothGattCharacteristic characteristic = service.getCharacteristics().get(0);
        BluetoothGattDescriptor descriptor = characteristic.getDescriptors().get(0);
        registry.services(Collections.singletonList(service));
        String sh = registry.handle(service),
                ch = registry.handle(characteristic),
                dh = registry.handle(descriptor);
        registry.clear();
        awaitCollection(retireGraphs(registry, false));
        Map<String, Object> callback = registry.descriptorEvent(descriptor);
        assertEquals(dh, callback.get("handle"));
        Map<String, Object> parent = object(callback.get("characteristic"));
        assertEquals(ch, parent.get("handle"));
        assertEquals(sh, object(parent.get("service")).get("handle"));
        assertEquals(ch, registry.characteristicEvent(characteristic).get("handle"));
        assertThrows(
                IllegalStateException.class, () -> registry.get(dh, BluetoothGattDescriptor.class));
        assertThrows(
                IllegalStateException.class,
                () -> registry.get(ch, BluetoothGattCharacteristic.class));
        assertTrue(registry.attributes.isEmpty());
        registry.forget();
        assertTrue(registry.retiredHandles.isEmpty());
    }

    @Test
    public void equalObjectsKeepSeparateIdentitiesAndNewRegistrationReplacesOnlyItsHistory() {
        GattAttributes registry = new GattAttributes();
        Object first = new EqualObjects(), second = new EqualObjects();
        assertEquals(first, second);
        String firstHandle = registry.handle(first), secondHandle = registry.handle(second);
        assertNotEquals(firstHandle, secondHandle);
        registry.clear();
        IdentityHashMap<Object, String> snapshot = new IdentityHashMap<>();
        registry.retiredHandles.copyTo(snapshot);
        assertEquals(firstHandle, snapshot.get(first));
        assertEquals(secondHandle, snapshot.get(second));
        String replacement = registry.handle(first);
        assertNotEquals(firstHandle, replacement);
        registry.clear();
        snapshot.clear();
        registry.retiredHandles.copyTo(snapshot);
        assertEquals(2, snapshot.size());
        assertEquals(replacement, snapshot.get(first));
        assertEquals(secondHandle, snapshot.get(second));
        assertThrows(IllegalStateException.class, () -> registry.get(firstHandle, Object.class));
        registry.forget();
        assertTrue(registry.retiredHandles.isEmpty());
    }
}
