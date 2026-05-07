package com.lib.android_bluetooth;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.BluetoothStatusCodes;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import io.flutter.plugin.common.EventChannel;

public final class GattController
{
    private final Map<String, BluetoothGatt> connectedDevices = new ConcurrentHashMap<>();
    private final Map<String, BluetoothGatt> connectingDevices = new ConcurrentHashMap<>();
    private EventChannel.EventSink characteristicChangedSink;
    private EventChannel.EventSink characteristicReadSink;
    private EventChannel.EventSink characteristicWriteSink;
    private EventChannel.EventSink connectionStateChangedSink;
    private EventChannel.EventSink descriptorReadSink;
    private EventChannel.EventSink descriptorWriteSink;
    private EventChannel.EventSink mtuChangedSink;
    private EventChannel.EventSink phyReadSink;
    private EventChannel.EventSink phyUpdateSink;
    private EventChannel.EventSink reliableWriteCompletedSink;
    private EventChannel.EventSink remoteRssiReadSink;
    private EventChannel.EventSink servicesDiscoveredSink;
    private final BluetoothGattCallback gattCallback = new BluetoothGattCallback()
    {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState)
        {
            String address = gatt.getDevice().getAddress();

            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connectedDevices.put(address, gatt);
                connectingDevices.remove(address);
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                connectedDevices.remove(address);
                connectingDevices.remove(address);
                gatt.close();
            }

            if (connectionStateChangedSink != null) {
                HashMap<String, Object> event = new HashMap<>();
                event.put("address", address);
                event.put("connectionState", mapConnectionState(newState));
                event.put("status", status);
                connectionStateChangedSink.success(event);
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status)
        {
            if (servicesDiscoveredSink == null) {
                return;
            }

            HashMap<String, Object> event = new HashMap<>();
            event.put("address", gatt.getDevice().getAddress());
            event.put("services", serializeServices(gatt.getServices()));
            event.put("success", status == BluetoothGatt.GATT_SUCCESS);
            event.put("status", status);
            servicesDiscoveredSink.success(event);
        }

        @Override
        public void onMtuChanged(BluetoothGatt gatt, int mtu, int status)
        {
            if (mtuChangedSink == null) {
                return;
            }

            HashMap<String, Object> event = new HashMap<>();
            event.put("address", gatt.getDevice().getAddress());
            event.put("mtu", mtu);
            event.put("success", status == BluetoothGatt.GATT_SUCCESS);
            event.put("status", status);
            mtuChangedSink.success(event);
        }

        @Override
        public void onPhyRead(BluetoothGatt gatt, int txPhy, int rxPhy, int status)
        {
            if (phyReadSink == null) {
                return;
            }

            HashMap<String, Object> event = new HashMap<>();
            event.put("address", gatt.getDevice().getAddress());
            event.put("rxPhy", rxPhy);
            event.put("success", status == BluetoothGatt.GATT_SUCCESS);
            event.put("status", status);
            event.put("txPhy", txPhy);
            phyReadSink.success(event);
        }

        @Override
        public void onPhyUpdate(BluetoothGatt gatt, int txPhy, int rxPhy, int status)
        {
            if (phyUpdateSink == null) {
                return;
            }

            HashMap<String, Object> event = new HashMap<>();
            event.put("address", gatt.getDevice().getAddress());
            event.put("rxPhy", rxPhy);
            event.put("success", status == BluetoothGatt.GATT_SUCCESS);
            event.put("status", status);
            event.put("txPhy", txPhy);
            phyUpdateSink.success(event);
        }

        @Override
        public void onReliableWriteCompleted(BluetoothGatt gatt, int status)
        {
            if (reliableWriteCompletedSink == null) {
                return;
            }

            HashMap<String, Object> event = new HashMap<>();
            event.put("address", gatt.getDevice().getAddress());
            event.put("success", status == BluetoothGatt.GATT_SUCCESS);
            event.put("status", status);
            reliableWriteCompletedSink.success(event);
        }

        @Override
        public void onReadRemoteRssi(BluetoothGatt gatt, int rssi, int status)
        {
            if (remoteRssiReadSink == null) {
                return;
            }

            HashMap<String, Object> event = new HashMap<>();
            event.put("address", gatt.getDevice().getAddress());
            event.put("rssi", rssi);
            event.put("success", status == BluetoothGatt.GATT_SUCCESS);
            event.put("status", status);
            remoteRssiReadSink.success(event);
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, byte[] value, int status)
        {
            emitCharacteristicRead(gatt, characteristic, value, status);
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, byte[] value)
        {
            emitCharacteristicChanged(gatt, characteristic, value);
        }

        @Override
        @SuppressWarnings("deprecation")
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic)
        {
            emitCharacteristicChanged(gatt, characteristic, characteristic.getValue());
        }

        @Override
        @SuppressWarnings("deprecation")
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            emitCharacteristicRead(
                gatt,
                characteristic,
                characteristic.getValue(),
                status
            );
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status)
        {
            if (characteristicWriteSink == null) {
                return;
            }

            HashMap<String, Object> event = new HashMap<>();
            populateCharacteristicEvent(event, gatt, characteristic);
            event.put("success", status == BluetoothGatt.GATT_SUCCESS);
            event.put("status", status);
            event.put("value", characteristic.getValue());
            characteristicWriteSink.success(event);
        }

        @Override
        public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status, byte[] value)
        {
            emitDescriptorRead(gatt, descriptor, value, status);
        }

        @Override
        @SuppressWarnings("deprecation")
        public void onDescriptorRead(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            emitDescriptorRead(
                gatt,
                descriptor,
                descriptor.getValue(),
                status
            );
        }

        @Override
        @SuppressWarnings("deprecation")
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status)
        {
            if (descriptorWriteSink == null) {
                return;
            }

            HashMap<String, Object> event = new HashMap<>();
            populateDescriptorEvent(event, gatt, descriptor);
            event.put("success", status == BluetoothGatt.GATT_SUCCESS);
            event.put("status", status);
            event.put("value", descriptor.getValue());
            descriptorWriteSink.success(event);
        }
    };

    public boolean connect(
        Context context,
        BluetoothAdapter bluetoothAdapter,
        String address,
        boolean autoConnect,
        String handlerName,
        Integer transport,
        Integer phy
    )
    {
        if (context == null || bluetoothAdapter == null || address == null) {
            return false;
        }

        if (connectedDevices.containsKey(address)) {
            return false;
        }

        if (connectingDevices.containsKey(address)) {
            return true;
        }

        if (handlerName != null && (Build.VERSION.SDK_INT < 26 || phy == null)) {
            return false;
        }

        BluetoothDevice device;
        try {
            device = bluetoothAdapter.getRemoteDevice(address);
        } catch (IllegalArgumentException exception) {
            return false;
        }

        BluetoothGatt gatt;
        if (Build.VERSION.SDK_INT >= 26 && phy != null && handlerName != null) {
            Handler handler = createHandler(handlerName);
            if (handler == null) {
                return false;
            }

            int transportValue = transport == null ? BluetoothDevice.TRANSPORT_AUTO : transport;
            gatt = device.connectGatt(context, autoConnect, gattCallback, transportValue, phy, handler);
        } else if (Build.VERSION.SDK_INT >= 26 && phy != null) {
            int transportValue = transport == null ? BluetoothDevice.TRANSPORT_AUTO : transport;
            gatt = device.connectGatt(context, autoConnect, gattCallback, transportValue, phy);
        } else if (Build.VERSION.SDK_INT >= 23 && transport != null) {
            gatt = device.connectGatt(context, autoConnect, gattCallback, transport);
        } else {
            gatt = device.connectGatt(context, autoConnect, gattCallback);
        }

        if (gatt == null) {
            return false;
        }

        connectingDevices.put(address, gatt);
        return true;
    }

    public boolean disconnect(String address)
    {
        if (address == null) {
            return false;
        }

        BluetoothGatt gatt = connectingDevices.remove(address);
        if (gatt != null) {
            gatt.disconnect();
            gatt.close();
            emitDisconnected(address);
            return true;
        }

        gatt = connectedDevices.remove(address);
        if (gatt != null) {
            gatt.disconnect();
            return true;
        }

        return false;
    }

    public boolean close(String address)
    {
        if (address == null) {
            return false;
        }

        BluetoothGatt gatt = connectingDevices.remove(address);
        if (gatt != null) {
            gatt.close();
            emitDisconnected(address);
            return true;
        }

        gatt = connectedDevices.remove(address);
        if (gatt != null) {
            gatt.close();
            emitDisconnected(address);
            return true;
        }

        return false;
    }

    public HashMap<String, Object> getDevice(String address)
    {
        if (address == null) {
            return null;
        }

        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return null;
        }

        return BluetoothDeviceSerializer.serialize(gatt.getDevice());
    }

    public List<HashMap<String, Object>> getServices(String address)
    {
        if (address == null) {
            return new ArrayList<>();
        }

        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return new ArrayList<>();
        }

        return serializeServices(gatt.getServices());
    }

    public HashMap<String, Object> getService(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return null;
        }

        String address = (String) arguments.get("address");
        String serviceUuid = (String) arguments.get("serviceUuid");
        if (address == null || serviceUuid == null) {
            return null;
        }

        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return null;
        }

        for (BluetoothGattService service : gatt.getServices()) {
            if (service.getUuid().toString().equalsIgnoreCase(serviceUuid)) {
                return serializeService(service);
            }
        }

        return null;
    }

    public HashMap<String, Object> getCharacteristic(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return null;
        }

        BluetoothGattCharacteristic characteristic = locateCharacteristic(arguments);
        if (characteristic == null) {
            return null;
        }

        return serializeCharacteristic(characteristic);
    }

    public HashMap<String, Object> getDescriptor(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return null;
        }

        BluetoothGattDescriptor descriptor = locateDescriptor(arguments);
        if (descriptor == null) {
            return null;
        }

        return serializeDescriptor(descriptor);
    }

    public HashMap<String, Object> getCharacteristicService(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return null;
        }

        BluetoothGattCharacteristic characteristic = locateCharacteristic(arguments);
        if (characteristic == null) {
            return null;
        }

        return serializeService(characteristic.getService());
    }

    public HashMap<String, Object> getDescriptorCharacteristic(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return null;
        }

        BluetoothGattDescriptor descriptor = locateDescriptor(arguments);
        if (descriptor == null) {
            return null;
        }

        return serializeCharacteristic(descriptor.getCharacteristic());
    }

    public boolean discoverServices(String address)
    {
        if (address == null) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return false;
        }

        return gatt.discoverServices();
    }

    public boolean readCharacteristic(HashMap<String, Object> arguments)
    {
        BluetoothGattCharacteristic characteristic = locateCharacteristic(arguments);
        if (characteristic == null) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get((String) arguments.get("address"));
        if (gatt == null) {
            return false;
        }

        return gatt.readCharacteristic(characteristic);
    }

    public boolean requestMtu(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return false;
        }

        String address = (String) arguments.get("address");
        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return false;
        }

        Integer mtu = (Integer) arguments.get("mtu");
        if (mtu == null) {
            return false;
        }

        return gatt.requestMtu(mtu);
    }

    public boolean requestConnectionPriority(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return false;
        }

        String address = (String) arguments.get("address");
        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return false;
        }

        Integer connectionPriority = (Integer) arguments.get("connectionPriority");
        if (connectionPriority == null) {
            return false;
        }

        return gatt.requestConnectionPriority(connectionPriority);
    }

    public boolean readPhy(String address)
    {
        if (address == null || Build.VERSION.SDK_INT < 26) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return false;
        }

        gatt.readPhy();
        return true;
    }

    public boolean setPreferredPhy(HashMap<String, Object> arguments)
    {
        if (arguments == null || Build.VERSION.SDK_INT < 26) {
            return false;
        }

        String address = (String) arguments.get("address");
        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return false;
        }

        Integer txPhy = (Integer) arguments.get("txPhy");
        Integer rxPhy = (Integer) arguments.get("rxPhy");
        Integer phyOptions = (Integer) arguments.get("phyOptions");
        if (txPhy == null || rxPhy == null || phyOptions == null) {
            return false;
        }

        gatt.setPreferredPhy(txPhy, rxPhy, phyOptions);
        return true;
    }

    public boolean beginReliableWrite(String address)
    {
        if (address == null) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return false;
        }

        return gatt.beginReliableWrite();
    }

    public boolean executeReliableWrite(String address)
    {
        if (address == null) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return false;
        }

        return gatt.executeReliableWrite();
    }

    public boolean abortReliableWrite(String address)
    {
        if (address == null) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return false;
        }

        gatt.abortReliableWrite();
        return true;
    }

    public boolean readRemoteRssi(String address)
    {
        if (address == null) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return false;
        }

        return gatt.readRemoteRssi();
    }

    public boolean setCharacteristicNotification(HashMap<String, Object> arguments)
    {
        BluetoothGattCharacteristic characteristic = locateCharacteristic(arguments);
        if (characteristic == null) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get((String) arguments.get("address"));
        if (gatt == null) {
            return false;
        }

        boolean enabled = Boolean.TRUE.equals(arguments.get("enabled"));
        return gatt.setCharacteristicNotification(characteristic, enabled);
    }

    public boolean writeCharacteristic(HashMap<String, Object> arguments)
    {
        BluetoothGattCharacteristic characteristic = locateCharacteristic(arguments);
        if (characteristic == null) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get((String) arguments.get("address"));
        if (gatt == null) {
            return false;
        }

        byte[] value = (byte[]) arguments.get("value");
        Integer writeTypeArgument = arguments.get("writeType") instanceof Integer ? (Integer) arguments.get("writeType") : null;
        boolean withoutResponse = Boolean.TRUE.equals(arguments.get("withoutResponse"));
        int writeType = writeTypeArgument != null
            ? writeTypeArgument
            : withoutResponse
                ? BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                : characteristic.getWriteType();

        byte[] valueToWrite = value != null ? value : characteristic.getValue();
        if (valueToWrite == null) {
            return false;
        }

        if (Build.VERSION.SDK_INT >= 33) {
            return gatt.writeCharacteristic(characteristic, valueToWrite, writeType) == BluetoothStatusCodes.SUCCESS;
        }

        if (value != null && !characteristic.setValue(value)) {
            return false;
        }
        characteristic.setWriteType(writeType);
        return gatt.writeCharacteristic(characteristic);
    }

    public boolean setCharacteristicWriteType(HashMap<String, Object> arguments)
    {
        BluetoothGattCharacteristic characteristic = locateCharacteristic(arguments);
        if (characteristic == null) {
            return false;
        }

        Integer writeType = (Integer) arguments.get("writeType");
        if (writeType == null) {
            return false;
        }

        characteristic.setWriteType(writeType);
        return true;
    }

    public boolean setCharacteristicValue(HashMap<String, Object> arguments)
    {
        BluetoothGattCharacteristic characteristic = locateCharacteristic(arguments);
        if (characteristic == null) {
            return false;
        }

        byte[] value = (byte[]) arguments.get("value");
        if (value == null) {
            return false;
        }

        return characteristic.setValue(value);
    }

    public boolean readDescriptor(HashMap<String, Object> arguments)
    {
        BluetoothGattDescriptor descriptor = locateDescriptor(arguments);
        if (descriptor == null) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get((String) arguments.get("address"));
        if (gatt == null) {
            return false;
        }

        return gatt.readDescriptor(descriptor);
    }

    public boolean setDescriptorValue(HashMap<String, Object> arguments)
    {
        BluetoothGattDescriptor descriptor = locateDescriptor(arguments);
        if (descriptor == null) {
            return false;
        }

        byte[] value = (byte[]) arguments.get("value");
        if (value == null) {
            return false;
        }

        return descriptor.setValue(value);
    }

    public boolean writeDescriptor(HashMap<String, Object> arguments)
    {
        BluetoothGattDescriptor descriptor = locateDescriptor(arguments);
        if (descriptor == null) {
            return false;
        }

        BluetoothGatt gatt = connectedDevices.get((String) arguments.get("address"));
        if (gatt == null) {
            return false;
        }

        byte[] value = (byte[]) arguments.get("value");
        byte[] valueToWrite = value != null ? value : descriptor.getValue();
        if (valueToWrite == null) {
            return false;
        }

        if (Build.VERSION.SDK_INT >= 33) {
            return gatt.writeDescriptor(descriptor, valueToWrite) == BluetoothStatusCodes.SUCCESS;
        }

        if (value != null && !descriptor.setValue(value)) {
            return false;
        }
        return gatt.writeDescriptor(descriptor);
    }

    public void setCharacteristicReadSink(EventChannel.EventSink characteristicReadSink)
    {
        this.characteristicReadSink = characteristicReadSink;
    }

    public void setCharacteristicChangedSink(EventChannel.EventSink characteristicChangedSink)
    {
        this.characteristicChangedSink = characteristicChangedSink;
    }

    public void setCharacteristicWriteSink(EventChannel.EventSink characteristicWriteSink)
    {
        this.characteristicWriteSink = characteristicWriteSink;
    }

    public void setConnectionStateChangedSink(EventChannel.EventSink connectionStateChangedSink)
    {
        this.connectionStateChangedSink = connectionStateChangedSink;
    }

    public void setDescriptorReadSink(EventChannel.EventSink descriptorReadSink)
    {
        this.descriptorReadSink = descriptorReadSink;
    }

    public void setDescriptorWriteSink(EventChannel.EventSink descriptorWriteSink)
    {
        this.descriptorWriteSink = descriptorWriteSink;
    }

    public void setMtuChangedSink(EventChannel.EventSink mtuChangedSink)
    {
        this.mtuChangedSink = mtuChangedSink;
    }

    public void setPhyReadSink(EventChannel.EventSink phyReadSink)
    {
        this.phyReadSink = phyReadSink;
    }

    public void setPhyUpdateSink(EventChannel.EventSink phyUpdateSink)
    {
        this.phyUpdateSink = phyUpdateSink;
    }

    public void setReliableWriteCompletedSink(EventChannel.EventSink reliableWriteCompletedSink)
    {
        this.reliableWriteCompletedSink = reliableWriteCompletedSink;
    }

    public void setRemoteRssiReadSink(EventChannel.EventSink remoteRssiReadSink)
    {
        this.remoteRssiReadSink = remoteRssiReadSink;
    }

    public void setServicesDiscoveredSink(EventChannel.EventSink servicesDiscoveredSink)
    {
        this.servicesDiscoveredSink = servicesDiscoveredSink;
    }

    private void emitDisconnected(String address)
    {
        if (connectionStateChangedSink == null) {
            return;
        }

        HashMap<String, Object> event = new HashMap<>();
        event.put("address", address);
        event.put("connectionState", "disconnected");
        event.put("status", BluetoothGatt.GATT_SUCCESS);
        connectionStateChangedSink.success(event);
    }

    private String mapConnectionState(int state)
    {
        switch (state) {
            case BluetoothProfile.STATE_DISCONNECTED:
                return "disconnected";
            case BluetoothProfile.STATE_CONNECTING:
                return "connecting";
            case BluetoothProfile.STATE_CONNECTED:
                return "connected";
            case BluetoothProfile.STATE_DISCONNECTING:
                return "disconnecting";
            default:
                return "unknown";
        }
    }

    private void emitCharacteristicRead(
        BluetoothGatt gatt,
        BluetoothGattCharacteristic characteristic,
        byte[] value,
        int status
    )
    {
        if (characteristicReadSink == null) {
            return;
        }

        HashMap<String, Object> event = new HashMap<>();
        populateCharacteristicEvent(event, gatt, characteristic);
        event.put("success", status == BluetoothGatt.GATT_SUCCESS);
        event.put("status", status);
        event.put("value", value);
        characteristicReadSink.success(event);
    }

    private void emitCharacteristicChanged(
        BluetoothGatt gatt,
        BluetoothGattCharacteristic characteristic,
        byte[] value
    )
    {
        if (characteristicChangedSink == null) {
            return;
        }

        HashMap<String, Object> event = new HashMap<>();
        populateCharacteristicEvent(event, gatt, characteristic);
        event.put("value", value);
        characteristicChangedSink.success(event);
    }

    private void emitDescriptorRead(
        BluetoothGatt gatt,
        BluetoothGattDescriptor descriptor,
        byte[] value,
        int status
    )
    {
        if (descriptorReadSink == null) {
            return;
        }

        HashMap<String, Object> event = new HashMap<>();
        populateDescriptorEvent(event, gatt, descriptor);
        event.put("success", status == BluetoothGatt.GATT_SUCCESS);
        event.put("status", status);
        event.put("value", value);
        descriptorReadSink.success(event);
    }

    private void populateCharacteristicEvent(
        HashMap<String, Object> event,
        BluetoothGatt gatt,
        BluetoothGattCharacteristic characteristic
    )
    {
        event.put("address", gatt.getDevice().getAddress());
        event.put("characteristicInstanceId", characteristic.getInstanceId());
        event.put("characteristicUuid", characteristic.getUuid().toString().toLowerCase());
        event.put("serviceInstanceId", characteristic.getService().getInstanceId());
        event.put("serviceUuid", characteristic.getService().getUuid().toString().toLowerCase());
    }

    private void populateDescriptorEvent(
        HashMap<String, Object> event,
        BluetoothGatt gatt,
        BluetoothGattDescriptor descriptor
    )
    {
        BluetoothGattCharacteristic characteristic = descriptor.getCharacteristic();
        populateCharacteristicEvent(event, gatt, characteristic);
        event.put("descriptorUuid", descriptor.getUuid().toString().toLowerCase());
    }

    private BluetoothGattCharacteristic locateCharacteristic(HashMap<String, Object> arguments)
    {
        if (arguments == null) {
            return null;
        }

        String address = (String) arguments.get("address");
        BluetoothGatt gatt = connectedDevices.get(address);
        if (gatt == null) {
            return null;
        }

        Integer characteristicInstanceId = (Integer) arguments.get("characteristicInstanceId");
        String characteristicUuid = (String) arguments.get("characteristicUuid");
        Integer serviceInstanceId = (Integer) arguments.get("serviceInstanceId");
        String serviceUuid = (String) arguments.get("serviceUuid");

        for (BluetoothGattService service : gatt.getServices()) {
            if (serviceInstanceId != null && service.getInstanceId() != serviceInstanceId) {
                continue;
            }
            if (serviceUuid != null && !service.getUuid().toString().equalsIgnoreCase(serviceUuid)) {
                continue;
            }

            for (BluetoothGattCharacteristic characteristic : service.getCharacteristics()) {
                if (characteristicInstanceId != null && characteristic.getInstanceId() != characteristicInstanceId) {
                    continue;
                }
                if (characteristicUuid != null &&
                    !characteristic.getUuid().toString().equalsIgnoreCase(characteristicUuid)) {
                    continue;
                }
                return characteristic;
            }
        }

        return null;
    }

    private BluetoothGattDescriptor locateDescriptor(HashMap<String, Object> arguments)
    {
        BluetoothGattCharacteristic characteristic = locateCharacteristic(arguments);
        if (characteristic == null) {
            return null;
        }

        String descriptorUuid = (String) arguments.get("descriptorUuid");
        if (descriptorUuid == null) {
            return null;
        }

        for (BluetoothGattDescriptor descriptor : characteristic.getDescriptors()) {
            if (descriptor.getUuid().toString().equalsIgnoreCase(descriptorUuid)) {
                return descriptor;
            }
        }

        return null;
    }

    private List<HashMap<String, Object>> serializeServices(List<BluetoothGattService> services)
    {
        List<HashMap<String, Object>> serializedServices = new ArrayList<>();
        for (BluetoothGattService service : services) {
            serializedServices.add(serializeService(service));
        }
        return serializedServices;
    }

    private HashMap<String, Object> serializeService(BluetoothGattService service)
    {
        HashMap<String, Object> map = new HashMap<>();
        List<HashMap<String, Object>> characteristics = new ArrayList<>();
        List<HashMap<String, Object>> includedServices = new ArrayList<>();
        List<String> includedServiceUuids = new ArrayList<>();
        for (BluetoothGattCharacteristic characteristic : service.getCharacteristics()) {
            characteristics.add(serializeCharacteristic(characteristic));
        }
        for (BluetoothGattService includedService : service.getIncludedServices()) {
            includedServices.add(serializeServiceSummary(includedService));
            includedServiceUuids.add(includedService.getUuid().toString().toLowerCase());
        }

        map.put("characteristics", characteristics);
        map.put("includedServices", includedServices);
        map.put("includedServiceUuids", includedServiceUuids);
        map.put("instanceId", service.getInstanceId());
        map.put("isPrimary", service.getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY);
        map.put("uuid", service.getUuid().toString().toLowerCase());
        return map;
    }

    private HashMap<String, Object> serializeCharacteristic(BluetoothGattCharacteristic characteristic)
    {
        HashMap<String, Object> map = new HashMap<>();
        List<HashMap<String, Object>> descriptors = new ArrayList<>();
        for (BluetoothGattDescriptor descriptor : characteristic.getDescriptors()) {
            descriptors.add(serializeDescriptor(descriptor));
        }

        BluetoothGattService service = characteristic.getService();
        map.put("descriptors", descriptors);
        map.put("instanceId", characteristic.getInstanceId());
        map.put("permissions", characteristic.getPermissions());
        map.put("properties", serializeCharacteristicProperties(characteristic.getProperties()));
        if (service != null) {
            List<HashMap<String, Object>> includedServices = new ArrayList<>();
            List<String> includedServiceUuids = new ArrayList<>();
            for (BluetoothGattService includedService : service.getIncludedServices()) {
                includedServices.add(serializeServiceSummary(includedService));
                includedServiceUuids.add(includedService.getUuid().toString().toLowerCase());
            }
            map.put("serviceIncludedServices", includedServices);
            map.put("serviceIncludedServiceUuids", includedServiceUuids);
            map.put("serviceInstanceId", service.getInstanceId());
            map.put("serviceIsPrimary", service.getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY);
            map.put("serviceUuid", service.getUuid().toString().toLowerCase());
        }
        map.put("uuid", characteristic.getUuid().toString().toLowerCase());
        map.put("value", characteristic.getValue());
        map.put("writeType", characteristic.getWriteType());
        return map;
    }

    private HashMap<String, Object> serializeDescriptor(BluetoothGattDescriptor descriptor)
    {
        HashMap<String, Object> map = new HashMap<>();
        BluetoothGattCharacteristic characteristic = descriptor.getCharacteristic();
        if (characteristic != null) {
            BluetoothGattService service = characteristic.getService();
            map.put("characteristicInstanceId", characteristic.getInstanceId());
            map.put("characteristicPermissions", characteristic.getPermissions());
            map.put("characteristicProperties", serializeCharacteristicProperties(characteristic.getProperties()));
            map.put("characteristicUuid", characteristic.getUuid().toString().toLowerCase());
            map.put("characteristicValue", characteristic.getValue());
            map.put("characteristicWriteType", characteristic.getWriteType());
            if (service != null) {
                List<HashMap<String, Object>> includedServices = new ArrayList<>();
                List<String> includedServiceUuids = new ArrayList<>();
                for (BluetoothGattService includedService : service.getIncludedServices()) {
                    includedServices.add(serializeServiceSummary(includedService));
                    includedServiceUuids.add(includedService.getUuid().toString().toLowerCase());
                }
                map.put("serviceIncludedServices", includedServices);
                map.put("serviceIncludedServiceUuids", includedServiceUuids);
                map.put("serviceInstanceId", service.getInstanceId());
                map.put("serviceIsPrimary", service.getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY);
                map.put("serviceUuid", service.getUuid().toString().toLowerCase());
            }
        }
        map.put("permissions", descriptor.getPermissions());
        map.put("uuid", descriptor.getUuid().toString().toLowerCase());
        map.put("value", descriptor.getValue());
        return map;
    }

    private HashMap<String, Object> serializeServiceSummary(BluetoothGattService service)
    {
        HashMap<String, Object> map = new HashMap<>();
        map.put("characteristics", new ArrayList<HashMap<String, Object>>());
        map.put("includedServices", new ArrayList<HashMap<String, Object>>());
        map.put("includedServiceUuids", new ArrayList<String>());
        map.put("instanceId", service.getInstanceId());
        map.put("isPrimary", service.getType() == BluetoothGattService.SERVICE_TYPE_PRIMARY);
        map.put("uuid", service.getUuid().toString().toLowerCase());
        return map;
    }

    private HashMap<String, Object> serializeCharacteristicProperties(int properties)
    {
        HashMap<String, Object> map = new HashMap<>();
        map.put("authenticatedSignedWrites", (properties & BluetoothGattCharacteristic.PROPERTY_SIGNED_WRITE) != 0);
        map.put("broadcast", (properties & BluetoothGattCharacteristic.PROPERTY_BROADCAST) != 0);
        map.put("extendedProperties", (properties & BluetoothGattCharacteristic.PROPERTY_EXTENDED_PROPS) != 0);
        map.put("indicate", (properties & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0);
        map.put("notify", (properties & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0);
        map.put("read", (properties & BluetoothGattCharacteristic.PROPERTY_READ) != 0);
        map.put("write", (properties & BluetoothGattCharacteristic.PROPERTY_WRITE) != 0);
        map.put("writeWithoutResponse", (properties & BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0);
        return map;
    }

    private Handler createHandler(String handlerName)
    {
        switch (handlerName) {
            case "main":
                return new Handler(Looper.getMainLooper());
            default:
                return null;
        }
    }
}
