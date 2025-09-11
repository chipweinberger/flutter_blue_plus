// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package com.lib.flutter_blue_plus;

import android.Manifest;
import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.app.Activity;
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
import android.bluetooth.BluetoothStatusCodes;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanRecord;
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
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;
import java.io.InputStream;
import java.io.OutputStream;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;


import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.LinkedList;
import java.util.Collections;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener;

@SuppressLint("MissingPermission")
public class FlutterBluePlusPlugin implements
    FlutterPlugin,
    MethodCallHandler,
    RequestPermissionsResultListener,
    ActivityResultListener,
    ActivityAware
{
    private Context context;
    private MethodChannel methodChannel;
    private static final String NAMESPACE = "flutter_blue_plus";

    private BluetoothManager mBluetoothManager;
    private BluetoothAdapter mBluetoothAdapter;
    private boolean mIsScanning = false;

    private FlutterPluginBinding pluginBinding;
    private ActivityPluginBinding activityBinding;

    static final private String CCCD = "2902";

    private final Map<String, BluetoothGatt> mConnectedDevices = new ConcurrentHashMap<>();
    private final Map<String, BluetoothGatt> mCurrentlyConnectingDevices = new ConcurrentHashMap<>();
    private final Map<String, BluetoothDevice> mBondingDevices = new ConcurrentHashMap<>();
    private final Map<String, Integer> mMtu = new ConcurrentHashMap<>();
    private final Map<String, BluetoothGatt> mAutoConnected = new ConcurrentHashMap<>();
    private final Map<String, String> mWriteChr = new ConcurrentHashMap<>();
    private final Map<String, String> mWriteDesc = new ConcurrentHashMap<>();
    private final Map<String, String> mAdvSeen = new ConcurrentHashMap<>();
    private final Map<String, Integer> mScanCounts = new ConcurrentHashMap<>();
    private HashMap<String, Object> mScanFilters = new HashMap<>();
    
    private final Map<Integer, OperationOnPermission> operationsOnPermission = new HashMap<>();
    private int lastEventId = 1452;

    private final int enableBluetoothRequestCode = 1879842617;

    // L2CAP Channel Management - Consolidated Implementation
    private final List<L2CapInfo> openL2CapChannelInfos = Collections.synchronizedList(new LinkedList<>());
    
    // L2CAP Info Interface
    private interface L2CapInfo {
        Type getType();
        int getPsm();
        L2CapChannel getL2CapChannel(BluetoothDevice remoteDevice);
        void close(BluetoothDevice device) throws IOException;
        
        enum Type {
            CLIENT,
            SERVER,
        }
    }
    
    // L2CAP Channel Base Class  
    private abstract class L2CapChannel {
        protected static final int DEFAULT_READ_BUFFER_SIZE = 50;
        protected final byte[] readBuffer;
        protected BluetoothSocket socket;
        protected OutputStream outputStream;
        protected InputStream inputStream;

        public L2CapChannel(int readBufferSize) {
            readBuffer = new byte[readBufferSize];
        }

        public BluetoothSocket getSocket() {
            return socket;
        }

        public void readL2CapChannel(String remoteId, int psm, Result resultCallback) {
            if (inputStream == null || socket == null || !socket.isConnected()) {
                resultCallback.error("socketNotOpen", "The bluetooth socket or the input stream is not open.", null);
                return;
            }
            try {
                int bytesRead = inputStream.read(readBuffer);
                // see: BmReadL2CapChannelResponse
                HashMap<String, Object> response = new HashMap<>();
                response.put("remote_id", remoteId);
                response.put("psm", psm);
                response.put("bytes_read", bytesRead);
                response.put("value", Arrays.copyOf(readBuffer, bytesRead));
                resultCallback.success(response);
            } catch (IOException e) {
                resultCallback.error("inputStreamReadFailed", e.getMessage(), null);
            }
        }

        public void writeL2CapChannel(byte[] data, Result resultCallback) {
            if (outputStream == null || socket == null || !socket.isConnected()) {
                resultCallback.error("socketNotOpen", "The bluetooth socket or the output stream is not open.", null);
                return;
            }
            try {
                outputStream.write(data);
                resultCallback.success(null);
            } catch (IOException e) {
                resultCallback.error("outputStreamWriteFailed", e.getMessage(), null);
            }
        }

        public synchronized void close() {
            if (outputStream != null) {
                try {
                    outputStream.close();
                } catch (IOException e) {
                    // ignore
                } finally {
                    outputStream = null;
                }
            }
            if (inputStream != null) {
                try {
                    inputStream.close();
                } catch (IOException e) {
                    // ignore
                } finally {
                    inputStream = null;
                }
            }
            if (socket != null) {
                try {
                    socket.close();
                } catch (IOException e) {
                    // ignore
                } finally {
                    socket = null;
                }
            }
        }
    }
    
    // L2CAP Client Channel Implementation
    private class L2CapClientChannel extends L2CapChannel {
        private final BluetoothDevice device;
        private final int psm;

        public L2CapClientChannel(BluetoothDevice device, int psm) {
            this(device, psm, DEFAULT_READ_BUFFER_SIZE);
        }

        public L2CapClientChannel(BluetoothDevice device, int psm, int readBufferSize) {
            super(readBufferSize);
            this.psm = psm;
            this.device = device;
        }

        @SuppressLint("MissingPermission")
        @TargetApi(Build.VERSION_CODES.Q)
        public synchronized void connectToL2CapChannel(boolean secure, Result resultCallback) {
            try {
                if (secure) {
                    socket = device.createL2capChannel(psm);
                } else {
                    socket = device.createInsecureL2capChannel(psm);
                }
                socket.connect();
                inputStream = socket.getInputStream();
                outputStream = socket.getOutputStream();
                resultCallback.success(null);
            } catch (IOException e) {
                resultCallback.error("openL2capChannelFailed", e.getMessage(), null);
            }
        }

        public BluetoothDevice getDevice() {
            return device;
        }

        public int getPsm() {
            return psm;
        }
    }
    
    // L2CAP Server Channel Implementation  
    private class L2CapServerChannel extends L2CapChannel {
        public L2CapServerChannel(BluetoothSocket socket) {
            super(DEFAULT_READ_BUFFER_SIZE);
            this.socket = socket;
        }

        public void openStreams() throws IOException {
            inputStream = socket.getInputStream();
            outputStream = socket.getOutputStream();
        }
    }
    
    // Client Socket Info Implementation
    private class ClientSocketInfo implements L2CapInfo {
        private final L2CapClientChannel l2CapChannel;

        public ClientSocketInfo(L2CapClientChannel l2CapChannel) {
            this.l2CapChannel = l2CapChannel;
        }

        @Override
        public Type getType() {
            return Type.CLIENT;
        }

        @Override
        public int getPsm() {
            return l2CapChannel.getPsm();
        }

        @Override
        public L2CapChannel getL2CapChannel(BluetoothDevice remoteDevice) {
            if (remoteDevice.getAddress().equals(l2CapChannel.getDevice().getAddress())) {
                return l2CapChannel;
            }
            return null;
        }

        @Override
        public void close(BluetoothDevice device) throws IOException {
            l2CapChannel.close();
        }
    }
    
    // Server Socket Info Implementation
    @RequiresApi(api = Build.VERSION_CODES.Q)
    private class ServerSocketInfo implements L2CapInfo {
        private final BluetoothServerSocket serverSocket;
        private final List<L2CapServerChannel> openChannels;
        private boolean isAcceptingConnections;

        public ServerSocketInfo(BluetoothServerSocket serverSocket) {
            this.serverSocket = serverSocket;
            this.openChannels = Collections.synchronizedList(new LinkedList<>());
            this.isAcceptingConnections = false;
        }

        @Override
        public Type getType() {
            return Type.SERVER;
        }

        @Override
        public int getPsm() {
            return serverSocket.getPsm();
        }

        void addConnection(L2CapServerChannel channel) {
            openChannels.add(channel);
        }

        @Override
        public L2CapServerChannel getL2CapChannel(BluetoothDevice remoteDevice) {
            for (L2CapServerChannel openChannel : openChannels) {
                if (remoteDevice.getAddress().equals(openChannel.getSocket().getRemoteDevice().getAddress())) {
                    return openChannel;
                }
            }
            return null;
        }

        @Override
        public void close(BluetoothDevice device) {
            L2CapServerChannel channelToDelete = getL2CapChannel(device);
            if (channelToDelete == null) {
                return;
            }
            channelToDelete.close();
            openChannels.remove(channelToDelete);
        }

        public void acceptConnections() {
            isAcceptingConnections = true;
            new Thread(() -> {
                while (isAcceptingConnections) {
                    try {
                        BluetoothSocket socket = serverSocket.accept();
                        if (!isAcceptingConnections) {
                            break;
                        }
                        L2CapServerChannel l2capChannel = new L2CapServerChannel(socket);
                        l2capChannel.openStreams();
                        addConnection(l2capChannel);
                        
                        // Fire device connected event
                        HashMap<String, Object> deviceConnectedData = new HashMap<>();
                        deviceConnectedData.put("remote_id", socket.getRemoteDevice().getAddress());
                        deviceConnectedData.put("psm", getPsm());
                        invokeMethodUIThread("deviceConnectedToL2CapChannel", deviceConnectedData);
                    } catch (IOException e) {
                        if (isAcceptingConnections) {
                            // Only log if we're still supposed to be accepting
                        }
                    }
                }
            }).start();
        }

        public void closeSocket() {
            for (L2CapServerChannel openChannel : openChannels) {
                openChannel.close();
            }
            openChannels.clear();
            isAcceptingConnections = false;
            try {
                serverSocket.close();
            } catch (IOException e) {
                // ignore
            }
        }
    }

    private interface OperationOnPermission {
        void op(boolean granted, String permission);
    }

    public FlutterBluePlusPlugin() {}


    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding)
    {
        LogLevel.DEBUG.log("onAttachedToEngine");

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
        LogLevel.DEBUG.log("onDetachedFromEngine");
        invokeMethodUIThread("OnDetachedFromEngine", new HashMap<>());

        pluginBinding = null;

        // stop scanning
        if (mBluetoothAdapter != null && mIsScanning) {
            BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
            if (scanner != null) {
                scanner.stopScan(getScanCallback());
                mIsScanning = false;
            }
        }

        disconnectAllDevices("onDetachedFromEngine");

        context.unregisterReceiver(mBluetoothBondStateReceiver);
        context.unregisterReceiver(mBluetoothAdapterStateReceiver);
        context = null;

        methodChannel.setMethodCallHandler(null);
        methodChannel = null;

        mBluetoothAdapter = null;
        mBluetoothManager = null;
        l2CapChannelManager = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding)
    {
        LogLevel.DEBUG.log("onAttachedToActivity");
        activityBinding = binding;
        activityBinding.addRequestPermissionsResultListener(this);
        activityBinding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges()
    {
        LogLevel.DEBUG.log("onDetachedFromActivityForConfigChanges");
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding)
    {
        LogLevel.DEBUG.log("onReattachedToActivityForConfigChanges");
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity()
    {
        LogLevel.DEBUG.log("onDetachedFromActivity");
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

    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    @SuppressWarnings({"deprecation", "unchecked"}) // needed for compatibility, type safety uses bluetooth_msgs.dart
    public void onMethodCall(@NonNull MethodCall call,
                                 @NonNull Result result)
    {
        try {
            LogLevel.DEBUG.log( "onMethodCall: " + call.method);

            // initialize adapter
            if (mBluetoothAdapter == null) {
                LogLevel.DEBUG.log("initializing BluetoothAdapter");
                mBluetoothManager = (BluetoothManager) this.context.getSystemService(Context.BLUETOOTH_SERVICE);
                mBluetoothAdapter = mBluetoothManager != null ? mBluetoothManager.getAdapter() : null;
            }

            // check that we have an adapter, except for 
            // the functions that do not need it
            if(mBluetoothAdapter == null && 
                "flutterHotRestart".equals(call.method) == false &&
                "connectedCount".equals(call.method) == false &&
                "setLogLevel".equals(call.method) == false &&
                "isSupported".equals(call.method) == false &&
                "getAdapterName".equals(call.method) == false &&
                "getAdapterState".equals(call.method) == false) {
                result.error("bluetoothUnavailable", "the device does not support bluetooth", null);
                return;
            }
            // L2CAP functionality integrated directly - no separate manager needed

            switch (call.method) {

                case "flutterHotRestart":
                {
                    // no adapter?
                    if (mBluetoothAdapter == null) {
                        result.success(0); // no work to do
                        break;
                    }

                    // stop scanning
                    BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
                    if(scanner != null && mIsScanning) {
                        scanner.stopScan(getScanCallback());
                        mIsScanning = false;
                    }

                    disconnectAllDevices("flutterHotRestart");

                    log(LogLevel.DEBUG, "connectedPeripherals: " + mConnectedDevices.size());

                    result.success(mConnectedDevices.size());
                    break;
                }

                case "setOptions":
                {
                    // Currently ignored on Android
                    result.success(true);
                    break;
                }

                case "connectedCount":
                {
                    log(LogLevel.DEBUG, "connectedPeripherals: " + mConnectedDevices.size());
                    if (mConnectedDevices.size() == 0) {
                        log(LogLevel.DEBUG, "Hot Restart: complete");
                    }
                    result.success(mConnectedDevices.size());
                    break;
                }

                case "setLogLevel":
                {
                    int idx = (int)call.arguments;

                    // set global var
                    LogLevel.setLogLevel(LogLevel.values()[idx]);

                    result.success(true);
                    break;
                }

                case "isSupported":
                {
                    result.success(mBluetoothAdapter != null);
                    break;
                }

               case "getAdapterName":
                {
                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    if (Build.VERSION.SDK_INT <= 30) { // Android 11 (September 2020)
                        permissions.add(Manifest.permission.BLUETOOTH);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        String adapterName = mBluetoothAdapter != null ? mBluetoothAdapter.getName() : "N/A";
                        result.success(adapterName != null ? adapterName : "");

                    });
                    break;
                }

                case "getAdapterState":
                {
                    // get adapterState, if we have permission
                    int adapterState = -1; // unknown
                    try {
                        adapterState = mBluetoothAdapter.getState();
                    } catch (Exception e) {}

                    // see: BmBluetoothAdapterState
                    HashMap<String, Object> map = new HashMap<>();
                    map.put("adapter_state", MarshallingUtil.bmAdapterStateEnum(adapterState));

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

                        if (granted == false) {
                            result.error("turnOn",
                                String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        if (mBluetoothAdapter.isEnabled()) {
                            result.success(false); // no work to do
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

                        if (granted == false) {
                            result.error("turnOff",
                                String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

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
                    // see: BmScanSettings
                    HashMap<String, Object> data = call.arguments();
                    List<String> withServices =    (List<String>) data.get("with_services");
                    List<String> withRemoteIds =   (List<String>) data.get("with_remote_ids");
                    List<String> withNames =       (List<String>) data.get("with_names");
                    List<String> withKeywords =    (List<String>) data.get("with_keywords");
                    List<Object> withMsd =         (List<Object>) data.get("with_msd");
                    List<Object> withServiceData = (List<Object>) data.get("with_service_data");
                    boolean continuousUpdates =         (boolean) data.get("continuous_updates");
                    int androidScanMode =                   (int) data.get("android_scan_mode");
                    boolean androidUsesFineLocation =   (boolean) data.get("android_uses_fine_location");

                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_SCAN);
                        if (androidUsesFineLocation) {
                            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
                        }
                        // it is unclear why this is needed, but some phones throw a
                        // SecurityException AdapterService getRemoteName, without it
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    if (Build.VERSION.SDK_INT <= 30) { // Android 11 (September 2020)
                        permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (granted == false) {
                            result.error("startScan", 
                                String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        // check adapter
                        if (isAdapterOn() == false) {
                            result.error("startScan", String.format("bluetooth must be turned on"), null);
                            return;
                        }

                        // get scanner
                        BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
                        if(scanner == null) {
                            result.error("startScan", String.format("getBluetoothLeScanner() is null. Is the Adapter on?"), null);
                            return;
                        }

                        // build scan settings
                        ScanSettings.Builder builder = new ScanSettings.Builder();
                        builder.setScanMode(androidScanMode);
                        if (Build.VERSION.SDK_INT >= 26) { // Android 8.0 (August 2017)
                            builder.setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED);
                            builder.setLegacy(false);
                        }
                        ScanSettings settings = builder.build();
                        
                        // set filters
                        List<ScanFilter> filters = new ArrayList<>();

                        // services
                        for (int i = 0; i < withServices.size(); i++) {
                            ParcelUuid s = ParcelUuid.fromString(MarshallingUtil.uuid128(withServices.get(i)));
                            ScanFilter f = new ScanFilter.Builder().setServiceUuid(s).build();
                            filters.add(f);
                        }
                        
                        // remoteIds
                        for (int i = 0; i < withRemoteIds.size(); i++) {
                            String address = withRemoteIds.get(i);
                            ScanFilter f = new ScanFilter.Builder().setDeviceAddress(address).build();
                            filters.add(f);
                        }

                        // names
                        for (int i = 0; i < withNames.size(); i++) {
                            String name = withNames.get(i);
                            ScanFilter f = new ScanFilter.Builder().setDeviceName(name).build();
                            filters.add(f);
                        }

                        // keywords
                        if (Build.VERSION.SDK_INT >= 33) { // Android 13 (August 2022)
                            if (withKeywords.size() > 0) {
                                // device must advertise a name
                                int a1 = ScanRecord.DATA_TYPE_LOCAL_NAME_SHORT;
                                int a2 = ScanRecord.DATA_TYPE_LOCAL_NAME_COMPLETE;
                                ScanFilter f1 = new ScanFilter.Builder().setAdvertisingDataType(a1).build();
                                ScanFilter f2 = new ScanFilter.Builder().setAdvertisingDataType(a2).build();
                                filters.add(f1);
                                filters.add(f2);
                            }
                        }

                        // msd
                        for (int i = 0; i < withMsd.size(); i++) {
                            HashMap<String, Object> m = (HashMap<String, Object>) withMsd.get(i);
                            int id =                    (int) m.get("manufacturer_id");
                            byte[] mdata = MarshallingUtil.hexToBytes((String) m.get("data"));
                            byte[] mask =  MarshallingUtil.hexToBytes((String) m.get("mask"));
                            ScanFilter f = null;
                            if (mask.length == 0) {
                                f = new ScanFilter.Builder().setManufacturerData(id, mdata).build();
                            } else {
                                f = new ScanFilter.Builder().setManufacturerData(id, mdata, mask).build();
                            }
                            filters.add(f);
                        }

                        // service data
                        for (int i = 0; i < withServiceData.size(); i++) {
                            HashMap<String, Object> m = (HashMap<String, Object>) withServiceData.get(i);
                            ParcelUuid s = ParcelUuid.fromString((String) m.get("service"));
                            byte[] mdata =             MarshallingUtil.hexToBytes((String) m.get("data"));
                            byte[] mask =              MarshallingUtil.hexToBytes((String) m.get("mask"));
                            ScanFilter f = null;
                            if (mask.length == 0) {
                                f = new ScanFilter.Builder().setServiceData(s, mdata).build();
                            } else {
                                f = new ScanFilter.Builder().setServiceData(s, mdata, mask).build();
                            }
                            filters.add(f);
                        }

                        // remember for later
                        mScanFilters = data;

                        // clear seen devices
                        mAdvSeen.clear();
                        mScanCounts.clear();

                        scanner.startScan(filters, settings, getScanCallback());

                        mIsScanning = true;

                        result.success(true);
                    });
                    break;
                }

                case "stopScan":
                {
                    BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();

                    if(scanner != null) {
                        scanner.stopScan(getScanCallback());
                        mIsScanning = false;
                    }

                    result.success(true);
                    break;
                }

                case "getSystemDevices":
                {
                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (granted == false) {
                            result.error("getSystemDevices",
                                String.format("FlutterBluePlus requires %s permission", perm), null);
                            return;
                        }

                        // this includes devices connected by other apps
                        List<BluetoothDevice> devices = mBluetoothManager.getConnectedDevices(BluetoothProfile.GATT);

                        List<HashMap<String, Object>> devList = new ArrayList<HashMap<String, Object>>();
                        for (BluetoothDevice d : devices) {
                            devList.add(MarshallingUtil.bmBluetoothDevice(d));
                        }

                        // See: BmDevicesList
                        HashMap<String, Object> response = new HashMap<>();
                        response.put("devices", devList);

                        result.success(response);
                    });
                    break;
                }

                case "connect":
                {
                    // see: BmConnectRequest
                    HashMap<String, Object> args = call.arguments();
                    String remoteId =    (String) args.get("remote_id");
                    boolean autoConnect = ((int) args.get("auto_connect")) != 0;

                    ArrayList<String> permissions = new ArrayList<>();

                    if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }

                    ensurePermissions(permissions, (granted, perm) -> {

                        if (granted == false) {
                            result.error("connect",
                                String.format("FlutterBluePlus requires %s for new connection", perm), null);
                            return;
                        }

                        // check adapter
                        if (isAdapterOn() == false) {
                            result.error("connect", String.format("bluetooth must be turned on"), null);
                            return;
                        }

                        // already connecting?
                        if (mCurrentlyConnectingDevices.get(remoteId) != null) {
                            LogLevel.DEBUG.log("already connecting");
                            result.success(true);  // still work to do
                            return;
                        } 

                        // already connected?
                        if (mConnectedDevices.get(remoteId) != null) {
                            LogLevel.DEBUG.log("already connected");
                            result.success(false);  // no work to do
                            return;
                        } 

                        // wait if any device is bonding (increases reliability)
                        waitIfBonding();

                        // connect
                        BluetoothGatt gatt = null;
                        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
                        if (Build.VERSION.SDK_INT >= 23) { // Android 6.0 (October 2015)
                            gatt = device.connectGatt(context, autoConnect, mGattCallback, BluetoothDevice.TRANSPORT_LE);
                        } else {
                            gatt = device.connectGatt(context, autoConnect, mGattCallback);
                        }

                        // error check
                        if (gatt == null) {
                            result.error("connect", String.format("device.connectGatt returned null"), null);
                            return;
                        }

                        // add to currently connecting peripherals
                        mCurrentlyConnectingDevices.put(remoteId, gatt);

                        // remember autoconnect 
                        if (autoConnect) {
                            mAutoConnected.put(remoteId, gatt);
                        } else {
                            mAutoConnected.remove(remoteId);
                        }

                        result.success(true);
                    });
                    break;
                }

                case "disconnect":
                {
                    String remoteId = (String) call.arguments;

                    // already disconnected?
                    BluetoothGatt gatt = null;
                    if (gatt == null) {
                        gatt = mCurrentlyConnectingDevices.get(remoteId);
                        if (gatt != null) {
                            LogLevel.DEBUG.log("disconnect: cancelling connection in progress");
                        }
                    }
                    if (gatt == null) {
                        gatt = mConnectedDevices.get(remoteId);;
                    }
                    if (gatt == null) {
                        gatt = mAutoConnected.get(remoteId);
                        if (gatt != null) {
                            LogLevel.DEBUG.log("already disconnected. disabling autoconnect");
                            mAutoConnected.remove(remoteId);
                            gatt.disconnect();
                            gatt.close();
                            result.success(false);  // no work to do
                            return;
                        }
                    }
                    if (gatt == null) {
                        LogLevel.DEBUG.log("already disconnected");
                        result.success(false);  // no work to do
                        return;
                    }

                    // calling disconnect explicitly turns off autoconnect.
                    // this allows gatt resources to be reclaimed
                    mAutoConnected.remove(remoteId);
                
                    // disconnect
                    gatt.disconnect();

                    // was connecting?
                    if (mCurrentlyConnectingDevices.get(remoteId) != null) {

                        // remove
                        mCurrentlyConnectingDevices.remove(remoteId);

                        // cleanup
                        gatt.close();

                        // see: BmConnectionStateResponse
                        HashMap<String, Object> response = new HashMap<>();
                        response.put("remote_id", remoteId);
                        response.put("connection_state", MarshallingUtil.bmConnectionStateEnum(BluetoothProfile.STATE_DISCONNECTED));
                        response.put("disconnect_reason_code", 23789258); // random value
                        response.put("disconnect_reason_string", "connection canceled");

                        invokeMethodUIThread("OnConnectionStateChanged", response);
                    }

                    result.success(true);
                    break;
                }

                case "discoverServices":
                {
                    String remoteId = (String) call.arguments;

                    // check connection
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("discoverServices", "device is disconnected", null);
                        break;
                    }

                    // wait if any device is bonding (increases reliability)
                    waitIfBonding();

                    // discover services
                    if(gatt.discoverServices() == false) {
                        result.error("discoverServices", "gatt.discoverServices() returned false", null);
                        break;
                    }

                    result.success(true);
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
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("readCharacteristic", "device is disconnected", null);
                        break;
                    }

                    // wait if any device is bonding (increases reliability)
                    waitIfBonding();

                    // find characteristic
                    ChrFound found = locateCharacteristic(gatt, serviceUuid, secondaryServiceUuid, characteristicUuid);
                    if (found.error != null) {
                        result.error("readCharacteristic", found.error, null);
                        break;
                    }

                    BluetoothGattCharacteristic characteristic = found.characteristic;

                    // check readable
                    if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_READ) == 0) {
                        result.error("readCharacteristic",
                            "The READ property is not supported by this BLE characteristic", null);
                        break;
                    }

                    // read
                    if(gatt.readCharacteristic(characteristic) == false) {
                        result.error("readCharacteristic",
                            "gatt.readCharacteristic() returned false", null);
                        break;
                    }

                    result.success(true);
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
                    boolean allowLongWrite =        ((int) data.get("allow_long_write")) != 0;

                    int writeType = writeTypeInt == 0 ?
                        BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT :
                        BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE;

                    // check connection
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("writeCharacteristic", "device is disconnected", null);
                        break;
                    }

                    // wait if any device is bonding (increases reliability)
                    waitIfBonding();

                    // find characteristic
                    ChrFound found = locateCharacteristic(gatt, serviceUuid, secondaryServiceUuid, characteristicUuid);
                    if (found.error != null) {
                        result.error("writeCharacteristic", found.error, null);
                        break;
                    }

                    BluetoothGattCharacteristic characteristic = found.characteristic;

                    // check writeable
                    if(writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
                        if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) == 0) {
                            result.error("writeCharacteristic",
                                "The WRITE_NO_RESPONSE property is not supported by this BLE characteristic", null);
                            break;
                        }
                    } else {
                         if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_WRITE) == 0) {
                            result.error("writeCharacteristic",
                                "The WRITE property is not supported by this BLE characteristic", null);
                            break;
                        }
                    }

                    // check maximum payload
                    int maxLen = getMaxPayload(remoteId, writeType, allowLongWrite);
                    int dataLen = MarshallingUtil.hexToBytes(value).length;
                    if (dataLen > maxLen) {
                        String a = writeTypeInt == 0 ? "withResponse" : "withoutResponse";
                        String b = writeTypeInt == 0 ? (allowLongWrite ? ", allowLongWrite" : ", noLongWrite") : "";
                        String str = "data longer than allowed. dataLen: " + dataLen + " > max: " + maxLen + " (" + a + b +")";
                        result.error("writeCharacteristic", str, null);
                        break;
                    }

                    // remember the data we are writing
                    String key = remoteId + ":" + serviceUuid + ":" + characteristicUuid;
                    mWriteChr.put(key, value);

                    // write characteristic
                    if (Build.VERSION.SDK_INT >= 33) { // Android 13 (August 2022)

                        int rv = gatt.writeCharacteristic(characteristic, MarshallingUtil.hexToBytes(value), writeType);

                        if (rv != BluetoothStatusCodes.SUCCESS) {
                            String s = "gatt.writeCharacteristic() returned " + rv + " : " + bluetoothStatusString(rv);
                            result.error("writeCharacteristic", s, null);
                            return;
                        }

                    } else {
                        // set value
                        if(!characteristic.setValue(MarshallingUtil.hexToBytes(value))) {
                            result.error("writeCharacteristic", "characteristic.setValue() returned false", null);
                            break;
                        }

                        // Write type
                        characteristic.setWriteType(writeType);

                        // Write Char
                        if(!gatt.writeCharacteristic(characteristic)){
                            result.error("writeCharacteristic", "gatt.writeCharacteristic() returned false", null);
                            break;
                        }
                    }

                    result.success(true);
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
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("readDescriptor", "device is disconnected", null);
                        break;
                    }

                    // wait if any device is bonding (increases reliability)
                    waitIfBonding();

                    // find characteristic
                    ChrFound found = locateCharacteristic(gatt, serviceUuid, secondaryServiceUuid, characteristicUuid);
                    if (found.error != null) {
                        result.error("readDescriptor", found.error, null);
                        break;
                    }

                    BluetoothGattCharacteristic characteristic = found.characteristic;

                    // find descriptor
                    BluetoothGattDescriptor descriptor = getDescriptorFromArray(descriptorUuid, characteristic.getDescriptors());
                    if(descriptor == null) {
                        String s = "descriptor not found on characteristic. (desc: " + descriptorUuid + " chr: " + characteristicUuid + ")";
                        result.error("writeDescriptor", s, null);
                        break;
                    }

                    // read descriptor
                    if(gatt.readDescriptor(descriptor) == false) {
                        result.error("readDescriptor", "gatt.readDescriptor() returned false", null);
                        break;
                    }

                    result.success(true);
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
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("writeDescriptor", "device is disconnected", null);
                        break;
                    }

                    // wait if any device is bonding (increases reliability)
                    waitIfBonding();

                    // find characteristic
                    ChrFound found = locateCharacteristic(gatt, serviceUuid, secondaryServiceUuid, characteristicUuid);
                    if (found.error != null) {
                        result.error("writeDescriptor", found.error, null);
                        break;
                    }

                    BluetoothGattCharacteristic characteristic = found.characteristic;

                    // find descriptor
                    BluetoothGattDescriptor descriptor = getDescriptorFromArray(descriptorUuid, characteristic.getDescriptors());
                    if(descriptor == null) {
                        String s = "descriptor not found on characteristic. (desc: " + descriptorUuid + " chr: " + characteristicUuid + ")";
                        result.error("writeDescriptor", s, null);
                        break;
                    }

                    // check mtu
                    int mtu = mMtu.get(remoteId);
                    if ((mtu-3) < MarshallingUtil.hexToBytes(value).length) {
                        String s = "data longer than mtu allows. dataLength: " +
                            MarshallingUtil.hexToBytes(value).length + "> max: " + (mtu-3);
                        result.error("writeDescriptor", s, null);
                        break;
                    }

                    // remember the data we are writing
                    String key = remoteId + ":" + serviceUuid + ":" + characteristicUuid + ":" + descriptorUuid;
                    mWriteDesc.put(key, value);

                    // write descriptor
                    if (Build.VERSION.SDK_INT >= 33) { // Android 13 (August 2022)

                        int rv = gatt.writeDescriptor(descriptor, MarshallingUtil.hexToBytes(value));
                        if (rv != BluetoothStatusCodes.SUCCESS) {
                            String s = "gatt.writeDescriptor() returned " + rv + " : " + bluetoothStatusString(rv);
                            result.error("writeDescriptor", s, null);
                            return;
                        }

                    } else {

                        // Set descriptor
                        if(!descriptor.setValue(MarshallingUtil.hexToBytes(value))){
                            result.error("writeDescriptor", "descriptor.setValue() returned false", null);
                            break;
                        }

                        // Write descriptor
                        if(!gatt.writeDescriptor(descriptor)){
                            result.error("writeDescriptor", "gatt.writeDescriptor() returned false", null);
                            break;
                        }
                    }

                    result.success(true);
                    break;
                }

                case "setNotifyValue":
                {
                    // see: BmSetNotifyValueRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId =             (String) data.get("remote_id");
                    String serviceUuid =          (String) data.get("service_uuid");
                    String secondaryServiceUuid = (String) data.get("secondary_service_uuid");
                    String characteristicUuid =   (String) data.get("characteristic_uuid");
                    boolean forceIndications =   (boolean) data.get("force_indications");
                    boolean enable =             (boolean) data.get("enable");

                    // check connection
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("setNotifyValue", "device is disconnected", null);
                        break;
                    }

                    // wait if any device is bonding (increases reliability)
                    waitIfBonding();

                    // find characteristic
                    ChrFound found = locateCharacteristic(gatt, serviceUuid, secondaryServiceUuid, characteristicUuid);
                    if (found.error != null) {
                        result.error("setNotifyValue", found.error, null);
                        break;
                    }

                    BluetoothGattCharacteristic characteristic = found.characteristic;

                    // configure local Android device to listen for characteristic changes
                    if(!gatt.setCharacteristicNotification(characteristic, enable)){
                        result.error("setNotifyValue",
                            "gatt.setCharacteristicNotification(" + enable + ") returned false", null);
                        break;
                    }

                    // find cccd descriptor
                    BluetoothGattDescriptor cccd = getDescriptorFromArray(CCCD, characteristic.getDescriptors());
                    if(cccd == null) {
                        // Some ble devices do not actually need their CCCD updated.
                        // thus setCharacteristicNotification() is all that is required to enable notifications.
                        // The arduino "bluno" devices are an example.
                        String uuid = MarshallingUtil.uuidStr(characteristic.getUuid());
                        LogLevel.WARNING.log("CCCD descriptor for characteristic not found: " + uuid);
                        result.success(false);
                        return;
                    }

                    byte[] descriptorValue = null;

                    // determine value to write
                    if(enable) {

                        boolean canNotify = (characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) > 0;
                        boolean canIndicate = (characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) > 0;

                        if(!canIndicate && !canNotify) {
                            result.error("setNotifyValue",
                                "neither NOTIFY nor INDICATE properties are supported by this BLE characteristic", null);
                            break;
                        }

                        if (forceIndications && !canIndicate) {
                            result.error("setNotifyValue","INDICATE not supported by this BLE characteristic", null);
                            break;
                        }

                        // If a characteristic supports both notifications and indications,
                        // we use notifications. This matches how CoreBluetooth works on iOS.
                        // Except of course, if forceIndications is enabled.
                        if(canIndicate)      {descriptorValue = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE;}
                        if(canNotify)        {descriptorValue = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE;}
                        if(forceIndications) {descriptorValue = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE;}

                    } else {
                        descriptorValue  = BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE;
                    }

                    // remember the data we are writing
                    String key = remoteId + ":" + serviceUuid + ":" + characteristicUuid + ":" + CCCD;
                    mWriteDesc.put(key, MarshallingUtil.bytesToHex(descriptorValue));

                    // write descriptor
                    if (Build.VERSION.SDK_INT >= 33) { // Android 13 (August 2022)

                        int rv = gatt.writeDescriptor(cccd, descriptorValue);
                        if (rv != BluetoothStatusCodes.SUCCESS) {
                            String s = "gatt.writeDescriptor() returned " + rv + " : " + bluetoothStatusString(rv);
                            result.error("setNotifyValue", s, null);
                            break;
                        }

                    } else {

                        // set new value
                        if (!cccd.setValue(descriptorValue)) {
                            result.error("setNotifyValue", "cccd.setValue() returned false", null);
                            break;
                        }

                        // update notifications on remote BLE device
                        if (!gatt.writeDescriptor(cccd)) {
                            result.error("setNotifyValue", "gatt.writeDescriptor() returned false", null);
                            break;
                        }
                    }

                    result.success(true);
                    break;
                }

                case "requestMtu":
                {
                    // see: BmMtuChangeRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId = (String) data.get("remote_id");
                    int mtu =            (int) data.get("mtu");

                    // check connection
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("requestMtu", "device is disconnected", null);
                        break;
                    }

                    // wait if any device is bonding (increases reliability)
                    waitIfBonding();

                    // request mtu
                    if(gatt.requestMtu(mtu) == false) {
                        result.error("requestMtu", "gatt.requestMtu() returned false", null);
                        break;
                    }

                    result.success(true);
                    break;
                }

                case "readRssi":
                {
                    String remoteId = (String) call.arguments;

                    // check connection
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("readRssi", "device is disconnected", null);
                        break;
                    }

                    // wait if any device is bonding (increases reliability)
                    waitIfBonding();

                    // read rssi
                    if(gatt.readRemoteRssi() == false) {
                        result.error("readRssi", "gatt.readRemoteRssi() returned false", null);
                        break;
                    }

                    result.success(true);
                    break;
                }

                case "requestConnectionPriority":
                {
                    // see: BmConnectionPriorityRequest
                    HashMap<String, Object> data = call.arguments();
                    String remoteId =     (String) data.get("remote_id");
                    int connectionPriority = (int) data.get("connection_priority");

                    // check connection
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("requestConnectionPriority", "device is disconnected", null);
                        break;
                    }

                    // wait if any device is bonding (increases reliability)
                    waitIfBonding();
                    int cpInteger = MarshallingUtil.bmConnectionPriorityParse(connectionPriority);

                    // request priority
                    if(gatt.requestConnectionPriority(cpInteger) == false) {
                        result.error("requestConnectionPriority", "gatt.requestConnectionPriority() returned false", null);
                        break;
                    }

                    result.success(true);
                    break;
                }

                case "getPhySupport":
                {
                  if(Build.VERSION.SDK_INT < 26) { // Android 8.0 (August 2017)
                        result.error("getPhySupport",
                            "Only supported on devices >= API 26. This device == " +
                            Build.VERSION.SDK_INT, null);
                        break;
                    }

                    // see: PhySupport
                    HashMap<String, Object> map = new HashMap<>();
                    map.put("le_2M", mBluetoothAdapter.isLe2MPhySupported());
                    map.put("le_coded", mBluetoothAdapter.isLeCodedPhySupported());

                    result.success(map);
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
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("setPreferredPhy", "device is disconnected", null);
                        break;
                    }

                    // wait if any device is bonding (increases reliability)
                    waitIfBonding();

                    // set preferred phy
                    gatt.setPreferredPhy(txPhy, rxPhy, phyOptions);

                    result.success(true);
                    break;
                }

                case "getBondedDevices":
                {
                    final Set<BluetoothDevice> bondedDevices = mBluetoothAdapter.getBondedDevices();

                    List<HashMap<String,Object>> devList = new ArrayList<HashMap<String,Object>>();
                    for (BluetoothDevice d : bondedDevices) {
                        devList.add(MarshallingUtil.bmBluetoothDevice(d));
                    }

                    HashMap<String, Object> response = new HashMap<String, Object>();
                    response.put("devices", devList);

                    result.success(response);
                    break;
                }

                case "getBondState":
                {
                    String remoteId = (String) call.arguments;

                    // get bond state
                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);

                    // see: BmBondStateResponse
                    HashMap<String, Object> response = new HashMap<>();
                    response.put("remote_id", remoteId);
                    response.put("bond_state", MarshallingUtil.bmBondStateEnum(device.getBondState()));
                    response.put("prev_state", null);
                    result.success(response);
                    break;
                }

                case "createBond":
                {
                    String remoteId = (String) call.arguments;

                    // check connection
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("createBond", "device is disconnected", null);
                        break;
                    }

                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);

                    // already bonded?
                    if (device.getBondState() == BluetoothDevice.BOND_BONDED) {
                        LogLevel.WARNING.log("already bonded");
                        result.success(false); // no work to do
                        break;
                    }

                    // bonding already in progress?
                    if (device.getBondState() == BluetoothDevice.BOND_BONDING) {
                        LogLevel.WARNING.log("bonding already in progress");
                        result.success(true); // caller must wait for bond completion
                        break;
                    }

                    // bond
                    if(device.createBond() == false) {
                        result.error("createBond", "device.createBond() returned false", null);
                        break;
                    }

                    result.success(true);
                    break;
                }

                case "removeBond":
                {
                    String remoteId = (String) call.arguments;

                    BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);

                    // already removed?
                    if (device.getBondState() == BluetoothDevice.BOND_NONE) {
                        LogLevel.WARNING.log("already not bonded");
                        result.success(false); // no work to do
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

                    // check connection
                    BluetoothGatt gatt = mConnectedDevices.get(remoteId);
                    if(gatt == null) {
                        result.error("clearGattCache", "device is disconnected", null);
                        break;
                    }

                    final Method refreshMethod = gatt.getClass().getMethod("refresh");
                    if (refreshMethod == null) {
                        result.error("clearGattCache", "unsupported on this android version", null);
                        break;
                    }

                    refreshMethod.invoke(gatt);

                    result.success(true);
                    break;
                }
                case "connectToL2CapChannel": {
                    ArrayList<String> permissions = new ArrayList<>();
                    if (Build.VERSION.SDK_INT >= 31) {
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }
                    if (Build.VERSION.SDK_INT <= 30) {
                        permissions.add(Manifest.permission.BLUETOOTH);
                    }
                    ensurePermissions(permissions, (granted, permission) -> {
                        if (!granted) {
                            result.error("no_permissions", String.format("FlutterBluePlus requires %s permission", permission), null);
                            return;
                        }
                        connectToL2CapChannel(call, result);
                    });
                    break;
                }
                case "closeL2CapChannel": {
                    ArrayList<String> permissions = new ArrayList<>();
                    if (Build.VERSION.SDK_INT >= 31) {
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }
                    if (Build.VERSION.SDK_INT <= 30) {
                        permissions.add(Manifest.permission.BLUETOOTH);
                    }
                    ensurePermissions(permissions, (granted, permission) -> {
                        if (!granted) {
                            result.error("no_permissions", String.format("FlutterBluePlus requires %s permission", permission), null);
                            return;
                        }
                        closeL2CapChannel(call, result);
                    });
                    break;
                }
                case "listenL2CapChannel": {
                    ArrayList<String> permissions = new ArrayList<>();
                    if (Build.VERSION.SDK_INT >= 31) {
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }
                    if (Build.VERSION.SDK_INT <= 30) {
                        permissions.add(Manifest.permission.BLUETOOTH);
                    }
                    ensurePermissions(permissions, (granted, permission) -> {
                        if (!granted) {
                            result.error("no_permissions", String.format("FlutterBluePlus requires %s permission", permission), null);
                            return;
                        }
                        listenL2CapChannel(call, result);
                    });
                    break;
                }
                case "closeL2CapServer": {
                    ArrayList<String> permissions = new ArrayList<>();
                    if (Build.VERSION.SDK_INT >= 31) {
                        permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                    }
                    if (Build.VERSION.SDK_INT <= 30) {
                        permissions.add(Manifest.permission.BLUETOOTH);
                    }
                    ensurePermissions(permissions, (granted, permission) -> {
                        if (!granted) {
                            result.error("no_permissions", String.format("FlutterBluePlus requires %s permission", permission), null);
                            return;
                        }
                        closeL2CapServer(call, result);
                    });
                    break;
                }
                case "readL2CapChannel": {
                    readL2CapChannel(call, result);
                    break;
                }
                case "writeL2CapChannel": {
                    writeL2CapChannel(call, result);
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

   //////////////////////////////////////////////////////////////////////
   //  █████    ██████  ████████  ██  ██    ██  ██  ████████  ██    ██ 
   // ██   ██  ██          ██     ██  ██    ██  ██     ██      ██  ██  
   // ███████  ██          ██     ██  ██    ██  ██     ██       ████   
   // ██   ██  ██          ██     ██   ██  ██   ██     ██        ██    
   // ██   ██   ██████     ██     ██    ████    ██     ██        ██    
   // 
   // ██████   ███████  ███████  ██    ██  ██       ████████ 
   // ██   ██  ██       ██       ██    ██  ██          ██    
   // ██████   █████    ███████  ██    ██  ██          ██    
   // ██   ██  ██            ██  ██    ██  ██          ██    
   // ██   ██  ███████  ███████   ██████   ███████     ██    

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data)
    {
        if (requestCode == enableBluetoothRequestCode) {

            // see: BmTurnOnResponse
            HashMap<String, Object> map = new HashMap<>();
            map.put("user_accepted", resultCode == Activity.RESULT_OK);

            invokeMethodUIThread("OnTurnOnResponse", map);

            return true;
        }

        return false; // did not handle anything
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

    private void waitIfBonding() {
        int counter = 0;
        if (mBondingDevices.isEmpty() == false) {
            if (counter == 0) {
                LogLevel.DEBUG.log("[FBP] waiting for bonding to complete...");
            }
            try{Thread.sleep(50);}catch(Exception e){}
            counter++;
        }
        if (counter > 0) {
            LogLevel.DEBUG.log("[FBP] bonding completed");
        }
    }

    class ChrFound {
        public BluetoothGattCharacteristic characteristic;
        public String error;

        public ChrFound(BluetoothGattCharacteristic characteristic, String error) {
            this.characteristic = characteristic;
            this.error = error;
        }
    }

    private ChrFound locateCharacteristic(BluetoothGatt gatt,
                                                 String serviceId,
                                                 String secondaryServiceId,
                                                 String characteristicId)
    {
        // primary
        BluetoothGattService primaryService = getServiceFromArray(serviceId, gatt.getServices());
        if(primaryService == null) {
            return new ChrFound(null, "service not found '" + serviceId + "'");
        }

        // secondary
        BluetoothGattService secondaryService = null;
        if(secondaryServiceId != null && secondaryServiceId.length() > 0) {
            secondaryService = getServiceFromArray(serviceId, primaryService.getIncludedServices());
            if(secondaryService == null) {
                return new ChrFound(null, "secondaryService not found '" + secondaryServiceId + "'");
            }
        }

        // which service?
        BluetoothGattService service = (secondaryService != null) ? secondaryService : primaryService;

        // characteristic
        BluetoothGattCharacteristic characteristic = getCharacteristicFromArray(characteristicId, service.getCharacteristics());
        if(characteristic == null) {
            return new ChrFound(null, "characteristic not found in service " +
                "(chr: '" + characteristicId + "' svc: '" + serviceId + "')");
        }

        return new ChrFound(characteristic, null);
    }

    private BluetoothGattService getServiceFromArray(String uuid, List<BluetoothGattService> array)
    {
        for (BluetoothGattService s : array) {
            if (MarshallingUtil.uuid128(s.getUuid()).equals(uuid)) {
                return s;
            }
        }
        return null;
    }

    private BluetoothGattCharacteristic getCharacteristicFromArray(String uuid, List<BluetoothGattCharacteristic> array)
    {
        for (BluetoothGattCharacteristic c : array) {
            if (MarshallingUtil.uuid128(c.getUuid()).equals(uuid)) {
                return c;
            }
        }
        return null;
    }

    private BluetoothGattDescriptor getDescriptorFromArray(String uuid, List<BluetoothGattDescriptor> array)
    {
        for (BluetoothGattDescriptor d : array) {
            if (MarshallingUtil.uuid128(d.getUuid()).equals(uuid)) {
                return d;
            }
        }
        return null;
    }

    private boolean filterKeywords(List<String> keywords, String target) {
        if (keywords.isEmpty()) {
            return true;
        }
        if (target == null) {
            return false;
        }
        for (String k : keywords) {
            if (target.contains(k)) {
                return true;
            }
        }
        return false;
    }

    private int getMaxPayload(String remoteId, int writeType, boolean allowLongWrite)
    {
        // 512 this comes from the BLE spec. Characteritics should not
        // be longer than 512. Android also enforces this as the maximum in internal code.
        int maxAttrLen = 512;

        // if no response, we can only write up to MTU-3.
        // This is the same limitation as iOS, and ensures transfer reliability.
        if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE || allowLongWrite == false) {

            // get mtu
            Integer mtu = mMtu.get(remoteId);
            if (mtu == null) {
                mtu = 23; // 23 is the minumum MTU, as per the BLE spec
            }

            return Math.min(mtu - 3, maxAttrLen);

        } else {
            // if using withResponse, android will auto split up to the maxAttrLen.
            return maxAttrLen;
        }
    }

    private void disconnectAllDevices(String func)
    {
        LogLevel.DEBUG.log("disconnectAllDevices("+func+")");

        // request disconnections
        for (BluetoothGatt gatt : mConnectedDevices.values()) {

            if (func.equals("adapterTurnOff")) {

                // Note: 
                //  - calling `disconnect` and `close` after the adapter
                //    is turned off is not necessary. It is implied.
                //    Calling them leads to a `DeadObjectException`.
                //  - But, we must make sure the disconnect callback is called.
                //    It's surprising but android does not invoke this callback itself.
                mGattCallback.onConnectionStateChange(gatt, 0, BluetoothProfile.STATE_DISCONNECTED);

            } else {

                String remoteId = gatt.getDevice().getAddress();
                LogLevel.DEBUG.log("calling disconnect: " + remoteId);
                gatt.disconnect();

                // it is important to close after disconnection, otherwise we will 
                // quickly run out of bluetooth resources, preventing new connections
                LogLevel.DEBUG.log("calling close: " + remoteId);
                gatt.close();
            }
        }
        mMtu.clear();
        mConnectedDevices.clear();
        mCurrentlyConnectingDevices.clear();
        mBondingDevices.clear();
        mMtu.clear();
        mWriteChr.clear();
        mWriteDesc.clear();
        mAutoConnected.clear();
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

            LogLevel.DEBUG.log("OnAdapterStateChanged: " + adapterStateString(adapterState));

            // see: BmBluetoothAdapterState
            HashMap<String, Object> map = new HashMap<>();
            map.put("adapter_state", MarshallingUtil.bmAdapterStateEnum(adapterState));

            invokeMethodUIThread("OnAdapterStateChanged", map);

            // disconnect all devices
            if (adapterState == BluetoothAdapter.STATE_TURNING_OFF || 
                adapterState == BluetoothAdapter.STATE_OFF) {
                disconnectAllDevices("adapterTurnOff");
            }
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


    private final BroadcastReceiver mBluetoothBondStateReceiver = new BroadcastReceiver()
    {
        @Override
        @SuppressWarnings("deprecation") // need for compatability
        public void onReceive(Context context, Intent intent)
        {
            final String action = intent.getAction();

            // no change?
            if (action == null || action.equals(BluetoothDevice.ACTION_BOND_STATE_CHANGED) == false) {
                return;
            }

            // BluetoothDevice
            final BluetoothDevice device;
            if (Build.VERSION.SDK_INT >= 33) { // Android 13 (August 2022)
                device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice.class);
            } else {
                device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
            }

            final int cur = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR);
            final int prev = intent.getIntExtra(BluetoothDevice.EXTRA_PREVIOUS_BOND_STATE, -1);

            LogLevel.DEBUG.log("OnBondStateChanged: " + bondStateString(cur) + " prev: " + bondStateString(prev));

            String remoteId = device.getAddress();

            // remember which devices are currently bonding
            if (cur == BluetoothDevice.BOND_BONDING) {
                mBondingDevices.put(remoteId, device);
            } else {
                mBondingDevices.remove(remoteId);
            }

            // see: BmBondStateResponse
            HashMap<String, Object> map = new HashMap<>();
            map.put("remote_id", remoteId);
            map.put("bond_state", MarshallingUtil.bmBondStateEnum(cur));
            map.put("prev_state", MarshallingUtil.bmBondStateEnum(prev));
            invokeMethodUIThread("OnBondStateChanged", map);
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

    private int scanCountIncrement(String remoteId) {
        if (mScanCounts.get(remoteId) == null) {mScanCounts.put(remoteId, 0);}
        int count = mScanCounts.get(remoteId);
        mScanCounts.put(remoteId, count+1);
        return count;
    }

    private ScanCallback getScanCallback()
    {
        if(scanCallback == null) {

            scanCallback = new ScanCallback()
            {
                @Override
                @SuppressWarnings("unchecked") // type safety uses bluetooth_msgs.dart
                public void onScanResult(int callbackType, ScanResult result)
                {
                    LogLevel.VERBOSE.log("onScanResult");

                    super.onScanResult(callbackType, result);

                    BluetoothDevice device = result.getDevice();
                    String remoteId = device.getAddress();
                    ScanRecord scanRecord = result.getScanRecord();
                    String advHex = scanRecord != null ? MarshallingUtil.bytesToHex(scanRecord.getBytes()) : "";

                    // filter duplicates
                    if (((boolean) mScanFilters.get("continuous_updates")) == false) {
                        boolean isDuplicate = mAdvSeen.containsKey(remoteId) && mAdvSeen.get(remoteId).equals(advHex);
                        mAdvSeen.put(remoteId, advHex); // remember
                        if (isDuplicate) {
                            return;
                        }
                    }

                    // filter keywords
                    String name = scanRecord != null ? scanRecord.getDeviceName() : "";
                    List<String> keywords = (List<String>) mScanFilters.get("with_keywords");
                    if (filterKeywords(keywords, name) == false) {
                        return;
                    }

                    // filter divisor
                    if (((boolean) mScanFilters.get("continuous_updates")) != false) {
                        int count = scanCountIncrement(remoteId);   
                        int divisor = (int) mScanFilters.get("continuous_divisor");
                        if ((count % divisor) != 0) {
                            return;
                        }
                    }

                    // see BmScanResponse
                    HashMap<String, Object> response = new HashMap<>();
                    response.put("advertisements", Arrays.asList(MarshallingUtil.bmScanAdvertisement(device, result)));

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
                    LogLevel.ERROR.log("onScanFailed: " + scanFailedString(errorCode));

                    super.onScanFailed(errorCode);

                    // see BmScanResponse
                    HashMap<String, Object> response = new HashMap<>();
                    response.put("advertisements", new ArrayList<>());
                    response.put("success", 0);
                    response.put("error_code", errorCode);
                    response.put("error_string", scanFailedString(errorCode));

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
            LogLevel.DEBUG.log("onConnectionStateChange:" + connectionStateString(newState));
            LogLevel.DEBUG.log("  status: " + hciStatusString(status));

            // android never uses this callback with enums values of CONNECTING or DISCONNECTING,
            // (theyre only used for gatt.getConnectionState()), but just to be
            // future proof, explicitly ignore anything else. iOS & macOS is the same way.
            if(newState != BluetoothProfile.STATE_CONNECTED &&
               newState != BluetoothProfile.STATE_DISCONNECTED) {
                return;
            }

            String remoteId = gatt.getDevice().getAddress();

            // connected?
            if(newState == BluetoothProfile.STATE_CONNECTED) {
                // add to connected devices
                mConnectedDevices.put(remoteId, gatt);

                // remove from currently connecting devices
                mCurrentlyConnectingDevices.remove(remoteId);

                // default minimum mtu
                mMtu.put(remoteId, 23);
            }

            // disconnected?
            if(newState == BluetoothProfile.STATE_DISCONNECTED) {

                // remove from connected devices
                mConnectedDevices.remove(remoteId);

                // remove from currently connecting devices
                mCurrentlyConnectingDevices.remove(remoteId);

                // remove from currently bonding devices
                mBondingDevices.remove(remoteId);

                // we cannot call 'close' for autoconnected devices
                // because it prevents autoconnect from working
                if (mAutoConnected.containsKey(remoteId)) {
                    LogLevel.DEBUG.log("autoconnect is true. skipping gatt.close()");
                } else {
                    // it is important to close after disconnection, otherwise we will 
                    // quickly run out of bluetooth resources, preventing new connections
                    gatt.close();
                }
            }

            // see: BmConnectionStateResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", remoteId);
            response.put("connection_state", MarshallingUtil.bmConnectionStateEnum(newState));
            response.put("disconnect_reason_code", status);
            response.put("disconnect_reason_string", hciStatusString(status));

            invokeMethodUIThread("OnConnectionStateChanged", response);
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status)
        {
            LogLevel level = status == 0 ? LogLevel.DEBUG : LogLevel.ERROR;
            log(level, "onServicesDiscovered:");
            log(level, "  count: " + gatt.getServices().size());
            log(level, "  status: " + status + gattErrorString(status));

            List<Object> services = new ArrayList<Object>();
            for(BluetoothGattService s : gatt.getServices()) {
                services.add(MarshallingUtil.bmBluetoothService(gatt.getDevice(), s, gatt));
            }

            // see: BmDiscoverServicesResult
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("services", services);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnDiscoveredServices", response);
        }

        // called for both notifications & reads
        public void onCharacteristicReceived(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, byte[] value, int status)
        {
            ServicePair pair = MarshallingUtil.getServicePair(gatt, characteristic);

            // GATT Service?
            if (MarshallingUtil.uuidStr(pair.primary).equals("1800")) {

                // services changed
                if (MarshallingUtil.uuidStr(characteristic.getUuid()).equals("2A05")) {
                    HashMap<String, Object> response = MarshallingUtil.bmBluetoothDevice(gatt.getDevice());
                    invokeMethodUIThread("OnServicesReset", response);
                }
            }

            // see: BmCharacteristicData
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());

            response.put("service_uuid", MarshallingUtil.uuidStr(pair.primary));
            if (pair.secondary != null) {
                response.put("secondary_service_uuid", MarshallingUtil.uuidStr(pair.secondary));
            }
            response.put("characteristic_uuid", MarshallingUtil.uuidStr(characteristic.getUuid()));
            response.put("value", MarshallingUtil.bytesToHex(value));
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnCharacteristicReceived", response);
        }

        @Override
        @TargetApi(33) // newer function with byte[] value argument
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, byte[] value)
        {
            // this callback is only for notifications & indications
            LogLevel.DEBUG.log( "onCharacteristicChanged:");
            LogLevel.DEBUG.log( "  chr: " + MarshallingUtil.uuidStr(characteristic.getUuid()));
            onCharacteristicReceived(gatt, characteristic, value, BluetoothGatt.GATT_SUCCESS);
        }

        @Override
        @TargetApi(33) // newer function with byte[] value argument
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, byte[] value, int status)
        {
            // this callback is only for explicit characteristic reads
            LogLevel level = status == 0 ? LogLevel.DEBUG : LogLevel.ERROR;
            level.log("onCharacteristicRead:");
            level.log("  chr: " + MarshallingUtil.uuidStr(characteristic.getUuid()));
            level.log("  status: " + gattErrorString(status) + " (" + status + ")");
            onCharacteristicReceived(gatt, characteristic, value, BluetoothGatt.GATT_SUCCESS);
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            LogLevel level = status == 0 ? LogLevel.DEBUG : LogLevel.ERROR;
            level.log("onCharacteristicWrite:");
            level.log("  chr: " + MarshallingUtil.uuidStr(characteristic.getUuid()));
            level.log("  status: " + gattErrorString(status) + " (" + status + ")");

            // For "writeWithResponse", onCharacteristicWrite is called after the remote sends back a write response.
            // For "writeWithoutResponse", onCharacteristicWrite is called as long as there is still space left
            // in android's internal buffer. When the buffer is full, it delays calling onCharacteristicWrite
            // until there is at least ~50% free space again.

            ServicePair pair = MarshallingUtil.getServicePair(gatt, characteristic);

            // for convenience
            String remoteId = gatt.getDevice().getAddress();
            String serviceUuid = MarshallingUtil.uuidStr(pair.primary);
            String secondaryServiceUuid = pair.secondary != null ? MarshallingUtil.uuidStr(pair.secondary) : null;
            String characteristicUuid = MarshallingUtil.uuidStr(characteristic.getUuid());

            // what data did we write?
            String key = remoteId + ":" + serviceUuid + ":" + characteristicUuid;
            String value = mWriteChr.get(key) != null ? mWriteChr.get(key) : "";
            mWriteChr.remove(key);

            // see: BmCharacteristicData
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", remoteId);
            response.put("service_uuid", serviceUuid);
            if (secondaryServiceUuid != null) {
                response.put("secondary_service_uuid", secondaryServiceUuid);
            }
            response.put("characteristic_uuid", characteristicUuid);
            response.put("value", value);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnCharacteristicWritten", response);
        }

        @Override
        @TargetApi(33) // newer function, passes byte[] value
        public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status, byte[] value)
        {
            LogLevel level = status == 0 ? LogLevel.DEBUG : LogLevel.ERROR;
            level.log("onDescriptorRead:");
            level.log("  chr: " + MarshallingUtil.uuidStr(descriptor.getCharacteristic().getUuid()));
            level.log("  desc: " + MarshallingUtil.uuidStr(descriptor.getUuid()));
            level.log("  status: " + gattErrorString(status) + " (" + status + ")");

            ServicePair pair = MarshallingUtil.getServicePair(gatt, descriptor.getCharacteristic());

            // see: BmDescriptorData
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("service_uuid", MarshallingUtil.uuidStr(pair.primary));
            if (pair.secondary != null) {
                response.put("secondary_service_uuid", MarshallingUtil.uuidStr(pair.secondary));
            }
            response.put("characteristic_uuid", MarshallingUtil.uuidStr(descriptor.getCharacteristic().getUuid()));
            response.put("descriptor_uuid", MarshallingUtil.uuidStr(descriptor.getUuid()));
            response.put("value", MarshallingUtil.bytesToHex(value));
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnDescriptorRead", response);
        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            LogLevel level = status == 0 ? LogLevel.DEBUG : LogLevel.ERROR;
            level.log("onDescriptorWrite:");
            level.log("  chr: " + MarshallingUtil.uuidStr(descriptor.getCharacteristic().getUuid()));
            level.log("  desc: " + MarshallingUtil.uuidStr(descriptor.getUuid()));
            level.log("  status: " + gattErrorString(status) + " (" + status + ")");

            ServicePair pair = MarshallingUtil.getServicePair(gatt, descriptor.getCharacteristic());

            // for convenience
            String remoteId = gatt.getDevice().getAddress();
            String serviceUuid = MarshallingUtil.uuidStr(pair.primary);
            String secondaryServiceUuid = pair.secondary != null ? MarshallingUtil.uuidStr(pair.secondary) : null;
            String characteristicUuid = MarshallingUtil.uuidStr(descriptor.getCharacteristic().getUuid());
            String descriptorUuid = MarshallingUtil.uuidStr(descriptor.getUuid());

            // what data did we write?
            String key = remoteId + ":" + serviceUuid + ":" + characteristicUuid + ":" + descriptorUuid;
            String value = mWriteDesc.get(key) != null ? mWriteDesc.get(key) : "";
            mWriteDesc.remove(key);

            // see: BmDescriptorData
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", remoteId);
            response.put("service_uuid", serviceUuid);
            if (secondaryServiceUuid != null) {
                response.put("secondary_service_uuid", secondaryServiceUuid);
            }
            response.put("characteristic_uuid", characteristicUuid);
            response.put("descriptor_uuid", descriptorUuid);
            response.put("value", value);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnDescriptorWritten", response);
        }

        @Override
        public void onReliableWriteCompleted(BluetoothGatt gatt, int status)
        {
            LogLevel level = status == 0 ? LogLevel.DEBUG : LogLevel.ERROR;
            log(level, "onReliableWriteCompleted:");
            log(level, "  status: " + gattErrorString(status) + " (" + status + ")");
        }

        @Override
        public void onReadRemoteRssi(BluetoothGatt gatt, int rssi, int status)
        {
            LogLevel level = status == 0 ? LogLevel.DEBUG : LogLevel.ERROR;
            log(level, "onReadRemoteRssi:");
            log(level, "  rssi: " + rssi);
            log(level, "  status: " + gattErrorString(status) + " (" + status + ")");

            // see: BmReadRssiResult
            HashMap<String, Object> response = new HashMap<>();
            response.put("remote_id", gatt.getDevice().getAddress());
            response.put("rssi", rssi);
            response.put("success", status == BluetoothGatt.GATT_SUCCESS ? 1 : 0);
            response.put("error_code", status);
            response.put("error_string", gattErrorString(status));

            invokeMethodUIThread("OnReadRssi", response);
        }

        @Override
        public void onMtuChanged(BluetoothGatt gatt, int mtu, int status)
        {
            LogLevel level = status == 0 ? LogLevel.DEBUG : LogLevel.ERROR;
            log(level, "onMtuChanged:");
            log(level, "  mtu: " + mtu );
            log(level, "  status: " + gattErrorString(status) + " (" + status + ")");

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

        @Override
        @SuppressWarnings("deprecation") // needed for android 12 & lower compatability
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic)
        {
            // getValue() was deprecated in API level 33 because the function makes it look like
            // you could always call getValue on a characteristic. But in reality, getValue()
            // only works after a *read* has been made, not a *write*.
            this.onCharacteristicChanged(gatt, characteristic, characteristic.getValue());
        }
        
        @Override
        @SuppressWarnings("deprecation") // needed for android 12 & lower compatability
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            // getValue() was deprecated in API level 33 because the function makes it look like
            // you could always call getValue on a characteristic. But in reality, getValue()
            // only works after a *read* has been made, not a *write*.
            this.onCharacteristicRead(gatt, characteristic, characteristic.getValue(), status);
        }

        @Override
        @SuppressWarnings("deprecation") // needed for android 12 & lower compatability
        public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            // getValue() was deprecated in API level 33 because the api makes it look like
            // you could always call getValue on a descriptor. But in reality, getValue()
            // only works after a *read* has been made, not a *write*.
            this.onDescriptorRead(gatt, descriptor, status, descriptor.getValue());
        }

    }; // BluetoothGattCallback

    public static class ServicePair {
        public UUID primary;
        public UUID secondary;
    }

    //////////////////////////////////////////
    // ██    ██ ████████  ██  ██       ███████
    // ██    ██    ██     ██  ██       ██
    // ██    ██    ██     ██  ██       ███████
    // ██    ██    ██     ██  ██            ██
    //  ██████     ██     ██  ███████  ███████

    private void log(LogLevel level, String message)
    {
        level.log(message);
    }

    private void invokeMethodUIThread(final String method, Map<String, Object> data)
    {
        new Handler(Looper.getMainLooper()).post(() -> {
            //Could already be teared down at this moment
            if (methodChannel != null) {
                methodChannel.invokeMethod(method, data);
            } else {
                LogLevel.WARNING.log("invokeMethodUIThread: tried to call method on closed channel: " + method);
            }
        });
    }
    private boolean isAdapterOn()
    {
        // get adapterState, if we have permission
        try {
            return mBluetoothAdapter.getState() == BluetoothAdapter.STATE_ON;
        } catch (Exception e) {
            return false;
        }
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

    // Defined in the Bluetooth Standard
    private static String gattErrorString(int value) {
        switch(value) {
            case BluetoothGatt.GATT_SUCCESS                     : return "GATT_SUCCESS";                     // 0
            case 0x01                                           : return "GATT_INVALID_HANDLE";              // 1
            case BluetoothGatt.GATT_READ_NOT_PERMITTED          : return "GATT_READ_NOT_PERMITTED";          // 2
            case BluetoothGatt.GATT_WRITE_NOT_PERMITTED         : return "GATT_WRITE_NOT_PERMITTED";         // 3
            case 0x04                                           : return "GATT_INVALID_PDU";                 // 4
            case BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION : return "GATT_INSUFFICIENT_AUTHENTICATION"; // 5
            case BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED       : return "GATT_REQUEST_NOT_SUPPORTED";       // 6
            case BluetoothGatt.GATT_INVALID_OFFSET              : return "GATT_INVALID_OFFSET";              // 7
            case BluetoothGatt.GATT_INSUFFICIENT_AUTHORIZATION  : return "GATT_INSUFFICIENT_AUTHORIZATION";  // 8
            case 0x09                                           : return "GATT_PREPARE_QUEUE_FULL";          // 9
            case 0x0a                                           : return "GATT_ATTR_NOT_FOUND";              // 10
            case 0x0b                                           : return "GATT_ATTR_NOT_LONG";               // 11
            case 0x0c                                           : return "GATT_INSUFFICIENT_KEY_SIZE";       // 12
            case BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH    : return "GATT_INVALID_ATTRIBUTE_LENGTH";    // 13
            case 0x0e                                           : return "GATT_UNLIKELY";                    // 14
            case BluetoothGatt.GATT_INSUFFICIENT_ENCRYPTION     : return "GATT_INSUFFICIENT_ENCRYPTION";     // 15
            case 0x10                                           : return "GATT_UNSUPPORTED_GROUP";           // 16
            case 0x11                                           : return "GATT_INSUFFICIENT_RESOURCES";      // 17
            case BluetoothGatt.GATT_CONNECTION_CONGESTED        : return "GATT_CONNECTION_CONGESTED";        // 143
            case BluetoothGatt.GATT_FAILURE                     : return "GATT_FAILURE";                     // 257
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
            case 0x08: return "LINK_SUPERVISION_TIMEOUT"; // The link supervision timeout has expired for a given connection.
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

    //////////////////////////////////////////////////////////////////////
    // ██      ██████   ██████  █████  ██████  
    // ██           ██ ██      ██   ██ ██   ██ 
    // ██       █████  ██      ███████ ██████  
    // ██      ██      ██      ██   ██ ██      
    // ███████ ███████  ██████ ██   ██ ██      
    
    // L2CAP Method Implementations - Consolidated following FBP patterns
    
    @SuppressLint("MissingPermission")
    @TargetApi(Build.VERSION_CODES.Q)
    private void listenL2CapChannel(MethodCall call, Result result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("platformNotSupported", "The device is running an older Android version. Minimum version is Android Q.", null);
            return;
        }
        
        if (!mBluetoothAdapter.isEnabled()) {
            result.error("bluetoothTurnedOff", "Bluetooth is turned off.", null);
            return;
        }

        Map<String, Object> data = call.arguments();
        if (data == null) {
            result.error("invalidArguments", "Arguments required", null);
            return;
        }

        // Extract parameters inline
        boolean secure = (boolean) data.get("secure");

        try {
            BluetoothServerSocket serverSocket;
            if (secure) {
                serverSocket = mBluetoothAdapter.listenUsingL2capChannel();
            } else {
                serverSocket = mBluetoothAdapter.listenUsingInsecureL2capChannel();
            }
            
            ServerSocketInfo socketInfo = new ServerSocketInfo(serverSocket);
            openL2CapChannelInfos.add(socketInfo);
            int psm = serverSocket.getPsm();
            socketInfo.acceptConnections();

            // see: BmListenL2CapChannelResponse
            HashMap<String, Object> response = new HashMap<>();
            response.put("psm", psm);
            result.success(response);

        } catch (IOException e) {
            result.error("openL2capChannelFailed", e.getMessage(), null);
        }
    }

    @TargetApi(Build.VERSION_CODES.Q)
    private void connectToL2CapChannel(MethodCall call, Result result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("platformNotSupported", "The device is running an older Android version. Minimum version is Android Q.", null);
            return;
        }

        Map<String, Object> data = call.arguments();
        if (data == null) {
            result.error("invalidArguments", "Arguments required", null);
            return;
        }

        // Extract parameters inline
        String remoteId = (String) data.get("remote_id");
        int psm = (int) data.get("psm");
        boolean secure = (boolean) data.get("secure");
        
        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);

        L2CapInfo l2CapInfo = findL2CapInfo(psm);
        if (l2CapInfo == null) {
            l2CapInfo = new ClientSocketInfo(new L2CapClientChannel(device, psm));
            openL2CapChannelInfos.add(l2CapInfo);
        }
        
        L2CapClientChannel l2CapChannel = (L2CapClientChannel) l2CapInfo.getL2CapChannel(device);
        l2CapChannel.connectToL2CapChannel(secure, result);
    }

    private void readL2CapChannel(MethodCall call, Result result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("platformNotSupported", "The device is running an older Android version. Minimum version is Android Q.", null);
            return;
        }

        Map<String, Object> data = call.arguments();
        if (data == null) {
            result.error("invalidArguments", "Arguments required", null);
            return;
        }

        // Extract parameters inline
        String remoteId = (String) data.get("remote_id");
        int psm = (int) data.get("psm");
        
        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
        L2CapChannel channel = findL2CapChannel(psm, device);
        
        if (channel == null) {
            result.error("noOpenL2capChannelFound", "No open channel found for device " + device.getAddress() + " / psm " + psm, null);
            return;
        }
        
        channel.readL2CapChannel(remoteId, psm, result);
    }

    private void writeL2CapChannel(MethodCall call, Result result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("platformNotSupported", "The device is running an older Android version. Minimum version is Android Q.", null);
            return;
        }

        Map<String, Object> data = call.arguments();
        if (data == null) {
            result.error("invalidArguments", "Arguments required", null);
            return;
        }

        // Extract parameters inline
        String remoteId = (String) data.get("remote_id");
        int psm = (int) data.get("psm");
        byte[] value = (byte[]) data.get("value");
        
        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
        L2CapChannel channel = findL2CapChannel(psm, device);
        
        if (channel == null) {
            result.error("noOpenL2capChannelFound", "No open channel found for device " + device.getAddress() + " / psm " + psm, null);
            return;
        }
        
        channel.writeL2CapChannel(value, result);
    }

    private synchronized void closeL2CapChannel(MethodCall call, Result result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("platformNotSupported", "The device is running an older Android version. Minimum version is Android Q.", null);
            return;
        }

        Map<String, Object> data = call.arguments();
        if (data == null) {
            result.error("invalidArguments", "Arguments required", null);
            return;
        }

        // Extract parameters inline
        String remoteId = (String) data.get("remote_id");
        int psm = (int) data.get("psm");
        
        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(remoteId);
        L2CapInfo channelInfo = findL2CapInfo(psm);
        
        if (channelInfo != null) {
            try {
                channelInfo.close(device);
            } catch (IOException e) {
                result.error("closeL2capChannelFailed", "Can't close channel with psm " + psm, null);
                return;
            }
            if (channelInfo.getType() == L2CapInfo.Type.CLIENT) {
                openL2CapChannelInfos.remove(channelInfo);
            }
        }
        result.success(null);
    }

    private synchronized void closeL2CapServer(MethodCall call, Result result) {
        Map<String, Object> data = call.arguments();
        if (data == null) {
            result.error("invalidArguments", "Arguments required", null);
            return;
        }

        // Extract parameters inline
        int psm = (int) data.get("psm");
        
        L2CapInfo channelInfo = findL2CapInfo(psm);
        if (channelInfo != null && channelInfo.getType() == L2CapInfo.Type.SERVER) {
            ((ServerSocketInfo) channelInfo).closeSocket();
            openL2CapChannelInfos.remove(channelInfo);
        }
        result.success(null);
    }

    // Helper methods for L2CAP functionality
    private L2CapInfo findL2CapInfo(int psm) {
        for (L2CapInfo channelInfo : openL2CapChannelInfos) {
            if (psm == channelInfo.getPsm()) {
                return channelInfo;
            }
        }
        return null;
    }

    private L2CapChannel findL2CapChannel(int psm, BluetoothDevice remoteDevice) {
        L2CapInfo l2CapInfo = findL2CapInfo(psm);
        if (l2CapInfo == null) {
            return null;
        }
        return l2CapInfo.getL2CapChannel(remoteDevice);
    }
}
