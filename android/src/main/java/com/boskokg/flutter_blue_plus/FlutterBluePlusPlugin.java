// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/////////////////////////////////////////////
// ██   ██ ███████ ██      ██       ██████  
// ██   ██ ██      ██      ██      ██    ██ 
// ███████ █████   ██      ██      ██    ██ 
// ██   ██ ██      ██      ██      ██    ██ 
// ██   ██ ███████ ███████ ███████  ██████  
/*

Please Read!!!!!

ANDROID CODE NEEDS TO BE UPDATED TO REMOVE PROTOBUF DEPENDENCY

For example, we have to replace:

            Protos.WriteDescriptorRequest.Builder request = Protos.WriteDescriptorRequest.newBuilder();
            request.setRemoteId(gatt.getDevice().getAddress());
            request.setDescriptorUuid(descriptor.getUuid().toString());
            request.setCharacteristicUuid(descriptor.getCharacteristic().getUuid().toString());
            request.setServiceUuid(descriptor.getCharacteristic().getService().getUuid().toString());

With

        HashMap<String, Integer> map = new HashMap<>();
        map.put("remote_id", gatt.getDevice().getAddress());
        map.put("descriptor_uuidd", descriptor.getUuid().toString());
        map.put("characteristic_uuid", descriptor.getCharacteristic().getUuid().toString());
        map.put("uuid", descriptor.getCharacteristic().getService().getUuid().toString();

For more information
    - see /lib/bluetooth_msg.dart for more details on the keys and values.
    - see iOS code for another example.
    - see flutter docs for supported types https://docs.flutter.dev/platform-integration/platform-channels?tab=type-mappings-java-tab

*/
/////////////////////////////////////////////

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

import com.google.protobuf.ByteString;
import com.google.protobuf.InvalidProtocolBufferException;

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
                try {
                    int idx = (int)call.arguments;

                    // set global var
                    logLevel = LogLevel.values()[idx];

                    result.success(null);

                } catch(Exception e) {
                    result.error("setLogLevel", e.getMessage(), e);
                }
                break;
            }

            case "state":
            {
                try {
                    // get state, if we can
                    int state = -1;
                    try {
                        state = mBluetoothAdapter.getState();
                    } catch (Exception e) {}
                    
                    // convert to protobuf enum
                    Protos.BluetoothState.State pbs;
                    switch(state) {
                        case BluetoothAdapter.STATE_OFF:          pbs = Protos.BluetoothState.State.OFF;         break;
                        case BluetoothAdapter.STATE_ON:           pbs = Protos.BluetoothState.State.ON;          break;
                        case BluetoothAdapter.STATE_TURNING_OFF:  pbs = Protos.BluetoothState.State.TURNING_OFF; break;
                        case BluetoothAdapter.STATE_TURNING_ON:   pbs = Protos.BluetoothState.State.TURNING_ON;  break;
                        default:                                  pbs = Protos.BluetoothState.State.UNKNOWN;     break;
                    }

                    Protos.BluetoothState.Builder p = Protos.BluetoothState.newBuilder();
                    p.setState(pbs);

                    result.success(p.build().toByteArray());

                } catch(Exception e) {
                    result.error("state", e.getMessage(), e);
                }
                break;
            }

            case "isAvailable":
            {
                try {
                    result.success(mBluetoothAdapter != null);
                } catch(Exception e) {
                    result.error("isAvailable", e.getMessage(), e);
                }
                break;
            }

            case "isOn":
            {
                try {
                    result.success(mBluetoothAdapter.isEnabled());
                } catch(Exception e) {
                    result.error("isOn", e.getMessage(), e);
                }
                break;
            }

            case "name":
            {
                try {

                    String name = mBluetoothAdapter.getName();

                    result.success(name != null ? name : "");

                } catch(Exception e) {
                    result.error("name", e.getMessage(), e);
                }
                break;
            }

            case "turnOn":
            {
                try {
                    if (mBluetoothAdapter.isEnabled()) {
                        result.success(true); // no work to do
                    }

                    Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);

                    activityBinding.getActivity().startActivityForResult(enableBtIntent, enableBluetoothRequestCode);

                    result.success(true);

                } catch(Exception e) {
                    result.error("turnOn", e.getMessage(), e);
                }
                break;
            }

            case "turnOff":
            {
                try {
                    if (mBluetoothAdapter.isEnabled() == false) {
                        result.success(true); // no work to do
                    }

                    boolean disabled = mBluetoothAdapter.disable();

                    result.success(disabled);

                } catch(Exception e) {
                    result.error("turnOff", e.getMessage(), e);
                }
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
                    try {
                        if (granted == false) {
                            result.error("startScan", String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        byte[] data = call.arguments();

                        Protos.ScanSettings p = 
                            Protos.ScanSettings.newBuilder().mergeFrom(data).build();

                        macDeviceScanned.clear();

                        BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
                        if(scanner == null) {
                            throw new Exception("getBluetoothLeScanner() is null. Is the Adapter on?");
                        }

                        int scanMode = p.getAndroidScanMode();
                        allowDuplicates = p.getAllowDuplicates();

                        List<ScanFilter> filters = fetchFilters(p);

                        // scan settings
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

                    } catch(Exception e) {
                        result.error("startScan", e.getMessage(), e);
                    }
                });
                break;
            }

            case "stopScan":
            {
                try {

                    BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
                    
                    if(scanner != null) {
                        scanner.stopScan(getScanCallback());
                    }

                    result.success(null);

                } catch(Exception e) {
                    result.error("stopScan", e.getMessage(), e);
                }
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
                    try {
                        if (!granted) {
                            result.error("getConnectedDevices", 
                                String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        List<BluetoothDevice> devices = mBluetoothManager.getConnectedDevices(BluetoothProfile.GATT);

                        Protos.ConnectedDevicesResponse.Builder p = Protos.ConnectedDevicesResponse.newBuilder();
                        for (BluetoothDevice d : devices) {
                            p.addDevices(ProtoMaker.from(d));
                        }

                        result.success(p.build().toByteArray());

                    } catch(Exception e) {
                        result.error("getConnectedDevices", e.getMessage(), e);
                    }
                });
                break;
            }

            case "getBondedDevices":
            {
                try {
                    final Set<BluetoothDevice> bondedDevices = mBluetoothAdapter.getBondedDevices();

                    Protos.ConnectedDevicesResponse.Builder p = Protos.ConnectedDevicesResponse.newBuilder();
                    for (BluetoothDevice d : bondedDevices) {
                        p.addDevices(ProtoMaker.from(d));
                    }

                    result.success(p.build().toByteArray()); 

                } catch(Exception e) {
                    result.error("getBondedDevices", e.getMessage(), e);
                }
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
                    try {

                        if (!granted) {
                            result.error("connect", 
                                String.format("FlutterBluePlus requires %s for new connection", perm), null);
                            return;
                        }

                        byte[] data = call.arguments();
                        Protos.ConnectRequest options = Protos.ConnectRequest.newBuilder().mergeFrom(data).build();
                        
                        String deviceId = options.getRemoteId();
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
                            }
                            result.success(null);
                            return;
                        }

                        // New request, connect and add gattServer to Map
                        BluetoothGatt gattServer;
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            gattServer = device.connectGatt(context, options.getAndroidAutoConnect(),
                                mGattCallback, BluetoothDevice.TRANSPORT_LE);
                        } else {
                            gattServer = device.connectGatt(context, options.getAndroidAutoConnect(),
                                mGattCallback);
                        }

                        mDevices.put(deviceId, new BluetoothDeviceCache(gattServer));

                        result.success(null);

                    } catch(Exception e) {
                        result.error("connect", e.getMessage(), e);
                    }
                });
                break;
            }

            case "pair":
            {
                try {
                    String deviceId = (String)call.arguments;

                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(deviceId);

                    device.createBond();

                    result.success(null);
                    
                } catch(Exception e) {
                    result.error("pair", e.getMessage(), e);
                }
                break;
            }

            case "clearGattCache":
            {
                try {
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

                } catch(Exception e) {
                    result.error("clearGattCache", e.getMessage(), e);
                }
                break;
            }

            case "disconnect":
            {
                try {
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

                } catch(Exception e) {
                    result.error("disconnect", e.getMessage(), e);
                }
                break;
            }

            case "deviceState":
            {
                try {
                    String deviceId = (String)call.arguments;

                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(deviceId);

                    int state = mBluetoothManager.getConnectionState(device, BluetoothProfile.GATT);

                    result.success(ProtoMaker.from(device, state).toByteArray());

                } catch(Exception e) {
                    result.error("deviceState", e.getMessage(), e);
                }
                break;
            }

            case "discoverServices":
            {
                try {
                    String deviceId = (String)call.arguments;

                    BluetoothGatt gatt = locateGatt(deviceId);

                    if(gatt.discoverServices() == false) {
                        result.error("discoverServices", "unknown reason", null);
                        break;
                    }

                    result.success(null);

                } catch(Exception e) {
                    result.error("discoverServices", e.getMessage(), e);
                }
                break;
            }

            case "services":
            {
                try {
                    String deviceId = (String)call.arguments;

                    BluetoothGatt gatt = locateGatt(deviceId);

                    Protos.DiscoverServicesResult.Builder p = Protos.DiscoverServicesResult.newBuilder();
                    p.setRemoteId(deviceId);
                    for(BluetoothGattService s : gatt.getServices()){
                        p.addServices(ProtoMaker.from(gatt.getDevice(), s, gatt));
                    }

                    result.success(p.build().toByteArray());

                } catch(Exception e) {
                    result.error("services", e.getMessage(), e);
                }
                break;
            }

            case "readCharacteristic":
            {
                try {
                    byte[] data = call.arguments();

                    Protos.ReadCharacteristicRequest request = 
                        Protos.ReadCharacteristicRequest.newBuilder().mergeFrom(data).build();

                    BluetoothGatt gattServer = locateGatt(request.getRemoteId());

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        request.getServiceUuid(), request.getSecondaryServiceUuid(), request.getCharacteristicUuid());

                    if(gattServer.readCharacteristic(characteristic) == false) {
                        result.error("read_characteristic_error", 
                            "unknown reason, may occur if readCharacteristic was called before last read finished.", null);
                        break;
                    } 

                    result.success(null);

                } catch(Exception e) {
                    result.error("read_characteristic_error", e.getMessage(), null);
                }
                break;
            }

            case "readDescriptor":
            {

                try {
                    byte[] data = call.arguments();

                    Protos.ReadDescriptorRequest request = 
                        Protos.ReadDescriptorRequest.newBuilder().mergeFrom(data).build();

                    BluetoothGatt gattServer = locateGatt(request.getRemoteId());

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        request.getServiceUuid(), request.getSecondaryServiceUuid(), request.getCharacteristicUuid());

                    BluetoothGattDescriptor descriptor = locateDescriptor(characteristic, request.getDescriptorUuid());

                    if(gattServer.readDescriptor(descriptor) == false) {
                        result.error("readDescriptor",
                            "unknown reason, may occur if readDescriptor was called before last read finished.", null);
                    }

                    result.success(null);

                } catch(Exception e) {
                    result.error("readDescriptor", e.getMessage(), null);
                }
                break;
            }

            case "writeCharacteristic":
            {
                try {
                    byte[] data = call.arguments();

                    Protos.WriteCharacteristicRequest request = 
                        Protos.WriteCharacteristicRequest.newBuilder().mergeFrom(data).build();

                    BluetoothGatt gattServer = locateGatt(request.getRemoteId());

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        request.getServiceUuid(), request.getSecondaryServiceUuid(), request.getCharacteristicUuid());

                    // Set Value
                    if(!characteristic.setValue(request.getValue().toByteArray())){
                        result.error("writeCharacteristic", "could not set the local value of characteristic", null);
                    }

                    // Write type
                    if(request.getWriteType() == Protos.WriteCharacteristicRequest.WriteType.WITHOUT_RESPONSE) {
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

                } catch(Exception e) {
                    result.error("writeCharacteristic", e.getMessage(), null);
                }
                break;
            }

            case "writeDescriptor":
            {
                try {
                    byte[] data = call.arguments();
                    Protos.WriteDescriptorRequest request = Protos.WriteDescriptorRequest.newBuilder().mergeFrom(data).build();

                    BluetoothGatt gattServer = locateGatt(request.getRemoteId());

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        request.getServiceUuid(),   request.getSecondaryServiceUuid(), request.getCharacteristicUuid());

                    BluetoothGattDescriptor descriptor = locateDescriptor(characteristic, request.getDescriptorUuid());

                    // Set descriptor
                    if(!descriptor.setValue(request.getValue().toByteArray())){
                        result.error("write_descriptor_error", "could not set the local value for descriptor", null);
                        break;
                    }

                    // Write descriptor
                    if(!gattServer.writeDescriptor(descriptor)){
                        result.error("write_descriptor_error", "writeCharacteristic failed", null);
                        break;
                    }

                } catch(Exception e) {
                    result.error("writeDescriptor", e.getMessage(), null);
                }

                result.success(null);
                break;
            }

            case "setNotification":
            {
                try {
                    byte[] data = call.arguments();

                    Protos.SetNotificationRequest request = 
                        Protos.SetNotificationRequest.newBuilder().mergeFrom(data).build();

                    BluetoothGatt gattServer = locateGatt(request.getRemoteId());

                    BluetoothGattCharacteristic characteristic = locateCharacteristic(gattServer,
                        request.getServiceUuid(), request.getSecondaryServiceUuid(), request.getCharacteristicUuid());

                    BluetoothGattDescriptor cccDescriptor = characteristic.getDescriptor(CCCD_ID);

                    if(cccDescriptor == null) {
                        //Some devices - including the widely used Bluno do not actually set the CCCD_ID.
                        //thus setNotifications works perfectly (tested on Bluno) without cccDescriptor
                        log(LogLevel.INFO, "could not locate CCCD descriptor for characteristic: " + characteristic.getUuid().toString());
                    }

                    // start notifications
                    if(!gattServer.setCharacteristicNotification(characteristic, request.getEnable())){
                        result.error("setNotification", 
                            "could not set characteristic notifications to :" + request.getEnable(), null);
                        break;
                    }

                    // update descriptor value
                    if(cccDescriptor != null) {

                        byte[] value = null;

                        // determine value 
                        if(request.getEnable()) {

                            boolean canNotify = (characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) > 0;
                            boolean canIndicate = (characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) > 0;

                            if(!canIndicate && !canNotify) {
                                result.error("setNotification", "characteristic cannot notify or indicate", null);
                                break;
                            }

                            if(canIndicate) {value = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE;}
                            if(canNotify)   {value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE;}

                        } else {
                            value  = BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE;
                        }
                        
                        if (!cccDescriptor.setValue(value)) {
                            result.error("setNotification", "error setting descriptor value to: " + Arrays.toString(value), null);
                            break;
                        }

                        if (!gattServer.writeDescriptor(cccDescriptor)) {
                            result.error("setNotification", "error writing descriptor", null);
                            break;
                        }
                    }

                    result.success(null);

                } catch(Exception e) {
                    result.error("setNotification", e.getMessage(), null);
                }
                break;
            }

            case "mtu":
            {
                try {
                    String deviceId = (String)call.arguments;
                    
                    BluetoothDeviceCache cache = mDevices.get(deviceId);
                    if(cache != null) {
                        result.error("mtu", "no instance of BluetoothGatt, have you connected first?", null);
                        break;
                    }

                    Protos.MtuSizeResponse.Builder p = Protos.MtuSizeResponse.newBuilder();
                    p.setRemoteId(deviceId);
                    p.setMtu(cache.mtu);

                    result.success(p.build().toByteArray());

                } catch(Exception e) {
                    result.error("mtu", e.getMessage(), e);
                }
                break;
            }

            case "requestMtu":
            {
                try {
                    byte[] data = call.arguments();

                    Protos.MtuSizeRequest request = Protos.MtuSizeRequest.newBuilder().mergeFrom(data).build();

                    BluetoothGatt gatt = locateGatt(request.getRemoteId());

                    int mtu = request.getMtu();

                    result.success(null);

                } catch(Exception e) {
                    result.error("requestMtu", e.getMessage(), e);
                }
                break;
            }

            case "readRssi":
            {
                try {
                    String remoteId = (String)call.arguments;
                    BluetoothGatt gatt = locateGatt(remoteId);

                    if(gatt.readRemoteRssi() == false) {
                        result.error("readRssi", "gatt.readRemoteRssi returned false", null);
                    } 

                    result.success(null);

                } catch(Exception e) {
                    result.error("readRssi", e.getMessage(), e);
                }
                break;
            }

            case "requestConnectionPriority":
            {
                try {
                    byte[] data = call.arguments();

                    Protos.ConnectionPriorityRequest request = 
                        Protos.ConnectionPriorityRequest.newBuilder().mergeFrom(data).build();

                    BluetoothGatt gatt = locateGatt(request.getRemoteId());

                    int connectionPriority = request.getConnectionPriority();

                    if(gatt.requestConnectionPriority(connectionPriority) == false) {
                        result.error("requestConnectionPriority", "returned false", null);
                        break;
                    }

                    result.success(null);

                } catch(Exception e) {
                    result.error("requestConnectionPriority", e.getMessage(), e);
                }
                break;
            }

            case "setPreferredPhy":
            {
                try {
                    // check version
                    if(Build.VERSION.SDK_INT < 26) {
                        result.error("setPreferredPhy", 
                            "Only supported on devices >= API 26. This device == " + 
                            Build.VERSION.SDK_INT, null);
                        break;
                    }

                    byte[] data = call.arguments();

                    Protos.PreferredPhy request = Protos.PreferredPhy.newBuilder().mergeFrom(data).build();

                    BluetoothGatt gatt = locateGatt(request.getRemoteId());
                    int txPhy = request.getTxPhy();
                    int rxPhy = request.getRxPhy();
                    int phyOptions = request.getPhyOptions();

                    gatt.setPreferredPhy(txPhy, rxPhy, phyOptions);
                    result.success(null);
                    break;

                } catch(Exception e) {
                    result.error("setPreferredPhy", e.getMessage(), e);
                }
            }

            case "removeBond":
            {
                try {
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

                } catch (Exception e) {
                    result.error("removeBond", e.getMessage(), null);
                }
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
            Protos.BluetoothState.State pbs;
            switch (state) {
                case BluetoothAdapter.STATE_OFF:          pbs = Protos.BluetoothState.State.OFF;         break;
                case BluetoothAdapter.STATE_ON:           pbs = Protos.BluetoothState.State.ON;          break;
                case BluetoothAdapter.STATE_TURNING_OFF:  pbs = Protos.BluetoothState.State.TURNING_OFF; break;
                case BluetoothAdapter.STATE_TURNING_ON:   pbs = Protos.BluetoothState.State.TURNING_ON;  break;
                default:                                  pbs = Protos.BluetoothState.State.UNKNOWN;     break;
            }

            Protos.BluetoothState.Builder p = Protos.BluetoothState.newBuilder();
            p.setState(pbs);

            sink.success(p);
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
                Protos.BluetoothState.State pbs;
                switch (cachedBluetoothState) {
                    case BluetoothAdapter.STATE_OFF:          pbs = Protos.BluetoothState.State.OFF;         break;
                    case BluetoothAdapter.STATE_ON:           pbs = Protos.BluetoothState.State.ON;          break;
                    case BluetoothAdapter.STATE_TURNING_OFF:  pbs = Protos.BluetoothState.State.TURNING_OFF; break;
                    case BluetoothAdapter.STATE_TURNING_ON:   pbs = Protos.BluetoothState.State.TURNING_ON;  break;
                    case STATE_UNAUTHORIZED:                  pbs = Protos.BluetoothState.State.OFF;         break;
                    default:                                  pbs = Protos.BluetoothState.State.UNKNOWN;     break;
                }

                Protos.BluetoothState.Builder p = Protos.BluetoothState.newBuilder();
                p.setState(pbs);

                sink.success(p.build().toByteArray());
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

    private List<ScanFilter> fetchFilters(Protos.ScanSettings proto)
    {
        List<ScanFilter> filters;

        int macCount = proto.getMacAddressesCount();
        int serviceCount = proto.getServiceUuidsCount();

        int count = macCount + serviceCount;

        filters = new ArrayList<>(count);

        for (int i = 0; i < macCount; i++) {
            String macAddress = proto.getMacAddresses(i);
            ScanFilter f = new ScanFilter.Builder().setDeviceAddress(macAddress).build();
            filters.add(f);
        }

        for (int i = 0; i < serviceCount; i++) {
            String uuid = proto.getServiceUuids(i);
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

                        Protos.ScanResult scanResult = ProtoMaker.from(result.getDevice(), result);

                        invokeMethodUIThread("ScanResult", scanResult.toByteArray());
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

            invokeMethodUIThread("DeviceState", ProtoMaker.from(gatt.getDevice(), newState).toByteArray());
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status)
        {
            log(LogLevel.DEBUG, "[onServicesDiscovered] count: " + gatt.getServices().size() + " status: " + status);

            Protos.DiscoverServicesResult.Builder p = Protos.DiscoverServicesResult.newBuilder();
            p.setRemoteId(gatt.getDevice().getAddress());

            for(BluetoothGattService s : gatt.getServices()) {
                p.addServices(ProtoMaker.from(gatt.getDevice(), s, gatt));
            }

            invokeMethodUIThread("DiscoverServicesResult", p.build().toByteArray());
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            log(LogLevel.DEBUG, "[onCharacteristicRead] uuid: " + characteristic.getUuid().toString() + " status: " + status);

            Protos.ReadCharacteristicResponse.Builder p = Protos.ReadCharacteristicResponse.newBuilder();
            p.setRemoteId(gatt.getDevice().getAddress());
            p.setCharacteristic(ProtoMaker.from(gatt.getDevice(), characteristic, gatt));

            invokeMethodUIThread("ReadCharacteristicResponse", p.build().toByteArray());
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            log(LogLevel.DEBUG, "[onCharacteristicWrite] uuid: " + characteristic.getUuid().toString() + " status: " + status);

            Protos.WriteCharacteristicRequest.Builder request = Protos.WriteCharacteristicRequest.newBuilder();
            request.setRemoteId(gatt.getDevice().getAddress());
            request.setCharacteristicUuid(characteristic.getUuid().toString());
            request.setServiceUuid(characteristic.getService().getUuid().toString());

            Protos.WriteCharacteristicResponse.Builder p = Protos.WriteCharacteristicResponse.newBuilder();
            p.setRequest(request);
            p.setSuccess(status == BluetoothGatt.GATT_SUCCESS);

            invokeMethodUIThread("WriteCharacteristicResponse", p.build().toByteArray());
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic)
        {
            log(LogLevel.DEBUG, "[onCharacteristicChanged] uuid: " + characteristic.getUuid().toString());

            Protos.OnCharacteristicChanged.Builder p = Protos.OnCharacteristicChanged.newBuilder();
            p.setRemoteId(gatt.getDevice().getAddress());
            p.setCharacteristic(ProtoMaker.from(gatt.getDevice(), characteristic, gatt));

            invokeMethodUIThread("OnCharacteristicChanged", p.build().toByteArray());
        }

        @Override
        public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            log(LogLevel.DEBUG, "[onDescriptorRead] uuid: " + descriptor.getUuid().toString() + " status: " + status);

            // Rebuild the ReadAttributeRequest and send back along with response
            Protos.ReadDescriptorRequest.Builder r = Protos.ReadDescriptorRequest.newBuilder();
            r.setRemoteId(gatt.getDevice().getAddress());
            r.setCharacteristicUuid(descriptor.getCharacteristic().getUuid().toString());
            r.setDescriptorUuid(descriptor.getUuid().toString());

            if(descriptor.getCharacteristic().getService().getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY) {

                r.setServiceUuid(descriptor.getCharacteristic().getService().getUuid().toString());

            } else {

                // Reverse search to find service
                for(BluetoothGattService s : gatt.getServices()) {
                    for(BluetoothGattService ss : s.getIncludedServices()) {

                        if(ss.getUuid().equals(descriptor.getCharacteristic().getService().getUuid())) {

                            r.setServiceUuid(s.getUuid().toString());
                            r.setSecondaryServiceUuid(ss.getUuid().toString());

                            break;
                        }
                    }
                }
            }

            Protos.ReadDescriptorResponse.Builder p = Protos.ReadDescriptorResponse.newBuilder();
            p.setRequest(r);
            p.setValue(ByteString.copyFrom(descriptor.getValue()));

            invokeMethodUIThread("ReadDescriptorResponse", p.build().toByteArray());
        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            log(LogLevel.DEBUG, "[onDescriptorWrite] uuid: " + descriptor.getUuid().toString() + " status: " + status);

            Protos.WriteDescriptorRequest.Builder request = Protos.WriteDescriptorRequest.newBuilder();
            request.setRemoteId(gatt.getDevice().getAddress());
            request.setDescriptorUuid(descriptor.getUuid().toString());
            request.setCharacteristicUuid(descriptor.getCharacteristic().getUuid().toString());
            request.setServiceUuid(descriptor.getCharacteristic().getService().getUuid().toString());

            Protos.WriteDescriptorResponse.Builder p = Protos.WriteDescriptorResponse.newBuilder();
            p.setRequest(request);
            p.setSuccess(status == BluetoothGatt.GATT_SUCCESS);

            invokeMethodUIThread("WriteDescriptorResponse", p.build().toByteArray());

            if(descriptor.getUuid().compareTo(CCCD_ID) == 0) {

                // SetNotificationResponse
                Protos.SetNotificationResponse.Builder q = Protos.SetNotificationResponse.newBuilder();
                q.setRemoteId(gatt.getDevice().getAddress());
                q.setCharacteristic(ProtoMaker.from(gatt.getDevice(), descriptor.getCharacteristic(), gatt));
                q.setSuccess(status == BluetoothGatt.GATT_SUCCESS);

                invokeMethodUIThread("SetNotificationResponse", q.build().toByteArray());
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

                Protos.ReadRssiResult.Builder p = Protos.ReadRssiResult.newBuilder();
                p.setRemoteId(gatt.getDevice().getAddress());
                p.setRssi(rssi);

                invokeMethodUIThread("ReadRssiResult", p.build().toByteArray());
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

                    Protos.MtuSizeResponse.Builder p = Protos.MtuSizeResponse.newBuilder();
                    p.setRemoteId(gatt.getDevice().getAddress());
                    p.setMtu(mtu);

                    invokeMethodUIThread("MtuSize", p.build().toByteArray());
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

    private void invokeMethodUIThread(final String name, final byte[] byteArray)
    {
        new Handler(Looper.getMainLooper()).post(() -> {
            synchronized (tearDownLock) {
                //Could already be teared down at this moment
                if (channel != null) {
                    channel.invokeMethod(name, byteArray);
                } else {
                    Log.w(TAG, "Tried to call " + name + " on closed channel");
                }
            }
        });
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
}
