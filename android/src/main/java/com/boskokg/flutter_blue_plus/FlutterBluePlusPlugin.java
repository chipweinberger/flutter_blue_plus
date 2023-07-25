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
    private final Object initializationLock = new Object();
    private final Object tearDownLock = new Object();
    private Context context;
    private MethodChannel methodChannel;
    private static final String NAMESPACE = "flutter_blue_plus";

    private BluetoothManager mBluetoothManager;
    private BluetoothAdapter mBluetoothAdapter;

    private FlutterPluginBinding pluginBinding;
    private ActivityPluginBinding activityBinding;

    static final private UUID CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
    private final Map<String, BluetoothDeviceCache> mDevices = new HashMap<>();
    private LogLevel logLevel = LogLevel.DEBUG;

    private interface OperationOnPermission {
        void op(boolean granted, String permission);
    }

    private int lastEventId = 1452;
    private final Map<Integer, OperationOnPermission> operationsOnPermission = new HashMap<>();

    private final ArrayList<String> macDeviceScanned = new ArrayList<>();
    private boolean allowDuplicates = false;

    private final int enableBluetoothRequestCode = 1879842617;

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

            methodChannel = new MethodChannel(messenger, NAMESPACE + "/methods");
            methodChannel.setMethodCallHandler(this);

            mBluetoothManager = (BluetoothManager) application.getSystemService(Context.BLUETOOTH_SERVICE);
            mBluetoothAdapter = mBluetoothManager.getAdapter();

            IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);

            context.registerReceiver(mBluetoothAdapterStateReceiver, filter);
        }
    }

    private void tearDown()
    {
        synchronized (tearDownLock)
        {
            Log.d(TAG, "teardown");

            for (Map.Entry<String, BluetoothDeviceCache> entry : mDevices.entrySet()) {
                String remoteId = entry.getKey();
                BluetoothDeviceCache cache = entry.getValue();
                BluetoothGatt gattServer = cache.gatt;
                if(gattServer != null) {
                    Log.d(TAG, "calling disconnect() on device: " + remoteId);
                    Log.d(TAG, "calling gattServer.close() on device: " + remoteId);
                    gattServer.disconnect();
                    gattServer.close();
                }
            }
            mDevices.clear();

            context.unregisterReceiver(mBluetoothAdapterStateReceiver);
            context = null;

            methodChannel.setMethodCallHandler(null);
            methodChannel = null;

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
            log(LogLevel.DEBUG, "[FBP-Android] onMethodCall: " + call.method);

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

                case "getAdapterState":
                {
                    // get adapterState, if we can
                    int adapterState = -1;
                    try {
                        adapterState = mBluetoothAdapter.getState();
                    } catch (Exception e) {}

                    int convertedState;
                    switch (adapterState) {
                        case BluetoothAdapter.STATE_OFF:          convertedState = 6;           break;
                        case BluetoothAdapter.STATE_ON:           convertedState = 4;           break;
                        case BluetoothAdapter.STATE_TURNING_OFF:  convertedState = 5;           break;
                        case BluetoothAdapter.STATE_TURNING_ON:   convertedState = 3;           break;
                        default:                                  convertedState = 0;           break;
                    }

                    // see: BmBluetoothAdapterState
                    HashMap<String, Object> map = new HashMap<>();
                    map.put("adapter_state", convertedState);

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

                case "getAdapterName":
                {
                    String adapterName = mBluetoothAdapter.getName();
                    result.success(adapterName != null ? adapterName : "");
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
                            devList.add(bmBluetoothDevice(d));
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
                        devList.add(bmBluetoothDevice(d));
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
                        String remoteId =  (String)  args.get("remote_id");
                        boolean autoConnect = ((int) args.get("auto_connect")) != 0;

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
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
                        result.error("pair", "The device is not connected", null);
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

                        int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                        if(cs == BluetoothProfile.STATE_DISCONNECTED ||
                           cs == BluetoothProfile.STATE_DISCONNECTING)
                        {
                            gattServer.close();
                        }
                    }

                    result.success(null);
                    break;
                }

                case "getConnectionState":
                {
                    String remoteId = (String) call.arguments;

                    // Note: a valid BluetoothDevice is always returned even
                    // if the remoteId has never been seen before
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);

                    int connectionState = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);

                    // see: BmConnectionStateResponse
                    HashMap<String, Object> response = new HashMap<>();
                    response.put("connection_state", connectionState);
                    response.put("remote_id", remoteId);

                    result.success(response);
                    break;
                }

                case "discoverServices":
                {
                    String remoteId = (String) call.arguments;

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
                        result.error("discover_services", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gatt = locateGatt(remoteId);

                    if(gatt.discoverServices() == false) {
                        result.error("discover_services", "gatt.discoverServices() returned false", null);
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
                        services.add(bmBluetoothService(gatt.getDevice(), s, gatt));
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
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
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
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
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

                    int writeType = writeTypeInt == 0 ?
                        BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT :
                        BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE;

                    // check connection
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
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

                    // check mtu
                    BluetoothDeviceCache cache = mDevices.get(remoteId);
                    if ((cache.mtu-3) < hexToBytes(value).length) {
                        String s = "data longer than mtu allows. dataLength: " +
                            hexToBytes(value).length + "> max: " + (cache.mtu-3);
                        result.error("write_characteristic_error", s, null);
                        break;
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
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
                        result.error("write_descriptor_error", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gattServer = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    BluetoothGattDescriptor descriptor = locateDescriptor(characteristic, descriptorUuid);

                    // check mtu
                    BluetoothDeviceCache cache = mDevices.get(remoteId);
                    if ((cache.mtu-3) < hexToBytes(value).length) {
                        String s = "data longer than mtu allows. dataLength: " +
                            hexToBytes(value).length + "> max: " + (cache.mtu-3);
                        result.error("write_characteristic_error", s, null);
                        break;
                    }

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
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
                        result.error("set_notification_error", "The device is not connected", null);
                        break;
                    }

                    BluetoothGatt gattServer = locateGatt(remoteId);

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        serviceUuid, secondaryServiceUuid, characteristicUuid);

                    // configure local Android device to listen for characteristic changes
                    if(!gattServer.setCharacteristicNotification(characteristic, enable)){
                        result.error("set_notification_error",
                            "gattServer.setCharacteristicNotification(" + enable + ") returned false", null);
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
                    if (!gattServer.writeDescriptor(cccDescriptor)) {
                        result.error("set_notification_error", "gattServer.writeDescriptor() returned false", null);
                        break;
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
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
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
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
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
                    int cs = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);
                    if(cs != BluetoothProfile.STATE_CONNECTED) {
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

    private final BroadcastReceiver mBluetoothAdapterStateReceiver = new BroadcastReceiver()
    {
        @Override
        public void onReceive(Context context, Intent intent) {

            final String action = intent.getAction();

            // no change?
            if (BluetoothAdapter.ACTION_STATE_CHANGED.equals(action) == false) {
                return;
            }

            final int adapterState = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR);

            // convert to Protobuf enum
            int convertedState;
            switch (adapterState) {
                case BluetoothAdapter.STATE_OFF:          convertedState = 6;           break;
                case BluetoothAdapter.STATE_ON:           convertedState = 4;           break;
                case BluetoothAdapter.STATE_TURNING_OFF:  convertedState = 5;           break;
                case BluetoothAdapter.STATE_TURNING_ON:   convertedState = 3;           break;
                default:                                  convertedState = 0;           break;
            }

            // see: BmBluetoothAdapterState
            HashMap<String, Object> map = new HashMap<>();
            map.put("adapter_state", convertedState);

            invokeMethodUIThread("adapterStateChanged", map);
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
                    log(LogLevel.VERBOSE, "[FBP-Android] onScanResult");

                    super.onScanResult(callbackType, result);

                    if(result != null){

                        if (!allowDuplicates && result.getDevice() != null && result.getDevice().getAddress() != null) {

                            if (macDeviceScanned.contains(result.getDevice().getAddress())) {
                                return;
                            }

                            macDeviceScanned.add(result.getDevice().getAddress());
                        }

                        // see BmScanResult
                        HashMap<String, Object> rr = bmScanResult(result.getDevice(), result);

                        // see BmScanResponse
                        HashMap<String, Object> response = new HashMap<>();
                        response.put("result", rr);

                        invokeMethodUIThread("ScanResponse", response);
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

                    invokeMethodUIThread("ScanResponse", response);
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
            log(LogLevel.DEBUG, "[FBP-Android] onConnectionStateChange: status: " + status + " newState: " + newState);

            if(newState == BluetoothProfile.STATE_DISCONNECTED) {

                if(!mDevices.containsKey(gatt.getDevice().getAddress())) {

                    gatt.close();
                }
            }

            // see: BmConnectionStateResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("connection_state", newState);
            response.put("remote_id", gatt.getDevice().getAddress());

            invokeMethodUIThread("connectionStateChanged", response);
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

            invokeMethodUIThread("DiscoverServicesResult", response);
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

            invokeMethodUIThread("ReadRssiResult", response);
        }

        @Override
        public void onMtuChanged(BluetoothGatt gatt, int mtu, int status)
        {
            log(LogLevel.DEBUG, "[FBP-Android] onMtuChanged: mtu: " + mtu + " status: " + status);

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
    static HashMap<String, Object> parseAdvertisementData(byte[] rawData) {
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


    static HashMap<String, Object> bmAdvertisementData(BluetoothDevice device, byte[] advertisementData, int rssi) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("device", bmBluetoothDevice(device));
        if(advertisementData != null && advertisementData.length > 0) {
            map.put("advertisement_data", parseAdvertisementData(advertisementData));
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

    static HashMap<String, Object> bmBluetoothDescriptor(BluetoothDevice device, BluetoothGattDescriptor descriptor) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("remote_id", device.getAddress());
        map.put("descriptor_uuid", descriptor.getUuid().toString());
        map.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
        map.put("service_uuid", descriptor.getCharacteristic().getService().getUuid().toString());
        map.put("value", bytesToHex(descriptor.getValue()));
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

    static int bmConnectionStateEnum(int cs) {
        switch (cs) {
            case BluetoothProfile.STATE_DISCONNECTED:  return 0;
            case BluetoothProfile.STATE_CONNECTING:    return 1;
            case BluetoothProfile.STATE_CONNECTED:     return 2;
            case BluetoothProfile.STATE_DISCONNECTING: return 3;
            default: return 0;
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
            synchronized (tearDownLock) {
                //Could already be teared down at this moment
                if (methodChannel != null) {
                   methodChannel.invokeMethod(method, data);
                } else {
                    Log.w(TAG, "invokeMethodUIThread: tried to call method on closed channel: " + method);
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
        if (bytes == null) {
            return "";
        }
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

    enum LogLevel
    {
        NONE,    // 0
        ERROR,   // 1
        WARNING, // 2
        INFO,    // 3
        DEBUG,   // 4
        VERBOSE  // 5
    }

    // BluetoothDeviceCache contains any other cached information not stored in Android Bluetooth API
    // but still needed Dart side.
    static class BluetoothDeviceCache
    {
        final BluetoothGatt gatt;
        int mtu;

        BluetoothDeviceCache(BluetoothGatt gatt) {
            this.gatt = gatt;
            mtu = 23;
        }
    }
}