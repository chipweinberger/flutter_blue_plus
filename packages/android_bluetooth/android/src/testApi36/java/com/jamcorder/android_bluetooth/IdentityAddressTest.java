package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;

import io.flutter.plugin.common.MethodCall;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.Implementation;
import org.robolectric.annotation.Implements;
import org.robolectric.annotation.RealObject;
import org.robolectric.shadow.api.Shadow;
import org.robolectric.shadows.ShadowBluetoothDevice;

import java.util.Map;

@RunWith(RobolectricTestRunner.class)
@Config(
        sdk = 36,
        manifest = Config.NONE,
        shadows = IdentityAddressTest.FrameworkIdentityShadow.class)
public class IdentityAddressTest {
    // The stock shadow supplies a known identity even with Bluetooth disabled.
    // Exercise the real SDK's unknown-identity fallback through the bridge instead.
    @Implements(BluetoothDevice.class)
    public static class FrameworkIdentityShadow extends ShadowBluetoothDevice {
        @RealObject BluetoothDevice realDevice;

        @Implementation(minSdk = 36)
        protected BluetoothDevice.BluetoothAddress getIdentityAddressWithType() {
            return Shadow.directlyOn(
                    realDevice, BluetoothDevice.class, "getIdentityAddressWithType");
        }
    }

    @Test
    public void disabledBluetoothPreservesNullIdentityAddressAndUnknownType() throws Exception {
        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        Shadows.shadowOf(adapter).setEnabled(false);
        BluetoothDevice device = adapter.getRemoteDevice(PluginTestSupport.ADDRESS);
        BluetoothDevice.BluetoothAddress identity = device.getIdentityAddressWithType();
        assertNotNull(identity);
        assertNull(identity.getAddress());
        assertEquals(BluetoothDevice.ADDRESS_TYPE_UNKNOWN, identity.getAddressType());

        AndroidBluetoothPlugin p = new AndroidBluetoothPlugin();
        try {
            p.knownDevices.put(device.getAddress(), device);
            PluginTestSupport.Result result = new PluginTestSupport.Result();
            p.onMethodCall(
                    new MethodCall(
                            "device.identityAddressWithType", map("address", device.getAddress())),
                    result);
            result.await();
            assertNull(result.error);
            Map<?, ?> value = (Map<?, ?>) result.value;
            assertTrue(value.containsKey("address"));
            assertNull(value.get("address"));
            assertEquals(BluetoothDevice.ADDRESS_TYPE_UNKNOWN, value.get("addressType"));
        } finally {
            p.io.shutdownNow();
        }
    }
}
