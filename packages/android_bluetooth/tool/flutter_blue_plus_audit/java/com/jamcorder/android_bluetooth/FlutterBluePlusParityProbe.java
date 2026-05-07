package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.*;
import android.bluetooth.le.ScanRecord;
import android.content.*;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.*;
import org.robolectric.annotation.Config;

import java.lang.reflect.*;
import java.util.*;

// Native compatibility checks plus the identity/advertisement translations the Dart adapter must
// retain.
@SuppressWarnings({"unchecked", "deprecation"})
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 36, manifest = Config.NONE)
public class FlutterBluePlusParityProbe {
    static Object oldPlugin() throws Exception {
        // The native backend changed namespace between the feature and main branches.
        for (String namespace :
                new String[] {"com.lib.flutter_blue_plus", "com.jmx.flutter_blue_plus"}) {
            try {
                return Class.forName(namespace + ".FlutterBluePlusPlugin")
                        .getConstructor()
                        .newInstance();
            } catch (ClassNotFoundException absent) {
                // Try the other source layout without changing the backend under test.
            }
        }
        throw new IllegalStateException(
                "FlutterBluePlus backend source is missing from the audit harness");
    }

    static Object field(Object target, String name) throws Exception {
        Field f = target.getClass().getDeclaredField(name);
        f.setAccessible(true);
        return f.get(target);
    }

    static void field(Object target, String name, Object value) throws Exception {
        Field f = target.getClass().getDeclaredField(name);
        f.setAccessible(true);
        f.set(target, value);
    }

    static Object invoke(Object target, String name, Class<?>[] types, Object... args)
            throws Exception {
        Method m = target.getClass().getDeclaredMethod(name, types);
        m.setAccessible(true);
        return m.invoke(target, args);
    }

    @Test
    public void uniqueCharacteristicIdsNeedTranslation() throws Exception {
        BluetoothGattService s = GattTestSupport.service();
        BluetoothGattCharacteristic c = mock(BluetoothGattCharacteristic.class);
        when(c.getUuid()).thenReturn(GattTestSupport.UUID_CHARACTERISTIC);
        when(c.getService()).thenReturn(s);
        when(c.getInstanceId()).thenReturn(77);
        when(c.getDescriptors()).thenReturn(Collections.emptyList());
        s.getCharacteristics().clear();
        s.addCharacteristic(c);
        BluetoothGatt g = mock(BluetoothGatt.class);
        when(g.getServices()).thenReturn(Collections.singletonList(s));
        assertEquals(
                0,
                invoke(
                        oldPlugin(),
                        "getInstanceId",
                        new Class<?>[] {BluetoothGatt.class, BluetoothGattCharacteristic.class},
                        g,
                        c));
        assertEquals(77, new GattAttributes().characteristic(c).get("instanceId"));
    }

    @Test
    public void compatibilityModePreservesLegacyReadAfterRefreshAndServiceChange()
            throws Exception {
        String address = "AA:BB:CC:DD:EE:FF";
        BluetoothGattService s = GattTestSupport.service();
        BluetoothGattCharacteristic c = s.getCharacteristics().get(0);
        BluetoothGatt g =
                mock(
                        BluetoothGatt.class,
                        i ->
                                i.getMethod().getName().equals("refresh")
                                        ? true
                                        : RETURNS_DEFAULTS.answer(i));
        when(g.getServices()).thenReturn(Collections.singletonList(s));
        when(g.readCharacteristic(c)).thenReturn(true);
        Object old = oldPlugin();
        field(old, "mBluetoothAdapter", mock(BluetoothAdapter.class));
        ((Map<String, BluetoothGatt>) field(old, "mConnectedDevices")).put(address, g);
        PluginTestSupport.Result refreshed = new PluginTestSupport.Result();
        ((MethodChannel.MethodCallHandler) old)
                .onMethodCall(new MethodCall("clearGattCache", address), refreshed);
        assertNull(refreshed.error);
        assertEquals(true, refreshed.value);
        PluginTestSupport.Result read = new PluginTestSupport.Result();
        HashMap<String, Object> args = new HashMap<>();
        args.put("remote_id", address);
        args.put("service_uuid", s.getUuid().toString());
        args.put("characteristic_uuid", c.getUuid().toString());
        args.put("instance_id", 0);
        ((MethodChannel.MethodCallHandler) old)
                .onMethodCall(new MethodCall("readCharacteristic", args), read);
        assertNull(read.error);
        assertEquals(true, read.value);

        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            GattBridge bridge = new GattBridge(p);
            GattClient client =
                    new GattClient(bridge.p, "gatt-audit", mock(BluetoothDevice.class), true);
            client.gatt = g;
            client.servicesValid = true;
            client.services(Collections.singletonList(s));
            String handle = client.handle(c);
            bridge.clients.put(client.id, client);
            bridge.handle("gatt.refresh", map("id", client.id), new PluginTestSupport.Result());
            assertTrue(client.servicesValid);
            PluginTestSupport.Result currentRead = new PluginTestSupport.Result();
            bridge.handle(
                    "gatt.readCharacteristic", map("id", client.id, "handle", handle), currentRead);
            assertEquals(read.value, currentRead.value);
            client.callback.onServiceChanged(g);
            assertSame(c, client.get(handle, BluetoothGattCharacteristic.class));
            verify(g, times(2)).readCharacteristic(c);
            verify(g, never()).discoverServices();
        } finally {
            p.io.shutdownNow();
        }
    }

    @Test
    public void repeatedManufacturerFieldsMustUseRawBytes() throws Exception {
        ScanRecord record = mock(ScanRecord.class);
        when(record.getBytes())
                .thenReturn(new byte[] {4, (byte) 255, 0x4c, 0, 1, 4, (byte) 255, 0x4c, 0, 2, 0});
        assertArrayEquals(
                new byte[] {0x4c, 0, 1, 0x4c, 0, 2},
                (byte[])
                        invoke(
                                oldPlugin(),
                                "getManufacturerSpecificData",
                                new Class<?>[] {ScanRecord.class},
                                record));
    }

    @Test
    public void pairingReceiversApplyPrearmedPinsSynchronously() throws Exception {
        BluetoothDevice d = mock(BluetoothDevice.class);
        when(d.getAddress()).thenReturn("AA:BB:CC:DD:EE:FF");
        byte[] pin = new byte[] {'1', '2', '3', '4'};
        Object old = oldPlugin();
        ((Map<String, byte[]>) field(old, "mBondingPins")).put(d.getAddress(), pin);
        Intent request =
                new Intent(BluetoothDevice.ACTION_PAIRING_REQUEST)
                        .putExtra(BluetoothDevice.EXTRA_DEVICE, d);
        ((BroadcastReceiver) field(old, "mBluetoothPairRequestReceiver"))
                .onReceive(RuntimeEnvironment.getApplication(), request);
        verify(d).setPin(pin);
        clearInvocations(d);
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            p.context = RuntimeEnvironment.getApplication();
            p.deviceBridge.setPinForNextPairing(d.getAddress(), pin);
            p.receiver.onReceive(p.context, request);
            verify(d).setPin(pin);
            p.receiver.onReceive(p.context, request);
            verify(d, times(1)).setPin(any());
        } finally {
            p.io.shutdownNow();
        }
    }

    @Test
    public void lateDescriptorCallbacksKeepRoutingIdentityWithoutReactivatingHandles() {
        GattAttributes a = new GattAttributes();
        BluetoothGattService s = GattTestSupport.service();
        BluetoothGattDescriptor d = s.getCharacteristics().get(0).getDescriptors().get(0);
        a.services(Collections.singletonList(s));
        String original = a.handle(d);
        a.clear();
        Map<String, Object> event = a.descriptorEvent(d);
        assertEquals(original, event.get("handle"));
        Map<String, Object> characteristic = object(event.get("characteristic"));
        assertEquals(
                s.getCharacteristics().get(0).getUuid().toString(), characteristic.get("uuid"));
        assertEquals(s.getUuid().toString(), object(characteristic.get("service")).get("uuid"));
        assertThrows(
                IllegalStateException.class, () -> a.get(original, BluetoothGattDescriptor.class));
    }

    @Test
    @Config(sdk = {23, 28, 30})
    public void locationPreflightMatchesLegacyWithoutAnActivity() throws Exception {
        Context context = RuntimeEnvironment.getApplication();
        Object old = oldPlugin();
        io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding binding =
                mock(io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding.class);
        when(binding.getApplicationContext()).thenReturn(context);
        field(old, "pluginBinding", binding);
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            p.context = context;
            for (boolean enabled : new boolean[] {false, true}) {
                if (android.os.Build.VERSION.SDK_INT >= 28)
                    Shadows.shadowOf(
                                    (android.location.LocationManager)
                                            context.getSystemService(Context.LOCATION_SERVICE))
                            .setLocationEnabled(enabled);
                else
                    android.provider.Settings.Secure.putInt(
                            context.getContentResolver(),
                            android.provider.Settings.Secure.LOCATION_MODE,
                            enabled ? 3 : 0);
                assertEquals(enabled, p.environment.isLocationEnabled());
                assertEquals(
                        invoke(old, "isLocationEnabled", new Class<?>[0]),
                        p.environment.isLocationEnabled());
            }
        } finally {
            p.io.shutdownNow();
        }
    }
}
