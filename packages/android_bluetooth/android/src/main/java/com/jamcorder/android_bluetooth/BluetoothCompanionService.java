package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.companion.*;

/** Presence events use process-local buffering until a Flutter engine listens. */
@android.annotation.TargetApi(33)
public class BluetoothCompanionService extends CompanionDeviceService {
    @Override
    public void onDeviceAppeared(String address) {
        BackgroundEvents.publish("companion", "onDeviceAppeared", map("address", address));
    }

    @Override
    public void onDeviceDisappeared(String address) {
        BackgroundEvents.publish("companion", "onDeviceDisappeared", map("address", address));
    }

    @Override
    public void onDeviceAppeared(AssociationInfo info) {
        BackgroundEvents.publish(
                "companion",
                "onDeviceAppeared",
                map("association", CompanionBridge.association(info)));
    }

    @Override
    public void onDeviceDisappeared(AssociationInfo info) {
        BackgroundEvents.publish(
                "companion",
                "onDeviceDisappeared",
                map("association", CompanionBridge.association(info)));
    }
}
