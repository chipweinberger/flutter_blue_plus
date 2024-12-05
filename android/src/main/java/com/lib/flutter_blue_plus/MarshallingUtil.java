// Copyright 2023, Charles Weinberger, Paul DeMarco & Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus;

import android.annotation.SuppressLint;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.os.Build;
import android.os.ParcelUuid;
import android.util.SparseArray;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class MarshallingUtil {
    @SuppressLint("MissingPermission")
    static HashMap<String, Object> bmScanAdvertisement(BluetoothDevice device, ScanResult result) {

        int min = Integer.MIN_VALUE;

        ScanRecord adv = result.getScanRecord();

        boolean connectable;
        if (Build.VERSION.SDK_INT >= 26) { // Android 8.0, August 2017
            connectable = result.isConnectable();
        } else {
            // Prior to Android 8.0, it is not possible to get if connectable.
            // Previously, we used to check `adv.getAdvertiseFlags() & 0x2` but that
            // returns if the device wants to be *discoverable*, which is not the same thing.
            connectable = true;
        }

        String advName = adv != null ? adv.getDeviceName() : null;
        int txPower = adv != null ? adv.getTxPowerLevel() : min;
        int appearance = adv != null ? getAppearanceFromScanRecord(adv) : 0;
        SparseArray<byte[]> manufData = adv != null ? adv.getManufacturerSpecificData() : null;
        List<ParcelUuid> serviceUuids = adv != null ? adv.getServiceUuids() : null;
        Map<ParcelUuid, byte[]> serviceData = adv != null ? adv.getServiceData() : null;

        // Manufacturer Specific Data
        HashMap<Integer, String> manufDataB = new HashMap<Integer, String>();
        if (manufData != null) {
            for (int i = 0; i < manufData.size(); i++) {
                int key = manufData.keyAt(i);
                byte[] value = manufData.valueAt(i);
                manufDataB.put(key, bytesToHex(value));
            }
        }

        // Service Data
        HashMap<String, Object> serviceDataB = new HashMap<>();
        if (serviceData != null) {
            for (Map.Entry<ParcelUuid, byte[]> entry : serviceData.entrySet()) {
                ParcelUuid key = entry.getKey();
                byte[] value = entry.getValue();
                serviceDataB.put(uuidStr(key.getUuid()), bytesToHex(value));
            }
        }

        // Service UUIDs
        List<String> serviceUuidsB = new ArrayList<String>();
        if (serviceUuids != null) {
            for (ParcelUuid s : serviceUuids) {
                serviceUuidsB.add(uuidStr(s.getUuid()));
            }
        }

        // See: BmScanAdvertisement
        // perf: only add keys if they exists
        HashMap<String, Object> map = new HashMap<>();
        if (device.getAddress() != null) {
            map.put("remote_id", device.getAddress());
        }

        if (device.getName() != null) {
            map.put("platform_name", device.getName());
        }
        if (connectable) {
            map.put("connectable", 1);
        }
        if (advName != null) {
            map.put("adv_name", advName);
        }
        if (txPower != min) {
            map.put("tx_power_level", txPower);
        }
        if (appearance != 0) {
            map.put("appearance", appearance);
        }
        if (manufData != null) {
            map.put("manufacturer_data", manufDataB);
        }
        if (serviceData != null) {
            map.put("service_data", serviceDataB);
        }
        if (serviceUuids != null) {
            map.put("service_uuids", serviceUuidsB);
        }
        if (result.getRssi() != 0) {
            map.put("rssi", result.getRssi());
        }

        return map;
    }

    // See: BmBluetoothDevice
    @SuppressLint("MissingPermission")
    public static HashMap<String, Object> bmBluetoothDevice(BluetoothDevice device) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("platform_name", device.getName());
        return map;
    }

    static HashMap<String, Object> bmBluetoothService(BluetoothDevice device, BluetoothGattService service, BluetoothGatt gatt) {

        List<Object> characteristics = new ArrayList<Object>();
        for (BluetoothGattCharacteristic c : service.getCharacteristics()) {
            characteristics.add(bmBluetoothCharacteristic(device, c, gatt));
        }

        List<Object> includedServices = new ArrayList<Object>();
        for (BluetoothGattService included : service.getIncludedServices()) {
            // service includes itself?
            if (included.getUuid().equals(service.getUuid())) {
                continue; // skip, infinite recursion
            }
            includedServices.add(bmBluetoothService(device, included, gatt));
        }

        // See: BmBluetoothService
        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("service_uuid", uuidStr(service.getUuid()));
        map.put("is_primary", service.getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY ? 1 : 0);
        map.put("characteristics", characteristics);
        map.put("included_services", includedServices);
        return map;
    }

    static HashMap<String, Object> bmBluetoothCharacteristic(BluetoothDevice device, BluetoothGattCharacteristic characteristic, BluetoothGatt gatt) {

        BluetoothGattService primaryService = FlutterBluePlusPlugin.getPrimaryService(gatt, characteristic);

        List<Object> descriptors = new ArrayList<Object>();
        for (BluetoothGattDescriptor d : characteristic.getDescriptors()) {
            descriptors.add(bmBluetoothDescriptor(device, d));
        }

        // See: BmBluetoothCharacteristic
        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("service_uuid", uuidStr(primaryService));
        map.put("characteristic_uuid", uuidStr(characteristic.getUuid()));
        map.put("descriptors", descriptors);
        map.put("properties", bmCharacteristicProperties(characteristic.getProperties()));
        return map;
    }

    // See: BmBluetoothDescriptor
    static HashMap<String, Object> bmBluetoothDescriptor(BluetoothDevice device, BluetoothGattDescriptor descriptor) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("descriptor_uuid", uuidStr(descriptor.getUuid()));
        map.put("characteristic_uuid", uuidStr(descriptor.getCharacteristic().getUuid()));
        map.put("service_uuid", uuidStr(descriptor.getCharacteristic().getService().getUuid()));
        return map;
    }

    // See: BmCharacteristicProperties
    static HashMap<String, Object> bmCharacteristicProperties(int properties) {
        HashMap<String, Object> props = new HashMap<>();
        props.put("broadcast", (properties & 1) != 0 ? 1 : 0);
        props.put("read", (properties & 2) != 0 ? 1 : 0);
        props.put("write_without_response", (properties & 4) != 0 ? 1 : 0);
        props.put("write", (properties & 8) != 0 ? 1 : 0);
        props.put("notify", (properties & 16) != 0 ? 1 : 0);
        props.put("indicate", (properties & 32) != 0 ? 1 : 0);
        props.put("authenticated_signed_writes", (properties & 64) != 0 ? 1 : 0);
        props.put("extended_properties", (properties & 128) != 0 ? 1 : 0);
        props.put("notify_encryption_required", (properties & 256) != 0 ? 1 : 0);
        props.put("indicate_encryption_required", (properties & 512) != 0 ? 1 : 0);
        return props;
    }

    // See: BmConnectionStateEnum
    static int bmConnectionStateEnum(int cs) {
        switch (cs) {
            case BluetoothProfile.STATE_DISCONNECTED:
                return 0;
            case BluetoothProfile.STATE_CONNECTED:
                return 1;
            default:
                return 0;
        }
    }

    // See: BmAdapterStateEnum
    static int bmAdapterStateEnum(int as) {
        switch (as) {
            case BluetoothAdapter.STATE_OFF:
                return 6;
            case BluetoothAdapter.STATE_ON:
                return 4;
            case BluetoothAdapter.STATE_TURNING_OFF:
                return 5;
            case BluetoothAdapter.STATE_TURNING_ON:
                return 3;
            default:
                return 0;
        }
    }

    // See: BmBondStateEnum
    static int bmBondStateEnum(int bs) {
        switch (bs) {
            case BluetoothDevice.BOND_NONE:
                return 0;
            case BluetoothDevice.BOND_BONDING:
                return 1;
            case BluetoothDevice.BOND_BONDED:
                return 2;
            default:
                return 0;
        }
    }

    // See: BmConnectionPriority
    static int bmConnectionPriorityParse(int value) {
        switch (value) {
            case 0:
                return BluetoothGatt.CONNECTION_PRIORITY_BALANCED;
            case 1:
                return BluetoothGatt.CONNECTION_PRIORITY_HIGH;
            case 2:
                return BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER;
            default:
                return BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER;
        }
    }

    public static byte[] hexToBytes(String s) {
        if (s == null) {
            return new byte[0];
        }
        int len = s.length();
        byte[] data = new byte[len / 2];

        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                    + Character.digit(s.charAt(i + 1), 16));
        }

        return data;
    }

    public static String bytesToHex(byte[] bytes) {
        if (bytes == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    static String uuid128(Object uuid) {
        if (!(uuid instanceof UUID) && !(uuid instanceof String)) {
            throw new IllegalArgumentException("input must be UUID or String");
        }

        String s = uuid.toString();

        if (s.length() == 4) {
            // 16-bit uuid
            return String.format("0000%s-0000-1000-8000-00805f9b34fb", s).toLowerCase();
        } else if (s.length() == 8) {
            // 32-bit uuid
            return String.format("%s-0000-1000-8000-00805f9b34fb", s).toLowerCase();
        } else {
            // 128-bit uuid
            return s.toLowerCase();
        }
    }

    // returns shortest representation
    static String uuidStr(Object uuid) {
        String s = uuid128(uuid);
        boolean starts = s.startsWith("0000");
        boolean ends = s.endsWith("-0000-1000-8000-00805f9b34fb");
        if (starts && ends) {
            // 16-bit
            return s.substring(4, 8);
        } else if (ends) {
            // 32-bit
            return s.substring(0, 8);
        } else {
            // 128-bit
            return s;
        }
    }

    static int getAppearanceFromScanRecord(ScanRecord adv) {

        if (Build.VERSION.SDK_INT >= 33) { // Android 13 (August 2022)
            Map<Integer, byte[]> map = adv.getAdvertisingDataMap();
            if (map.containsKey(ScanRecord.DATA_TYPE_APPEARANCE)) {
                byte[] bytes = map.get(ScanRecord.DATA_TYPE_APPEARANCE);
                if (bytes.length == 2) {
                    int loByte = bytes[0] & 0xFF;
                    int hiByte = bytes[1] & 0xFF;
                    return hiByte * 256 + loByte;
                }
            }
            return 0;
        }

        // For API Level 21+
        byte[] bytes = adv.getBytes();

        int n = 0;

        while (n < bytes.length) {

            int fieldLen = bytes[n];

            // no more or malformed data
            if (fieldLen <= 0) {
                break;
            }

            // end of packet
            if (fieldLen + n > bytes.length - 1) {
                break;
            }

            int dataType = bytes[n + 1];

            // no more data
            if (dataType == 0) {
                break;
            }

            // appearance type byte
            if (dataType == 0x19 && fieldLen == 3) {
                int loByte = bytes[n + 2] & 0xFF;
                int hiByte = bytes[n + 3] & 0xFF;
                return hiByte * 256 + loByte;
            }

            n += fieldLen + 1;
        }

        return 0;
    }
}
