package com.jamcorder.android_bluetooth;

import android.bluetooth.*;

import java.util.UUID;

/** Shared GATT graphs and UUIDs for native contract and parity tests. */
final class GattTestSupport {
    static final UUID UUID_SERVICE = UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb");
    static final UUID UUID_CHARACTERISTIC = UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb");

    static BluetoothGattCharacteristic characteristic() {
        BluetoothGattCharacteristic c = new BluetoothGattCharacteristic(UUID_CHARACTERISTIC, 18, 1);
        c.addDescriptor(
                new BluetoothGattDescriptor(
                        UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"), 17));
        return c;
    }

    static BluetoothGattService service() {
        BluetoothGattService s = new BluetoothGattService(UUID_SERVICE, 0);
        s.addCharacteristic(characteristic());
        return s;
    }
}
