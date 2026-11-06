package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;
import static com.jamcorder.android_bluetooth.GattTestSupport.*;

import static org.junit.Assert.*;

import android.bluetooth.*;
import android.bluetooth.le.*;
import android.content.Context;
import android.os.Looper;

import io.flutter.plugin.common.EventChannel;

import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class BluetoothContractTest {
    @Test
    public void duplicateUuidsKeepDistinctHandlesAndInvalidateOnRediscovery() {
        GattAttributes a = new GattAttributes();
        BluetoothGattService one = service(), two = service();
        a.services(Arrays.asList(one, two));
        String h1 = a.handle(one.getCharacteristics().get(0)),
                h2 = a.handle(two.getCharacteristics().get(0));
        assertNotEquals(h1, h2);
        assertSame(one.getCharacteristics().get(0), a.get(h1, BluetoothGattCharacteristic.class));
        assertThrows(
                IllegalStateException.class,
                () -> new GattAttributes().get(h1, BluetoothGattCharacteristic.class));
        a.clear();
        assertThrows(
                IllegalStateException.class, () -> a.get(h1, BluetoothGattCharacteristic.class));
        assertNotEquals(h1, a.handle(one.getCharacteristics().get(0)));
    }

    @Test
    public void removingServiceInvalidatesAllChildrenButKeepsOtherServices() {
        GattAttributes a = new GattAttributes();
        BluetoothGattService one = service(), two = service();
        a.services(Arrays.asList(one, two));
        BluetoothGattCharacteristic c = one.getCharacteristics().get(0);
        String ch = a.handle(c), dh = a.handle(c.getDescriptors().get(0)), other = a.handle(two);
        a.remove(one);
        assertThrows(
                IllegalStateException.class, () -> a.get(ch, BluetoothGattCharacteristic.class));
        assertThrows(IllegalStateException.class, () -> a.get(dh, BluetoothGattDescriptor.class));
        assertSame(two, a.get(other, BluetoothGattService.class));
    }

    @Test
    public void includedServicesDoNotRecurseForever() {
        GattAttributes a = new GattAttributes();
        BluetoothGattService one = service(), two = service();
        one.addService(two);
        two.addService(one);
        assertEquals(1, a.services(Collections.singletonList(one)).size());
    }

    @Test
    public void rejectedLocalGraphRollsBackWithoutStealingAnExistingAttribute() {
        GattAttributes a = new GattAttributes();
        BluetoothGattService existing = service();
        a.bind("taken", existing);
        Map<String, Object> graph =
                map(
                        "uuid",
                        UUID_SERVICE.toString(),
                        "handle",
                        "new",
                        "characteristics",
                        Arrays.asList(
                                map(
                                        "uuid",
                                        UUID_CHARACTERISTIC.toString(),
                                        "handle",
                                        "new-char",
                                        "properties",
                                        2,
                                        "permissions",
                                        1),
                                map(
                                        "uuid",
                                        UUID_CHARACTERISTIC.toString(),
                                        "handle",
                                        "taken",
                                        "properties",
                                        2,
                                        "permissions",
                                        1)));
        assertThrows(IllegalArgumentException.class, () -> a.createService(graph));
        assertSame(existing, a.get("taken", BluetoothGattService.class));
        assertThrows(IllegalStateException.class, () -> a.get("new", BluetoothGattService.class));
        assertThrows(
                IllegalStateException.class,
                () -> a.get("new-char", BluetoothGattCharacteristic.class));
    }

    @Test
    public void rejectedDescriptorRollsBackPartialGraphWithoutStealingAnExistingAttribute() {
        GattAttributes a = new GattAttributes();
        BluetoothGattDescriptor existing =
                service().getCharacteristics().get(0).getDescriptors().get(0);
        a.bind("taken", existing);
        Map<String, Object> graph =
                map(
                        "uuid", UUID_SERVICE.toString(),
                        "handle", "new",
                        "characteristics",
                                Collections.singletonList(
                                        map(
                                                "uuid", UUID_CHARACTERISTIC.toString(),
                                                "handle", "new-char",
                                                "descriptors",
                                                        Arrays.asList(
                                                                map(
                                                                        "uuid",
                                                                        existing.getUuid()
                                                                                .toString(),
                                                                        "handle",
                                                                        "new-desc"),
                                                                map(
                                                                        "uuid",
                                                                        existing.getUuid()
                                                                                .toString(),
                                                                        "handle",
                                                                        "taken")))));
        assertThrows(IllegalArgumentException.class, () -> a.createService(graph));
        assertSame(existing, a.get("taken", BluetoothGattDescriptor.class));
        assertThrows(IllegalStateException.class, () -> a.get("new", BluetoothGattService.class));
        assertThrows(
                IllegalStateException.class,
                () -> a.get("new-char", BluetoothGattCharacteristic.class));
        assertThrows(
                IllegalStateException.class,
                () -> a.get("new-desc", BluetoothGattDescriptor.class));
    }

    @Test
    public void notificationBytesAreCopiedBeforeMainThreadDispatch() {
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        p.context = RuntimeEnvironment.getApplication();
        BluetoothAdapter adapter =
                ((BluetoothManager) p.context.getSystemService(Context.BLUETOOTH_SERVICE))
                        .getAdapter();
        GattBridge bridge = new GattBridge(p);
        GattClient c =
                new GattClient(bridge.p, "gatt", adapter.getRemoteDevice("AA:BB:CC:DD:EE:FF"));
        List<Object> received = new ArrayList<>();
        p.sink =
                new EventChannel.EventSink() {
                    public void success(Object event) {
                        received.add(event);
                    }

                    public void error(String code, String message, Object details) {
                        fail(message);
                    }

                    public void endOfStream() {}
                };
        byte[] bytes = new byte[] {1, (byte) 255};
        c.callback.onCharacteristicChanged(null, characteristic(), bytes);
        bytes[0] = 99;
        Shadows.shadowOf(Looper.getMainLooper()).idle();
        assertArrayEquals(
                new byte[] {1, (byte) 255}, (byte[]) object(received.get(0)).get("value"));
        p.io.shutdownNow();
    }

    @Test
    public void scanFiltersPreserveMasksAndRejectDifferentMaskLengths() {
        ScanFilter f =
                ScanBridge.filter(
                        map(
                                "manufacturerId",
                                7,
                                "manufacturerData",
                                new byte[] {1, 2},
                                "manufacturerDataMask",
                                new byte[] {(byte) 255, 0}));
        assertEquals(7, f.getManufacturerId());
        assertArrayEquals(new byte[] {(byte) 255, 0}, f.getManufacturerDataMask());
        assertThrows(
                IllegalArgumentException.class,
                () ->
                        ScanBridge.filter(
                                map(
                                        "manufacturerId",
                                        7,
                                        "manufacturerData",
                                        new byte[] {1, 2},
                                        "manufacturerDataMask",
                                        new byte[] {1})));
        assertThrows(
                IllegalArgumentException.class,
                () ->
                        ScanBridge.filter(
                                map(
                                        "serviceDataUuid",
                                        UUID_SERVICE.toString(),
                                        "serviceData",
                                        new byte[] {1, 2},
                                        "serviceDataMask",
                                        new byte[] {1})));
    }

    @Test
    @Config(sdk = 23)
    public void unsupportedScanOptionsFailInsteadOfBeingSilentlyIgnored() {
        assertThrows(
                UnsupportedOperationException.class,
                () -> ScanBridge.settings(map("legacy", false)));
    }

    @Test
    public void capabilityBootstrapDoesNotRequireConnectPermission() {
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        p.context = RuntimeEnvironment.getApplication();
        p.manager = (BluetoothManager) p.context.getSystemService(Context.BLUETOOTH_SERVICE);
        Map<String, Object> capabilities = p.adapterBridge.capabilities();
        assertEquals(android.os.Build.VERSION.SDK_INT, capabilities.get("apiLevel"));
        assertEquals(true, capabilities.get("hasAdapter"));
        assertEquals(true, capabilities.get("permissionRequired"));
        assertNull(capabilities.get("isEnabled"));
        p.io.shutdownNow();
    }

    @Test
    public void lateCallbacksCannotResurrectAttributesAfterServiceChange() {
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        p.context = RuntimeEnvironment.getApplication();
        BluetoothAdapter adapter =
                ((BluetoothManager) p.context.getSystemService(Context.BLUETOOTH_SERVICE))
                        .getAdapter();
        GattClient client = new GattClient(p, "gatt", adapter.getRemoteDevice("AA:BB:CC:DD:EE:FF"));
        BluetoothGattService original = service();
        client.servicesValid = true;
        client.services(Collections.singletonList(original));
        BluetoothGattCharacteristic stale = original.getCharacteristics().get(0);
        String oldHandle = client.handle(stale);
        client.invalidate();
        String lateHandle = (String) client.characteristicEvent(stale).get("handle");
        client.servicesValid = true;
        client.services(Collections.singletonList(service()));
        assertThrows(
                IllegalStateException.class,
                () -> client.get(oldHandle, BluetoothGattCharacteristic.class));
        assertThrows(
                IllegalStateException.class,
                () -> client.get(lateHandle, BluetoothGattCharacteristic.class));
        p.io.shutdownNow();
    }

    @Test
    public void scanReportDelayRetainsItsNative64BitRange() throws Exception {
        long delay = 1L << 34;
        assertEquals(
                delay, ScanBridge.settings(map("reportDelayMillis", delay)).getReportDelayMillis());
    }
}
