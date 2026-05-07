package com.jamcorder.android_bluetooth;

import java.lang.ref.ReferenceQueue;
import java.lang.ref.WeakReference;
import java.util.HashMap;
import java.util.IdentityHashMap;
import java.util.Iterator;
import java.util.Map;

/** Retired callback identities, accessed under the owning GattAttributes monitor. */
final class GattHandleHistory {
    private static final class Key extends WeakReference<Object> {
        private final int hash;

        Key(Object object, ReferenceQueue<Object> queue) {
            super(object, queue);
            hash = System.identityHashCode(object);
        }

        @Override
        public int hashCode() {
            return hash;
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) return true;
            Object object = get();
            return object != null && other instanceof Key && object == ((Key) other).get();
        }
    }

    private final ReferenceQueue<Object> collected = new ReferenceQueue<>();
    private final Map<Key, String> entries = new HashMap<>();

    private void purge() {
        Key key;
        while ((key = (Key) collected.poll()) != null) entries.remove(key);
    }

    void clear() {
        entries.clear();
        while (collected.poll() != null) {}
    }

    boolean isEmpty() {
        purge();
        return entries.isEmpty();
    }

    void put(Object object, String handle) {
        purge();
        entries.put(new Key(object, collected), handle);
    }

    void putAll(IdentityHashMap<Object, String> handles) {
        purge();
        for (Map.Entry<Object, String> entry : handles.entrySet())
            entries.put(new Key(entry.getKey(), collected), entry.getValue());
    }

    void copyTo(IdentityHashMap<Object, String> handles) {
        purge();
        Iterator<Map.Entry<Key, String>> iterator = entries.entrySet().iterator();
        while (iterator.hasNext()) {
            Map.Entry<Key, String> entry = iterator.next();
            Object object = entry.getKey().get();
            if (object == null) iterator.remove();
            else handles.put(object, entry.getValue());
        }
    }
}
