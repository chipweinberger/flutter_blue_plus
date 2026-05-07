package com.jamcorder.android_bluetooth;

import static com.jamcorder.android_bluetooth.BluetoothCodec.*;

import android.bluetooth.*;
import android.content.*;
import android.os.*;

import io.flutter.plugin.common.MethodChannel;

import java.util.*;

/** Device lookup, bonding, pairing PINs, and device operations. */
final class DeviceBridge {
    final AndroidBluetoothPlugin p;

    DeviceBridge(AndroidBluetoothPlugin p) {
        this.p = p;
    }

    BluetoothDevice device(Map<String, Object> a) {
        String address = string(a, "address").toUpperCase(Locale.ROOT);
        if (a.get("addressType") != null) {
            if (Build.VERSION.SDK_INT < 33)
                throw new UnsupportedOperationException("Requires Android API 33");
            return p.adapterBridge
                    .adapter()
                    .getRemoteLeDevice(address, integer(a, "addressType", 0));
        }
        BluetoothDevice known = p.knownDevices.get(address);
        return known == null ? p.adapterBridge.adapter().getRemoteDevice(address) : known;
    }

    void setPinForNextPairing(String address, byte[] pin) {
        if (pin == null) p.pairingPins.remove(address);
        else p.pairingPins.put(address, pin.clone());
    }

    void clearPairingPin(BluetoothDevice device) {
        String address = device.getAddress();
        if (address != null) p.pairingPins.remove(address);
    }

    // Apply a prearmed PIN before returning from the pairing broadcast, as Android expects.
    @android.annotation.SuppressLint("MissingPermission")
    void applyPairingPin(BluetoothDevice device) {
        byte[] pin = p.pairingPins.remove(device.getAddress());
        if (pin == null) return;
        Map<String, Object> result = map("device", deviceMap(device));
        try {
            result.put("accepted", device.setPin(pin));
        } catch (RuntimeException e) {
            result.put("accepted", false);
            result.put("message", e.toString());
        }
        p.emit("device", "onPairingPinSet", result);
    }

    @android.annotation.SuppressLint("MissingPermission")
    void handle(String method, Map<String, Object> a, MethodChannel.Result result)
            throws Exception {
        Object value;
        switch (method) {
            case "bondState":
                value = device(a).getBondState();
                break;
            case "get":
                {
                    Map<String, Object> snapshot = deviceMap(device(a));
                    if (a.get("addressType") != null)
                        snapshot.put("addressType", a.get("addressType"));
                    value = snapshot;
                    break;
                }
            case "identityAddressWithType":
                {
                    if (Build.VERSION.SDK_INT < 36)
                        throw new UnsupportedOperationException("Requires Android API 36");
                    Object address =
                            optional(device(a), "getIdentityAddressWithType", new Class<?>[0]);
                    value =
                            map(
                                    "address",
                                    optional(address, "getAddress", new Class<?>[0]),
                                    "addressType",
                                    optional(address, "getAddressType", new Class<?>[0]));
                    break;
                }
            case "createBond":
                {
                    BluetoothDevice d = device(a);
                    if (a.containsKey("pin"))
                        setPinForNextPairing(d.getAddress(), (byte[]) a.get("pin"));
                    try {
                        value = d.createBond();
                        if (!Boolean.TRUE.equals(value)) p.pairingPins.remove(d.getAddress());
                    } catch (RuntimeException e) {
                        p.pairingPins.remove(d.getAddress());
                        throw e;
                    }
                    break;
                }
            case "setPinForNextPairing":
                setPinForNextPairing(
                        string(a, "address").toUpperCase(Locale.ROOT), (byte[]) a.get("pin"));
                value = null;
                break;
            case "setAlias":
                {
                    if (Build.VERSION.SDK_INT < 31)
                        throw new UnsupportedOperationException("Requires Android API 31");
                    BluetoothDevice d = device(a);
                    Object alias = a.get("alias");
                    if (alias != null && !(alias instanceof String))
                        throw new IllegalArgumentException("alias must be a string or null");
                    value = d.setAlias((String) alias);
                    break;
                }
            case "setPairingConfirmation":
                {
                    BluetoothDevice d = device(a);
                    if (!bool(a, "confirm", false)) clearPairingPin(d);
                    value = d.setPairingConfirmation(bool(a, "confirm", false));
                    break;
                }
            case "setPin":
                value = device(a).setPin((byte[]) a.get("pin"));
                break;
            case "removeBond":
                {
                    BluetoothDevice d = device(a);
                    clearPairingPin(d);
                    value = reflect(d, "removeBond", new Class<?>[0]);
                    break;
                }
            default:
                result.notImplemented();
                return;
        }
        result.success(value);
    }
}
