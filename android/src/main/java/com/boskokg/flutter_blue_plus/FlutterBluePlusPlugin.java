// Copyright 2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package com.boskokg.flutter_blue_plus;

import android.Manifest;
import android.annotation.TargetApi;
import android.app.Application;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothStatusCodes;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanSettings;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;
import android.util.Log;
import android.util.SparseArray;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentHashMap;
import java.io.StringWriter;
import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

import java.lang.reflect.Method;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener;

public class FlutterBluePlusPlugin implements
    FlutterPlugin,
    MethodCallHandler,
    RequestPermissionsResultListener,
    ActivityAware
{
    private static final String TAG = "[FBP-Android]";

    private LogLevel logLevel = LogLevel.DEBUG;

    private Context context;
    private MethodChannel methodChannel;
    private static final String NAMESPACE = "flutter_blue_plus";

    private BluetoothManager mBluetoothManager;
    private BluetoothAdapter mBluetoothAdapter;

    private FlutterPluginBinding pluginBinding;
    private ActivityPluginBinding activityBinding;

    static final private UUID CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    private final Map<String, BluetoothGatt> mConnectedDevices = new ConcurrentHashMap<>();
    private final Map<String, Integer> mConnectionState = new ConcurrentHashMap<>();
    private final Map<String, BondState> mBondState = new ConcurrentHashMap<>();
    private final Map<String, Integer> mMtu = new ConcurrentHashMap<>();

    private int lastEventId = 1452;
    private final Map<Integer, OperationOnPermission> operationsOnPermission = new HashMap<>();

    private final int enableBluetoothRequestCode = 1879842617;

    private interface OperationOnPermission {
        void op(boolean granted, String permission);
    }

    public FlutterBluePlusPlugin() {}

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding)
    {
        Log.d(TAG, "onAttachedToEngine");

        pluginBinding = flutterPluginBinding;

        this.context = (Application) pluginBinding.getApplicationContext();

        methodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), NAMESPACE + "/methods");
        methodChannel.setMethodCallHandler(this);

        IntentFilter filterAdapter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
        this.context.registerReceiver(mBluetoothAdapterStateReceiver, filterAdapter);

        IntentFilter filterBond = new IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED);
        this.context.registerReceiver(mBluetoothBondStateReceiver, filterBond);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding)
    {
        Log.d(TAG, "onDetachedFromEngine");

        pluginBinding = null;

        closeAllConnections();

        context.unregisterReceiver(mBluetoothBondStateReceiver);
        context.unregisterReceiver(mBluetoothAdapterStateReceiver);
        context = null;

        methodChannel.setMethodCallHandler(null);
        methodChannel = null;

        mBluetoothAdapter = null;
        mBluetoothManager = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding)
    {
        Log.d(TAG, "onAttachedToActivity");
        activityBinding = binding;
        activityBinding.addRequestPermissionsResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges()
    {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges");
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding)
    {
        Log.d(TAG, "onReattachedToActivityForConfigChanges");
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity()
    {
        Log.d(TAG, "onDetachedFromActivity");
        activityBinding.removeRequestPermissionsResultListener(this);
        activityBinding = null;
    }

    ////////////////////////////////////////////////////////////
    // ███    ███  ███████  ████████  ██   ██   ██████   ██████
    // ████  ████  ██          ██     ██   ██  ██    ██  ██   ██
    // ██ ████ ██  █████       ██     ███████  ██    ██  ██   ██
    // ██  ██  ██  ██          ██     ██   ██  ██    ██  ██   ██
    // ██      ██  ███████     ██     ██   ██   ██████   ██████
    //
    //  ██████   █████   ██       ██
    // ██       ██   ██  ██       ██
    // ██       ███████  ██       ██
    // ██       ██   ██  ██       ██
    //  ██████  ██   ██  ███████  ███████

    @Override
    public void onMethodCall(@NonNull MethodCall call,
                                 @NonNull Result result)
    {
        try {
            log(LogLevel.DEBUG, "[FBP-Android] onMethodCall: " + call.method);

            // initialize adapter
            if (mBluetoothAdapter == null) {
                log(LogLevel.DEBUG, "[FBP-Android] initializing BluetoothAdapter");
                mBluetoothManager = (BluetoothManager) this.context.getSystemService(Context.BLUETOOTH_SERVICE);
                mBluetoothAdapter = mBluetoothManager != null ? mBluetoothManager.getAdapter() : null;
            }

            // check that we have an adapter, except for 
            // the functions that do not need it
            if(mBluetoothAdapter == null && 
                "setLogLevel".equals(call.method) == false &&
                "isAvailable".equals(call.method) == false &&
                "getAdapterName".equals(call.method) == false &&
                "getAdapterState".equals(call.method) == false) {
                result.error("bluetooth_unavailable", "the device does not have bluetooth", null);
                return;
            }

            switch (call.method) {

                case "setLogLevel":
                {
                    int idx = (int)call.arguments;

                    // set global var
                    logLevel = LogLevel.values()[idx];

                    result.success(null);
                    break;
                }

                case "isAvailable":
                {
                    result.success(mBluetoothAdapter != null);
                    break;
                }

               case "getAdapterName":
                {
                    String adapterName = mBluetoothAdapter != null ? mBluetoothAdapter.getName() : "N/A";
                    result.success(adapterName != null ? adapterName : "");
                    break;
                }

                case "getAdapterState":
                {
                    // get adapterState, if we can
                    int adapterState = -1;
                    try {
                        adapterState = mBluetoothAdapter.getState();
                    } catch (Exception e) {}

                    // see: BmBluetoothAdapterState
                    HashMap<String, Object> map = new HashMap<>();
                    map.put("adapter_state", bmAdapterStateEnum(adapterState));

                    result.success(map);
                    break;
                }

                case "turnOn":
                {
                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    if (Build.VERSION.SDK_INT <= 30) { // Android 11 (September 2020)
                        permissions.add(Manifest.permission.BLUETOOTH);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (mBluetoothAdapter.isEnabled()) {
                            result.success(true); // no work to do
                            return;
                        }

                        Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);

                        activityBinding.getActivity().startActivityForResult(enableBtIntent, enableBluetoothRequestCode);

                        result.success(true);
                        return;
                    });
                    break;
                }

                case "turnOff":
                {
                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    if (Build.VERSION.SDK_INT <= 30) { // Android 11 (September 2020)
                        permissions.add(Manifest.permission.BLUETOOTH);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (mBluetoothAdapter.isEnabled() == false) {
                            result.success(true); // no work to do
                            return;
                        }

                        // this is deprecated in API level 33.
                        boolean disabled = mBluetoothAdapter.disable();

                        result.success(disabled);
                        return;
                    });
                    break;
                }

                case "startScan":
                {
                    ArrayList<String> permissions = new ArrayList<>();

                    // see: BmScanSettings
                    HashMap<String, Object> data = call.arguments();
                    List<String> serviceUuids = (List<String>) data.get("service_uuids");
                    List<String> macAddresses =  (List<String>) data.get("mac_addresses");
                    boolean allowDuplicates =         (boolean) data.get("allow_duplicates");
                    int scanMode =                        (int) data.get("android_scan_mode");
                    boolean usesFineLocation =        (boolean) data.get("android_uses_fine_location");

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_SCAN);
                        if (usesFineLocation) {
                            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
                        }
                    }

                    if (Build.VERSION.SDK_INT <= 30) { // Android 11 (September 2020)
                        permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (granted == false) {
                            result.error("startScan", String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
                        if(scanner == null) {
                            result.error("startScan", String.format("getBluetoothLeScanner() is null. Is the Adapter on?"), null);
                            return;
                        }

                        ScanSettings settings;
                        if (Build.VERSION.SDK_INT >= 26) { // Android 8.0 (August 2017)
                            settings = new ScanSettings.Builder()
                                .setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED)
                                .setLegacy(false)
                                .setScanMode(scanMode)
                                .build();
                        } else {
                            settings = new ScanSettings.Builder()
                                .setScanMode(scanMode).build();
                        }

                        List<ScanFilter> filters = new ArrayList<>();
                        
                        for (int i = 0; i < macAddresses.size(); i++) {
                            String macAddress = macAddresses.get(i);
                            ScanFilter f = new ScanFilter.Builder().setDeviceAddress(macAddress).build();
                            filters.add(f);
                        }

                        for (int i = 0; i < serviceUuids.size(); i++) {
                            String uuid = serviceUuids.get(i);
                            ScanFilter f = new ScanFilter.Builder().setServiceUuid(ParcelUuid.fromString(uuid)).build();
                            filters.add(f);
                        }

                        scanner.startScan(filters, settings, getScanCallback());

                        result.success(null);
                    });
                    break;
                }

                case "stopScan":
                {
                    BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();

                    if(scanner != null) {
                        scanner.stopScan(getScanCallback());
                    }

                    result.success(null);
                    break;
                }

                case "getConnectedSystemDevices":
                {
                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (!granted) {
                            result.error("getConnectedSystemDevices",
                                String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        // this includes devices connected by other apps
                        List<BluetoothDevice> devices = mBluetoothManager.getConnectedDevices(BluetoothProfile.GATT);

                        List<HashMap<String, Object>> devList = new ArrayList<HashMap<String, Object>>();
                        for (BluetoothDevice d : devices) {
                            devList.add(bmBluetoothDevice(d));
                        }

                        HashMap<String, Object> response = new HashMap<>();
                        response.put("devices", devList);

                        result.success(response);
                    });
                    break;
                }

                case "connect":
                {
                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (!granted) {
                            result.error("connect",
                                String.format("FlutterBluePlus requires %s for new connection", perm), null);
                            return;
                        }

                        // see: BmConnectRequest
                        HashMap<String, Object> args = call.arguments();
                        String remoteId =  (String)  args.get("remote_id");
                        boolean autoConnect = ((int) args.get("auto_connect")) != 0;

                        // already connected?
                        if (connectionStateOfThisApp(remoteId) == BluetoothProfile.STATE_CONNECTED) {

                            // see: BmConnectionStateResponse
                            HashMap<String, Object> response = new HashMap<>();
                            response.put("remote_id", remoteId);
                            response.put("connection_state", bmConnectionStateEnum(BluetoothProfile.STATE_CONNECTED));
                            response.put("disconnect_reason_code", null);
                            response.put("disconnect_reason_string", null);

                            // the dart code always waits for this callback
                            invokeMethodUIThread("OnConnectionStateChanged", response);

                            result.success(null);
                            return;
                        } 

                        // connect with new gatt
                        BluetoothGatt gatt;
                        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                        if (Build.VERSION.SDK_INT >= 23) { // Android 6.0 (October 2015)
                            gatt = device.connectGatt(context, autoConnect, mGattCallback, BluetoothDevice.TRANSPORT_LE);
                        } else {
                            gatt = device.connectGatt(context, autoConnect, mGattCallback);
                        }

                        mMtu.put(remoteId, 23); // default minimum mtu
                        mConnectedDevices.put(remoteId, gatt);

                        result.success(null);
                    });
                    break;
                }

                case "disconnect":
                {
                    String remoteId = (String) call.arguments;

                    // already disconnected?
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if (gatt == null) {
                        // see: BmConnectionStateResponse
                        HashMap<String, Object> response = new HashMap<>();
                        response.put("remote_id", remoteId);
                        response.put("connection_state", bmConnectionStateEnum(BluetoothProfile.STATE_DISCONNECTED));
                        response.put("disconnect_reason_code", 0x00);
                        response.put("disconnect_reason_string", "ALREADY_DISCONNECTED");

                        // the dart code always waits for this callback
                        invokeMethodUIThread("OnConnectionStateChanged", response);
                        return;
                    }
                
                    gatt.disconnect();

                    result.success(null);
                    break;
                }

                case "discoverServices":
                {
                    String remoteId = (String) call.arguments;

                    checkAndroid7discoverServicesWorkaround(remoteId);

                    BluetoothGatt gatt = locateGatt(remoteId);

                    if(gatt.discoverServices() == false) {
                        result.error("discover_services", "gatt.discoverServices() returned false", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "readCharacteristic":
                {
                    // see: BmReadCharacteristicRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId =             (String) data.get("remote_id");
                    String serviceUuid =          (String) data.get("service_uuid");
                    String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                    String characteristicUuid =   (String) data.get("characteristic_uuid");

                    BluetoothGatt gatt = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gatt,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_READ) == 0) {
                        result.error("read_characteristic_error",
                            "The READ property is not supported by this BLE characteristic", null);
                        break;
                    }

                    if(gatt.readCharacteristic(characteristic) == false) {
                        result.error("read_characteristic_error",
                            "gatt.readCharacteristic() returned false", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "writeCharacteristic":
                {
                    // see: BmWriteCharacteristicRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId =             (String) data.get("remote_id");
                    String serviceUuid =          (String) data.get("service_uuid");
                    String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                    String characteristicUuid =   (String) data.get("characteristic_uuid");
                    String value =                (String) data.get("value");
                    int writeTypeInt =               (int) data.get("write_type");

                    int writeType = writeTypeInt == 0 ?
                        BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT :
                        BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE;

                    BluetoothGatt gatt = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gatt,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    // check writeable
                    if(writeType == 1) {
                        if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) == 0) {
                            result.error("write_characteristic_error",
                                "The WRITE_NO_RESPONSE property is not supported by this BLE characteristic", null);
                            break;
                        }
                    } else {
                         if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_WRITE) == 0) {
                            result.error("write_characteristic_error",
                                "The WRITE property is not supported by this BLE characteristic", null);
                            break;
                        }
                    }

                    // check mtu
                    int mtu = mMtu.get(remoteId);
                    if ((mtu-3) < hexToBytes(value).length) {
                        String s = "data longer than mtu allows. dataLength: " +
                            hexToBytes(value).length + "> max: " + (mtu-3);
                        result.error("write_characteristic_error", s, null);
                        break;
                    }

                    if (Build.VERSION.SDK_INT >= 33) { // Android 13 (August 2022)

                        int rv = gatt.writeCharacteristic(characteristic, hexToBytes(value), writeType);

                        if (rv != BluetoothStatusCodes.SUCCESS) {
                            String s = "gatt.writeCharacteristic() returned " + rv + " : " + bluetoothStatusString(rv);
                            result.error("write_characteristic_error", s, null);
                            return;
                        }

                    } else {
                        // set value
                        if(!characteristic.setValue(hexToBytes(value))) {
                            result.error("write_characteristic_error", "characteristic.setValue() returned false", null);
                            break;
                        }

                        // Write type
                        characteristic.setWriteType(writeType);

                        // Write Char
                        if(!gatt.writeCharacteristic(characteristic)){
                            result.error("write_characteristic_error", "gatt.writeCharacteristic() returned false", null);
                            break;
                        }
                    }

                    result.success(null);
                    break;
                }

                case "readDescriptor":
                {
                    // see: BmReadDescriptorRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId =             (String) data.get("remote_id");
                    String serviceUuid =          (String) data.get("service_uuid");
                    String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                    String characteristicUuid =   (String) data.get("characteristic_uuid");
                    String descriptorUuid =       (String) data.get("descriptor_uuid");

                    BluetoothGatt gatt = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gatt,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    BluetoothGattDescriptor descriptor = locateDescriptor(characteristic, descriptorUuid);

                    if(gatt.readDescriptor(descriptor) == false) {
                        result.error("read_descriptor_error", "gatt.readDescriptor() returned false", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "writeDescriptor":
                {
                    // see: BmWriteDescriptorRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId =             (String) data.get("remote_id");
                    String serviceUuid =          (String) data.get("service_uuid");
                    String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                    String characteristicUuid =   (String) data.get("characteristic_uuid");
                    String descriptorUuid =       (String) data.get("descriptor_uuid");
                    String value =                (String) data.get("value");

                    BluetoothGatt gatt = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gatt,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    BluetoothGattDescriptor descriptor = locateDescriptor(characteristic, descriptorUuid);

                    // check mtu
                    int mtu = mMtu.get(remoteId);
                    if ((mtu-3) < hexToBytes(value).length) {
                        String s = "data longer than mtu allows. dataLength: " +
                            hexToBytes(value).length + "> max: " + (mtu-3);
                        result.error("write_characteristic_error", s, null);
                        break;
                    }

                    if (Build.VERSION.SDK_INT >= 33) { // Android 13 (August 2022)

                        int rv = gatt.writeDescriptor(descriptor, hexToBytes(value));

                        if (rv != BluetoothStatusCodes.SUCCESS) {
                            String s = "gatt.writeDescriptor() returned " + rv + " : " + bluetoothStatusString(rv);
                            result.error("write_characteristic_error", s, null);
                            return;
                        }

                    } else {

                        // Set descriptor
                        if(!descriptor.setValue(hexToBytes(value))){
                            result.error("write_descriptor_error", "descriptor.setValue() returned false", null);
                            break;
                        }

                        // Write descriptor
                        if(!gatt.writeDescriptor(descriptor)){
                            result.error("write_descriptor_error", "gatt.writeDescriptor() returned false", null);
                            break;
                        }
                    }

                    result.success(null);
                    break;
                }

                case "setNotification":
                {
                    // see: BmSetNotificationRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId =             (String) data.get("remote_id");
                    String serviceUuid =          (String) data.get("service_uuid");
                    String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                    String characteristicUuid =   (String) data.get("characteristic_uuid");
                    boolean enable =             (boolean) data.get("enable");

                    BluetoothGatt gatt = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gatt,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    // configure local Android device to listen for characteristic changes
                    if(!gatt.setCharacteristicNotification(characteristic, enable)){
                        result.error("set_notification_error",
                            "gatt.setCharacteristicNotification(" + enable + ") returned false", null);
                        break;
                    }

                    BluetoothGattDescriptor cccDescriptor = characteristic.getDescriptor(CCCD_UUID);
                    if(cccDescriptor == null) {
                        // Some ble devices do not actually need their CCCD updated.
                        // thus setCharacteristicNotification() is all that is required to enable notifications.
                        // The arduino "bluno" devices are an example.
                        String chr = characteristic.getUuid().toString();
                        log(LogLevel.WARNING, "[FBP-Android] CCCD descriptor for characteristic not found: " + chr);
                        result.success(null);
                        return;
                    }

                    byte[] descriptorValue = null;

                    // determine value
                    if(enable) {

                        boolean canNotify = (characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) > 0;
                        boolean canIndicate = (characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) > 0;

                        if(!canIndicate && !canNotify) {
                            result.error("set_notification_error",
                                "neither NOTIFY nor INDICATE properties are supported by this BLE characteristic", null);
                            break;
                        }

                        // If a characteristic supports both notifications and indications,
                        // we'll use notifications. This matches how CoreBluetooth works on iOS.
                        if(canIndicate) {descriptorValue = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE;}
                        if(canNotify)   {descriptorValue = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE;}

                    } else {
                        descriptorValue  = BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE;
                    }

                    if (!cccDescriptor.setValue(descriptorValue)) {
                        result.error("set_notification_error", "cccDescriptor.setValue() returned false", null);
                        break;
                    }

                    // update notifications on remote BLE device
                    if (!gatt.writeDescriptor(cccDescriptor)) {
                        result.error("set_notification_error", "gatt.writeDescriptor() returned false", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "requestMtu":
                {
                    // see: BmMtuChangeRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId = (String) data.get("remote_id");
                    int mtu =            (int) data.get("mtu");

                    BluetoothGatt gatt = locateGatt(remoteId);

                    if(gatt.requestMtu(mtu) == false) {
                        result.error("request_mtu", "gatt.requestMtu() returned false", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "readRssi":
                {
                    String remoteId = (String) call.arguments;

                    BluetoothGatt gatt = locateGatt(remoteId);

                    if(gatt.readRemoteRssi() == false) {
                        result.error("read_rssi", "gatt.readRemoteRssi() returned false", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "requestConnectionPriority":
                {
                    // see: BmConnectionPriorityRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId =     (String) data.get("remote_id");
                    int connectionPriority = (int) data.get("connection_priority");

                    BluetoothGatt gatt = locateGatt(remoteId);

                    int cpInteger = bmConnectionPriorityParse(connectionPriority);

                    if(gatt.requestConnectionPriority(cpInteger) == false) {
                        result.error("request_connection_priority", "gatt.requestConnectionPriority() returned false", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "setPreferredPhy":
                {
                    if(Build.VERSION.SDK_INT < 26) { // Android 8.0 (August 2017)
                        result.error("setPreferredPhy",
                            "Only supported on devices >= API 26. This device == " +
                            Build.VERSION.SDK_INT, null);
                        break;
                    }

                    // see: BmPreferredPhy
                    HashMap<String, Object> data = call.arguments();
                    String remoteId = (String) data.get("remote_id");
                    int txPhy =          (int) data.get("tx_phy");
                    int rxPhy =          (int) data.get("rx_phy");
                    int phyOptions =     (int) data.get("phy_options");

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
                        result.error("set_preferred_phy", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gatt = locateGatt(remoteId);

                    gatt.setPreferredPhy(txPhy, rxPhy, phyOptions);

                    result.success(null);
                    break;
                }

                case "getBondedDevices":
                {
                    final Set<BluetoothDevice> bondedDevices = mBluetoothAdapter.getBondedDevices();

                    List<HashMap<String,Object>> devList = new ArrayList<HashMap<String,Object>>();
                    for (BluetoothDevice d : bondedDevices) {
                        devList.add(bmBluetoothDevice(d));
                    }

                    HashMap<String, Object> response = new HashMap<String, Object>();
                    response.put("devices", devList);

                    result.success(response);
                    break;
                }

                case "createBond":
                {
                    String remoteId = (String) call.arguments;

                    // check connected
                    int cs = connectionStateOfThisApp(remoteId);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
                        result.error("createBond", "you must call connect() first", null);
                        return;
                    }

                    // get bond state
                    BondState bs = mBondState.get(remoteId) != null ? mBondState.get(remoteId) : BondState.NONE;

                    // already bonded?
                    if (bs == BondState.BONDED) {

                        // see: BmBondStateResponse
                        HashMap<String, Object> response = new HashMap<>();
                        response.put("remote_id", remoteId);
                        response.put("bond_state", bmBondStateEnum(bs));

                        // the dart code always waits on this
                        invokeMethodUIThread("OnBondStateChanged", response);

                        result.success(true); // no work to do
                        break;
                    }

                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);

                    // bond
                    if(device.createBond() == false) {
                        result.error("createBond", "device.createBond() returned false", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "removeBond":
                {
                    String remoteId = (String) call.arguments;
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);

                    // get bond state
                    BondState bs = mBondState.get(remoteId) != null ? mBondState.get(remoteId) : BondState.NONE;

                    // already unbonded?
                    if (bs == BondState.NONE || bs == BondState.LOST) {

                        // see: BmBondStateResponse
                        HashMap<String, Object> response = new HashMap<>();
                        response.put("remote_id", remoteId);
                        response.put("bond_state", bmBondStateEnum(bs));

                        // the dart code always waits on this
                        invokeMethodUIThread("OnBondStateChanged", response);

                        result.success(true); // no work to do
                        break;
                    }

                    Method removeBondMethod = device.getClass().getMethod("removeBond");
                    boolean rv = (boolean) removeBondMethod.invoke(device);
                    if(rv == false) {
                        result.error("removeBond", "device.removeBond() returned false", null);
                        break;
                    }

                    result.success(true);
                    break;
                }

                case "clearGattCache":
                {
                    String remoteId = (String) call.arguments;

                    BluetoothGatt gatt = locateGatt(remoteId);

                    final Method refreshMethod = gatt.getClass().getMethod("refresh");
                    if (refreshMethod == null) {
                        result.error("clearGattCache", "unsupported on this android version", null);
                        break;
                    }

                    refreshMethod.invoke(gatt);

                    result.success(null);
                    break;
                }

                default:
                {
                    result.notImplemented();
                    break;
                }
            }
        } catch (Exception e) {
            StringWriter sw = new StringWriter();
            PrintWriter pw = new PrintWriter(sw);
            e.printStackTrace(pw);
            String stackTrace = sw.toString();
            result.error("androidException", e.toString(), stackTrace);
            return;
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////
    // ██████   ███████  ██████   ███    ███  ██  ███████  ███████  ██   ██████   ███    ██
    // ██   ██  ██       ██   ██  ████  ████  ██  ██       ██       ██  ██    ██  ████   ██
    // ██████   █████    ██████   ██ ████ ██  ██  ███████  ███████  ██  ██    ██  ██ ██  ██
    // ██       ██       ██   ██  ██  ██  ██  ██       ██       ██  ██  ██    ██  ██  ██ ██
    // ██       ███████  ██   ██  ██      ██  ██  ███████  ███████  ██   ██████   ██   ████

    @Override
    public boolean onRequestPermissionsResult(int requestCode,
                                         String[] permissions,
                                            int[] grantResults)
    {
        OperationOnPermission operation = operationsOnPermission.get(requestCode);

        if (operation != null && grantResults.length > 0) {
            operation.op(grantResults[0] == PackageManager.PERMISSION_GRANTED, permissions[0]);
            return true;
        } else {
            return false;
        }
    }

    private void ensurePermissions(List<String> permissions, OperationOnPermission operation)
    {
        // only request permission we don't already have
        List<String> permissionsNeeded = new ArrayList<>();
        for (String permission : permissions) {
            if (permission != null && ContextCompat.checkSelfPermission(context, permission)
                    != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(permission);
            }
        }

        // no work to do?
        if (permissionsNeeded.isEmpty()) {
            operation.op(true, null);
            return;
        }

        askPermission(permissionsNeeded, operation);
    }

    private void askPermission(List<String> permissionsNeeded, OperationOnPermission operation)
    {
        // finished asking for permission? call callback
        if (permissionsNeeded.isEmpty()) {
            operation.op(true, null);
            return;
        }

        String nextPermission = permissionsNeeded.remove(0);

        operationsOnPermission.put(lastEventId, (granted, perm) -> {
            operationsOnPermission.remove(lastEventId);
            if (!granted) {
                operation.op(false, perm);
                return;
            }
            // recursively ask for next permission
            askPermission(permissionsNeeded, operation);
        });

        ActivityCompat.requestPermissions(
                activityBinding.getActivity(),
                new String[]{nextPermission},
                lastEventId);

        lastEventId++;
    }

    //////////////////////////////////////////////
    // ██████   ██       ███████
    // ██   ██  ██       ██
    // ██████   ██       █████
    // ██   ██  ██       ██
    // ██████   ███████  ███████
    //
    // ██    ██  ████████  ██  ██       ███████
    // ██    ██     ██     ██  ██       ██
    // ██    ██     ██     ██  ██       ███████
    // ██    ██     ██     ██  ██            ██
    //  ██████      ██     ██  ███████  ███████

    private int connectionStateOfThisApp(String remoteId)
    {
        // other apps may be connected to the device.
        // so we are careful to only check our connection state
        if(mConnectionState.get(remoteId) == null) {
            return BluetoothProfile.STATE_DISCONNECTED;
        } else {
            return mConnectionState.get(remoteId);
        }
    }

    private BluetoothGatt locateGatt(String remoteId) throws Exception
    {
        BluetoothGatt gatt = mConnectedDevices.get(remoteId);
        if(gatt == null) {
            throw new Exception("locateGatt failed. have you connected first?");
        }
        return gatt;
    }

    private BluetoothGattCharacteristic locateCharacteristic(BluetoothGatt gatt,
                                                                    String serviceId,
                                                                    String secondaryServiceId,
                                                                    String characteristicId)
                                                                    throws Exception
    {
        BluetoothGattService primaryService = gatt.getService(UUID.fromString(serviceId));

        if(primaryService == null) {
            throw new Exception("service not found on this device \n" +
                "service: "+ serviceId);
        }

        BluetoothGattService secondaryService = null;

        if(secondaryServiceId != null && secondaryServiceId.length() > 0) {

            for(BluetoothGattService s : primaryService.getIncludedServices()){
                if(s.getUuid().equals(UUID.fromString(secondaryServiceId))){
                    secondaryService = s;
                }
            }

            if(secondaryService == null) {
                throw new Exception("secondaryService not found on this device \n" +
                    "secondaryService: " + secondaryServiceId);
            }
        }

        BluetoothGattService service = (secondaryService != null) ?
            secondaryService :
            primaryService;

        BluetoothGattCharacteristic characteristic =
            service.getCharacteristic(UUID.fromString(characteristicId));

        if(characteristic == null) {
            throw new Exception("characteristic not found in service \n" +
                "characteristic: " + characteristicId + " \n" +
                "service: "+ serviceId);
        }

        return characteristic;
    }

    private BluetoothGattDescriptor locateDescriptor(BluetoothGattCharacteristic characteristic,
                                                                          String descriptorId) throws Exception
    {
        BluetoothGattDescriptor descriptor = characteristic.getDescriptor(UUID.fromString(descriptorId));

        if(descriptor == null) {
            throw new Exception("descriptor not found on this characteristic \n" +
                "descriptor: " + descriptorId + " \n" +
                "characteristic: " + characteristic.getUuid().toString());
        }

        return descriptor;
    }

    private BondState bondState(int cur, int prev) {
        BondState bs = BondState.NONE;
        switch(cur) {
            case BluetoothDevice.BOND_NONE:
                if (prev == BluetoothDevice.BOND_BONDING) {
                    return BondState.FAILED;
                }
                if (prev == BluetoothDevice.BOND_BONDED) {
                    return BondState.LOST;
                }
                return BondState.NONE;
            case BluetoothDevice.BOND_BONDING: bs = BondState.BONDING;
            case BluetoothDevice.BOND_BONDED: bs = BondState.BONDED;
            default: return BondState.NONE;
        }
    }           

    private void closeAllConnections()
    {
        for (BluetoothGatt gatt : mConnectedDevices.values()) {
            if(gatt != null) {
                String remoteId = gatt.getDevice().getAddress();
                Log.d(TAG, "calling disconnect() on device: " + remoteId);
                Log.d(TAG, "calling gatt.close() on device: " + remoteId);
                gatt.disconnect();
                gatt.close();
            }
        }
        mConnectedDevices.clear();
        mConnectionState.clear();
        mBondState.clear();
        mMtu.clear();
    }

    private void checkAndroid7discoverServicesWorkaround(String remoteId) throws InterruptedException
    {
        // on Android 7.1 and below, discoverServices will fail if called
        // too quickly after bonding completes. For simplicity, we always delay when bonded.
        // see: https://github.com/weliem/blessed-android
        // see: https://medium.com/@martijn.van.welie/making-android-ble-work-part-2-47a3cdaade07
        if (Build.VERSION.SDK_INT <= 25) { // Android 7.1 (October 2016)
            if (mBondState.get(remoteId) != null && mBondState.get(remoteId) == BondState.BONDED) {
                log(LogLevel.WARNING, "[FBP-Android] waiting 1.5s before calling discoverServices to workaround android 7 bug");
                Thread.sleep(1500); // sleep 1500ms
            }
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //  █████   ██████    █████   ██████   ████████  ███████  ██████
    // ██   ██  ██   ██  ██   ██  ██   ██     ██     ██       ██   ██
    // ███████  ██   ██  ███████  ██████      ██     █████    ██████
    // ██   ██  ██   ██  ██   ██  ██          ██     ██       ██   ██
    // ██   ██  ██████   ██   ██  ██          ██     ███████  ██   ██
    //
    // ██████   ███████   ██████  ███████  ██  ██    ██  ███████  ██████
    // ██   ██  ██       ██       ██       ██  ██    ██  ██       ██   ██
    // ██████   █████    ██       █████    ██  ██    ██  █████    ██████
    // ██   ██  ██       ██       ██       ██   ██  ██   ██       ██   ██
    // ██   ██  ███████   ██████  ███████  ██    ████    ███████  ██   ██

    private final BroadcastReceiver mBluetoothAdapterStateReceiver = new BroadcastReceiver()
    {
        @Override
        public void onReceive(Context context, Intent intent)
        {
            final String action = intent.getAction();

            // no change?
            if (action == null || BluetoothAdapter.ACTION_STATE_CHANGED.equals(action) == false) {
                return;
            }

            final int adapterState = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR);

            log(LogLevel.DEBUG, "[FBP-Android] OnAdapterStateChanged: " + adapterStateString(adapterState));

            // close all connections
            if (adapterState == BluetoothAdapter.STATE_TURNING_OFF || 
                adapterState == BluetoothAdapter.STATE_OFF) {
                closeAllConnections();
            }
            
            // see: BmBluetoothAdapterState
            HashMap<String, Object> map = new HashMap<>();
            map.put("adapter_state", bmAdapterStateEnum(adapterState));

            invokeMethodUIThread("OnAdapterStateChanged", map);
        }
    };

    /////////////////////////////////////////////////////////////////////////////////////
    // ██████    ██████   ███    ██  ██████
    // ██   ██  ██    ██  ████   ██  ██   ██
    // ██████   ██    ██  ██ ██  ██  ██   ██
    // ██   ██  ██    ██  ██  ██ ██  ██   ██
    // ██████    ██████   ██   ████  ██████
    //
    // ██████   ███████   ██████  ███████  ██  ██    ██  ███████  ██████
    // ██   ██  ██       ██       ██       ██  ██    ██  ██       ██   ██
    // ██████   █████    ██       █████    ██  ██    ██  █████    ██████
    // ██   ██  ██       ██       ██       ██   ██  ██   ██       ██   ██
    // ██   ██  ███████   ██████  ███████  ██    ████    ███████  ██   ██

    private enum BondState {
        NONE,
        BONDING,
        BONDED,
        FAILED,
        LOST,
    }

    private final BroadcastReceiver mBluetoothBondStateReceiver = new BroadcastReceiver()
    {
        @Override
        public void onReceive(Context context, Intent intent)
        {
            final String action = intent.getAction();

            // no change?
            if (action == null || action.equals(BluetoothDevice.ACTION_BOND_STATE_CHANGED) == false) {
                return;
            }

            final BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);

            final int cur = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR);
            final int prev = intent.getIntExtra(BluetoothDevice.EXTRA_PREVIOUS_BOND_STATE, -1);

            log(LogLevel.DEBUG, "[FBP-Android] OnBondStateChanged: " + bondStateString(cur) + " prev: " + bondStateString(prev));

            String remoteId = device.getAddress();

            BondState bs = bondState(cur, prev);

            // remember state
            mBondState.put(remoteId, bs);

            // see: BmBondStateResponse
            HashMap<String, Object> map = new HashMap<>();
            map.put("remote_id", remoteId);
            map.put("bond_state", bmBondStateEnum(bs));

            invokeMethodUIThread("OnBondStateChanged", map);

            // lost bond. Peripherals can typically store keys for only 1 bond and will delete
            // keys to previously bonded phones on new connections. Android does not handle
            // this case very well, and we must disconnect in order to force re-bonding.
            // see: https://github.com/weliem/blessed-android
            // see: https://medium.com/@martijn.van.welie/making-android-ble-work-part-4-72a0b85cb442
            if (bs == BondState.LOST) {
                BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                if(gatt != null) {
                    log(LogLevel.WARNING, "[FBP-Android] bond lost. we must reconnect");
                    // It seems to take 1 second for the Bluetooth stack to fully update its internal administration. 
                    // So if you lose a bond, disconnect + reconnect immediately, Android will tell you the
                    // device is still bonded but it it won’t fully work, So wait 1 second before disconnecting and reconnecting.
                    Timer timer = new Timer();
                    timer.schedule(new TimerTask() {
                        @Override
                        public void run() {
                            gatt.disconnect();
                        }
                    }, 1000);
                }
            }
        }
    };

    /////////////////////////////////////////////////////////////////////////////
    // ███████   ██████   █████   ███    ██
    // ██       ██       ██   ██  ████   ██
    // ███████  ██       ███████  ██ ██  ██
    //      ██  ██       ██   ██  ██  ██ ██
    // ███████   ██████  ██   ██  ██   ████
    //
    //  ██████   █████   ██       ██       ██████    █████    ██████  ██   ██
    // ██       ██   ██  ██       ██       ██   ██  ██   ██  ██       ██  ██
    // ██       ███████  ██       ██       ██████   ███████  ██       █████
    // ██       ██   ██  ██       ██       ██   ██  ██   ██  ██       ██  ██
    //  ██████  ██   ██  ███████  ███████  ██████   ██   ██   ██████  ██   ██

    private ScanCallback scanCallback;

    @TargetApi(21)
    private ScanCallback getScanCallback()
    {
        if(scanCallback == null) {

            scanCallback = new ScanCallback()
            {
                @Override
                public void onScanResult(int callbackType, ScanResult result)
                {
                    log(LogLevel.VERBOSE, "[FBP-Android] onScanResult");

                    super.onScanResult(callbackType, result);

                    BluetoothDevice device = result.getDevice();

                    // see BmScanResult
                    HashMap<String, Object> rr = bmScanResult(device, result);

                    // see BmScanResponse
                    HashMap<String, Object> response = new HashMap<>();
                    response.put("result", rr);

                    invokeMethodUIThread("OnScanResponse", response);
                }

                @Override
                public void onBatchScanResults(List<ScanResult> results)
                {
                    super.onBatchScanResults(results);
                }

                @Override
                public void onScanFailed(int errorCode)
                {
                    log(LogLevel.ERROR, "[FBP-Android] onScanFailed: " + scanFailedString(errorCode));

                    super.onScanFailed(errorCode);

                    // see: BmScanFailed
                    HashMap<String, Object> failed = new HashMap<>();
                    failed.put("success", 0);
                    failed.put("error_code", errorCode);
                    failed.put("error_string", scanFailedString(errorCode));

                    // see BmScanResponse
                    HashMap<String, Object> response = new HashMap<>();
                    response.put("failed", failed);

                    invokeMethodUIThread("OnScanResponse", response);
                }
            };
        }
        return scanCallback;
    }

    /////////////////////////////////////////////////////////////////////////////
    //  ██████    █████   ████████  ████████
    // ██        ██   ██     ██        ██
    // ██   ███  ███████     ██        ██
    // ██    ██  ██   ██     ██        ██
    //  ██████   ██   ██     ██        ██
    //
    //  ██████   █████   ██       ██       ██████    █████    ██████  ██   ██
    // ██       ██   ██  ██       ██       ██   ██  ██   ██  ██       ██  ██
    // ██       ███████  ██       ██       ██████   ███████  ██       █████
    // ██       ██   ██  ██       ██       ██   ██  ██   ██  ██       ██  ██
    //  ██████  ██   ██  ███████  ███████  ██████   ██   ██   ██████  ██   ██

    private final BluetoothGattCallback mGattCallback = new BluetoothGattCallback()
    {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState)
        {
            log(LogLevel.DEBUG, "[FBP-Android] onConnectionStateChange: status: " + status +
                " (" + hciStatusString(status) + ")" +
                " newState: " + connectionStateString(newState));

            String remoteId = gatt.getDevice().getAddress();

            // remember the connection state of this app
            mConnectionState.put(remoteId, newState);

            // disconnection?
            if(newState == BluetoothProfile.STATE_DISCONNECTED) {

                // mConnectedDevices only keeps a value if our app is connected
                mConnectedDevices.remove(remoteId);

                // it is important to close, otherwise we could run out
                // of bluetooth resources preventing new connections
                gatt.close();
            }

            // see: BmConnectionStateResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", remoteId);
            response.put("connection_state", bmConnectionStateEnum(newState));
            response.put("disconnect_reason_code", status);
            response.put("disconnect_reason_string", hciStatusString(status));

            invokeMethodUIThread("OnConnectionStateChanged", response);
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status)
        {
            log(LogLevel.DEBUG, "[FBP-Android] onServicesDiscovered: count: " + gatt.getServices().size() + " status: " + status);

            List<Object> services = new ArrayList<Object>();
            for(BluetoothGattService s : gatt.getServices()) {
                services.add(bmBluetoothService(gatt.getDevice(), s, gatt));
            }

            // see: BmDiscoverServicesResult
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("services", services);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnDiscoverServicesResult", response);
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic)
        {
            // this callback is only for notifications & indications
            log(LogLevel.DEBUG, "[FBP-Android] onCharacteristicChanged: uuid: " + characteristic.getUuid().toString());

            ServicePair pair = getServicePair(gatt, characteristic);

            // see: BmOnCharacteristicReceived
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("service_uuid", pair.primary);
            response.put("secondary_service_uuid", pair.secondary);
            response.put("characteristic_uuid", characteristic.getUuid().toString());
            response.put("value", bytesToHex(characteristic.getValue()));
            response.put("success", 1);
            response.put("error_code", 0);
            response.put("error_string", gattErrorString(0));

            invokeMethodUIThread("OnCharacteristicReceived", response);
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            // this callback is only for explicit characteristic reads
            log(LogLevel.DEBUG, "[FBP-Android] onCharacteristicRead: uuid: " + characteristic.getUuid().toString() + " status: " + status);

            ServicePair pair = getServicePair(gatt, characteristic);

            // see: BmOnCharacteristicReceived
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("service_uuid", pair.primary);
            response.put("secondary_service_uuid", pair.secondary);
            response.put("characteristic_uuid", characteristic.getUuid().toString());
            response.put("value", bytesToHex(characteristic.getValue()));
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnCharacteristicReceived", response);
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            log(LogLevel.DEBUG, "[FBP-Android] onCharacteristicWrite: uuid: " + characteristic.getUuid().toString() + " status: " + status);

            // For "writeWithResponse", onCharacteristicWrite is called after the remote sends back a write response. 
            // For "writeWithoutResponse", onCharacteristicWrite is called as long as there is still space left 
            // in android's internal buffer. When the buffer is full, it delays calling onCharacteristicWrite 
            // until there is at least ~50% free space again. 

            ServicePair pair = getServicePair(gatt, characteristic);

            // see: BmOnCharacteristicWritten
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("service_uuid", pair.primary);
            response.put("secondary_service_uuid", pair.secondary);
            response.put("characteristic_uuid", characteristic.getUuid().toString());
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnCharacteristicWritten", response);
        }

        @Override
        public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            log(LogLevel.DEBUG, "[FBP-Android] onDescriptorRead: uuid: " + descriptor.getUuid().toString() + " status: " + status);

            ServicePair pair = getServicePair(gatt, descriptor.getCharacteristic());

            // see: BmOnDescriptorResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("type", 0); // type: read
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("service_uuid", pair.primary);
            response.put("secondary_service_uuid", pair.secondary);
            response.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
            response.put("descriptor_uuid", descriptor.getUuid().toString());
            response.put("value", bytesToHex(descriptor.getValue()));
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnDescriptorResponse", response);
        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            log(LogLevel.DEBUG, "[FBP-Android] onDescriptorWrite: uuid: " + descriptor.getUuid().toString() + " status: " + status);

            ServicePair pair = getServicePair(gatt, descriptor.getCharacteristic());

            // see: BmOnDescriptorResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("type", 1); // type: write
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("service_uuid", pair.primary);
            response.put("secondary_service_uuid", pair.secondary);
            response.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
            response.put("descriptor_uuid", descriptor.getUuid().toString());
            response.put("value", bytesToHex(descriptor.getValue()));
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnDescriptorResponse", response);
        }

        @Override
        public void onReliableWriteCompleted(BluetoothGatt gatt, int status)
        {
            log(LogLevel.DEBUG, "[FBP-Android] onReliableWriteCompleted: status: " + status);
        }

        @Override
        public void onReadRemoteRssi(BluetoothGatt gatt, int rssi, int status)
        {
            log(LogLevel.DEBUG, "[FBP-Android] onReadRemoteRssi: rssi: " + rssi + " status: " + status);

            // see: BmReadRssiResult
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("rssi", rssi);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnReadRssiResult", response);
        }

        @Override
        public void onMtuChanged(BluetoothGatt gatt, int mtu, int status)
        {
            log(LogLevel.DEBUG, "[FBP-Android] onMtuChanged: mtu: " + mtu + " status: " + status);

            String remoteId = gatt.getDevice().getAddress();

            // remember mtu
            mMtu.put(remoteId, mtu);

            // see: BmMtuChangedResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", remoteId);
            response.put("mtu", mtu);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnMtuChanged", response);
        }
    }; // BluetoothGattCallback

    //////////////////////////////////////////////////////////////
    // ██████    █████   ██████   ███████  ███████           
    // ██   ██  ██   ██  ██   ██  ██       ██                
    // ██████   ███████  ██████   ███████  █████             
    // ██       ██   ██  ██   ██       ██  ██                
    // ██       ██   ██  ██   ██  ███████  ███████           
    //                                                     
    //                                                     
    //  █████   ██████   ██    ██  ███████  ██████   ████████ 
    // ██   ██  ██   ██  ██    ██  ██       ██   ██     ██    
    // ███████  ██   ██  ██    ██  █████    ██████      ██    
    // ██   ██  ██   ██   ██  ██   ██       ██   ██     ██    
    // ██   ██  ██████     ████    ███████  ██   ██     ██   

    /**
    * Parses packet data into {@link HashMap<String, Object>} structure.
    *
    * @param rawData The scan record data.
    * @return An AdvertisementData proto object.
    * @throws ArrayIndexOutOfBoundsException if the input is truncated.
    */
    HashMap<String, Object> parseAdvertisementData(byte[] rawData) {
        ByteBuffer data = ByteBuffer.wrap(rawData).asReadOnlyBuffer().order(ByteOrder.LITTLE_ENDIAN);
        HashMap<String, Object> response = new HashMap<>();
        boolean seenLongLocalName = false;
        HashMap<String, Object> serviceData = new HashMap<>();
        HashMap<String, Object> manufacturerData = new HashMap<>();
        do {
            int length = data.get() & 0xFF;
            if (length == 0) {
                break;
            }
            if (length > data.remaining()) {
                Log.w(TAG, "parseAdvertisementData: Not enough data.");
                return response;
            }

            int type = data.get() & 0xFF;
            length--;

            switch (type) {
                case 0x08: // Short local name.
                case 0x09: { // Long local name.
                    if (seenLongLocalName) {
                        // Prefer the long name over the short.
                        data.position(data.position() + length);
                        break;
                    }
                    byte[] localName = new byte[length];
                    data.get(localName);
                    try {
                        response.put("local_name", new String(localName, "UTF-8"));
                    } catch (UnsupportedEncodingException e) {}
                    if (type == 0x09) {
                        seenLongLocalName = true;
                    }
                    break;
                }
                case 0x0A: { // Power level.
                    response.put("tx_power_level", data.get());
                    break;
                }
                case 0x16: // Service Data with 16 bit UUID.
                case 0x20: // Service Data with 32 bit UUID.
                case 0x21: { // Service Data with 128 bit UUID.
                    UUID svcUuid;
                    int remainingDataLength = 0;
                    if (type == 0x16 || type == 0x20) {
                        long svcUuidInteger;
                        if (type == 0x16) {
                            svcUuidInteger = data.getShort() & 0xFFFF;
                            remainingDataLength = length - 2;
                        } else {
                            svcUuidInteger = data.getInt() & 0xFFFFFFFF;
                            remainingDataLength = length - 4;
                        }
                        svcUuid = UUID.fromString(String.format("%08x-0000-1000-8000-00805f9b34fb", svcUuidInteger));
                    } else {
                        long msb = data.getLong();
                        long lsb = data.getLong();
                        svcUuid = new UUID(msb, lsb);
                        remainingDataLength = length - 16;
                    }
                    byte[] remainingData = new byte[remainingDataLength];
                    data.get(remainingData);

                    serviceData.put(svcUuid.toString(), remainingData);
                    response.put("service_data", serviceData);
                    break;
                }
                case 0xFF: {// Manufacturer specific data.
                    if(length < 2) {
                        Log.w(TAG, "parseAdvertisementData: Not enough data for Manufacturer specific data.");
                        break;
                    }
                    int manufacturerId = data.getShort();
                    if((length - 2) > 0) {
                        byte[] msd = new byte[length - 2];
                        data.get(msd);
                        manufacturerData.put(Integer.toString(manufacturerId), msd);
                        response.put("manufacturer_data", manufacturerId);
                    }
                    break;
                }
                default: {
                    data.position(data.position() + length);
                    break;
                }
            }
        } while (true);
        return response;
    } 

    //////////////////////////////////////////////////////////////////////
    // ███    ███  ███████   ██████      
    // ████  ████  ██       ██           
    // ██ ████ ██  ███████  ██   ███     
    // ██  ██  ██       ██  ██    ██     
    // ██      ██  ███████   ██████ 
    //     
    // ██   ██  ███████  ██       ██████   ███████  ██████   ███████ 
    // ██   ██  ██       ██       ██   ██  ██       ██   ██  ██      
    // ███████  █████    ██       ██████   █████    ██████   ███████ 
    // ██   ██  ██       ██       ██       ██       ██   ██       ██ 
    // ██   ██  ███████  ███████  ██       ███████  ██   ██  ███████ 


    HashMap<String, Object> bmAdvertisementData(BluetoothDevice device, byte[] advertisementData, int rssi) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("device", bmBluetoothDevice(device));
        if(advertisementData != null && advertisementData.length > 0) {
            map.put("advertisement_data", parseAdvertisementData(advertisementData));
        }
        map.put("rssi", rssi);
        return map;
    }

    @TargetApi(21)
    HashMap<String, Object> bmScanResult(BluetoothDevice device, ScanResult result) {

        ScanRecord scanRecord = result.getScanRecord();

        HashMap<String, Object> advertisementData = new HashMap<>();
        
        // connectable
        if(Build.VERSION.SDK_INT >= 26) { // Android 8.0 (August 2017)
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
                    msdMap.put(key, bytesToHex(value));
                }
            }

            // Service Data
            Map<ParcelUuid, byte[]> serviceData = scanRecord.getServiceData();
            HashMap<String, Object> serviceDataMap = new HashMap<>();
            if(serviceData != null) {
                for (Map.Entry<ParcelUuid, byte[]> entry : serviceData.entrySet()) {
                    ParcelUuid key = entry.getKey();
                    byte[] value = entry.getValue();
                    serviceDataMap.put(key.getUuid().toString(), bytesToHex(value));
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

    HashMap<String, Object> bmBluetoothDevice(BluetoothDevice device) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        if(device.getName() != null) {
            map.put("local_name", device.getName());
        }
        map.put("type", device.getType());
        return map;
    }

    HashMap<String, Object> bmBluetoothService(BluetoothDevice device, BluetoothGattService service, BluetoothGatt gatt) {

        List<Object> characteristics = new ArrayList<Object>();
        for(BluetoothGattCharacteristic c : service.getCharacteristics()) {
            characteristics.add(bmBluetoothCharacteristic(device, c, gatt));
        }

        List<Object> includedServices = new ArrayList<Object>();
        for(BluetoothGattService included : service.getIncludedServices()) {
            // service includes itself?
            if (included.getUuid().equals(service.getUuid())) {
                continue; // skip, infinite recursion
            }
            includedServices.add(bmBluetoothService(device, included, gatt));
        }

        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("service_uuid", service.getUuid().toString());
        map.put("is_primary", service.getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY ? 1 : 0);
        map.put("characteristics", characteristics);
        map.put("included_services", includedServices);
        return map;
    }

    HashMap<String, Object> bmBluetoothCharacteristic(BluetoothDevice device, BluetoothGattCharacteristic characteristic, BluetoothGatt gatt) {

        ServicePair pair = getServicePair(gatt, characteristic);

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
        map.put("value", bytesToHex(characteristic.getValue()));
        return map;
    }

    HashMap<String, Object> bmBluetoothDescriptor(BluetoothDevice device, BluetoothGattDescriptor descriptor) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("descriptor_uuid", descriptor.getUuid().toString());
        map.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
        map.put("service_uuid", descriptor.getCharacteristic().getService().getUuid().toString());
        map.put("value", bytesToHex(descriptor.getValue()));
        return map;
    }

    HashMap<String, Object> bmCharacteristicProperties(int properties) {
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

    static int bmConnectionStateEnum(int cs) {
        switch (cs) {
            case BluetoothProfile.STATE_DISCONNECTED:  return 0;
            case BluetoothProfile.STATE_CONNECTING:    return 1;
            case BluetoothProfile.STATE_CONNECTED:     return 2;
            case BluetoothProfile.STATE_DISCONNECTING: return 3;
            default:                                   return 0;
        }
    }

    static int bmAdapterStateEnum(int as) {
        switch (as) {
            case BluetoothAdapter.STATE_OFF:          return 6;
            case BluetoothAdapter.STATE_ON:           return 4;
            case BluetoothAdapter.STATE_TURNING_OFF:  return 5;
            case BluetoothAdapter.STATE_TURNING_ON:   return 3;
            default:                                  return 0; 
        }
    }

    static int bmBondStateEnum(BondState bs) {
        switch (bs) {
            case NONE:    return 0;
            case BONDING: return 1;
            case BONDED:  return 2;
            case FAILED:  return 3;
            case LOST:    return 4;
            default:                return 0; 
        }
    }

    static int bmConnectionPriorityParse(int value) {
        switch(value) {
            case 0: return BluetoothGatt.CONNECTION_PRIORITY_BALANCED;
            case 1: return BluetoothGatt.CONNECTION_PRIORITY_HIGH;
            case 2: return BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER;
            default: return BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER;
        }
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

    //////////////////////////////////////////
    // ██    ██ ████████  ██  ██       ███████
    // ██    ██    ██     ██  ██       ██
    // ██    ██    ██     ██  ██       ███████
    // ██    ██    ██     ██  ██            ██
    //  ██████     ██     ██  ███████  ███████

    private void log(LogLevel level, String message)
    {
        if(level.ordinal() <= logLevel.ordinal()) {
            Log.d(TAG, message);
        }
    }

    private void invokeMethodUIThread(final String method, HashMap<String, Object> data)
    {
        new Handler(Looper.getMainLooper()).post(() -> {
            //Could already be teared down at this moment
            if (methodChannel != null) {
                methodChannel.invokeMethod(method, data);
            } else {
                Log.w(TAG, "invokeMethodUIThread: tried to call method on closed channel: " + method);
            }
        });
    }

    private static byte[] hexToBytes(String s) {
        if (s == null) {
            return new byte[0];
        }
        int len = s.length();
        byte[] data = new byte[len / 2];

        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                                + Character.digit(s.charAt(i+1), 16));
        }

        return data;
    }

    private static String bytesToHex(byte[] bytes) {
        if (bytes == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    private static String connectionStateString(int cs) {
        switch (cs) {
            case BluetoothProfile.STATE_DISCONNECTED:  return "disconnected";
            case BluetoothProfile.STATE_CONNECTING:    return "connecting";
            case BluetoothProfile.STATE_CONNECTED:     return "connected";
            case BluetoothProfile.STATE_DISCONNECTING: return "disconnecting";
            default:                                   return "UNKNOWN_CONNECTION_STATE (" + cs + ")";
        }
    }

    private static String adapterStateString(int as) {
        switch (as) {
            case BluetoothAdapter.STATE_OFF:          return "off";
            case BluetoothAdapter.STATE_ON:           return "on";
            case BluetoothAdapter.STATE_TURNING_OFF:  return "turningOff";
            case BluetoothAdapter.STATE_TURNING_ON:   return "turningOn";
            default:                                  return "UNKNOWN_ADAPTER_STATE (" + as + ")";
        }
    }

    private static String bondStateString(int bs) {
        switch (bs) {
            case BluetoothDevice.BOND_BONDING: return "bonding";
            case BluetoothDevice.BOND_BONDED:  return "bonded";
            case BluetoothDevice.BOND_NONE:    return "bond-none";
            default:                           return "UNKNOWN_BOND_STATE (" + bs + ")";
        }
    }

    private static String gattErrorString(int value) {
        switch(value) {
            case BluetoothGatt.GATT_SUCCESS                     : return "GATT_SUCCESS";
            case BluetoothGatt.GATT_CONNECTION_CONGESTED        : return "GATT_CONNECTION_CONGESTED";
            case BluetoothGatt.GATT_FAILURE                     : return "GATT_FAILURE";
            case BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION : return "GATT_INSUFFICIENT_AUTHENTICATION";
            case BluetoothGatt.GATT_INSUFFICIENT_AUTHORIZATION  : return "GATT_INSUFFICIENT_AUTHORIZATION";
            case BluetoothGatt.GATT_INSUFFICIENT_ENCRYPTION     : return "GATT_INSUFFICIENT_ENCRYPTION";
            case BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH    : return "GATT_INVALID_ATTRIBUTE_LENGTH";
            case BluetoothGatt.GATT_INVALID_OFFSET              : return "GATT_INVALID_OFFSET";
            case BluetoothGatt.GATT_READ_NOT_PERMITTED          : return "GATT_READ_NOT_PERMITTED";
            case BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED       : return "GATT_REQUEST_NOT_SUPPORTED";
            case BluetoothGatt.GATT_WRITE_NOT_PERMITTED         : return "GATT_WRITE_NOT_PERMITTED";
            default: return "UNKNOWN_GATT_ERROR (" + value + ")";
        }
    }

    private static String bluetoothStatusString(int value) {
        switch(value) {
            case BluetoothStatusCodes.ERROR_BLUETOOTH_NOT_ALLOWED                : return "ERROR_BLUETOOTH_NOT_ALLOWED";
            case BluetoothStatusCodes.ERROR_BLUETOOTH_NOT_ENABLED                : return "ERROR_BLUETOOTH_NOT_ENABLED";
            case BluetoothStatusCodes.ERROR_DEVICE_NOT_BONDED                    : return "ERROR_DEVICE_NOT_BONDED";
            case BluetoothStatusCodes.ERROR_GATT_WRITE_NOT_ALLOWED               : return "ERROR_GATT_WRITE_NOT_ALLOWED";
            case BluetoothStatusCodes.ERROR_GATT_WRITE_REQUEST_BUSY              : return "ERROR_GATT_WRITE_REQUEST_BUSY";
            case BluetoothStatusCodes.ERROR_MISSING_BLUETOOTH_CONNECT_PERMISSION : return "ERROR_MISSING_BLUETOOTH_CONNECT_PERMISSION";
            case BluetoothStatusCodes.ERROR_PROFILE_SERVICE_NOT_BOUND            : return "ERROR_PROFILE_SERVICE_NOT_BOUND";
            case BluetoothStatusCodes.ERROR_UNKNOWN                              : return "ERROR_UNKNOWN";
            //case BluetoothStatusCodes.FEATURE_NOT_CONFIGURED                     : return "FEATURE_NOT_CONFIGURED";
            case BluetoothStatusCodes.FEATURE_NOT_SUPPORTED                      : return "FEATURE_NOT_SUPPORTED";
            case BluetoothStatusCodes.FEATURE_SUPPORTED                          : return "FEATURE_SUPPORTED";
            case BluetoothStatusCodes.SUCCESS                                    : return "SUCCESS";
            default: return "UNKNOWN_BLE_ERROR (" + value + ")";
        }
    }

    private static String scanFailedString(int value) {
        switch(value) {
            case ScanCallback.SCAN_FAILED_ALREADY_STARTED                : return "SCAN_FAILED_ALREADY_STARTED";
            case ScanCallback.SCAN_FAILED_APPLICATION_REGISTRATION_FAILED: return "SCAN_FAILED_APPLICATION_REGISTRATION_FAILED";
            case ScanCallback.SCAN_FAILED_FEATURE_UNSUPPORTED            : return "SCAN_FAILED_FEATURE_UNSUPPORTED";
            case ScanCallback.SCAN_FAILED_INTERNAL_ERROR                 : return "SCAN_FAILED_INTERNAL_ERROR";
            case ScanCallback.SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES      : return "SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES";
            case ScanCallback.SCAN_FAILED_SCANNING_TOO_FREQUENTLY        : return "SCAN_FAILED_SCANNING_TOO_FREQUENTLY";
            default: return "UNKNOWN_SCAN_ERROR (" + value + ")";
        }
    }


    // Defined in the Bluetooth Standard, Volume 1, Part F, 1.3 HCI Error Code, pages 364-377.
    // See https://www.bluetooth.org/docman/handlers/downloaddoc.ashx?doc_id=478726,
    private static String hciStatusString(int value) {
         switch(value) {
            case 0x00: return "SUCCESS";
            case 0x01: return "UNKNOWN_COMMAND"; // The controller does not understand the HCI Command Packet OpCode that the Host sent.
            case 0x02: return "UNKNOWN_CONNECTION_IDENTIFIER"; // The connection identifier used is unknown
            case 0x03: return "HARDWARE_FAILURE"; // A hardware failure has occurred
            case 0x04: return "PAGE_TIMEOUT"; // a page timed out because of the Page Timeout configuration parameter.
            case 0x05: return "AUTHENTICATION_FAILURE"; // Pairing or authentication failed. This could be due to an incorrect PIN or Link Key.
            case 0x06: return "PIN_OR_KEY_MISSING"; // Pairing failed because of a missing PIN
            case 0x07: return "MEMORY_FULL"; // The Controller has run out of memory to store new parameters.
            case 0x08: return "CONNECTION_TIMEOUT"; // The link supervision timeout has expired for a given connection.
            case 0x09: return "CONNECTION_LIMIT_EXCEEDED"; // The Controller is already at its limit of the number of connections it can support.
            case 0x0A: return "MAX_NUM_OF_CONNECTIONS_EXCEEDED"; // The Controller has reached the limit of connections
            case 0x0B: return "CONNECTION_ALREADY_EXISTS"; // A connection to this device already exists 
            case 0x0C: return "COMMAND_DISALLOWED"; // The command requested cannot be executed by the Controller at this time.
            case 0x0D: return "CONNECTION_REJECTED_LIMITED_RESOURCES"; // A connection was rejected due to limited resources.
            case 0x0E: return "CONNECTION_REJECTED_SECURITY_REASONS"; // A connection was rejected due to security, e.g. aauth or pairing.
            case 0x0F: return "CONNECTION_REJECTED_UNACCEPTABLE_MAC_ADDRESS"; // connection rejected, this device does not accept the BD_ADDR
            case 0x10: return "CONNECTION_ACCEPT_TIMEOUT_EXCEEDED"; // Connection Accept Timeout exceeded for this connection attempt.
            case 0x11: return "UNSUPPORTED_PARAMETER_VALUE"; // A feature or parameter value in the HCI command is not supported.
            case 0x12: return "INVALID_COMMAND_PARAMETERS"; // At least one of the HCI command parameters is invalid.
            case 0x13: return "REMOTE_USER_TERMINATED_CONNECTION"; // The user on the remote device terminated the connection.
            case 0x14: return "REMOTE_DEVICE_TERMINATED_CONNECTION_LOW_RESOURCES"; // remote device terminated connection due to low resources.
            case 0x15: return "REMOTE_DEVICE_TERMINATED_CONNECTION_POWER_OFF"; // The remote device terminated the connection due to power off
            case 0x16: return "CONNECTION_TERMINATED_BY_LOCAL_HOST"; // The local device terminated the connection.
            case 0x17: return "REPEATED_ATTEMPTS"; // The Controller is disallowing auth because of too quick attempts.
            case 0x18: return "PAIRING_NOT_ALLOWED"; // The device does not allow pairing
            case 0x19: return "UNKNOWN_LMP_PDU"; // The Controller has received an unknown LMP OpCode.
            case 0x1A: return "UNSUPPORTED_REMOTE_FEATURE"; // The remote device does not support feature for the issued command or LMP PDU.
            case 0x1B: return "SCO_OFFSET_REJECTED"; // The offset requested in the LMP_SCO_link_req PDU has been rejected.
            case 0x1C: return "SCO_INTERVAL_REJECTED"; // The interval requested in the LMP_SCO_link_req PDU has been rejected.
            case 0x1D: return "SCO_AIR_MODE_REJECTED"; // The air mode requested in the LMP_SCO_link_req PDU has been rejected.
            case 0x1E: return "INVALID_LMP_OR_LL_PARAMETERS"; // Some LMP PDU / LL Control PDU parameters were invalid.
            case 0x1F: return "UNSPECIFIED"; // No other error code specified is appropriate to use
            case 0x20: return "UNSUPPORTED_LMP_OR_LL_PARAMETER_VALUE"; // An LMP PDU or an LL Control PDU contains a value that is not supported
            case 0x21: return "ROLE_CHANGE_NOT_ALLOWED"; // a Controller will not allow a role change at this time.
            case 0x22: return "LMP_OR_LL_RESPONSE_TIMEOUT"; // An LMP transaction failed to respond within the LMP response timeout
            case 0x23: return "LMP_OR_LL_ERROR_TRANS_COLLISION"; // An LMP transaction or LL procedure has collided with the same transaction
            case 0x24: return "LMP_PDU_NOT_ALLOWED"; // A Controller sent an LMP PDU with an OpCode that was not allowed.
            case 0x25: return "ENCRYPTION_MODE_NOT_ACCEPTABLE"; // The requested encryption mode is not acceptable at this time.
            case 0x26: return "LINK_KEY_CANNOT_BE_EXCHANGED"; // A link key cannot be changed because a fixed unit key is being used.
            case 0x27: return "REQUESTED_QOS_NOT_SUPPORTED"; // The requested Quality of Service is not supported.
            case 0x28: return "INSTANT_PASSED"; // The LMP PDU or LL PDU instant has already passed
            case 0x29: return "PAIRING_WITH_UNIT_KEY_NOT_SUPPORTED"; // It was not possible to pair as a unit key is not supported.
            case 0x2A: return "DIFFERENT_TRANSACTION_COLLISION"; // An LMP transaction or LL Procedure collides with an ongoing transaction.
            case 0x2B: return "UNDEFINED_0x2B"; // Undefined error code
            case 0x2C: return "QOS_UNACCEPTABLE_PARAMETER"; // The quality of service parameters could not be accepted at this time.
            case 0x2D: return "QOS_REJECTED"; // The specified quality of service parameters cannot be accepted. negotiation should be terminated
            case 0x2E: return "CHANNEL_CLASSIFICATION_NOT_SUPPORTED"; // The Controller cannot perform channel assessment. not supported.
            case 0x2F: return "INSUFFICIENT_SECURITY"; // The HCI command or LMP PDU sent is only possible on an encrypted link.
            case 0x30: return "PARAMETER_OUT_OF_RANGE"; // A parameter in the HCI command is outside of valid range
            case 0x31: return "UNDEFINED_0x31"; // Undefined error
            case 0x32: return "ROLE_SWITCH_PENDING"; // A Role Switch is pending, sothe HCI command or LMP PDU is rejected
            case 0x33: return "UNDEFINED_0x33"; // Undefined error
            case 0x34: return "RESERVED_SLOT_VIOLATION"; // Synchronous negotiation terminated with negotiation state set to Reserved Slot Violation.
            case 0x35: return "ROLE_SWITCH_FAILED"; // A role switch was attempted but it failed and the original piconet structure is restored.
            case 0x36: return "INQUIRY_RESPONSE_TOO_LARGE"; // The extended inquiry response is too large to fit in packet supported by Controller.
            case 0x37: return "SECURE_SIMPLE_PAIRING_NOT_SUPPORTED"; // Host does not support Secure Simple Pairing, but receiving Link Manager does.
            case 0x38: return "HOST_BUSY_PAIRING"; // The Host is busy with another pairing operation. The receiving device should retry later.
            case 0x39: return "CONNECTION_REJECTED_NO_SUITABLE_CHANNEL"; // Controller could not calculate an appropriate value for Channel selection.
            case 0x3A: return "CONTROLLER_BUSY"; // The Controller was busy and unable to process the request.
            case 0x3B: return "UNACCEPTABLE_CONNECTION_PARAMETERS"; // The remote device terminated connection, unacceptable connection parameters.
            case 0x3C: return "ADVERTISING_TIMEOUT"; // Advertising completed. Or for directed advertising, no connection was created.
            case 0x3D: return "CONNECTION_TERMINATED_MIC_FAILURE"; // Connection terminated because Message Integrity Check failed on received packet.
            case 0x3E: return "CONNECTION_FAILED_ESTABLISHMENT"; // The LL initiated a connection but the connection has failed to be established.
            case 0x3F: return "MAC_CONNECTION_FAILED"; // The MAC of the 802.11 AMP was requested to connect to a peer, but the connection failed.
            case 0x40: return "COARSE_CLOCK_ADJUSTMENT_REJECTED"; // The master is unable to make a coarse adjustment to the piconet clock.
            case 0x41: return "TYPE0_SUBMAP_NOT_DEFINED"; // The LMP PDU is rejected because the Type 0 submap is not currently defined.
            case 0x42: return "UNKNOWN_ADVERTISING_IDENTIFIER"; // A command was sent from the Host but the Advertising or Sync handle does not exist.
            case 0x43: return "LIMIT_REACHED"; // The number of operations requested has been reached and has indicated the completion of the activity
            case 0x44: return "OPERATION_CANCELLED_BY_HOST"; // A request to the Controller issued by the Host and still pending was successfully canceled.
            case 0x45: return "PACKET_TOO_LONG"; // An attempt was made to send or receive a packet that exceeds the maximum allowed packet length.
            case 0x85: return "ANDROID_SPECIFIC_ERROR"; // Additional Android specific errors
            case 0x101: return "FAILURE_REGISTERING_CLIENT"; //  max of 30 clients has been reached.
            default: return "UNKNOWN_HCI_ERROR (" + value + ")";
         }
    }


    enum LogLevel
    {
        NONE,    // 0
        ERROR,   // 1
        WARNING, // 2
        INFO,    // 3
        DEBUG,   // 4
        VERBOSE  // 5
    }
}