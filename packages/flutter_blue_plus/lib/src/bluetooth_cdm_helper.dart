// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../flutter_blue_plus.dart';

/// Android Companion Device Manager (CDM) helper utilities
/// 
/// CDM is available on Android 8.0+ and provides a streamlined pairing
/// experience for companion devices like wearables, IoT devices, and AR glasses.
/// CDM devices often reject traditional Bluetooth bonding and should use
/// CDM-specific connection parameters.
class BluetoothCdmHelper {
  
  /// Check if Companion Device Manager is supported on this platform
  /// Returns true on Android 8.0+ devices, false otherwise
  static Future<bool> get isSupported async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    // CDM was introduced in Android API 26 (Android 8.0)
    return true;
  }

  /// Check if a specific device is associated via Companion Device Manager
  /// 
  /// [deviceId] The device identifier (MAC address on Android)
  /// Returns true if the device is CDM-associated, false otherwise
  static Future<bool> isDeviceAssociated(String deviceId) async {
    if (!await isSupported) {
      return false;
    }

    try {
      final MethodChannel methodChannel = MethodChannel('flutter_blue_plus/methods');
      return await methodChannel.invokeMethod('isCdmDeviceAssociated', deviceId) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get all devices currently associated via Companion Device Manager
  /// 
  /// Returns a list of device identifiers that are CDM-associated
  static Future<List<String>> getAssociatedDevices() async {
    if (!await isSupported) {
      return [];
    }

    try {
      final MethodChannel methodChannel = MethodChannel('flutter_blue_plus/methods');
      final List<dynamic> result = await methodChannel.invokeMethod('getCdmAssociatedDevices') ?? [];
      return result.cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// Start the Android CDM pairing process with system dialog
  /// 
  /// This will show the system Companion Device Manager pairing dialog
  /// allowing the user to select and associate a companion device.
  /// 
  /// Returns the device identifier of the paired device, or null if cancelled
  static Future<String?> startCdmPairing() async {
    if (!await isSupported) {
      throw PlatformException(
        code: 'CDM_NOT_SUPPORTED',
        message: 'Companion Device Manager not supported on this device',
      );
    }

    try {
      final MethodChannel methodChannel = MethodChannel('flutter_blue_plus/methods');
      final String? deviceId = await methodChannel.invokeMethod('startCdmPairing');
      return deviceId;
    } catch (e) {
      if (e is PlatformException) {
        rethrow;
      }
      throw PlatformException(
        code: 'CDM_ERROR',
        message: 'Failed to start CDM pairing: $e',
      );
    }
  }

  /// Remove CDM association for a specific device
  /// 
  /// [deviceId] The device identifier to remove association for
  /// Returns true if the association was successfully removed
  /// 
  /// Note: This requires Android 13+ (API 33). On older versions, 
  /// associations can only be removed by uninstalling the app.
  static Future<bool> removeAssociation(String deviceId) async {
    if (!await isSupported) {
      return false;
    }

    try {
      final MethodChannel methodChannel = MethodChannel('flutter_blue_plus/methods');
      final bool removed = await methodChannel.invokeMethod('removeCdmAssociation', deviceId) ?? false;
      return removed;
    } catch (e) {
      return false;
    }
  }

  /// Helper method to connect to a device with appropriate CDM settings
  /// 
  /// This method automatically detects if a device is CDM-associated and
  /// applies the correct connection parameters to prevent bonding conflicts.
  /// 
  /// [device] The Bluetooth device to connect to
  /// [timeout] Connection timeout duration
  /// [mtu] Android only. Request a larger mtu right after connection
  /// [autoConnect] Enable auto-reconnection
  /// 
  /// Returns true if connection parameters were applied, false otherwise
  static Future<bool> connectWithCdmDetection(
    BluetoothDevice device, {
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool autoConnect = false,
  }) async {
    bool isCdmDevice = await isDeviceAssociated(device.remoteId.str);
    
    await device.connect(
      timeout: timeout,
      mtu: mtu,
      autoConnect: autoConnect,
      allowAutoBonding: !isCdmDevice,
      isCdmDevice: isCdmDevice,
    );

    return isCdmDevice;
  }

  /// Create a BluetoothDevice from a device ID with CDM-aware connection helper
  /// 
  /// This is a convenience method that combines device creation and CDM detection.
  /// 
  /// [deviceId] The device identifier (MAC address on Android, UUID on iOS)
  /// 
  /// Returns a BluetoothDevice configured for CDM-aware connections
  static BluetoothDevice deviceFromId(String deviceId) {
    return BluetoothDevice.fromId(deviceId);
  }
}