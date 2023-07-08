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

                // scan
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    permissions.add(Manifest.permission.BLUETOOTH_SCAN);
                } else {
                    permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
                }

                // connect
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                }

                // fine location
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
                }

                ensurePermissions(permissions, (granted, perm) -> {

                    if (granted == false) {
                        result.error("startScan", String.format("FlutterBluePlus requires %s permission", perm), null);
                        return;
                    }

                    HashMap<String, Object> data = call.arguments();

                    macDeviceScanned.clear();

                    BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
                    if(scanner == null) {
                        result.error("startScan", String.format("getBluetoothLeScanner() is null. Is the Adapter on?", null);
                        return;
                    }
                    
                    int scanMode =        (int) data.get("android_scan_mode");
                    allowDuplicates = (boolean) data.get("allow_duplicates");

                    List<ScanFilter> filters = fetchFilters(data);

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

                // connect
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

                    HashMap<String, Object> response = new HashMap<String, Object>();
                    List<HashMap<String, Object>> responseDevices = new ArrayList<HashMap<String, Object>>();
                    for (BluetoothDevice d : devices) {
                        responseDevices.add(MessageMaker.bmBluetoothDevice(d));
                    }
                    response.put("devices", responseDevices);

                    result.success(response);
                });
                break;
            }

            case "getBondedDevices":
            {
                final Set<BluetoothDevice> bondedDevices = mBluetoothAdapter.getBondedDevices();

                HashMap<String, Object> response = new HashMap<String, Object>();
                List<HashMap<String,Object>> devices = new ArrayList<HashMap<String,Object>>();
                for (BluetoothDevice d : bondedDevices) {
                    devices.add(MessageMaker.bmBluetoothDevice(d));
                }
                response.put("devices", devices);

                result.success(response);
                break;
            }

            case "connect":
            {
                ArrayList<String> permissions = new ArrayList<>();

                // connect
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                }

                ensurePermissions(permissions, (granted, perm) -> {

                    if (!granted) {
                        result.error("connect", 
                            String.format("FlutterBluePlus requires %s for new connection", perm), null);
                        return;
                    }

                    HashMap<String, Object> args = call.arguments();
                    String deviceId = (String)args.get("remote_id");
                    boolean autoConnect = (boolean)args.get("android_auto_connect");
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(deviceId);
                    
                    boolean isConnected = mBluetoothManager.getConnectedDevices(BluetoothProfile.GATT).contains(device);

                    // If device is already connected, return error
                    if(mDevices.containsKey(deviceId) && isConnected) {
                        result.error("connect", "connection with device already exists", null);
                        return;
                    }

                    // If device was connected to previously but
                    // is now disconnected, attempt a reconnect
                    BluetoothDeviceCache bluetoothDeviceCache = mDevices.get(deviceId);
                    if(bluetoothDeviceCache != null && !isConnected) {
                        if(bluetoothDeviceCache.gatt.connect() == false) {
                            result.error("connect", "error when reconnecting to device", null);
                            break;
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

                    mDevices.put(deviceId, new BluetoothDeviceCache(gattServer));

                    result.success(null);
                });
                break;
            }

            case "pair":
            {
                String deviceId = (String)call.arguments;

                BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(deviceId);

                device.createBond();

                result.success(null);
                break;
            }

            case "clearGattCache":
            {
                String deviceId = (String)call.arguments;

                BluetoothDeviceCache cache = mDevices.get(deviceId);
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
                String deviceId = (String)call.arguments;
                BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(deviceId);
                BluetoothDeviceCache cache = mDevices.remove(deviceId);

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
                String deviceId = (String) call.arguments;

                BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(deviceId);

                int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);

                result.success(MessageMaker.bmConnectionStateResponse(device, state));
                break;
            }

            case "discoverServices":
            {
                String deviceId = (String) call.arguments;

                BluetoothGatt gatt = locateGatt(deviceId);

                if(gatt.discoverServices() == false) {
                    result.error("discoverServices", "unknown reason", null);
                    break;
                }

                result.success(null);
                break;
            }

            case "services":
            {
                String deviceId = (String) call.arguments;

                BluetoothGatt gatt = locateGatt(deviceId);

                HashMap<String, Object> map = new HashMap<>();
                map.put("remote_id", deviceId);
                
                List<Object> services = new ArrayList<>();
                for(BluetoothGattService s : gatt.getServices()){
                    services.add(MessageMaker.bmBluetoothService(gatt.getDevice(), s, gatt));
                }
                map.put("services", services);

                result.success(map);
                break;
            }

            case "readCharacteristic":
            {
                HashMap<String, Object> data = call.arguments();
                String remoteId =             (String) data.get("remote_id");
                String serviceUuid =          (String) data.get("service_uuid");
                String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                String characteristicUuid =   (String) data.get("characteristic_uuid");

                BluetoothGatt gattServer = locateGatt(remoteId);
                BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                    serviceUuid, secondaryServiceUuid, characteristicUuid);

                if(gattServer.readCharacteristic(characteristic) == false) {
                    result.error("read_characteristic_error",
                        "unknown reason, may occur if readCharacteristic was called before last read finished.", null);
                    break;
                }

                result.success(null);
                break;
            }

            case "readDescriptor":
            {
                HashMap<String, Object> data = call.arguments();
                String remoteId =             (String) data.get("remote_id");
                String serviceUuid =          (String) data.get("service_uuid");
                String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                String characteristicUuid =   (String) data.get("characteristic_uuid");
                String descriptorUuid =       (String) data.get("descriptor_uuid");

                BluetoothGatt gattServer = locateGatt(remoteId);

                BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                    serviceUuid, secondaryServiceUuid, characteristicUuid);

                BluetoothGattDescriptor descriptor = locateDescriptor(characteristic, descriptorUuid);

                if(gattServer.readDescriptor(descriptor) == false) {
                    result.error("readDescriptor",
                        "unknown reason, may occur if readDescriptor was called before last read finished.", null);
                    break;
                }

                result.success(null);
                break;
            }

            case "writeCharacteristic":
            {
                HashMap<String, Object> data = call.arguments();
                String remoteId =             (String) data.get("remote_id");
                String serviceUuid =          (String) data.get("service_uuid");
                String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                String characteristicUuid =   (String) data.get("characteristic_uuid");
                List<Byte> value =        (List<Byte>) data.get("value");
                int writeType =                  (int) data.get("write_type");

                BluetoothGatt gattServer = locateGatt(remoteId);

                BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                    serviceUuid, secondaryServiceUuid, characteristicUuid);

                byte[] val = new byte[value.size()];
                for(int i = 0; i < value.size(); i++) {
                    val[i] = value.get(i).byteValue();
                }

                if(!characteristic.setValue(val)) {
                    result.error("writeCharacteristic", "could not set the local value of characteristic", null);
                    break;
                }

                // Write type
                if(writeType == 1) {
                    characteristic.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
                } else {
                    characteristic.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);
                }

                // Write Char
                if(!gattServer.writeCharacteristic(characteristic)){
                    result.error("writeCharacteristic", "writeCharacteristic failed", null);
                    break;
                }

                result.success(null);
                break;
            }

            case "writeDescriptor":
            {
                HashMap<String, Object> data = call.arguments();
                String remoteId =             (String) data.get("remote_id");
                String serviceUuid =          (String) data.get("service_uuid");
                String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                String characteristicUuid =   (String) data.get("characteristic_uuid");
                String descriptorUuid =       (String) data.get("descriptor_uuid");
                String value =                (String) data.get("value");

                BluetoothGatt gattServer = locateGatt(remoteId);

                BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                    serviceUuid, secondaryServiceUuid, characteristicUuid);

                BluetoothGattDescriptor descriptor = locateDescriptor(characteristic, descriptorUuid);

                // Set descriptor
                if(!descriptor.setValue(hexToBytes(value))){
                    result.error("write_descriptor_error", "could not set the local value for descriptor", null);
                    break;
                }

                // Write descriptor
                if(!gattServer.writeDescriptor(descriptor)){
                    result.error("write_descriptor_error", "writeCharacteristic failed", null);
                    break;
                }

                result.success(null);
                break;
            }

            case "setNotification":
            {
                HashMap<String, Object> data = call.arguments();
                String remoteId =             (String) data.get("remote_id");
                String serviceUuid =          (String) data.get("service_uuid");
                String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                String characteristicUuid =   (String) data.get("characteristic_uuid");
                boolean enable =             (boolean) data.get("enable");

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
                    result.error("setNotification", 
                        "could not set characteristic notifications to :" + enable, null);
                    break;
                }

                // update descriptor value
                if(cccDescriptor != null) {

                    byte[] descriptorValue = null;

                    // determine value 
                    if(enable) {

                        boolean canNotify = (properties & BluetoothGattCharacteristic.PROPERTY_NOTIFY) > 0;
                        boolean canIndicate = (properties & BluetoothGattCharacteristic.PROPERTY_INDICATE) > 0;

                        if(!canIndicate && !canNotify) {
                            result.error("setNotification", "characteristic cannot notify or indicate", null);
                            break;
                        }

                        if(canIndicate) {descriptorValue = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE;}
                        if(canNotify)   {descriptorValue = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE;}

                    } else {
                        descriptorValue  = BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE;
                    }
                    
                    if (!cccDescriptor.setValue(descriptorValue)) {
                        result.error("setNotification", "error setting descriptor value to: " + Arrays.toString(descriptorValue), null);
                        break;
                    }

                    if (!gattServer.writeDescriptor(cccDescriptor)) {
                        result.error("setNotification", "error writing descriptor", null);
                        break;
                    }
                }

                result.success(null);
                break;
            }

            case "mtu":
            {
                String deviceId = (String)call.arguments;
                
                BluetoothDeviceCache cache = mDevices.get(deviceId);
                if(cache == null) {
                    result.error("mtu", "no instance of BluetoothGatt, have you connected first?", null);
                    break;
                }

                HashMap<String, Object> response = new HashMap<String, Object>();
                response.put("remote_id", deviceId);
                response.put("mtu", cache.mtu);

                result.success(response);
                break;
            }

            case "requestMtu":
            {
                HashMap<String, Object> data = call.arguments();
                String remoteId = (String) data.get("remote_id");
                int mtu =            (int) data.get("mtu");

                BluetoothGatt gatt = locateGatt(remoteId);

                if(gatt.requestMtu(mtu) == false) {
                    result.error("requestMtu", "gatt.requestMtu returned false", null);
                    break;
                }

                result.success(null);
                break;
            }

            case "readRssi":
            {
                String remoteId = (String)call.arguments;
                BluetoothGatt gatt = locateGatt(remoteId);

                if(gatt.readRemoteRssi() == false) {
                    result.error("readRssi", "gatt.readRemoteRssi returned false", null);
                    break;
                } 

                result.success(null);
                break;
            }

            case "requestConnectionPriority":
            {
                HashMap<String, Object> data = call.arguments();
                String remoteId =     (String) data.get("remote_id");
                int connectionPriority = (int) data.get("connection_priority");

                BluetoothGatt gatt = locateGatt(remoteId);

                if(gatt.requestConnectionPriority(connectionPriority) == false) {
                    result.error("requestConnectionPriority", "returned false", null);
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

                HashMap<String, Object> data = call.arguments();
                String remoteId = (String) data.get("remote_id");
                int txPhy =          (int) data.get("tx_phy");
                int rxPhy =          (int) data.get("rx_phy");
                int phyOptions =     (int) data.get("phy_options");

                BluetoothGatt gatt = locateGatt(remoteId);

                gatt.setPreferredPhy(txPhy, rxPhy, phyOptions);

                result.success(null);
                break;
            }

            case "removeBond":
            {
                String deviceId = (String)call.arguments;
                BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(deviceId);

                // not bonded?
                if (device.getBondState() != BluetoothDevice.BOND_BONDED) {
                    result.success(false);
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

        if(cache == null || cache.gatt == null) {
            throw new Exception("no instance of BluetoothGatt, have you connected first?");
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
            throw new Exception("service (" + serviceId + ") could not be located on the device");
        }

        BluetoothGattService secondaryService = null;

        if(secondaryServiceId.length() > 0) {

            for(BluetoothGattService s : primaryService.getIncludedServices()){
                if(s.getUuid().equals(UUID.fromString(secondaryServiceId))){
                    secondaryService = s;
                }
            }

            if(secondaryService == null) {
                throw new Exception("secondary service (" + secondaryServiceId + ") could not be located on the device");
            }
        }

        BluetoothGattService service = (secondaryService != null) ?
            secondaryService : 
            primaryService;

        BluetoothGattCharacteristic characteristic = 
            service.getCharacteristic(UUID.fromString(characteristicId));

        if(characteristic == null) {
            throw new Exception("characteristic (" + characteristicId + ") " + 
                "could not be located in the service ("+service.getUuid().toString()+")");
        }

        return characteristic;
    }

    private BluetoothGattDescriptor locateDescriptor(BluetoothGattCharacteristic characteristic, 
                                                                          String descriptorId) throws Exception
    {
        BluetoothGattDescriptor descriptor = characteristic.getDescriptor(UUID.fromString(descriptorId));

        if(descriptor == null) {
            throw new Exception("descriptor (" + descriptorId + ") " + 
                "could not be located in the characteristic ("+characteristic.getUuid().toString()+")");
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

            HashMap<String, Object> map = new HashMap<>();
            map.put("state", convertedState);

            // sink.success(map);
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

                HashMap<String, Object> map = new HashMap<>();
                map.put("state", convertedState);

                // sink.success(map);
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

            // Protos.DiscoverServicesResult.Builder p = Protos.DiscoverServicesResult.newBuilder();
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            List<Object> services = new ArrayList<Object>();

            for(BluetoothGattService s : gatt.getServices()) {
                services.add(MessageMaker.bmBluetoothService(gatt.getDevice(), s, gatt));
            }
            response.put("services", services);

            invokeMethodUIThread("DiscoverServicesResult", response);
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            log(LogLevel.DEBUG, "[onCharacteristicRead] uuid: " + characteristic.getUuid().toString() + " status: " + status);

            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("characteristic", MessageMaker.bmBluetoothCharacteristic(gatt.getDevice(), characteristic, gatt));

            invokeMethodUIThread("ReadCharacteristicResponse", response);
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            log(LogLevel.DEBUG, "[onCharacteristicWrite] uuid: " + characteristic.getUuid().toString() + " status: " + status);

            HashMap<String, Object> request = new HashMap<>();
            request.put("remote_id", gatt.getDevice().getAddress());
            request.put("characteristic_uuid", characteristic.getUuid().toString());
            request.put("service_uuid", characteristic.getService().getUuid().toString());

            HashMap<String, Object> response = new HashMap<>();
            response.put("request", request);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS);

            invokeMethodUIThread("WriteCharacteristicResponse", response);
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic)
        {
            log(LogLevel.DEBUG, "[onCharacteristicChanged] uuid: " + characteristic.getUuid().toString());

            HashMap<String, Object> map = new HashMap<>();
            map.put("remote_id", gatt.getDevice().getAddress());
            map.put("characteristic", MessageMaker.bmBluetoothCharacteristic(gatt.getDevice(), characteristic, gatt));

             invokeMethodUIThread("OnCharacteristicChanged", map);
        }

        @Override
        public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            log(LogLevel.DEBUG, "[onDescriptorRead] uuid: " + descriptor.getUuid().toString() + " status: " + status);

            // Rebuild the ReadAttributeRequest and send back along with response
            HashMap<String, Object> request = new HashMap<>();
            request.put("remote_id", gatt.getDevice().getAddress());
            request.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
            request.put("descriptor_uuid", descriptor.getUuid().toString());

            if(descriptor.getCharacteristic().getService().getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY) {

                request.put("service_uuid", descriptor.getCharacteristic().getService().getUuid().toString());

            } else {

                // Reverse search to find service
                for(BluetoothGattService s : gatt.getServices()) {
                    for(BluetoothGattService ss : s.getIncludedServices()) {

                        if(ss.getUuid().equals(descriptor.getCharacteristic().getService().getUuid())) {

                            request.put("service_uuid", s.getUuid().toString());
                            request.put("secondary_service_uuid", ss.getUuid().toString());

                            break;
                        }
                    }
                }
            }

            HashMap<String, Object> response = new HashMap<>();
            response.put("request", request);
            response.put("value", bytesToHex(descriptor.getValue()));

            invokeMethodUIThread("ReadDescriptorResponse", response);
        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            log(LogLevel.DEBUG, "[onDescriptorWrite] uuid: " + descriptor.getUuid().toString() + " status: " + status);

            HashMap<String, Object> request = new HashMap<>();
            request.put("remote_id", gatt.getDevice().getAddress());
            request.put("descriptor_uuid", descriptor.getUuid().toString());
            request.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
            request.put("uuid", descriptor.getCharacteristic().getService().getUuid().toString());

            HashMap<String, Object> response = new HashMap<>();
            response.put("request", request);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS);

            invokeMethodUIThread("WriteDescriptorResponse", response);

            if(descriptor.getUuid().compareTo(CCCD_ID) == 0) {

                // SetNotificationResponse
                HashMap<String, Object> notificationResponse = new HashMap<>();
                notificationResponse.put("remote_id", gatt.getDevice().getAddress());
                notificationResponse.put("characteristic", MessageMaker.bmBluetoothCharacteristic(gatt.getDevice(), descriptor.getCharacteristic(), gatt));
                notificationResponse.put("success", status == BluetoothGatt.GATT_SUCCESS);

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

            if(status == BluetoothGatt.GATT_SUCCESS) {

                HashMap<String, Object> result = new HashMap<>();
                result.put("remote_id", gatt.getDevice().getAddress());
                result.put("rssi", rssi);

                invokeMethodUIThread("ReadRssiResult", result);
            }
        }

        @Override
        public void onMtuChanged(BluetoothGatt gatt, int mtu, int status)
        {
            log(LogLevel.DEBUG, "[onMtuChanged] mtu: " + mtu + " status: " + status);

            if(status == BluetoothGatt.GATT_SUCCESS) {

                if(mDevices.containsKey(gatt.getDevice().getAddress())) {

                    BluetoothDeviceCache cache = mDevices.get(gatt.getDevice().getAddress());
                    if (cache != null) {
                        cache.mtu = mtu;
                    }

                    HashMap<String, Object> result = new HashMap<>();
                    result.put("remote_id", gatt.getDevice().getAddress());
                    result.put("mtu", mtu);

                    invokeMethodUIThread("MtuSize", result);
                }
            }
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