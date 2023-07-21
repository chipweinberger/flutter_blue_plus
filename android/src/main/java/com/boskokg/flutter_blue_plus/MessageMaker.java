// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package com.boskokg.flutter_blue_plus;

import android.annotation.TargetApi;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.os.Build;
import android.os.Parcel;
import android.os.ParcelUuid;
import android.util.Log;
import android.util.SparseArray;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Created by bosko on 30/01/22.
 * Updated by outlandnish on 20/06/23.
 */

public class MessageMaker {

    private static final UUID CCCD_UUID = UUID.fromString("000002902-0000-1000-8000-00805f9b34fb");

    private static final char[] HEX_ARRAY = "0123456789ABCDEF".toCharArray();
    public static String toHexString(byte[] bytes) {
        char[] hexChars = new char[bytes.length * 2];
        for (int j = 0; j < bytes.length; j++) {
            int v = bytes[j] & 0xFF;
            hexChars[j * 2] = HEX_ARRAY[v >>> 4];
            hexChars[j * 2 + 1] = HEX_ARRAY[v & 0x0F];
        }
        return new String(hexChars);
    }

    static HashMap<String, Object> bmAdvertisementData(BluetoothDevice device, byte[] advertisementData, int rssi) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("device", bmBluetoothDevice(device));
        if(advertisementData != null && advertisementData.length > 0) {
            map.put("advertisement_data", AdvertisementParser.parse(advertisementData));
        }
        map.put("rssi", rssi);
        return map;
    }

    @TargetApi(21)
    static HashMap<String, Object> bmScanResult(BluetoothDevice device, ScanResult result) {

        ScanRecord scanRecord = result.getScanRecord();

        HashMap<String, Object> advertisementData = new HashMap<>();
        
        // connectable
        if(Build.VERSION.SDK_INT >= 26) {
            advertisementData.put("connectable", result.isConnectable() ? 1 : 0);
        } else if(scanRecord != null) {
            int flags = scanRecord.getAdvertiseFlags();
            advertisementData.put("connectable", (flags & 0x2) > 0 ? 1 : 0);
        }

        if(scanRecord != null) {

            String localName = scanRecord.getDeviceName();

            int txPower = scanRecord.getTxPowerLevel();

            // Manufacturer Specific Data
            SparseArray<byte[]> msd = scanRecord.getManufacturerSpecificData();
            HashMap<Integer, String> msdMap = new HashMap<Integer, String>();
            if(msd != null) {
                for (int i = 0; i < msd.size(); i++) {
                    int key = msd.keyAt(i);
                    byte[] value = msd.valueAt(i);
                    msdMap.put(key, toHexString(value));
                }
            }

            // Service Data
            Map<ParcelUuid, byte[]> serviceData = scanRecord.getServiceData();
            HashMap<String, Object> serviceDataMap = new HashMap<>();
            if(serviceData != null) {
                for (Map.Entry<ParcelUuid, byte[]> entry : serviceData.entrySet()) {
                    ParcelUuid key = entry.getKey();
                    byte[] value = entry.getValue();
                    serviceDataMap.put(key.getUuid().toString(), toHexString(value));
                }
            }

            // Service UUIDs
            List<ParcelUuid> serviceUuids = scanRecord.getServiceUuids();
            List<String> serviceUuidList = new ArrayList<String>();
            if(serviceUuids != null) {
                for (ParcelUuid s : serviceUuids) {
                    serviceUuidList.add(s.getUuid().toString());
                }
            }

            // add to map
            if(localName != null) {
                advertisementData.put("local_name", localName);
            }
            if(txPower != Integer.MIN_VALUE) {
                advertisementData.put("tx_power_level", txPower);
            }
            if(msd != null) {
                advertisementData.put("manufacturer_data", msdMap);
            }
            if(serviceData != null) {
                advertisementData.put("service_data", serviceDataMap);
            }
            if(serviceUuids != null) {
                advertisementData.put("service_uuids", serviceUuidList);
            }
        }

        HashMap<String, Object> map = new HashMap<>();
        map.put("device", bmBluetoothDevice(device));
        map.put("rssi", result.getRssi());
        map.put("advertisement_data", advertisementData);
        return map;
    }

    static HashMap<String, Object> bmBluetoothDevice(BluetoothDevice device) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        if(device.getName() != null) {
            map.put("local_name", device.getName());
        }
        map.put("type", device.getType());
        return map;
    }

    static HashMap<String, Object> bmBluetoothService(BluetoothDevice device, BluetoothGattService service, BluetoothGatt gatt) {

        List<Object> characteristics = new ArrayList<Object>();
        for(BluetoothGattCharacteristic c : service.getCharacteristics()) {
            characteristics.add(bmBluetoothCharacteristic(device, c, gatt));
        }

        List<Object> includedServices = new ArrayList<Object>();
        for(BluetoothGattService s : service.getIncludedServices()) {
            includedServices.add(bmBluetoothService(device, s, gatt));
        }

        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("service_uuid", service.getUuid().toString());
        map.put("is_primary", service.getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY ? 1 : 0);
        map.put("characteristics", characteristics);
        map.put("included_services", includedServices);
        return map;
    }

    static HashMap<String, Object> bmBluetoothCharacteristic(BluetoothDevice device, BluetoothGattCharacteristic characteristic, BluetoothGatt gatt) {

        ServicePair pair = MessageMaker.getServicePair(gatt, characteristic);

        List<Object> descriptors = new ArrayList<Object>();
        for(BluetoothGattDescriptor d : characteristic.getDescriptors()) {
            descriptors.add(bmBluetoothDescriptor(device, d));
        }

        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("service_uuid", pair.primary);
        map.put("secondary_service_uuid", pair.secondary);
        map.put("characteristic_uuid", characteristic.getUuid().toString());
        map.put("descriptors", descriptors);
        map.put("properties", bmCharacteristicProperties(characteristic.getProperties()));
        if(characteristic.getValue() != null) {
            map.put("value", toHexString(characteristic.getValue()));
        }
        return map;
    }

    static HashMap<String, Object> bmBluetoothDescriptor(BluetoothDevice device, BluetoothGattDescriptor descriptor) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("descriptor_uuid", descriptor.getUuid().toString());
        map.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
        map.put("service_uuid", descriptor.getCharacteristic().getService().getUuid().toString());
        if(descriptor.getValue() != null) {
            map.put("value", toHexString(descriptor.getValue()));
        }
        return map;
    }

    static HashMap<String, Object> bmCharacteristicProperties(int properties) {
        HashMap<String, Object> props = new HashMap<>();
        props.put("broadcast",                      (properties & 1)   != 0 ? 1 : 0);
        props.put("read",                           (properties & 2)   != 0 ? 1 : 0);
        props.put("write_without_response",         (properties & 4)   != 0 ? 1 : 0);
        props.put("write",                          (properties & 8)   != 0 ? 1 : 0);
        props.put("notify",                         (properties & 16)  != 0 ? 1 : 0);
        props.put("indicate",                       (properties & 32)  != 0 ? 1 : 0);
        props.put("authenticated_signed_writes",    (properties & 64)  != 0 ? 1 : 0);
        props.put("extended_properties",            (properties & 128) != 0 ? 1 : 0);
        props.put("notify_encryption_required",     (properties & 256) != 0 ? 1 : 0);
        props.put("indicate_encryption_required",   (properties & 512) != 0 ? 1 : 0);
        return props;
    }

    public static class ServicePair {
        public String primary;
        public String secondary;
    }

    static ServicePair getServicePair(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {

        ServicePair result = new ServicePair();

        BluetoothGattService service = characteristic.getService();

        // is this a primary service?
        if(service.getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY) {
            result.primary = service.getUuid().toString();
            return result;
        } 

        // Otherwise, iterate all services until we find the primary service
        for(BluetoothGattService primary : gatt.getServices()) {
            for(BluetoothGattService secondary : primary.getIncludedServices()) {
                if(secondary.getUuid().equals(service.getUuid())) {
                    result.primary = primary.getUuid().toString();
                    result.secondary = secondary.getUuid().toString();
                    return result;
                }
            }
        }

        return result;
    }
}