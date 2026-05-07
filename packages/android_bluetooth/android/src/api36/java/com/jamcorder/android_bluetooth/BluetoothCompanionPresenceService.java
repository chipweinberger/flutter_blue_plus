package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.companion.DevicePresenceEvent;

/** Optional API 36 service; declare this instead of the base service for presence events. */
@android.annotation.TargetApi(36)
public final class BluetoothCompanionPresenceService extends BluetoothCompanionService {
    @Override
    public void onDevicePresenceEvent(DevicePresenceEvent event) {
        BackgroundEvents.publish(
                "companion",
                "onDevicePresenceEvent",
                map(
                        "associationId",
                        event.getAssociationId(),
                        "presenceEvent",
                        event.getEvent(),
                        "uuid",
                        event.getUuid() == null ? null : event.getUuid().toString()));
    }
}
