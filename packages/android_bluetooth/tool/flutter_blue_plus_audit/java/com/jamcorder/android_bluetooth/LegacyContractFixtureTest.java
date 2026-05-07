package com.jamcorder.android_bluetooth;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.*;
import android.bluetooth.le.*;
import android.os.ParcelUuid;

import org.json.*;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

/** Generates and checks wire fixtures using the unmodified pre-migration FBP implementation. */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 36, manifest = Config.NONE)
public class LegacyContractFixtureTest {
    static UUID uuid(String shortUuid) {
        return UUID.fromString("0000" + shortUuid + "-0000-1000-8000-00805f9b34fb");
    }

    static BluetoothGattService service(String uuid, int type) {
        return new BluetoothGattService(uuid(uuid), type);
    }

    static void characteristic(BluetoothGattService service, String uuid, int instance) {
        BluetoothGattCharacteristic c = mock(BluetoothGattCharacteristic.class);
        when(c.getUuid()).thenReturn(uuid(uuid));
        when(c.getService()).thenReturn(service);
        when(c.getInstanceId()).thenReturn(instance);
        when(c.getProperties()).thenReturn(62);
        BluetoothGattDescriptor d = mock(BluetoothGattDescriptor.class);
        when(d.getUuid()).thenReturn(uuid("2902"));
        when(d.getCharacteristic()).thenReturn(c);
        when(c.getDescriptors()).thenReturn(Collections.singletonList(d));
        service.getCharacteristics().add(c);
    }

    static Object graph(Object legacy, BluetoothDevice device, List<BluetoothGattService> services)
            throws Exception {
        BluetoothGatt gatt = mock(BluetoothGatt.class);
        when(gatt.getServices()).thenReturn(services);
        List<Object> result = new ArrayList<>();
        for (BluetoothGattService primary : services) {
            for (BluetoothGattService service : combined(primary)) {
                result.add(
                        FlutterBluePlusParityProbe.invoke(
                                legacy,
                                "bmBluetoothService",
                                new Class<?>[] {
                                    BluetoothDevice.class,
                                    BluetoothGattService.class,
                                    BluetoothGattService.class,
                                    BluetoothGatt.class
                                },
                                device,
                                service,
                                service == primary ? null : primary,
                                gatt));
            }
        }
        return result;
    }

    static List<BluetoothGattService> combined(BluetoothGattService primary) {
        List<BluetoothGattService> services = new ArrayList<>();
        services.add(primary);
        services.addAll(primary.getIncludedServices());
        return services;
    }

    static Object jsonValue(Object value) throws Exception {
        if (value == null) return JSONObject.NULL;
        if (value instanceof Map) {
            JSONObject result = new JSONObject();
            for (Object raw : ((Map<?, ?>) value).entrySet()) {
                Map.Entry<?, ?> entry = (Map.Entry<?, ?>) raw;
                result.put(entry.getKey().toString(), jsonValue(entry.getValue()));
            }
            return result;
        }
        if (value instanceof Iterable) {
            JSONArray result = new JSONArray();
            for (Object item : (Iterable<?>) value) result.put(jsonValue(item));
            return result;
        }
        if (value instanceof byte[]) {
            JSONArray result = new JSONArray();
            for (byte item : (byte[]) value) result.put(item & 255);
            return result;
        }
        return value;
    }

    static Object canonical(Object value) throws Exception {
        if (value == JSONObject.NULL) return null;
        if (value instanceof JSONObject) {
            Map<String, Object> result = new TreeMap<>();
            JSONObject object = (JSONObject) value;
            for (Iterator<String> keys = object.keys(); keys.hasNext(); ) {
                String key = keys.next();
                result.put(key, canonical(object.get(key)));
            }
            return result;
        }
        if (value instanceof JSONArray) {
            List<Object> result = new ArrayList<>();
            JSONArray array = (JSONArray) value;
            for (int i = 0; i < array.length(); i++) result.add(canonical(array.get(i)));
            return result;
        }
        return value;
    }

    @Test
    public void contractMatchesOriginalJavaBackend() throws Exception {
        Object legacy = FlutterBluePlusParityProbe.oldPlugin();
        BluetoothDevice device = mock(BluetoothDevice.class);
        when(device.getAddress()).thenReturn("AA:BB:CC:DD:EE:FF");
        when(device.getName()).thenReturn("Device");
        Map<String, Object> fixtures = new LinkedHashMap<>();
        BluetoothGattService one = service("180d", 0);
        characteristic(one, "2a37", 77);
        fixtures.put("unique", graph(legacy, device, Collections.singletonList(one)));
        BluetoothGattService duplicate = service("180d", 0);
        characteristic(duplicate, "2a37", 4);
        characteristic(duplicate, "2a37", 9);
        fixtures.put(
                "duplicateCharacteristics",
                graph(legacy, device, Collections.singletonList(duplicate)));
        BluetoothGattService first = service("180d", 0), second = service("180d", 0);
        characteristic(first, "2a37", 77);
        characteristic(first, "2a38", 78);
        characteristic(second, "2a37", 79);
        fixtures.put("duplicateServices", graph(legacy, device, Arrays.asList(first, second)));
        BluetoothGattService primary = service("1800", 0), secondary = service("180d", 1);
        characteristic(primary, "2a00", 3);
        characteristic(secondary, "2a37", 77);
        primary.addService(secondary);
        fixtures.put("included", graph(legacy, device, Collections.singletonList(primary)));
        ScanRecord record = mock(ScanRecord.class);
        when(record.getBytes())
                .thenReturn(
                        new byte[] {
                            4,
                            (byte) 255,
                            0x4c,
                            0,
                            1,
                            4,
                            (byte) 255,
                            0x4c,
                            0,
                            2,
                            3,
                            0x19,
                            0x40,
                            3,
                            0
                        });
        when(record.getDeviceName()).thenReturn("Heart");
        when(record.getTxPowerLevel()).thenReturn(Integer.MIN_VALUE);
        when(record.getServiceUuids())
                .thenReturn(Collections.singletonList(new ParcelUuid(uuid("180d"))));
        when(record.getServiceData()).thenReturn(Collections.emptyMap());
        when(record.getAdvertisingDataMap())
                .thenReturn(Collections.singletonMap(0x19, new byte[] {0x40, 3}));
        ScanResult scan = mock(ScanResult.class);
        when(scan.getScanRecord()).thenReturn(record);
        when(scan.isConnectable()).thenReturn(true);
        when(scan.getRssi()).thenReturn(-40);
        fixtures.put(
                "advertisement",
                FlutterBluePlusParityProbe.invoke(
                        legacy,
                        "bmScanAdvertisement",
                        new Class<?>[] {BluetoothDevice.class, ScanResult.class},
                        device,
                        scan));
        JSONObject actual = (JSONObject) jsonValue(fixtures);
        Path path = Paths.get(System.getProperty("fbp.contractFile"));
        if (Boolean.getBoolean("fbp.updateContract")) {
            Files.write(path, (actual.toString(2) + "\n").getBytes(StandardCharsets.UTF_8));
        }
        JSONObject expected =
                new JSONObject(new String(Files.readAllBytes(path), StandardCharsets.UTF_8));
        assertEquals(canonical(expected), canonical(actual));
    }
}
