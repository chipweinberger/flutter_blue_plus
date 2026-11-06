package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.bluetooth.*;

import java.util.*;

/** Registration-scoped GATT attribute handles and callback snapshots. */
class GattAttributes {
    final Map<String, Object> attributes = new HashMap<>();
    final IdentityHashMap<Object, String> handles = new IdentityHashMap<>();
    // Routing identities survive invalidation; they never make old handles usable again.
    final IdentityHashMap<Object, String> retiredHandles = new IdentityHashMap<>();

    synchronized String handle(Object object) {
        String handle = handles.get(object);
        if (handle == null) {
            handle = id("attribute");
            bind(handle, object);
        }
        return handle;
    }

    synchronized void bind(String handle, Object object) {
        attributes.put(handle, object);
        handles.put(object, handle);
    }

    synchronized <T> T get(String handle, Class<T> type) {
        Object object = attributes.get(handle);
        if (!type.isInstance(object))
            throw new IllegalStateException(
                    "Unknown, foreign or stale attribute handle: " + handle);
        return type.cast(object);
    }

    synchronized Map<String, Object> characteristicEvent(BluetoothGattCharacteristic c) {
        // An in-flight callback may outlive discovery or service removal. Serialize
        // its metadata without registering the removed attribute again.
        if (handles.containsKey(c)) return characteristic(c);
        return callbackSnapshot().characteristic(c);
    }

    synchronized Map<String, Object> descriptorEvent(BluetoothGattDescriptor d) {
        if (handles.containsKey(d)) return descriptor(d);
        return callbackSnapshot().descriptor(d);
    }

    GattAttributes callbackSnapshot() {
        GattAttributes snapshot = new GattAttributes();
        snapshot.handles.putAll(retiredHandles);
        snapshot.handles.putAll(handles);
        return snapshot;
    }

    synchronized void clear() {
        retiredHandles.putAll(handles);
        attributes.clear();
        handles.clear();
    }

    synchronized void forget() {
        clear();
        retiredHandles.clear();
    }

    Map<String, Object> serviceIdentity(BluetoothGattService service) {
        if (service == null) return null;
        return map(
                "handle",
                handle(service),
                "uuid",
                service.getUuid().toString(),
                "instanceId",
                service.getInstanceId(),
                "serviceType",
                service.getType());
    }

    Map<String, Object> characteristicIdentity(BluetoothGattCharacteristic characteristic) {
        if (characteristic == null) return null;
        return map(
                "handle",
                handle(characteristic),
                "uuid",
                characteristic.getUuid().toString(),
                "instanceId",
                characteristic.getInstanceId(),
                "properties",
                characteristic.getProperties(),
                "permissions",
                characteristic.getPermissions(),
                "service",
                serviceIdentity(characteristic.getService()));
    }

    synchronized Map<String, Object> descriptor(BluetoothGattDescriptor d) {
        return map(
                "handle",
                handle(d),
                "uuid",
                d.getUuid().toString(),
                "permissions",
                d.getPermissions(),
                "characteristic",
                characteristicIdentity(d.getCharacteristic()));
    }

    synchronized Map<String, Object> characteristic(BluetoothGattCharacteristic c) {
        List<Object> descriptors = new ArrayList<>();
        for (BluetoothGattDescriptor d : c.getDescriptors()) descriptors.add(descriptor(d));
        return map(
                "handle",
                handle(c),
                "uuid",
                c.getUuid().toString(),
                "instanceId",
                c.getInstanceId(),
                "properties",
                c.getProperties(),
                "permissions",
                c.getPermissions(),
                "descriptors",
                descriptors,
                "service",
                serviceIdentity(c.getService()));
    }

    synchronized Map<String, Object> service(
            BluetoothGattService s, Set<BluetoothGattService> visited) {
        List<Object> chars = new ArrayList<>(), included = new ArrayList<>();
        if (visited.add(s)) {
            for (BluetoothGattCharacteristic c : s.getCharacteristics())
                chars.add(characteristic(c));
            for (BluetoothGattService i : s.getIncludedServices())
                included.add(service(i, visited));
        }
        return map(
                "handle",
                handle(s),
                "uuid",
                s.getUuid().toString(),
                "instanceId",
                s.getInstanceId(),
                "serviceType",
                s.getType(),
                "characteristics",
                chars,
                "includedServices",
                included);
    }

    synchronized List<Object> services(List<BluetoothGattService> services) {
        List<Object> result = new ArrayList<>();
        for (BluetoothGattService s : services)
            result.add(service(s, Collections.newSetFromMap(new IdentityHashMap<>())));
        return result;
    }

    synchronized void remove(BluetoothGattService s) {
        for (BluetoothGattCharacteristic c : s.getCharacteristics()) {
            for (BluetoothGattDescriptor d : c.getDescriptors()) removeAttribute(d);
            removeAttribute(c);
        }
        removeAttribute(s);
    }

    void removeAttribute(Object object) {
        String handle = handles.remove(object);
        if (handle != null) {
            attributes.remove(handle);
            retiredHandles.put(object, handle);
        }
    }

    private void addDescriptor(BluetoothGattCharacteristic characteristic, Map<String, Object> a) {
        String handle = string(a, "handle");
        if (attributes.containsKey(handle))
            throw new IllegalArgumentException("Descriptor already belongs to a characteristic");
        BluetoothGattDescriptor descriptor =
                new BluetoothGattDescriptor(
                        UUID.fromString(string(a, "uuid")), integer(a, "permissions", 0));
        characteristic.addDescriptor(descriptor);
        bind(handle, descriptor);
    }

    private void addCharacteristic(BluetoothGattService service, Map<String, Object> a) {
        String handle = string(a, "handle");
        if (attributes.containsKey(handle))
            throw new IllegalArgumentException("Characteristic already belongs to a service");
        BluetoothGattCharacteristic characteristic =
                new BluetoothGattCharacteristic(
                        UUID.fromString(string(a, "uuid")),
                        integer(a, "properties", 0),
                        integer(a, "permissions", 0));
        service.addCharacteristic(characteristic);
        bind(handle, characteristic);
        for (Object raw : list(a.get("descriptors"))) addDescriptor(characteristic, object(raw));
    }

    synchronized BluetoothGattService createService(Map<String, Object> a) {
        String serviceHandle = string(a, "handle");
        if (attributes.containsKey(serviceHandle))
            throw new IllegalStateException("Service already registered");
        BluetoothGattService service =
                new BluetoothGattService(
                        UUID.fromString(string(a, "uuid")), integer(a, "serviceType", 0));
        bind(serviceHandle, service);
        try {
            for (Object raw : list(a.get("characteristics")))
                addCharacteristic(service, object(raw));
            for (Object raw : list(a.get("includedServices")))
                service.addService(get(string(object(raw), "handle"), BluetoothGattService.class));
            return service;
        } catch (RuntimeException e) {
            remove(service);
            throw e;
        }
    }
}
