// Copyright 2017, Paul DeMarco.
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


import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.io.StringWriter;
import java.io.PrintWriter;

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
    private static final String TAG = "FlutterBluePlugin";
    private final Object initializationLock = new Object();
    private final Object tearDownLock = new Object();
    private Context context;
    private MethodChannel channel;
    private static final String NAMESPACE = "flutter_blue_plus";

    private EventChannel stateChannel;
    private BluetoothManager mBluetoothManager;
    private BluetoothAdapter mBluetoothAdapter;

    private FlutterPluginBinding pluginBinding;
    private ActivityPluginBinding activityBinding;

    static final private UUID CCCD_ID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
    private final Map<String, BluetoothDeviceCache> mDevices = new HashMap<>();
    private LogLevel logLevel = LogLevel.EMERGENCY;

    private interface OperationOnPermission {
        void op(boolean granted, String permission);
    }

    private int lastEventId = 1452;
    private final Map<Integer, OperationOnPermission> operationsOnPermission = new HashMap<>();

    private final ArrayList<String> macDeviceScanned = new ArrayList<>();
    private boolean allowDuplicates = false;

    private final int enableBluetoothRequestCode = 1879842617;

    private final MyStreamHandler stateHandler = new MyStreamHandler();

    public FlutterBluePlusPlugin() {}

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding)
    {
        Log.d(TAG, "onAttachedToEngine");
        pluginBinding = flutterPluginBinding;
        setup(pluginBinding.getBinaryMessenger(),
                        (Application) pluginBinding.getApplicationContext());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding)
    {
        Log.d(TAG, "onDetachedFromEngine");
        pluginBinding = null;
        tearDown();
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

    private void setup(final BinaryMessenger messenger,
                           final Application application)
    {
        synchronized (initializationLock)
        {
            Log.d(TAG, "setup");

            this.context = application;

            channel = new MethodChannel(messenger, NAMESPACE + "/methods");
            channel.setMethodCallHandler(this);

            stateChannel = new EventChannel(messenger, NAMESPACE + "/state");
            stateChannel.setStreamHandler(stateHandler);

            mBluetoothManager = (BluetoothManager) application.getSystemService(Context.BLUETOOTH_SERVICE);
            mBluetoothAdapter = mBluetoothManager.getAdapter();

            IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);

            context.registerReceiver(mBluetoothStateReceiver, filter);

            try {
                stateHandler.setCachedBluetoothState(mBluetoothAdapter.getState());
            } catch (SecurityException e) {
                stateHandler.setCachedBluetoothStateUnauthorized();
            }
        }
    }

    private void tearDown()
    {
        synchronized (tearDownLock)
        {
            Log.d(TAG, "teardown");

            context.unregisterReceiver(mBluetoothStateReceiver);
            context = null;

            channel.setMethodCallHandler(null);
            channel = null;

            stateChannel.setStreamHandler(null);
            stateChannel = null;

            mBluetoothAdapter = null;
            mBluetoothManager = null;
        }
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

            if(mBluetoothAdapter == null && !"isAvailable".equals(call.method)) {
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

                case "state":
                {
                    // get state, if we can
                    int state = -1;
                    try {
                        state = mBluetoothAdapter.getState();
                    } catch (Exception e) {}
                    
                    int convertedState;
                    switch (state) {
                        case BluetoothAdapter.STATE_OFF:          convertedState = 6;           break;
                        case BluetoothAdapter.STATE_ON:           convertedState = 4;           break;
                        case BluetoothAdapter.STATE_TURNING_OFF:  convertedState = 5;           break;
                        case BluetoothAdapter.STATE_TURNING_ON:   convertedState = 3;           break;
                        default:                                  convertedState = 0;           break;
                    }

                    // see: BmBluetoothPowerState
                    HashMap<String, Object> map = new HashMap<>();
                    map.put("state", convertedState);

                    result.success(map);
                    break;
                }

                case "isAvailable":
                {
                    result.success(mBluetoothAdapter != null);
                    break;
                }

                case "isOn":
                {
                    result.success(mBluetoothAdapter.isEnabled());
                    break;
                }

                case "name":
                {
                    String name = mBluetoothAdapter.getName();
                    result.success(name != null ? name : "");
                    break;
                }

                case "turnOn":
                {
                    if (mBluetoothAdapter.isEnabled()) {
                        result.success(true); // no work to do
                        break;
                    }

                    Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);

                    activityBinding.getActivity().startActivityForResult(enableBtIntent, enableBluetoothRequestCode);

                    result.success(true);
                    break;
                }

                case "turnOff":
                {
                    if (mBluetoothAdapter.isEnabled() == false) {
                        result.success(true); // no work to do
                        break;
                    }

                    boolean disabled = mBluetoothAdapter.disable();

                    result.success(disabled);
                    break;
                }

                case "startScan":
                {
                    ArrayList<String> permissions = new ArrayList<>();

                    // see: BmScanSettings
                    HashMap<String, Object> data = call.arguments();
                    List<ScanFilter> filters = fetchFilters(data);
                    allowDuplicates =          (boolean) data.get("allow_duplicates");
                    int scanMode =                 (int) data.get("android_scan_mode");
                    boolean usesFineLocation = (boolean) data.get("android_uses_fine_location");

                    // Android 12+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        permissions.add(Manifest.permission.BLUETOOTH_SCAN);
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                        if (usesFineLocation) {
                            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
                        }
                    }

                    // Android 11 or lower
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (granted == false) {
                            result.error("startScan", String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        macDeviceScanned.clear();

                        BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
                        if(scanner == null) {
                            result.error("startScan", String.format("getBluetoothLeScanner() is null. Is the Adapter on?"), null);
                            return;
                        }

                        ScanSettings settings;
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            settings = new ScanSettings.Builder()
                                .setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED)
                                .setLegacy(false)
                                .setScanMode(scanMode)
                                .build();
                        } else {
                            settings = new ScanSettings.Builder()
                                .setScanMode(scanMode).build();
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

                case "getConnectedDevices":
                {
                    ArrayList<String> permissions = new ArrayList<>();

                    // Android 12+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (!granted) {
                            result.error("getConnectedDevices", 
                                String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        List<BluetoothDevice> devices = mBluetoothManager.getConnectedDevices(BluetoothProfile.GATT);

                        List<HashMap<String, Object>> devList = new ArrayList<HashMap<String, Object>>();
                        for (BluetoothDevice d : devices) {
                            devList.add(MessageMaker.bmBluetoothDevice(d));
                        }

                        HashMap<String, Object> response = new HashMap<>();
                        response.put("devices", devList);

                        result.success(response);
                    });
                    break;
                }

                case "getBondedDevices":
                {
                    final Set<BluetoothDevice> bondedDevices = mBluetoothAdapter.getBondedDevices();

                    List<HashMap<String,Object>> devList = new ArrayList<HashMap<String,Object>>();
                    for (BluetoothDevice d : bondedDevices) {
                        devList.add(MessageMaker.bmBluetoothDevice(d));
                    }

                    HashMap<String, Object> response = new HashMap<String, Object>();
                    response.put("devices", devList);

                    result.success(response);
                    break;
                }

                case "connect":
                {
                    ArrayList<String> permissions = new ArrayList<>();

                    // Android 12+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
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
                        String remoteId =      (String) args.get("remote_id");
                        boolean autoConnect = (boolean) args.get("android_auto_connect");
                        
                        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                        
                        boolean isConnected = mBluetoothManager.getConnectedDevices(BluetoothProfile.GATT).contains(device);

                        // already connected?
                        if(mDevices.containsKey(remoteId) && isConnected) {
                            result.success(null); // no work to do
                            return;
                        }

                        // If device was connected to previously but
                        // is now disconnected, attempt a reconnect
                        BluetoothDeviceCache bluetoothDeviceCache = mDevices.get(remoteId);
                        if(bluetoothDeviceCache != null && !isConnected) {
                            if(bluetoothDeviceCache.gatt.connect() == false) {
                                result.error("connect", "error when reconnecting to device", null);
                                return;
                            }
                            result.success(null);
                            return;
                        }

                        // New request, connect and add gattServer to Map
                        BluetoothGatt gattServer;
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            gattServer = device.connectGatt(context, autoConnect, mGattCallback, BluetoothDevice.TRANSPORT_LE);
                        } else {
                            gattServer = device.connectGatt(context, autoConnect, mGattCallback);
                        }

                        mDevices.put(remoteId, new BluetoothDeviceCache(gattServer));

                        result.success(null);
                    });
                    break;
                }

                case "pair":
                {
                    String remoteId = (String) call.arguments;

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("discover_services", "The device is not connected", null);
                        break;
                    }

                    if(device.createBond() == false) {
                        result.error("pair", "device.createBond() returned false", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "clearGattCache":
                {
                    String remoteId = (String) call.arguments;

                    BluetoothDeviceCache cache = mDevices.get(remoteId);
                    if (cache == null) {
                        result.success(null); // no work to do 
                        break;
                    }

                    BluetoothGatt gattServer = cache.gatt;
                    final Method refreshMethod = gattServer.getClass().getMethod("refresh");
                    if (refreshMethod == null) {
                        result.error("clearGattCache", "unsupported on this android version", null);
                        break;
                    }

                    refreshMethod.invoke(gattServer);

                    result.success(null);
                    break;
                }

                case "disconnect":
                {
                    String remoteId = (String) call.arguments;
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    BluetoothDeviceCache cache = mDevices.remove(remoteId);

                    if(cache != null) {

                        BluetoothGatt gattServer = cache.gatt;

                        gattServer.disconnect();

                        int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                        if(state == BluetoothProfile.STATE_DISCONNECTED) {
                            gattServer.close();
                        }
                    }

                    result.success(null);
                    break;
                }

                case "deviceState":
                {
                    String remoteId = (String) call.arguments;

                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);

                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);

                    result.success(MessageMaker.bmConnectionStateResponse(device, state));
                    break;
                }

                case "discoverServices":
                {
                    String remoteId = (String) call.arguments;

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("discover_services", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gatt = locateGatt(remoteId);

                    if(gatt.discoverServices() == false) {
                        result.error("discover_services", "unknown reason", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "services":
                {
                    String remoteId = (String) call.arguments;

                    BluetoothGatt gatt = locateGatt(remoteId);

                    List<Object> services = new ArrayList<>();
                    for(BluetoothGattService s : gatt.getServices()){
                        services.add(MessageMaker.bmBluetoothService(gatt.getDevice(), s, gatt));
                    }

                    // see: BmDiscoverServicesResult
                    HashMap<String, Object> map = new HashMap<>();
                    map.put("remote_id", remoteId);
                    map.put("services", services);
                    map.put("success", 1);
                    map.put("error_code", 0);
                    map.put("error_string", "");

                    result.success(map);
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

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("read_characteristic_error", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gattServer = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_READ) == 0) {
                        result.error("read_characteristic_error", 
                            "The READ property is not supported by this BLE characteristic", null);
                        break;
                    }

                    if(gattServer.readCharacteristic(characteristic) == false) {
                        result.error("read_characteristic_error", 
                            "gattServer.readCharacteristic() returned false", null);
                        break;
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

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("read_descriptor_error", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gattServer = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    BluetoothGattDescriptor descriptor = locateDescriptor(characteristic, descriptorUuid);

                    if(gattServer.readDescriptor(descriptor) == false) {
                        result.error("read_descriptor_error", "gattServer.readDescriptor() returned false", null);
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

                    int writeType = writeTypeInt == 1 ? 
                            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE :
                            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT;

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("write_characteristic_error", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gattServer = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
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

                    // Version 33 
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {

                        int rv = gattServer.writeCharacteristic(characteristic, hexToBytes(value), writeType);

                        if (rv != BluetoothStatusCodes.SUCCESS) {
                            String s = "gattServer.writeCharacteristic() returned " + rv + " : " + bluetoothStatusString(rv);
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
                        if(!gattServer.writeCharacteristic(characteristic)){
                            result.error("write_characteristic_error", "gattServer.writeCharacteristic() returned false", null);
                            break;
                        }
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

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("write_descriptor_error", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gattServer = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    BluetoothGattDescriptor descriptor = locateDescriptor(characteristic, descriptorUuid);

                    // Version 33 
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {

                        int rv = gattServer.writeDescriptor(descriptor, hexToBytes(value));

                        if (rv != BluetoothStatusCodes.SUCCESS) {
                            String s = "gattServer.writeDescriptor() returned " + rv + " : " + bluetoothStatusString(rv);
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
                        if(!gattServer.writeDescriptor(descriptor)){
                            result.error("write_descriptor_error", "gattServer.writeDescriptor() returned false", null);
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

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("set_notification_error", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gattServer = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    BluetoothGattDescriptor cccDescriptor = characteristic.getDescriptor(CCCD_ID);

                    if(cccDescriptor == null) {
                        //Some devices - including the widely used Bluno do not actually set the CCCD_ID.
                        //thus setNotifications works perfectly (tested on Bluno) without cccDescriptor
                        log(LogLevel.INFO, "could not locate CCCD descriptor for characteristic: " + characteristic.getUuid().toString());
                    }

                    // start notifications
                    if(!gattServer.setCharacteristicNotification(characteristic, enable)){
                        result.error("set_notification_error", 
                            "gattServer.setCharacteristicNotification(" + enable + ") returned false", null);
                        break;
                    }

                    // update descriptor value
                    if(cccDescriptor != null) {

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

                            if(canIndicate) {descriptorValue = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE;}
                            if(canNotify)   {descriptorValue = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE;}

                        } else {
                            descriptorValue  = BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE;
                        }
                        
                        if (!cccDescriptor.setValue(descriptorValue)) {
                            result.error("set_notification_error", "cccDescriptor.setValue() returned false", null);
                            break;
                        }

                        if (!gattServer.writeDescriptor(cccDescriptor)) {
                            result.error("set_notification_error", "gattServer.writeDescriptor() returned false", null);
                            break;
                        }
                    }

                    result.success(null);
                    break;
                }

                case "mtu":
                {
                    String remoteId = (String) call.arguments;
                    
                    BluetoothDeviceCache cache = mDevices.get(remoteId);
                    if(cache == null) {
                        result.error("mtu", "no instance of BluetoothGatt, have you connected first?", null);
                        break;
                    }

                    HashMap<String, Object> response = new HashMap<String, Object>();
                    response.put("remote_id", remoteId);
                    response.put("mtu", cache.mtu);

                    result.success(response);
                    break;
                }

                case "requestMtu":
                {
                    // see: BmMtuSizeRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId = (String) data.get("remote_id");
                    int mtu =            (int) data.get("mtu");

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("request_mtu", "The device is not connected", null);
                        break;
                    }

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

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("read_rssi", "The device is not connected", null);
                        break;
                    }

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

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("request_connection_priority", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gatt = locateGatt(remoteId);

                    if(gatt.requestConnectionPriority(connectionPriority) == false) {
                        result.error("request_connection_priority", "gatt.requestConnectionPriority() returned false", null);
                        break;
                    }

                    result.success(null);
                    break;
                }

                case "setPreferredPhy":
                {
                    // check version
                    if(Build.VERSION.SDK_INT < 26) {
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
                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(state == BluetoothProfile.STATE_DISCONNECTED) {
                        result.error("set_preferred_phy", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gatt = locateGatt(remoteId);

                    gatt.setPreferredPhy(txPhy, rxPhy, phyOptions);

                    result.success(null);
                    break;
                }

                case "removeBond":
                {
                    String remoteId = (String) call.arguments;
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);

                    // not bonded?
                    if (device.getBondState() != BluetoothDevice.BOND_BONDED) {
                        result.success(true);
                        break;
                    }

                    Method removeBondMethod = device.getClass().getMethod("removeBond");
                    removeBondMethod.invoke(device);

                    result.success(true);
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

    private BluetoothGatt locateGatt(String remoteId) throws Exception
    {
        BluetoothDeviceCache cache = mDevices.get(remoteId);

        if(cache == null) {
            throw new Exception("locateGatt: BluetoothDeviceCache is null, have you connected first?");
        } else if(cache.gatt == null) {
            throw new Exception("locateGatt: no instance of BluetoothGatt, have you connected first?");
        } else {
            return cache.gatt;
        }
    }

    private BluetoothGattCharacteristic locateCharacteristic(BluetoothGatt gattServer, 
                                                                    String serviceId,
                                                                    String secondaryServiceId,
                                                                    String characteristicId) 
                                                                    throws Exception
    {
        BluetoothGattService primaryService = gattServer.getService(UUID.fromString(serviceId));

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

    /////////////////////////////////////////////////////////////////////////////////////
    // ██████   ██████    ██████    █████   ██████    ██████   █████   ███████  ████████     
    // ██   ██  ██   ██  ██    ██  ██   ██  ██   ██  ██       ██   ██  ██          ██        
    // ██████   ██████   ██    ██  ███████  ██   ██  ██       ███████  ███████     ██        
    // ██   ██  ██   ██  ██    ██  ██   ██  ██   ██  ██       ██   ██       ██     ██        
    // ██████   ██   ██   ██████   ██   ██  ██████    ██████  ██   ██  ███████     ██        
    //  
    // ██████   ███████   ██████  ███████  ██  ██    ██  ███████  ██████  
    // ██   ██  ██       ██       ██       ██  ██    ██  ██       ██   ██ 
    // ██████   █████    ██       █████    ██  ██    ██  █████    ██████  
    // ██   ██  ██       ██       ██       ██   ██  ██   ██       ██   ██ 
    // ██   ██  ███████   ██████  ███████  ██    ████    ███████  ██   ██ 

    private final BroadcastReceiver mBluetoothStateReceiver = new BroadcastReceiver()
    {
        @Override
        public void onReceive(Context context, Intent intent) {

            final String action = intent.getAction();

            // no change?
            if (BluetoothAdapter.ACTION_STATE_CHANGED.equals(action) == false) {
                return;
            }

            final int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR);

            EventSink sink = stateHandler.getSink();
            if (sink == null) {
                stateHandler.setCachedBluetoothState(state);
                return;
            }

            // convert to Protobuf enum
            int convertedState;
            switch (state) {
                case BluetoothAdapter.STATE_OFF:          convertedState = 6;           break;
                case BluetoothAdapter.STATE_ON:           convertedState = 4;           break;
                case BluetoothAdapter.STATE_TURNING_OFF:  convertedState = 5;           break;
                case BluetoothAdapter.STATE_TURNING_ON:   convertedState = 3;           break;
                default:                                  convertedState = 0;           break;
            }

            // see: BmBluetoothPowerState
            HashMap<String, Object> map = new HashMap<>();
            map.put("state", convertedState);

            sink.success(map);
        }
    };

    /////////////////////////////////////////////////////////////////////////////
    // ███████  ███████   ██████   ███████   █████   ███    ███    
    // ██          ██     ██   ██  ██       ██   ██  ████  ████    
    // ███████     ██     ██████   █████    ███████  ██ ████ ██    
    //      ██     ██     ██   ██  ██       ██   ██  ██  ██  ██    
    // ███████     ██     ██   ██  ███████  ██   ██  ██      ██    
    //  
    // ██   ██   █████   ███    ██  ██████   ██       ███████  ██████ 
    // ██   ██  ██   ██  ████   ██  ██   ██  ██       ██       ██   ██
    // ███████  ███████  ██ ██  ██  ██   ██  ██       █████    ██████ 
    // ██   ██  ██   ██  ██  ██ ██  ██   ██  ██       ██       ██   ██
    // ██   ██  ██   ██  ██   ████  ██████   ███████  ███████  ██   ██

    private class MyStreamHandler implements StreamHandler {
        private final int STATE_UNAUTHORIZED = -1;

        private EventSink sink;

        public EventSink getSink() {
            return sink;
        }

        private int cachedBluetoothState;

        public void setCachedBluetoothState(int value) {
            cachedBluetoothState = value;
        }

        public void setCachedBluetoothStateUnauthorized() {
            cachedBluetoothState = STATE_UNAUTHORIZED;
        }

        @Override
        public void onListen(Object o, EventChannel.EventSink eventSink) {

            sink = eventSink;

            if (cachedBluetoothState != 0) {

                // convert to Protobuf enum
                int convertedState;
                switch (cachedBluetoothState) {
                    case BluetoothAdapter.STATE_OFF:          convertedState = 6;           break;
                    case BluetoothAdapter.STATE_ON:           convertedState = 4;           break;
                    case BluetoothAdapter.STATE_TURNING_OFF:  convertedState = 5;           break;
                    case BluetoothAdapter.STATE_TURNING_ON:   convertedState = 3;           break;
                    case STATE_UNAUTHORIZED:                  convertedState = 2;           break;
                    default:                                  convertedState = 0;           break;
                }

                // see: BmBluetoothPowerState
                HashMap<String, Object> map = new HashMap<>();
                map.put("state", convertedState);

                sink.success(map);
            }
        }

        @Override
        public void onCancel(Object o) {
            sink = null;
        }
    };

     ////////////////////////////////////////////////////////////////
    // ███████  ███████  ████████   ██████  ██   ██     
    // ██       ██          ██     ██       ██   ██     
    // █████    █████       ██     ██       ███████     
    // ██       ██          ██     ██       ██   ██     
    // ██       ███████     ██      ██████  ██   ██     
    // 
    // ███████  ██  ██       ████████  ███████  ██████   ███████ 
    // ██       ██  ██          ██     ██       ██   ██  ██      
    // █████    ██  ██          ██     █████    ██████   ███████ 
    // ██       ██  ██          ██     ██       ██   ██       ██ 
    // ██       ██  ███████     ██     ███████  ██   ██  ███████

    private List<ScanFilter> fetchFilters(HashMap<String, Object> scanSettings)
    {
        List<ScanFilter> filters;

        List<String> servicesUuids = (List<String>)scanSettings.get("service_uuids");
        int macCount = (int)scanSettings.getOrDefault("mac_count", 0);
        int serviceCount = servicesUuids.size();
        int count = macCount + serviceCount;

        filters = new ArrayList<>(count);

        List<String> noMacAddresses = new ArrayList<String>();
        List<String> macAddresses = (List<String>)scanSettings.getOrDefault("mac_addresses", noMacAddresses);

        for (int i = 0; i < macCount; i++) {
            String macAddress = macAddresses.get(i);
            ScanFilter f = new ScanFilter.Builder().setDeviceAddress(macAddress).build();
            filters.add(f);
        }

        for (int i = 0; i < serviceCount; i++) {
            String uuid = servicesUuids.get(i);
            ScanFilter f = new ScanFilter.Builder().setServiceUuid(ParcelUuid.fromString(uuid)).build();
            filters.add(f);
        }

        return filters;
    }

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
                    super.onScanResult(callbackType, result);

                    if(result != null){

                        if (!allowDuplicates && result.getDevice() != null && result.getDevice().getAddress() != null) {

                            if (macDeviceScanned.contains(result.getDevice().getAddress())) {
                                return;
                            }

                            macDeviceScanned.add(result.getDevice().getAddress());
                        }

                        invokeMethodUIThread("ScanResult", MessageMaker.bmScanResult(result.getDevice(), result));
                    }
                }

                @Override
                public void onBatchScanResults(List<ScanResult> results)
                {
                    super.onBatchScanResults(results);
                }

                @Override
                public void onScanFailed(int errorCode)
                {
                    super.onScanFailed(errorCode);
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
            log(LogLevel.DEBUG, "[onConnectionStateChange] status: " + status + " newState: " + newState);

            if(newState == BluetoothProfile.STATE_DISCONNECTED) {

                if(!mDevices.containsKey(gatt.getDevice().getAddress())) {

                    gatt.close();
                }
            }

            invokeMethodUIThread("DeviceState", MessageMaker.bmConnectionStateResponse(gatt.getDevice(), newState));
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status)
        {
            log(LogLevel.DEBUG, "[onServicesDiscovered] count: " + gatt.getServices().size() + " status: " + status);

            List<Object> services = new ArrayList<Object>();
            for(BluetoothGattService s : gatt.getServices()) {
                services.add(MessageMaker.bmBluetoothService(gatt.getDevice(), s, gatt));
            }

            // see: BmDiscoverServicesResult
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("services", services);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("DiscoverServicesResult", response);
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            log(LogLevel.DEBUG, "[onCharacteristicRead] uuid: " + characteristic.getUuid().toString() + " status: " + status);

            // see: BmReadCharacteristicResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("characteristic", MessageMaker.bmBluetoothCharacteristic(gatt.getDevice(), characteristic, gatt));
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("ReadCharacteristicResponse", response);
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            log(LogLevel.DEBUG, "[onCharacteristicWrite] uuid: " + characteristic.getUuid().toString() + " status: " + status);

            // see: BmWriteCharacteristicRequest
            HashMap<String, Object> request = new HashMap<>();
            request.put("remote_id", gatt.getDevice().getAddress());
            request.put("characteristic_uuid", characteristic.getUuid().toString());
            request.put("service_uuid", characteristic.getService().getUuid().toString());
            request.put("write_type", 0);
            request.put("value", "");

            // see: BmWriteCharacteristicResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("request", request);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("WriteCharacteristicResponse", response);
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic)
        {
            log(LogLevel.DEBUG, "[onCharacteristicChanged] uuid: " + characteristic.getUuid().toString());

            // see: BmOnCharacteristicChanged
            HashMap<String, Object> map = new HashMap<>();
            map.put("remote_id", gatt.getDevice().getAddress());
            map.put("characteristic", MessageMaker.bmBluetoothCharacteristic(gatt.getDevice(), characteristic, gatt));

            invokeMethodUIThread("OnCharacteristicChanged", map);
        }

        @Override
        public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            log(LogLevel.DEBUG, "[onDescriptorRead] uuid: " + descriptor.getUuid().toString() + " status: " + status);

            boolean hasSecondary = false;
            String serviceUuid = "";
            String secondaryServiceUuid = "";

            // find service uuid
            if(descriptor.getCharacteristic().getService().getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY) {
                serviceUuid = descriptor.getCharacteristic().getService().getUuid().toString();
            } else {
                // Reverse search to find service
                for(BluetoothGattService s : gatt.getServices()) {
                    for(BluetoothGattService ss : s.getIncludedServices()) {
                        if(ss.getUuid().equals(descriptor.getCharacteristic().getService().getUuid())) {
                            serviceUuid = s.getUuid().toString();
                            secondaryServiceUuid = ss.getUuid().toString();
                            hasSecondary = true;
                            break;
                        }
                    }
                }
            }

            // see: BmReadAttributeRequest
            HashMap<String, Object> request = new HashMap<>();
            request.put("remote_id", gatt.getDevice().getAddress());
            request.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
            request.put("descriptor_uuid", descriptor.getUuid().toString());
            request.put("service_uuid", serviceUuid);
            if (hasSecondary) {
                request.put("secondary_service_uuid", secondaryServiceUuid);
            }

            // see: BmReadDescriptorResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("request", request);
            response.put("value", bytesToHex(descriptor.getValue()));
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("ReadDescriptorResponse", response);
        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            log(LogLevel.DEBUG, "[onDescriptorWrite] uuid: " + descriptor.getUuid().toString() + " status: " + status);

            // see: BmWriteDescriptorRequest
            HashMap<String, Object> request = new HashMap<>();
            request.put("remote_id", gatt.getDevice().getAddress());
            request.put("descriptor_uuid", descriptor.getUuid().toString());
            request.put("service_uuid", descriptor.getCharacteristic().getService().getUuid().toString());
            request.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
            request.put("value", "");

            // see: BmWriteDescriptorResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("request", request);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("WriteDescriptorResponse", response);

            if(descriptor.getUuid().compareTo(CCCD_ID) == 0) {

                // see: BmSetNotificationResponse
                HashMap<String, Object> notificationResponse = new HashMap<>();
                notificationResponse.put("remote_id", gatt.getDevice().getAddress());
                notificationResponse.put("characteristic", MessageMaker.bmBluetoothCharacteristic(gatt.getDevice(), descriptor.getCharacteristic(), gatt));
                notificationResponse.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
                notificationResponse.put("error_code", status);
                notificationResponse.put("error_string", gattErrorString(status));

                invokeMethodUIThread("SetNotificationResponse", notificationResponse);
            }
        }

        @Override
        public void onReliableWriteCompleted(BluetoothGatt gatt, int status)
        {
            log(LogLevel.DEBUG, "[onReliableWriteCompleted] status: " + status);
        }

        @Override
        public void onReadRemoteRssi(BluetoothGatt gatt, int rssi, int status)
        {
            log(LogLevel.DEBUG, "[onReadRemoteRssi] rssi: " + rssi + " status: " + status);

            // see: BmReadRssiResult
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("rssi", rssi);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("ReadRssiResult", response);
        }

        @Override
        public void onMtuChanged(BluetoothGatt gatt, int mtu, int status)
        {
            log(LogLevel.DEBUG, "[onMtuChanged] mtu: " + mtu + " status: " + status);

            BluetoothDeviceCache cache = mDevices.get(gatt.getDevice().getAddress());
            if (cache != null) {
                cache.mtu = mtu;
            }

            // see: BmMtuSizeResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("mtu", mtu);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("MtuSize", response);
        }
    }; // BluetoothGattCallback

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

    private void invokeMethodUIThread(final String name, HashMap<String, Object> data)
    {
        new Handler(Looper.getMainLooper()).post(() -> {
            synchronized (tearDownLock) {
                //Could already be teared down at this moment
                if (channel != null) {
                   channel.invokeMethod(name, data);
                } else {
                    Log.w(TAG, "Tried to call " + name + " on closed channel");
                }
            }
        });
    }

    private static byte[] hexToBytes(String s) {
        int len = s.length();
        byte[] data = new byte[len / 2];
        
        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                                + Character.digit(s.charAt(i+1), 16));
        }
        
        return data;
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
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
            default: return "UNKNOWN_ERROR (" + value + ")";
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
            default: return "UNKNOWN_ERROR (" + value + ")";
        }
    }

    enum LogLevel
    {
        EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG
    }

    // BluetoothDeviceCache contains any other cached information not stored in Android Bluetooth API
    // but still needed Dart side.
    static class BluetoothDeviceCache
    {
        final BluetoothGatt gatt;
        int mtu;

        BluetoothDeviceCache(BluetoothGatt gatt) {
            this.gatt = gatt;
            mtu = 20;
        }
    }
} // FlutterBluePlusPlugin