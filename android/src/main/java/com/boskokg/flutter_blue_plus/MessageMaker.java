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
        HashMap<String, Object> scanResult = new HashMap<>();
        scanResult.put("device", from(device));
        if(advertisementData != null && advertisementData.length > 0)
            scanResult.put("advertisement_data", AdvertisementParser.parse(advertisementData));
        scanResult.put("rssi", rssi);
        return scanResult;
    }

    @TargetApi(21)
    static HashMap<String, Object> bmScanResult(BluetoothDevice device, ScanResult result) {
        HashMap<String, Object> scanResult = new HashMap<>();
        scanResult.put("device", from(device));

        HashMap<String, Object> advertisementData = new HashMap<>();
        ScanRecord scanRecord = result.getScanRecord();
        if(Build.VERSION.SDK_INT >= 26) {
            advertisementData.put("connectable", result.isConnectable());
        } else {
            if(scanRecord != null) {
                int flags = scanRecord.getAdvertiseFlags();
                advertisementData.put("connectable", (flags & 0x2) > 0);
            }
        }
        if(scanRecord != null) {
            String deviceName = scanRecord.getDeviceName();
            if(deviceName != null) {
                advertisementData.put("local_name", deviceName);
            }
            int txPower = scanRecord.getTxPowerLevel();
            if(txPower != Integer.MIN_VALUE) {
                advertisementData.put("tx_power_level", txPower);
            }
            // Manufacturer Specific Data
            SparseArray<byte[]> msd = scanRecord.getManufacturerSpecificData();
            if(msd != null) {
                HashMap<Integer, String> manufacturerData = new HashMap<Integer, String>();
                for (int i = 0; i < msd.size(); i++) {
                    int key = msd.keyAt(i);
                    byte[] value = msd.valueAt(i);
                    manufacturerData.put(key, toHexString(value));
                }
                advertisementData.put("manufacturer_data", manufacturerData);
            }
            // Service Data
            Map<ParcelUuid, byte[]> serviceData = scanRecord.getServiceData();
            if(serviceData != null) {
                HashMap<String, Object> serviceDataMap = new HashMap<>();
                for (Map.Entry<ParcelUuid, byte[]> entry : serviceData.entrySet()) {
                    ParcelUuid key = entry.getKey();
                    byte[] value = entry.getValue();
                    serviceDataMap.put(key.getUuid().toString(), toHexString(value));
                }
                advertisementData.put("service_data", serviceDataMap);
            }
            // Service UUIDs
            List<ParcelUuid> serviceUuids = scanRecord.getServiceUuids();
            if(serviceUuids != null) {
                List<String> serviceUuidList = new ArrayList<String>();
                for (ParcelUuid s : serviceUuids) {
                    serviceUuidList.add(s.getUuid().toString());
                }
                advertisementData.put("service_uuids", serviceUuidList);
            }
        }
        scanResult.put("rssi", result.getRssi());
        scanResult.put("advertisement_data", advertisementData);
        return scanResult;
    }

    static HashMap<String, Object> bmBluetoothDevice(BluetoothDevice device) {
        HashMap<String, Object> dev = new HashMap<>();
        dev.put("remote_id", device.getAddress());
        String name = device.getName();
        if(name != null) {
            dev.put("name", name);
        }
        dev.put("type", device.getType());
        return dev;
    }

    static HashMap<String, Object> bmBluetoothService(BluetoothDevice device, BluetoothGattService service, BluetoothGatt gatt) {
        HashMap<String, Object> dev = new HashMap<>();
        dev.put("remote_id", device.getAddress());
        dev.put("uuid", service.getUuid().toString());
        dev.put("is_primary", service.getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY);
        List<Object> characteristics = new ArrayList<Object>();
        for(BluetoothGattCharacteristic c : service.getCharacteristics()) {
            characteristics.add(bmBluetoothCharacteristic(device, c, gatt));
        }
        dev.put("characteristics", characteristics);
        List<Object> includedServices = new ArrayList<Object>();
        for(BluetoothGattService s : service.getIncludedServices()) {
            includedServices.add(bmBluetoothService(device, s, gatt));
        }
        dev.put("included_services", includedServices);
        return dev;
    }

    static HashMap<String, Object> bmBluetoothCharacteristic(BluetoothDevice device, BluetoothGattCharacteristic characteristic, BluetoothGatt gatt) {
        HashMap<String, Object> ch = new HashMap<>();
        ch.put("remote_id", device.getAddress());
        ch.put("uuid", characteristic.getUuid().toString());
        ch.put("properties", from(characteristic.getProperties()));
        if(characteristic.getValue() != null) {
            ch.put("value", toHexString(characteristic.getValue()));
        }
        List<Object> descriptors = new ArrayList<Object>();
        for(BluetoothGattDescriptor d : characteristic.getDescriptors()) {
            descriptors.add(bmBluetoothDescriptor(device, d));
        }
        ch.put("descriptors", descriptors);
        if(characteristic.getService().getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY) {
            ch.put("service_uuid", characteristic.getService().getUuid().toString());
        } else {
            // Reverse search to find service
            for(BluetoothGattService s : gatt.getServices()) {
                for(BluetoothGattService ss : s.getIncludedServices()) {
                    if(ss.getUuid().equals(characteristic.getService().getUuid())){
                        ch.put("service_uuid", s.getUuid().toString());
                        ch.put("secondary_service_uuid", ss.getUuid().toString());
                        break;
                    }
                }
            }
        }
        return ch;
    }

    static HashMap<String, Object> bmBluetoothDescriptor(BluetoothDevice device, BluetoothGattDescriptor descriptor) {
        HashMap<String, Object> desc = new HashMap<>();
        desc.put("remote_id", device.getAddress());
        desc.put("uuid", descriptor.getUuid().toString());
        desc.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
        desc.put("service_uuid", descriptor.getCharacteristic().getService().getUuid().toString());
        if(descriptor.getValue() != null) {
            desc.put("value", toHexString(descriptor.getValue()));
        }
        return desc;
    }

    static HashMap<String, Object> bmCharacteristicProperties(int properties) {
        HashMap<String, Object> props = new HashMap<>();
        props.put("broadcast", (properties & 1) != 0);
        props.put("read", (properties & 2) != 0);
        props.put("write_without_response", (properties & 4) != 0);
        props.put("write", (properties & 8) != 0);
        props.put("notify", (properties & 16) != 0);
        props.put("indicate", (properties & 32) != 0);
        props.put("authenticated_signed_writes", (properties & 64) != 0);
        props.put("extended_properties", (properties & 128) != 0);
        props.put("notify_encryption_required", (properties & 256) != 0);
        props.put("indicate_encryption_required", (properties & 512) != 0);
        return props;
    }

    static HashMap<String, Object> bmConnectionStateResponse(BluetoothDevice device, int state) {
        HashMap<String, Object> deviceState = new HashMap<>();
        deviceState.put("state", state);
        deviceState.put("remote_id", device.getAddress());
        return deviceState;
    }
}