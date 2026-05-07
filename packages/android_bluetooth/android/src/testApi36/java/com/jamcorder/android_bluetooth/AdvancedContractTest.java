package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.bluetooth.*;
import android.content.Context;
import android.ranging.*;
import android.ranging.raw.*;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.robolectric.*;
import org.robolectric.annotation.Config;

import java.util.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 36, manifest = Config.NONE)
public class AdvancedContractTest {
    @Test
    public void socketSettingsAlwaysSelectLeAndPreserveIndependentSecurityRequirements()
            throws Exception {
        BluetoothSocketSettings settings =
                (BluetoothSocketSettings)
                        SocketBridge.settings(
                                map(
                                        "l2capPsm",
                                        129,
                                        "authenticationRequired",
                                        false,
                                        "encryptionRequired",
                                        true));
        assertEquals(BluetoothSocket.TYPE_LE, settings.getSocketType());
        assertEquals(129, settings.getL2capPsm());
        assertFalse(settings.isAuthenticationRequired());
        assertTrue(settings.isEncryptionRequired());
    }

    @Test
    public void rangingConfigurationPreservesBlePeerAndCentimeterThresholds() {
        Map<String, Object> device =
                map(
                        "uuid",
                        GattTestSupport.UUID_SERVICE.toString(),
                        "bleRssiRangingParams",
                        map("peerBluetoothAddress", "AA:BB:CC:DD:EE:FF", "rangingUpdateRate", 1));
        RangingPreference preference =
                RangingBridge.preference(
                        map(
                                "deviceRole",
                                1,
                                "devices",
                                Collections.singletonList(device),
                                "sessionConfig",
                                map(
                                        "notificationConfigType",
                                        2,
                                        "proximityNearCm",
                                        100,
                                        "proximityFarCm",
                                        200)));
        assertEquals(RangingPreference.DEVICE_ROLE_INITIATOR, preference.getDeviceRole());
        assertEquals(
                100,
                preference.getSessionConfig().getDataNotificationConfig().getProximityNearCm());
        assertThrows(
                IllegalArgumentException.class,
                () ->
                        RangingBridge.preference(
                                map("deviceRole", 0, "devices", Arrays.asList(device, device))));
    }

    @Test
    public void rangingPeerAdditionUsesResponderConfigAndBleRemovalIsExplicitlyUnsupported() {
        try (PluginTestSupport.Attached a = new PluginTestSupport.Attached()) {
            Context context = mock(Context.class);
            RangingManager manager = mock(RangingManager.class);
            when(context.getSystemService(RangingManager.class)).thenReturn(manager);
            a.p.context = context;
            RangingBridge bridge = new RangingBridge(a.p);
            a.p.context = RuntimeEnvironment.getApplication();
            RangingSession session = mock(RangingSession.class);
            bridge.sessions.put("ranging-peer", session);
            String uuid = "12345678-1234-5678-1234-567812345678";
            bridge.handle(
                    "addDevice",
                    map(
                            "id",
                            "ranging-peer",
                            "device",
                            map(
                                    "uuid",
                                    uuid,
                                    "bleRssiRangingParams",
                                    map("peerBluetoothAddress", PluginTestSupport.ADDRESS))),
                    new PluginTestSupport.Result());
            ArgumentCaptor<RangingConfig> config = ArgumentCaptor.forClass(RangingConfig.class);
            verify(session).addDeviceToRangingSession(config.capture());
            assertTrue(config.getValue() instanceof RawResponderRangingConfig);
            assertEquals(
                    UUID.fromString(uuid),
                    ((RawResponderRangingConfig) config.getValue())
                            .getRawRangingDevice()
                            .getRangingDevice()
                            .getUuid());
            UnsupportedOperationException error =
                    assertThrows(
                            UnsupportedOperationException.class,
                            () ->
                                    bridge.handle(
                                            "removeDevice",
                                            map("id", "ranging-peer", "uuid", uuid),
                                            new PluginTestSupport.Result()));
            assertTrue(error.getMessage().contains("UWB multicast"));
            verify(session, never()).removeDeviceFromRangingSession(any());
        }
    }
}
