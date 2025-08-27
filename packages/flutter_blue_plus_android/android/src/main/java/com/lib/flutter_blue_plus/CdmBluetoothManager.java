// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package com.lib.flutter_blue_plus;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothProfile;
import android.companion.AssociationRequest;
import android.companion.BluetoothDeviceFilter;
import android.companion.CompanionDeviceManager;
import android.content.Context;
import android.content.IntentSender;
import android.os.Build;
import android.util.Log;

import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;

import io.flutter.plugin.common.MethodChannel;

/**
 * Android Companion Device Manager (CDM) integration for Flutter Blue Plus
 * 
 * This class manages CDM device associations, pairing workflows, and 
 * CDM-specific GATT operations that avoid traditional Bluetooth bonding.
 * 
 * CDM was introduced in Android 8.0 (API 26) to provide streamlined pairing
 * for companion devices like wearables, IoT devices, and AR glasses.
 */
public class CdmBluetoothManager {
    private static final String TAG = "[FBP-CDM]";
    
    // CDM request codes for activity results
    private static final int REQUEST_CODE_CDM_PAIRING = 1001;
    
    private final Context context;
    private final Activity activity;
    private final CompanionDeviceManager companionDeviceManager;
    private final BluetoothAdapter bluetoothAdapter;
    
    // Track CDM devices to prevent auto-bonding
    private final Set<String> cdmDevices = ConcurrentHashMap.newKeySet();
    
    // Pending CDM pairing operations
    private MethodChannel.Result pendingPairingResult;
    
    public CdmBluetoothManager(Context context, Activity activity, BluetoothAdapter bluetoothAdapter) {
        this.context = context;
        this.activity = activity;
        this.bluetoothAdapter = bluetoothAdapter;
        
        if (Build.VERSION.SDK_INT >= 26) {
            this.companionDeviceManager = (CompanionDeviceManager) 
                context.getSystemService(Context.COMPANION_DEVICE_SERVICE);
        } else {
            this.companionDeviceManager = null;
        }
    }
    
    /**
     * Check if CDM is supported on this device
     */
    public boolean isCdmSupported() {
        return Build.VERSION.SDK_INT >= 26 && companionDeviceManager != null;
    }
    
    /**
     * Check if a device is associated via CDM
     */
    public boolean isDeviceAssociated(String deviceAddress) {
        if (!isCdmSupported()) {
            return false;
        }
        
        try {
            List<String> associations = companionDeviceManager.getAssociations();
            return associations.contains(deviceAddress);
        } catch (Exception e) {
            Log.w(TAG, "Failed to check CDM associations: " + e.getMessage());
            return false;
        }
    }
    
    /**
     * Get all CDM-associated devices
     */
    public List<String> getAssociatedDevices() {
        if (!isCdmSupported()) {
            return java.util.Collections.emptyList();
        }
        
        try {
            return companionDeviceManager.getAssociations();
        } catch (Exception e) {
            Log.w(TAG, "Failed to get CDM associations: " + e.getMessage());
            return java.util.Collections.emptyList();
        }
    }
    
    /**
     * Start CDM pairing process with system dialog
     */
    public void startCdmPairing(MethodChannel.Result result) {
        if (!isCdmSupported()) {
            result.error("CDM_NOT_SUPPORTED", "Companion Device Manager not supported on this device", null);
            return;
        }
        
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity required for CDM pairing", null);
            return;
        }
        
        try {
            // Create a generic Bluetooth device filter for CDM pairing
            BluetoothDeviceFilter deviceFilter = new BluetoothDeviceFilter.Builder()
                // Optional: add device name pattern matching
                // .setNamePattern(Pattern.compile(".*"))
                .build();
            
            AssociationRequest pairingRequest = new AssociationRequest.Builder()
                .addDeviceFilter(deviceFilter)
                .setSingleDevice(false)  // Allow multiple device selection
                .build();
                
            // Store the result to complete when pairing finishes
            this.pendingPairingResult = result;
            
            companionDeviceManager.associate(pairingRequest,
                new CompanionDeviceManager.Callback() {
                    @Override
                    public void onDeviceFound(IntentSender chooserLauncher) {
                        try {
                            activity.startIntentSenderForResult(chooserLauncher,
                                REQUEST_CODE_CDM_PAIRING, null, 0, 0, 0);
                        } catch (IntentSender.SendIntentException e) {
                            Log.e(TAG, "Failed to start CDM chooser", e);
                            if (pendingPairingResult != null) {
                                pendingPairingResult.error("CHOOSER_FAILED", 
                                    "Failed to start device chooser: " + e.getMessage(), null);
                                pendingPairingResult = null;
                            }
                        }
                    }
                    
                    @Override
                    public void onFailure(CharSequence error) {
                        Log.e(TAG, "CDM association failed: " + error);
                        if (pendingPairingResult != null) {
                            pendingPairingResult.error("CDM_PAIRING_FAILED", 
                                "CDM pairing failed: " + error, null);
                            pendingPairingResult = null;
                        }
                    }
                }, null);
                
        } catch (Exception e) {
            Log.e(TAG, "Failed to start CDM pairing", e);
            result.error("CDM_ERROR", "Failed to start CDM pairing: " + e.getMessage(), null);
        }
    }
    
    /**
     * Handle CDM pairing result from activity
     */
    public boolean handleCdmPairingResult(int requestCode, int resultCode, android.content.Intent data) {
        if (requestCode != REQUEST_CODE_CDM_PAIRING) {
            return false;
        }
        
        if (pendingPairingResult == null) {
            Log.w(TAG, "Received CDM pairing result but no pending result callback");
            return true;
        }
        
        if (resultCode == Activity.RESULT_OK && data != null) {
            try {
                BluetoothDevice device = data.getParcelableExtra(CompanionDeviceManager.EXTRA_DEVICE);
                if (device != null) {
                    String deviceAddress = device.getAddress();
                    
                    // Add to CDM devices set for auto-bonding prevention
                    cdmDevices.add(deviceAddress);
                    
                    Log.i(TAG, "CDM pairing successful for device: " + deviceAddress);
                    pendingPairingResult.success(deviceAddress);
                } else {
                    pendingPairingResult.error("NO_DEVICE", "No device selected", null);
                }
            } catch (Exception e) {
                Log.e(TAG, "Error processing CDM pairing result", e);
                pendingPairingResult.error("RESULT_ERROR", 
                    "Error processing pairing result: " + e.getMessage(), null);
            }
        } else {
            Log.i(TAG, "CDM pairing cancelled by user");
            pendingPairingResult.error("USER_CANCELLED", "User cancelled CDM pairing", null);
        }
        
        pendingPairingResult = null;
        return true;
    }
    
    /**
     * Remove CDM association for a device
     */
    public boolean removeAssociation(String deviceAddress) {
        if (!isCdmSupported()) {
            return false;
        }
        
        try {
            if (Build.VERSION.SDK_INT >= 33) { // Android 13+
                // Use new disassociate method if available
                companionDeviceManager.disassociate(deviceAddress);
            } else {
                // Fallback: CDM doesn't provide public disassociate before API 33
                // The association will remain until the app is uninstalled
                Log.w(TAG, "CDM disassociation not available before Android 13");
                return false;
            }
            
            // Remove from our tracking set
            cdmDevices.remove(deviceAddress);
            
            Log.i(TAG, "Removed CDM association for device: " + deviceAddress);
            return true;
            
        } catch (Exception e) {
            Log.e(TAG, "Failed to remove CDM association: " + e.getMessage());
            return false;
        }
    }
    
    /**
     * Mark a device as CDM-associated for auto-bonding prevention
     */
    public void markAsCdmDevice(String deviceAddress) {
        cdmDevices.add(deviceAddress);
        Log.d(TAG, "Marked device as CDM: " + deviceAddress);
    }
    
    /**
     * Check if a device is tracked as CDM (either associated or manually marked)
     */
    public boolean isCdmDevice(String deviceAddress) {
        return cdmDevices.contains(deviceAddress) || isDeviceAssociated(deviceAddress);
    }
    
    /**
     * Remove CDM tracking for a device
     */
    public void unmarkCdmDevice(String deviceAddress) {
        cdmDevices.remove(deviceAddress);
        Log.d(TAG, "Unmarked CDM device: " + deviceAddress);
    }
    
    /**
     * Get all currently tracked CDM devices (both associated and manually marked)
     */
    public Set<String> getTrackedCdmDevices() {
        return java.util.Collections.unmodifiableSet(cdmDevices);
    }
    
    /**
     * Create a CDM-aware GATT callback that prevents auto-bonding
     */
    public BluetoothGattCallback createCdmGattCallback(String deviceAddress, 
                                                      BluetoothGattCallback originalCallback) {
        if (!isCdmDevice(deviceAddress)) {
            return originalCallback;
        }
        
        return new CdmGattCallback(deviceAddress, originalCallback);
    }
    
    /**
     * CDM-specific GATT callback that handles authentication differently
     */
    private class CdmGattCallback extends BluetoothGattCallback {
        private final String deviceAddress;
        private final BluetoothGattCallback originalCallback;
        
        public CdmGattCallback(String deviceAddress, BluetoothGattCallback originalCallback) {
            this.deviceAddress = deviceAddress;
            this.originalCallback = originalCallback;
        }
        
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            Log.d(TAG, "CDM GATT connection state change: " + deviceAddress + 
                  ", status: " + status + ", newState: " + newState);
            originalCallback.onConnectionStateChange(gatt, status, newState);
        }
        
        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            Log.d(TAG, "CDM GATT services discovered: " + deviceAddress + ", status: " + status);
            originalCallback.onServicesDiscovered(gatt, status);
        }
        
        @Override
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            if (status == BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION) {
                Log.w(TAG, "CDM device authentication required for read, but auto-bonding disabled: " + deviceAddress);
                // Note: For CDM devices, this may be expected behavior
                // The app should handle this or use alternative approaches
            }
            originalCallback.onCharacteristicRead(gatt, characteristic, status);
        }
        
        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            if (status == BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION) {
                Log.w(TAG, "CDM device authentication required for write, but auto-bonding disabled: " + deviceAddress);
            }
            originalCallback.onCharacteristicWrite(gatt, characteristic, status);
        }
        
        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
            if (status == BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION) {
                Log.w(TAG, "CDM device authentication required for descriptor write, but auto-bonding disabled: " + deviceAddress);
                // This is the common case that causes problems with CDM devices
                // They reject bonding when setNotifyValue tries to write CCCD
            }
            originalCallback.onDescriptorWrite(gatt, descriptor, status);
        }
        
        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
            originalCallback.onCharacteristicChanged(gatt, characteristic);
        }
        
        @Override
        public void onReadRemoteRssi(BluetoothGatt gatt, int rssi, int status) {
            originalCallback.onReadRemoteRssi(gatt, rssi, status);
        }
        
        @Override
        public void onMtuChanged(BluetoothGatt gatt, int mtu, int status) {
            originalCallback.onMtuChanged(gatt, mtu, status);
        }
    }
}