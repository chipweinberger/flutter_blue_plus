package com.lib.android_bluetooth;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class AndroidBluetoothPlugin implements FlutterPlugin, MethodCallHandler
{
    private EventChannel.EventSink adapterStateChangedSink;
    private EventChannel.EventSink bondStateChangedSink;
    private Context context;
    private MethodChannel methodChannel;
    private boolean adapterStateReceiverRegistered = false;
    private boolean bondStateReceiverRegistered = false;
    private AdapterController adapterController;
    private final List<EventChannel> eventChannels = new ArrayList<>();
    private final DeviceController deviceController = new DeviceController();
    private final GattController gattController = new GattController();
    private final ManagerController managerController = new ManagerController();
    private final ScanController scanController = new ScanController();
    private final SocketController socketController = new SocketController();

    private interface EventSinkSetter
    {
        void set(EventChannel.EventSink sink);
    }

    private interface ResultProvider
    {
        Object get();
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding)
    {
        context = binding.getApplicationContext();
        adapterController = new AdapterController(context);
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), "android_bluetooth/methods");
        methodChannel.setMethodCallHandler(this);
        setUpEventChannels(binding);
        registerReceivers();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding)
    {
        tearDownMethodChannel();
        tearDownEventChannels();
        stopActiveOperations();
        clearEventSinks();
        unregisterReceivers();
        clearReferences();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result)
    {
        if (handleGeneralMethod(call, result)
            || handleAdapterMethod(call, result)
            || handleManagerMethod(call, result)
            || handleGattMethod(call, result)
            || handleDeviceMethod(call, result)
            || handleSocketMethod(call, result)
            || handleScanMethod(call, result)) {
            return;
        }

        result.notImplemented();
    }

    private boolean handleGeneralMethod(@NonNull MethodCall call, @NonNull Result result)
    {
        switch (call.method) {
            case "isSupported":
                result.success(adapterController != null && adapterController.isSupported(getBluetoothAdapter()));
                return true;
            case "hasBluetoothConnectPermission":
                result.success(adapterController != null && adapterController.hasBluetoothConnectPermission());
                return true;
            case "hasBluetoothScanPermission":
                result.success(adapterController != null && adapterController.hasBluetoothScanPermission());
                return true;
            default:
                return false;
        }
    }

    private boolean handleAdapterMethod(@NonNull MethodCall call, @NonNull Result result)
    {
        switch (call.method) {
            case "isEnabled":
                result.success(adapterController != null && adapterController.isEnabled(getBluetoothAdapter()));
                return true;
            case "enable":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> adapterController != null && adapterController.enable(getBluetoothAdapter())
                );
            case "disable":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> adapterController != null && adapterController.disable(getBluetoothAdapter())
                );
            case "getAdapterState":
                result.success(adapterController == null ? "unknown" : adapterController.getAdapterState(getBluetoothAdapter()));
                return true;
            case "getAdapterName":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> adapterController == null ? null : adapterController.getAdapterName(getBluetoothAdapter())
                );
            case "getAdapterAddress":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> adapterController == null ? null : adapterController.getAdapterAddress(getBluetoothAdapter())
                );
            case "setAdapterName":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> adapterController != null && adapterController.setAdapterName(getBluetoothAdapter(), argument(call))
                );
            case "getBluetoothLeScanner":
                return succeedWithScanPermission(
                    result,
                    call.method,
                    () -> adapterController != null && adapterController.hasBluetoothLeScanner(getBluetoothAdapter())
                );
            case "isOffloadedFilteringSupported":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> adapterController != null
                        && adapterController.isOffloadedFilteringSupported(getBluetoothAdapter())
                );
            case "isOffloadedScanBatchingSupported":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> adapterController != null
                        && adapterController.isOffloadedScanBatchingSupported(getBluetoothAdapter())
                );
            case "isLe2MPhySupported":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> adapterController != null && adapterController.isLe2MPhySupported(getBluetoothAdapter())
                );
            case "isLeCodedPhySupported":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> adapterController != null && adapterController.isLeCodedPhySupported(getBluetoothAdapter())
                );
            case "checkBluetoothAddress":
                result.success(adapterController != null && adapterController.checkBluetoothAddress(argument(call)));
                return true;
            default:
                return false;
        }
    }

    private boolean handleManagerMethod(@NonNull MethodCall call, @NonNull Result result)
    {
        switch (call.method) {
            case "getRemoteLeDevice":
                return succeedWithConnectPermission(result, call.method, () -> getRemoteLeDevice(argumentsMap(call)));
            case "getConnectedDevices":
                return succeedWithConnectPermission(result, call.method, () -> getConnectedDevices(argument(call)));
            case "getDevicesMatchingConnectionStates":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> getDevicesMatchingConnectionStates(argumentsMap(call))
                );
            case "getConnectionState":
                return succeedWithConnectPermission(result, call.method, () -> getConnectionState(argumentsMap(call)));
            case "getGattConnectionState":
                return succeedWithConnectPermission(result, call.method, () -> getGattConnectionState(argument(call)));
            default:
                return false;
        }
    }

    private boolean handleGattMethod(@NonNull MethodCall call, @NonNull Result result)
    {
        switch (call.method) {
            case "connectGatt":
                return succeedWithConnectPermission(result, call.method, () -> connectGatt(argumentsMap(call)));
            case "disconnectGatt":
                return succeedWithConnectPermission(result, call.method, () -> gattController.disconnect(argument(call)));
            case "closeGatt":
                return succeedWithConnectPermission(result, call.method, () -> gattController.close(argument(call)));
            case "getGattDevice":
                return succeedWithConnectPermission(result, call.method, () -> gattController.getDevice(argument(call)));
            case "getGattServices":
                return succeedWithConnectPermission(result, call.method, () -> gattController.getServices(argument(call)));
            case "getGattService":
                return succeedWithConnectPermission(result, call.method, () -> gattController.getService(argumentsMap(call)));
            case "getGattCharacteristic":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.getCharacteristic(argumentsMap(call))
                );
            case "getGattDescriptor":
                return succeedWithConnectPermission(result, call.method, () -> gattController.getDescriptor(argumentsMap(call)));
            case "getGattCharacteristicService":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.getCharacteristicService(argumentsMap(call))
                );
            case "getGattDescriptorCharacteristic":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.getDescriptorCharacteristic(argumentsMap(call))
                );
            case "discoverGattServices":
                return succeedWithConnectPermission(result, call.method, () -> gattController.discoverServices(argument(call)));
            case "requestGattMtu":
                return succeedWithConnectPermission(result, call.method, () -> gattController.requestMtu(argumentsMap(call)));
            case "requestGattConnectionPriority":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.requestConnectionPriority(argumentsMap(call))
                );
            case "readGattPhy":
                return succeedWithConnectPermission(result, call.method, () -> gattController.readPhy(argument(call)));
            case "setGattPreferredPhy":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.setPreferredPhy(argumentsMap(call))
                );
            case "beginGattReliableWrite":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.beginReliableWrite(argument(call))
                );
            case "executeGattReliableWrite":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.executeReliableWrite(argument(call))
                );
            case "abortGattReliableWrite":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.abortReliableWrite(argument(call))
                );
            case "readGattRemoteRssi":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.readRemoteRssi(argument(call))
                );
            case "setGattCharacteristicNotification":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.setCharacteristicNotification(argumentsMap(call))
                );
            case "readGattCharacteristic":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.readCharacteristic(argumentsMap(call))
                );
            case "setGattCharacteristicWriteType":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.setCharacteristicWriteType(argumentsMap(call))
                );
            case "setGattCharacteristicValue":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.setCharacteristicValue(argumentsMap(call))
                );
            case "writeGattCharacteristic":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.writeCharacteristic(argumentsMap(call))
                );
            case "readGattDescriptor":
                return succeedWithConnectPermission(result, call.method, () -> gattController.readDescriptor(argumentsMap(call)));
            case "setGattDescriptorValue":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> gattController.setDescriptorValue(argumentsMap(call))
                );
            case "writeGattDescriptor":
                return succeedWithConnectPermission(result, call.method, () -> gattController.writeDescriptor(argumentsMap(call)));
            default:
                return false;
        }
    }

    private boolean handleDeviceMethod(@NonNull MethodCall call, @NonNull Result result)
    {
        switch (call.method) {
            case "getBondState":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> deviceController.getBondState(getBluetoothAdapter(), argument(call))
                );
            case "getAddress":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> deviceController.getAddress(getBluetoothAdapter(), argument(call))
                );
            case "createBond":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> deviceController.createBond(getBluetoothAdapter(), argument(call))
                );
            case "setPin":
                return succeedWithConnectPermission(result, call.method, () -> setPin(argumentsMap(call)));
            case "setPairingConfirmation":
                return succeedWithConnectPermission(result, call.method, () -> setPairingConfirmation(argumentsMap(call)));
            case "getName":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> deviceController.getName(getBluetoothAdapter(), argument(call))
                );
            case "getDeviceType":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> deviceController.getDeviceType(getBluetoothAdapter(), argument(call))
                );
            case "getUuids":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> deviceController.getUuids(getBluetoothAdapter(), argument(call))
                );
            case "removeBond":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> deviceController.removeBond(getBluetoothAdapter(), argument(call))
                );
            default:
                return false;
        }
    }

    private boolean handleSocketMethod(@NonNull MethodCall call, @NonNull Result result)
    {
        switch (call.method) {
            case "listenUsingL2capChannel":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> socketController.listenUsingL2capChannel(getBluetoothAdapter(), false)
                );
            case "listenUsingInsecureL2capChannel":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> socketController.listenUsingL2capChannel(getBluetoothAdapter(), true)
                );
            case "acceptServerSocket":
                return succeedWithConnectPermission(result, call.method, () -> acceptServerSocket(argumentsMap(call)));
            case "closeServerSocket":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> closeServerSocket(argument(call))
                );
            case "getServerSocketPsm":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> getServerSocketPsm(argument(call))
                );
            case "createL2capChannel":
                return succeedWithConnectPermission(result, call.method, () -> createL2capSocket(argumentsMap(call), false));
            case "createInsecureL2capChannel":
                return succeedWithConnectPermission(result, call.method, () -> createL2capSocket(argumentsMap(call), true));
            case "connectSocket":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> connectSocket(argument(call))
                );
            case "closeSocket":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> closeSocket(argument(call))
                );
            case "isSocketConnected":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> isSocketConnected(argument(call))
                );
            case "getSocketConnectionType":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> getSocketConnectionType(argument(call))
                );
            case "getSocketMaxReceivePacketSize":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> getSocketMaxReceivePacketSize(argument(call))
                );
            case "getSocketMaxTransmitPacketSize":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> getSocketMaxTransmitPacketSize(argument(call))
                );
            case "getSocketInputStreamAvailable":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> getSocketInputStreamAvailable(argument(call))
                );
            case "readSocketInputStreamByte":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> readSocketInputStreamByte(argument(call))
                );
            case "readSocketInputStream":
                return succeedWithConnectPermission(result, call.method, () -> readSocketInputStream(argumentsMap(call)));
            case "skipSocketInputStream":
                return succeedWithConnectPermission(result, call.method, () -> skipSocketInputStream(argumentsMap(call)));
            case "writeSocketOutputStreamByte":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> writeSocketOutputStreamByte(argumentsMap(call))
                );
            case "writeSocketOutputStream":
                return succeedWithConnectPermission(result, call.method, () -> writeSocketOutputStream(argumentsMap(call)));
            case "flushSocketOutputStream":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> flushSocketOutputStream(argument(call))
                );
            case "getSocketRemoteDevice":
                return succeedWithConnectPermission(
                    result,
                    call.method,
                    () -> getSocketRemoteDevice(argument(call))
                );
            default:
                return false;
        }
    }

    private boolean handleScanMethod(@NonNull MethodCall call, @NonNull Result result)
    {
        switch (call.method) {
            case "startScan":
                return succeedWithScanPermission(
                    result,
                    call.method,
                    () -> scanController.startScan(getBluetoothAdapter(), argumentsMap(call))
                );
            case "stopScan":
                return succeedWithScanPermission(
                    result,
                    call.method,
                    () -> scanController.stopScan(getBluetoothAdapter())
                );
            case "flushPendingScanResults":
                return succeedWithScanPermission(
                    result,
                    call.method,
                    () -> scanController.flushPendingScanResults(getBluetoothAdapter())
                );
            case "isScanning":
                result.success(scanController.isScanning());
                return true;
            default:
                return false;
        }
    }

    private void setUpEventChannels(@NonNull FlutterPlugin.FlutterPluginBinding binding)
    {
        bindEventChannel(binding, "android_bluetooth/adapter_state_changed", this::setAdapterStateSink);
        bindEventChannel(binding, "android_bluetooth/bond_state_changed", this::setBondStateSink);
        bindEventChannel(binding, "android_bluetooth/gatt_characteristic_read", gattController::setCharacteristicReadSink);
        bindEventChannel(binding, "android_bluetooth/gatt_characteristic_write", gattController::setCharacteristicWriteSink);
        bindEventChannel(binding, "android_bluetooth/gatt_characteristic_changed", gattController::setCharacteristicChangedSink);
        bindEventChannel(binding, "android_bluetooth/gatt_connection_state_changed", gattController::setConnectionStateChangedSink);
        bindEventChannel(binding, "android_bluetooth/gatt_descriptor_read", gattController::setDescriptorReadSink);
        bindEventChannel(binding, "android_bluetooth/gatt_descriptor_write", gattController::setDescriptorWriteSink);
        bindEventChannel(binding, "android_bluetooth/gatt_mtu_changed", gattController::setMtuChangedSink);
        bindEventChannel(binding, "android_bluetooth/gatt_phy_read", gattController::setPhyReadSink);
        bindEventChannel(binding, "android_bluetooth/gatt_phy_update", gattController::setPhyUpdateSink);
        bindEventChannel(
            binding,
            "android_bluetooth/gatt_reliable_write_completed",
            gattController::setReliableWriteCompletedSink
        );
        bindEventChannel(binding, "android_bluetooth/gatt_remote_rssi_read", gattController::setRemoteRssiReadSink);
        bindEventChannel(binding, "android_bluetooth/gatt_services_discovered", gattController::setServicesDiscoveredSink);
        bindEventChannel(binding, "android_bluetooth/scan_batch_results", scanController::setScanBatchResultsSink);
        bindEventChannel(binding, "android_bluetooth/scan_failed", scanController::setScanFailedSink);
        bindEventChannel(binding, "android_bluetooth/scan_results", scanController::setScanResultsSink);
    }

    private void tearDownMethodChannel()
    {
        if (methodChannel != null) {
            methodChannel.setMethodCallHandler(null);
        }
    }

    private void tearDownEventChannels()
    {
        for (EventChannel eventChannel : eventChannels) {
            eventChannel.setStreamHandler(null);
        }
        eventChannels.clear();
    }

    private void stopActiveOperations()
    {
        stopScanIfNeeded();
        socketController.closeAll();
    }

    private void clearEventSinks()
    {
        adapterStateChangedSink = null;
        bondStateChangedSink = null;
        gattController.setCharacteristicReadSink(null);
        gattController.setCharacteristicWriteSink(null);
        gattController.setCharacteristicChangedSink(null);
        gattController.setConnectionStateChangedSink(null);
        gattController.setDescriptorReadSink(null);
        gattController.setDescriptorWriteSink(null);
        gattController.setMtuChangedSink(null);
        gattController.setPhyReadSink(null);
        gattController.setPhyUpdateSink(null);
        gattController.setReliableWriteCompletedSink(null);
        gattController.setRemoteRssiReadSink(null);
        gattController.setServicesDiscoveredSink(null);
        scanController.setScanBatchResultsSink(null);
        scanController.setScanFailedSink(null);
        scanController.setScanResultsSink(null);
    }

    private void registerReceivers()
    {
        registerAdapterStateReceiver();
        registerBondStateReceiver();
    }

    private void unregisterReceivers()
    {
        unregisterAdapterStateReceiver();
        unregisterBondStateReceiver();
    }

    private void clearReferences()
    {
        adapterController = null;
        methodChannel = null;
        context = null;
    }

    private void setAdapterStateSink(EventChannel.EventSink sink)
    {
        adapterStateChangedSink = sink;
    }

    private void setBondStateSink(EventChannel.EventSink sink)
    {
        bondStateChangedSink = sink;
    }

    private void bindEventChannel(
        @NonNull FlutterPlugin.FlutterPluginBinding binding,
        @NonNull String channelName,
        @NonNull EventSinkSetter sinkSetter
    )
    {
        EventChannel eventChannel = new EventChannel(binding.getBinaryMessenger(), channelName);
        eventChannel.setStreamHandler(new EventChannel.StreamHandler()
        {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events)
            {
                sinkSetter.set(events);
            }

            @Override
            public void onCancel(Object arguments)
            {
                sinkSetter.set(null);
            }
        });
        eventChannels.add(eventChannel);
    }

    private BluetoothAdapter getBluetoothAdapter()
    {
        BluetoothManager bluetoothManager = getBluetoothManager();
        if (bluetoothManager == null) {
            return null;
        }

        return bluetoothManager.getAdapter();
    }

    private BluetoothManager getBluetoothManager()
    {
        return context == null ? null : context.getSystemService(BluetoothManager.class);
    }

    @SuppressWarnings("unchecked")
    private <T> T argument(@NonNull MethodCall call)
    {
        return (T) call.arguments();
    }

    @SuppressWarnings("unchecked")
    private HashMap<String, Object> argumentsMap(@NonNull MethodCall call)
    {
        return call.arguments() instanceof HashMap ? (HashMap<String, Object>) call.arguments() : null;
    }

    private boolean succeedWithConnectPermission(
        @NonNull Result result,
        @NonNull String method,
        @NonNull ResultProvider provider
    )
    {
        if (!ensureBluetoothConnectPermission(result, method)) {
            return true;
        }

        result.success(provider.get());
        return true;
    }

    private boolean succeedWithScanPermission(
        @NonNull Result result,
        @NonNull String method,
        @NonNull ResultProvider provider
    )
    {
        if (!ensureBluetoothScanPermission(result, method)) {
            return true;
        }

        result.success(provider.get());
        return true;
    }

    private Integer acceptServerSocket(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return null;
        }

        Integer serverSocketId =
            arguments.get("serverSocketId") instanceof Integer ? (Integer) arguments.get("serverSocketId") : null;
        Integer timeoutMillis =
            arguments.get("timeoutMillis") instanceof Integer ? (Integer) arguments.get("timeoutMillis") : null;
        return serverSocketId == null ? null : socketController.acceptServerSocket(serverSocketId, timeoutMillis);
    }

    private boolean closeServerSocket(Integer serverSocketId)
    {
        return serverSocketId != null && socketController.closeServerSocket(serverSocketId);
    }

    private Integer getServerSocketPsm(Integer serverSocketId)
    {
        return serverSocketId == null ? null : socketController.getServerSocketPsm(serverSocketId);
    }

    private HashMap<String, Object> getRemoteLeDevice(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return null;
        }

        String address = (String) arguments.get("address");
        Integer addressType = (Integer) arguments.get("addressType");
        return deviceController.getRemoteLeDevice(getBluetoothAdapter(), address, addressType);
    }

    private java.util.List<HashMap<String, Object>> getConnectedDevices(Integer profile)
    {
        BluetoothManager bluetoothManager = getBluetoothManager();
        int profileValue = profile == null ? BluetoothProfile.GATT : profile;
        return managerController.getConnectedDevices(bluetoothManager, profileValue);
    }

    private java.util.List<HashMap<String, Object>> getDevicesMatchingConnectionStates(HashMap<String, Object> arguments)
    {
        BluetoothManager bluetoothManager = getBluetoothManager();
        if (arguments == null) {
            return new java.util.ArrayList<>();
        }

        Number profileNumber = (Number) arguments.get("profile");
        java.util.List<Integer> statesList = (java.util.List<Integer>) arguments.get("states");
        int profile = profileNumber == null ? 0 : profileNumber.intValue();
        int[] states = new int[statesList == null ? 0 : statesList.size()];

        if (statesList != null) {
            for (int i = 0; i < statesList.size(); i++) {
                states[i] = statesList.get(i);
            }
        }

        return managerController.getDevicesMatchingConnectionStates(bluetoothManager, profile, states);
    }

    private String getGattConnectionState(String address)
    {
        BluetoothManager bluetoothManager = getBluetoothManager();
        BluetoothDevice bluetoothDevice = deviceController.getBluetoothDevice(getBluetoothAdapter(), address);
        return managerController.getGattConnectionState(bluetoothManager, bluetoothDevice);
    }

    private String getConnectionState(HashMap<String, Object> arguments)
    {
        BluetoothManager bluetoothManager = getBluetoothManager();
        if (arguments == null) {
            return "unknown";
        }

        String address = (String) arguments.get("address");
        Number profileNumber = (Number) arguments.get("profile");
        BluetoothDevice bluetoothDevice = deviceController.getBluetoothDevice(getBluetoothAdapter(), address);
        int profile = profileNumber == null ? BluetoothProfile.GATT : profileNumber.intValue();
        return managerController.getConnectionState(bluetoothManager, bluetoothDevice, profile);
    }

    private boolean connectGatt(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return false;
        }

        String address = (String) arguments.get("address");
        boolean autoConnect = Boolean.TRUE.equals(arguments.get("autoConnect"));
        HashMap<String, Object> handlerMap = arguments.get("handler") instanceof HashMap ?
            (HashMap<String, Object>) arguments.get("handler") :
            null;
        String handlerName = handlerMap == null ? null : (String) handlerMap.get("name");
        Integer transport = arguments.get("transport") instanceof Integer ? (Integer) arguments.get("transport") : null;
        Integer phy = arguments.get("phy") instanceof Integer ? (Integer) arguments.get("phy") : null;
        return gattController.connect(context, getBluetoothAdapter(), address, autoConnect, handlerName, transport, phy);
    }

    private boolean setPin(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return false;
        }

        String address = (String) arguments.get("address");
        byte[] pin = (byte[]) arguments.get("pin");
        return deviceController.setPin(getBluetoothAdapter(), address, pin);
    }

    private boolean setPairingConfirmation(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return false;
        }

        String address = (String) arguments.get("address");
        Boolean confirm = (Boolean) arguments.get("confirm");
        return deviceController.setPairingConfirmation(
            getBluetoothAdapter(),
            address,
            confirm != null && confirm
        );
    }

    private Integer createL2capSocket(HashMap<String, Object> arguments, boolean insecure)
    {
        if (arguments == null) {
            return null;
        }

        String address = (String) arguments.get("address");
        Integer psm = arguments.get("psm") instanceof Integer ? (Integer) arguments.get("psm") : null;
        BluetoothDevice device = deviceController.getBluetoothDevice(getBluetoothAdapter(), address);
        return socketController.createL2capChannel(device, psm, insecure);
    }

    private boolean connectSocket(Integer socketId)
    {
        return socketId != null && socketController.connectSocket(socketId);
    }

    private boolean closeSocket(Integer socketId)
    {
        return socketId != null && socketController.closeSocket(socketId);
    }

    private boolean isSocketConnected(Integer socketId)
    {
        return socketId != null && socketController.isSocketConnected(socketId);
    }

    private Integer getSocketConnectionType(Integer socketId)
    {
        return socketId == null ? null : socketController.getSocketConnectionType(socketId);
    }

    private Integer getSocketMaxReceivePacketSize(Integer socketId)
    {
        return socketId == null ? null : socketController.getSocketMaxReceivePacketSize(socketId);
    }

    private Integer getSocketMaxTransmitPacketSize(Integer socketId)
    {
        return socketId == null ? null : socketController.getSocketMaxTransmitPacketSize(socketId);
    }

    private Integer getSocketInputStreamAvailable(Integer socketId)
    {
        return socketId == null ? null : socketController.getSocketInputStreamAvailable(socketId);
    }

    private Integer readSocketInputStreamByte(Integer socketId)
    {
        return socketId == null ? null : socketController.readSocketInputStreamByte(socketId);
    }

    private byte[] readSocketInputStream(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return null;
        }

        Integer socketId = arguments.get("socketId") instanceof Integer ? (Integer) arguments.get("socketId") : null;
        Integer maxBytes = arguments.get("maxBytes") instanceof Integer ? (Integer) arguments.get("maxBytes") : null;
        return socketId == null ? null : socketController.readSocketInputStream(socketId, maxBytes);
    }

    private Integer skipSocketInputStream(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return null;
        }

        Integer socketId = arguments.get("socketId") instanceof Integer ? (Integer) arguments.get("socketId") : null;
        Integer byteCount = arguments.get("byteCount") instanceof Integer ? (Integer) arguments.get("byteCount") : null;
        return socketId == null ? null : socketController.skipSocketInputStream(socketId, byteCount);
    }

    private boolean writeSocketOutputStreamByte(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return false;
        }

        Integer socketId = arguments.get("socketId") instanceof Integer ? (Integer) arguments.get("socketId") : null;
        Integer value = arguments.get("value") instanceof Integer ? (Integer) arguments.get("value") : null;
        return socketId != null && socketController.writeSocketOutputStreamByte(socketId, value);
    }

    private boolean writeSocketOutputStream(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return false;
        }

        Integer socketId = arguments.get("socketId") instanceof Integer ? (Integer) arguments.get("socketId") : null;
        byte[] bytes = arguments.get("bytes") instanceof byte[] ? (byte[]) arguments.get("bytes") : null;
        return socketId != null && socketController.writeSocketOutputStream(socketId, bytes);
    }

    private boolean flushSocketOutputStream(Integer socketId)
    {
        return socketId != null && socketController.flushSocketOutputStream(socketId);
    }

    private HashMap<String, Object> getSocketRemoteDevice(Integer socketId)
    {
        return socketId == null ? null : socketController.getSocketRemoteDevice(socketId);
    }

    private boolean ensureBluetoothConnectPermission(@NonNull Result result, String method)
    {
        if (adapterController == null) {
            result.error("permission_denied", "Bluetooth connect permission is required for " + method, null);
            return false;
        }

        String missingPermission = adapterController.getMissingBluetoothConnectPermission();
        if (missingPermission != null) {
            result.error(
                "permission_denied",
                "Permission " + missingPermission + " is required for " + method,
                missingPermission
            );
            return false;
        }

        return true;
    }

    private boolean ensureBluetoothScanPermission(@NonNull Result result, String method)
    {
        if (adapterController == null) {
            result.error("permission_denied", "Bluetooth scan permission is required for " + method, null);
            return false;
        }

        String missingPermission = adapterController.getMissingBluetoothScanPermission();
        if (missingPermission != null) {
            result.error(
                "permission_denied",
                "Permission " + missingPermission + " is required for " + method,
                missingPermission
            );
            return false;
        }

        return true;
    }

    private void registerAdapterStateReceiver()
    {
        if (context == null || adapterStateReceiverRegistered) {
            return;
        }

        context.registerReceiver(adapterStateReceiver, new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED));
        adapterStateReceiverRegistered = true;
    }

    private void unregisterAdapterStateReceiver()
    {
        if (context == null || !adapterStateReceiverRegistered) {
            return;
        }

        context.unregisterReceiver(adapterStateReceiver);
        adapterStateReceiverRegistered = false;
    }

    private void registerBondStateReceiver()
    {
        if (context == null || bondStateReceiverRegistered) {
            return;
        }

        context.registerReceiver(bondStateReceiver, new IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED));
        bondStateReceiverRegistered = true;
    }

    private void unregisterBondStateReceiver()
    {
        if (context == null || !bondStateReceiverRegistered) {
            return;
        }

        context.unregisterReceiver(bondStateReceiver);
        bondStateReceiverRegistered = false;
    }

    private final BroadcastReceiver adapterStateReceiver = new BroadcastReceiver()
    {
        @Override
        public void onReceive(Context context, Intent intent)
        {
            if (adapterStateChangedSink == null) {
                return;
            }

            String action = intent.getAction();
            if (action == null || !BluetoothAdapter.ACTION_STATE_CHANGED.equals(action)) {
                return;
            }

            int adapterState = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR);
            if (adapterState == BluetoothAdapter.STATE_TURNING_OFF || adapterState == BluetoothAdapter.STATE_OFF) {
                stopScanIfNeeded();
            }
            adapterStateChangedSink.success(mapAdapterState(adapterState));
        }
    };

    private final BroadcastReceiver bondStateReceiver = new BroadcastReceiver()
    {
        @Override
        @SuppressWarnings("deprecation")
        public void onReceive(Context context, Intent intent)
        {
            if (bondStateChangedSink == null) {
                return;
            }

            String action = intent.getAction();
            if (action == null || !BluetoothDevice.ACTION_BOND_STATE_CHANGED.equals(action)) {
                return;
            }

            BluetoothDevice device;
            if (android.os.Build.VERSION.SDK_INT >= 33) {
                device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice.class);
            } else {
                device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
            }

            if (device == null) {
                return;
            }

            int previousBondState = intent.getIntExtra(BluetoothDevice.EXTRA_PREVIOUS_BOND_STATE, BluetoothDevice.ERROR);

            HashMap<String, Object> event = new HashMap<>();
            event.put("device", BluetoothDeviceSerializer.serialize(device));
            event.put("previousBondState", BluetoothDeviceSerializer.mapBondState(previousBondState));
            bondStateChangedSink.success(event);
        }
    };

    private void stopScanIfNeeded()
    {
        if (!scanController.isScanning()) {
            return;
        }

        stopScan();
    }

    private String mapAdapterState(int adapterState)
    {
        return adapterController == null ? "unknown" : adapterController.mapAdapterState(adapterState);
    }

}
