package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;
import static com.jamcorder.android_bluetooth.PluginTestSupport.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.companion.AssociationInfo;
import android.companion.DevicePresenceEvent;
import android.net.MacAddress;
import android.os.Looper;
import android.os.ParcelUuid;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.android.controller.ServiceController;
import org.robolectric.annotation.Config;

import java.util.List;
import java.util.Map;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 36, manifest = Config.NONE)
public class CompanionPresenceTest {
    private static final int[] EVENTS = {
        DevicePresenceEvent.EVENT_BLE_APPEARED,
        DevicePresenceEvent.EVENT_BLE_DISAPPEARED,
        DevicePresenceEvent.EVENT_BT_CONNECTED,
        DevicePresenceEvent.EVENT_BT_DISCONNECTED,
        DevicePresenceEvent.EVENT_SELF_MANAGED_APPEARED,
        DevicePresenceEvent.EVENT_SELF_MANAGED_DISAPPEARED
    };
    private ServiceController<BluetoothCompanionPresenceService> controller;

    private void idle() {
        Shadows.shadowOf(Looper.getMainLooper()).idle();
    }

    private void publishPresenceEvents(ParcelUuid uuid) {
        int associationId = uuid == null ? 7 : DevicePresenceEvent.NO_ASSOCIATION;
        for (int event : EVENTS)
            controller
                    .get()
                    .onDevicePresenceEvent(new DevicePresenceEvent(associationId, event, uuid));
        idle();
    }

    private void assertPresenceEvents(List<Object> events, ParcelUuid uuid) {
        assertEquals(EVENTS.length, events.size());
        for (int i = 0; i < events.size(); i++) {
            Map<String, Object> event = object(events.get(i));
            assertEquals("companion", event.get("owner"));
            assertEquals("onDevicePresenceEvent", event.get("type"));
            assertEquals(
                    uuid == null ? 7 : DevicePresenceEvent.NO_ASSOCIATION,
                    event.get("associationId"));
            assertEquals(EVENTS[i], event.get("presenceEvent"));
            assertEquals(uuid == null ? null : uuid.toString(), event.get("uuid"));
            assertNotNull(event.get("receivedAtMillis"));
        }
    }

    @Before
    public void setUp() {
        idle();
        BackgroundEvents.pending.clear();
        controller = Robolectric.buildService(BluetoothCompanionPresenceService.class).create();
    }

    @After
    public void tearDown() {
        controller.destroy();
        idle();
        BackgroundEvents.pending.clear();
    }

    @Test
    public void modernPresenceEventsReachLiveAndLaterEngineListeners() {
        for (ParcelUuid uuid :
                new ParcelUuid[] {
                    null, ParcelUuid.fromString("0000180f-0000-1000-8000-00805f9b34fb")
                }) {
            publishPresenceEvents(uuid);
            assertEquals(EVENTS.length, BackgroundEvents.pending.size());
            try (Attached attached = new Attached()) {
                Sink sink = new Sink();
                attached.p.onListen(null, sink);
                assertPresenceEvents(sink.values, uuid);
                assertTrue(BackgroundEvents.pending.isEmpty());
                sink.values.clear();
                publishPresenceEvents(uuid);
                assertPresenceEvents(sink.values, uuid);
                assertTrue(BackgroundEvents.pending.isEmpty());
            }
        }
    }

    @Test
    public void modernServiceAlsoDeliversInheritedLegacyCallbacks() {
        AssociationInfo info = mock(AssociationInfo.class);
        when(info.getId()).thenReturn(7);
        when(info.getDeviceMacAddress()).thenReturn(MacAddress.fromString(ADDRESS));
        BluetoothCompanionPresenceService service = controller.get();
        try (Attached attached = new Attached()) {
            Sink sink = new Sink();
            attached.p.onListen(null, sink);
            service.onDeviceAppeared(ADDRESS);
            service.onDeviceDisappeared(ADDRESS);
            service.onDeviceAppeared(info);
            service.onDeviceDisappeared(info);
            idle();
            assertEquals(4, sink.values.size());
            for (int i = 0; i < sink.values.size(); i++) {
                Map<String, Object> event = object(sink.values.get(i));
                assertEquals("companion", event.get("owner"));
                assertEquals(
                        i % 2 == 0 ? "onDeviceAppeared" : "onDeviceDisappeared", event.get("type"));
                if (i < 2) assertEquals(ADDRESS, event.get("address"));
                else {
                    Map<String, Object> association = object(event.get("association"));
                    assertEquals(7, association.get("id"));
                    assertEquals("aa:bb:cc:dd:ee:ff", association.get("deviceMacAddress"));
                }
            }
        }
    }
}
