package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.*;
import android.content.*;
import android.os.Looper;

import io.flutter.plugin.common.*;

import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.*;
import org.robolectric.annotation.Config;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = {33, 36},
        manifest = Config.NONE)
public class CompatibilityTest {
    @Test
    public void bondStateQueryDoesNotTreatDeniedMetadataAsAnUnbondedDevice() throws Exception {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            BluetoothDevice device = device();
            a.p.knownDevices.put(device.getAddress(), device);
            when(device.getName()).thenThrow(new SecurityException("name denied"));
            when(device.getBondState()).thenReturn(BluetoothDevice.BOND_BONDING);
            assertNull(deviceMap(device).get("bondState"));
            PluginTestSupport.Result result = new PluginTestSupport.Result();
            a.p.deviceBridge.handle("bondState", map("address", device.getAddress()), result);
            assertEquals(BluetoothDevice.BOND_BONDING, result.value);
            when(device.getBondState()).thenThrow(new SecurityException("bond state denied"));
            assertThrows(
                    SecurityException.class,
                    () ->
                            a.p.deviceBridge.handle(
                                    "bondState",
                                    map("address", device.getAddress()),
                                    new PluginTestSupport.Result()));
        }
    }

    @Test
    public void phyQueriesPropagatePermissionFailuresRatherThanReturningFalse() throws Exception {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            a.p.manager = mock(BluetoothManager.class);
            BluetoothAdapter adapter = mock(BluetoothAdapter.class);
            when(a.p.manager.getAdapter()).thenReturn(adapter);
            when(adapter.isLe2MPhySupported()).thenReturn(true);
            PluginTestSupport.Result result = new PluginTestSupport.Result();
            a.p.adapterBridge.handle("adapter.isLe2MPhySupported", map(), result);
            assertEquals(true, result.value);
            when(adapter.isLe2MPhySupported()).thenThrow(new SecurityException("PHY denied"));
            assertThrows(
                    SecurityException.class,
                    () ->
                            a.p.adapterBridge.handle(
                                    "adapter.isLe2MPhySupported",
                                    map(),
                                    new PluginTestSupport.Result()));
        }
    }

    static BluetoothDevice device() {
        BluetoothDevice device = mock(BluetoothDevice.class);
        when(device.getAddress()).thenReturn(PluginTestSupport.ADDRESS);
        return device;
    }

    static Intent event(BluetoothDevice device, String action) {
        return new Intent(action).putExtra(BluetoothDevice.EXTRA_DEVICE, device);
    }

    @Test
    public void createBondArmsACopiedPinBeforeNativeSubmissionAndUsesItOnlyOnce() throws Exception {
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            p.context = RuntimeEnvironment.getApplication();
            BluetoothDevice device = device();
            p.knownDevices.put(device.getAddress(), device);
            byte[] pin = new byte[] {'1', '2', '3', '4'};
            when(device.createBond())
                    .thenAnswer(
                            invocation -> {
                                assertArrayEquals(pin, p.pairingPins.get(device.getAddress()));
                                assertNotSame(pin, p.pairingPins.get(device.getAddress()));
                                return true;
                            });
            PluginTestSupport.Result result = new PluginTestSupport.Result();
            p.onMethodCall(
                    new MethodCall(
                            "device.createBond", map("address", device.getAddress(), "pin", pin)),
                    result);
            result.await();
            assertEquals(true, result.value);
            pin[0] = '9';
            Intent pairing = event(device, BluetoothDevice.ACTION_PAIRING_REQUEST);
            p.receiver.onReceive(p.context, pairing);
            verify(device).setPin(new byte[] {'1', '2', '3', '4'});
            assertTrue(p.pairingPins.isEmpty());
            p.receiver.onReceive(p.context, pairing);
            verify(device, times(1)).setPin(any());
        } finally {
            p.io.shutdownNow();
        }
    }

    @Test
    public void cancelledPairingAndDisconnectCannotLeakPinsToTheNextAttempt() throws Exception {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            AndroidBluetoothPlugin p = a.p;
            BluetoothDevice device = device();
            for (String action :
                    new String[] {
                        BluetoothDevice.ACTION_BOND_STATE_CHANGED,
                        BluetoothDevice.ACTION_ACL_DISCONNECTED
                    }) {
                p.deviceBridge.setPinForNextPairing(device.getAddress(), new byte[] {'1'});
                p.receiver.onReceive(
                        p.context,
                        event(device, action)
                                .putExtra(
                                        BluetoothDevice.EXTRA_BOND_STATE,
                                        BluetoothDevice.BOND_NONE));
                assertTrue(p.pairingPins.isEmpty());
            }
            GattClient client = new GattClient(p, "gatt-pin", device);
            client.gatt = mock(BluetoothGatt.class);
            p.gatts.clients.put(client.id, client);
            p.deviceBridge.setPinForNextPairing(device.getAddress(), new byte[] {'1'});
            p.gatts.handle("gatt.disconnect", map("id", client.id), new PluginTestSupport.Result());
            assertTrue(p.pairingPins.isEmpty());
            p.deviceBridge.setPinForNextPairing(device.getAddress(), new byte[] {'1'});
            client.callback.onConnectionStateChange(
                    client.gatt, 0, BluetoothProfile.STATE_DISCONNECTED);
            assertTrue(p.pairingPins.isEmpty());
            p.deviceBridge.setPinForNextPairing(device.getAddress(), new byte[] {'1'});
            p.resetSession();
            assertTrue(p.pairingPins.isEmpty());
        }
    }

    @Test
    public void rejectedBondSubmissionAndExplicitCancellationClearThePin() throws Exception {
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            BluetoothDevice device = device();
            p.knownDevices.put(device.getAddress(), device);
            PluginTestSupport.Result result = new PluginTestSupport.Result();
            p.onMethodCall(
                    new MethodCall(
                            "device.createBond",
                            map("address", device.getAddress(), "pin", new byte[] {'1'})),
                    result);
            result.await();
            assertEquals(false, result.value);
            assertTrue(p.pairingPins.isEmpty());
            p.deviceBridge.setPinForNextPairing(device.getAddress(), new byte[] {'1'});
            p.onMethodCall(
                    new MethodCall(
                            "device.setPinForNextPairing",
                            map("address", device.getAddress(), "pin", null)),
                    new PluginTestSupport.Result());
            assertTrue(p.pairingPins.isEmpty());
        } finally {
            p.io.shutdownNow();
        }
    }

    @Test
    public void legacyTransportAttemptsLeAndFallsBackWhenTheHiddenOverloadFails() {
        BluetoothDevice device = device();
        Context context = RuntimeEnvironment.getApplication();
        BluetoothGattCallback callback = mock(BluetoothGattCallback.class);
        BluetoothGatt explicit = mock(BluetoothGatt.class), fallback = mock(BluetoothGatt.class);
        when(device.connectGatt(context, false, callback, 2)).thenReturn(explicit);
        assertSame(explicit, GattClient.connectLegacyLe(device, context, false, callback));
        verify(device, never()).connectGatt(context, false, callback);
        when(device.connectGatt(context, false, callback, 2))
                .thenThrow(new IllegalStateException());
        when(device.connectGatt(context, false, callback)).thenReturn(fallback);
        assertSame(fallback, GattClient.connectLegacyLe(device, context, false, callback));
    }

    @Test
    public void enableSubmissionAndUserDecisionStaySeparate() throws Exception {
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            p.activity = mock(android.app.Activity.class);
            PluginTestSupport.Sink sink = new PluginTestSupport.Sink();
            p.sink = sink;
            PluginTestSupport.Result result = new PluginTestSupport.Result();
            p.onMethodCall(
                    new MethodCall("adapter.requestEnable", map("waitForResult", false)), result);
            result.await();
            assertEquals(true, result.value);
            assertTrue(sink.values.isEmpty());
            assertTrue(
                    p.onActivityResult(
                            p.enableEvents.keySet().iterator().next(),
                            android.app.Activity.RESULT_CANCELED,
                            null));
            Shadows.shadowOf(Looper.getMainLooper()).idle();
            assertEquals(true, result.value);
            assertEquals("onEnableResponse", object(sink.values.get(0)).get("type"));
            assertEquals(false, object(sink.values.get(0)).get("userAccepted"));
            assertNull(p.enableResult);
        } finally {
            p.io.shutdownNow();
        }
    }

    @Test
    public void failedEnableLaunchThrowsImmediatelyAndCanBeRetried() throws Exception {
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            p.activity = mock(android.app.Activity.class);
            doThrow(new ActivityNotFoundException())
                    .when(p.activity)
                    .startActivityForResult(any(), anyInt());
            PluginTestSupport.Result failed = new PluginTestSupport.Result();
            p.onMethodCall(
                    new MethodCall("adapter.requestEnable", map("waitForResult", false)), failed);
            failed.await();
            assertEquals("android_error", failed.error);
            assertNull(p.enableResult);
            doNothing().when(p.activity).startActivityForResult(any(), anyInt());
            PluginTestSupport.Result retry = new PluginTestSupport.Result();
            p.onMethodCall(
                    new MethodCall("adapter.requestEnable", map("waitForResult", false)), retry);
            retry.await();
            assertEquals(true, retry.value);
        } finally {
            p.io.shutdownNow();
        }
    }

    @Test
    public void splitEnableRequestsAllowConcurrentLaunchesAndRouteEachResult() throws Exception {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            a.p.activity = mock(android.app.Activity.class);
            PluginTestSupport.Sink sink = new PluginTestSupport.Sink();
            a.p.sink = sink;
            for (int i = 0; i < 2; i++) {
                PluginTestSupport.Result result = new PluginTestSupport.Result();
                a.p.onMethodCall(
                        new MethodCall("adapter.requestEnable", map("waitForResult", false)),
                        result);
                result.await();
                assertEquals(true, result.value);
            }
            assertEquals(2, a.p.enableEvents.size());
            List<Integer> codes = new ArrayList<>(a.p.enableEvents.keySet());
            assertTrue(a.p.onActivityResult(codes.get(1), android.app.Activity.RESULT_OK, null));
            assertTrue(
                    a.p.onActivityResult(codes.get(0), android.app.Activity.RESULT_CANCELED, null));
            Shadows.shadowOf(Looper.getMainLooper()).idle();
            assertEquals(2, sink.values.size());
            assertEquals(true, object(sink.values.get(0)).get("userAccepted"));
            assertEquals(false, object(sink.values.get(1)).get("userAccepted"));
            assertTrue(a.p.enableEvents.isEmpty());
        }
    }

    @Test
    public void lateCallbacksKeepBothParentHandlesButCannotReactivateStaleAttributes() {
        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            GattClient client = new GattClient(p, "gatt-late", device());
            client.gatt = mock(BluetoothGatt.class);
            BluetoothGattService service = GattTestSupport.service();
            BluetoothGattCharacteristic characteristic = service.getCharacteristics().get(0);
            BluetoothGattDescriptor descriptor = characteristic.getDescriptors().get(0);
            client.servicesValid = true;
            client.services(Collections.singletonList(service));
            String sh = client.handle(service),
                    ch = client.handle(characteristic),
                    dh = client.handle(descriptor);
            client.invalidate();
            Map<String, Object> late = client.descriptorEvent(descriptor);
            assertEquals(dh, late.get("handle"));
            Map<String, Object> parent = object(late.get("characteristic"));
            assertEquals(ch, parent.get("handle"));
            assertEquals(sh, object(parent.get("service")).get("handle"));
            client.servicesValid = true;
            assertThrows(
                    IllegalStateException.class,
                    () -> client.get(dh, BluetoothGattDescriptor.class));
            assertTrue(client.attributes.isEmpty());
            client.close();
            assertTrue(client.retiredHandles.isEmpty());
        } finally {
            p.io.shutdownNow();
        }
    }

    @Test
    public void compatibilityModeKeepsFailedDiscoveryGraphAndStillRetiresHandlesOnSuccess() {
        for (boolean preserve : new boolean[] {false, true}) {
            AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
            try {
                GattClient client = new GattClient(p, "gatt-discovery", device(), preserve);
                client.gatt = mock(BluetoothGatt.class);
                BluetoothGattService service = GattTestSupport.service();
                when(client.gatt.getServices()).thenReturn(Collections.singletonList(service));
                client.servicesValid = true;
                client.services(Collections.singletonList(service));
                String original = client.handle(service.getCharacteristics().get(0));
                PluginTestSupport.Sink sink = new PluginTestSupport.Sink();
                p.sink = sink;
                client.callback.onServicesDiscovered(client.gatt, 5);
                Shadows.shadowOf(Looper.getMainLooper()).idle();
                List<?> services = (List<?>) object(sink.values.get(0)).get("services");
                assertEquals(preserve ? 1 : 0, services.size());
                client.callback.onServicesDiscovered(client.gatt, 0);
                assertThrows(
                        IllegalStateException.class,
                        () -> client.get(original, BluetoothGattCharacteristic.class));
            } finally {
                p.io.shutdownNow();
            }
        }
    }

    @Test
    public void detachIsDeliveredBeforeClosingRegistrationsAndEndingTheEventStream() {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            List<String> order = new ArrayList<>();
            GattClient client = new GattClient(a.p, "gatt-detach", device());
            client.gatt = mock(BluetoothGatt.class);
            doAnswer(
                            invocation -> {
                                order.add("close");
                                return null;
                            })
                    .when(client.gatt)
                    .close();
            a.p.gatts.clients.put(client.id, client);
            a.p.sink =
                    new EventChannel.EventSink() {
                        public void success(Object value) {
                            order.add((String) object(value).get("type"));
                        }

                        public void error(String code, String message, Object details) {
                            fail(message);
                        }

                        public void endOfStream() {
                            order.add("done");
                        }
                    };
            a.p.onDetachedFromEngine(a.binding);
            assertEquals(Arrays.asList("onDetachedFromEngine", "done", "close"), order);
            assertTrue(a.p.gatts.clients.isEmpty());
        }
    }

    @Test
    public void reattachingTheSamePluginReopensIoAndDoesNotReplayItsDetach() throws Exception {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            a.p.onDetachedFromEngine(a.binding);
            assertTrue(a.p.io.isShutdown());
            a.p.onAttachedToEngine(a.binding);
            assertEquals(Integer.valueOf(42), a.p.io.submit(() -> 42).get());
            PluginTestSupport.Sink fresh = new PluginTestSupport.Sink();
            a.p.onListen(null, fresh);
            assertTrue(fresh.values.isEmpty());
        }
    }
}
