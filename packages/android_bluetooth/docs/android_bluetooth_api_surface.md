# AndroidBluetooth API Surface

This document captures the Android framework Bluetooth API surface from the official Android Developers
reference as of 2026-05-07.

Source package summaries:

- `android.bluetooth`: <https://developer.android.com/reference/android/bluetooth/package-summary>
- `android.bluetooth.le`: <https://developer.android.com/reference/android/bluetooth/le/package-summary.html>

## Scope

This is the platform API inventory we should treat as the initial surface area for the `android_bluetooth`
package. It is intentionally framed as if FlutterBluePlus does not exist.

The inventory below is taken from the official package summary pages so we have:

- every top-level symbol listed by Google for the Bluetooth framework packages
- nested types that are listed as distinct symbols in those package summaries
- direct links back to the official reference pages

## android.bluetooth

Official package summary:

- URL: <https://developer.android.com/reference/android/bluetooth/package-summary>
- Added in API level 5
- Last updated by Google: 2026-03-26 UTC

### Interfaces

- [`BluetoothAdapter.LeScanCallback`](https://developer.android.com/reference/android/bluetooth/BluetoothAdapter.LeScanCallback)
- [`BluetoothProfile`](https://developer.android.com/reference/android/bluetooth/BluetoothProfile)
- [`BluetoothProfile.ServiceListener`](https://developer.android.com/reference/android/bluetooth/BluetoothProfile.ServiceListener)

### Classes

- [`BluetoothA2dp`](https://developer.android.com/reference/android/bluetooth/BluetoothA2dp)
- [`BluetoothAdapter`](https://developer.android.com/reference/android/bluetooth/BluetoothAdapter)
- [`BluetoothAssignedNumbers`](https://developer.android.com/reference/android/bluetooth/BluetoothAssignedNumbers)
- [`BluetoothClass`](https://developer.android.com/reference/android/bluetooth/BluetoothClass)
- [`BluetoothClass.Device`](https://developer.android.com/reference/android/bluetooth/BluetoothClass.Device)
- [`BluetoothClass.Device.Major`](https://developer.android.com/reference/android/bluetooth/BluetoothClass.Device.Major)
- [`BluetoothClass.Service`](https://developer.android.com/reference/android/bluetooth/BluetoothClass.Service)
- [`BluetoothCodecConfig`](https://developer.android.com/reference/android/bluetooth/BluetoothCodecConfig)
- [`BluetoothCodecConfig.Builder`](https://developer.android.com/reference/android/bluetooth/BluetoothCodecConfig.Builder)
- [`BluetoothCodecStatus`](https://developer.android.com/reference/android/bluetooth/BluetoothCodecStatus)
- [`BluetoothCodecStatus.Builder`](https://developer.android.com/reference/android/bluetooth/BluetoothCodecStatus.Builder)
- [`BluetoothCodecType`](https://developer.android.com/reference/android/bluetooth/BluetoothCodecType)
- [`BluetoothCsipSetCoordinator`](https://developer.android.com/reference/android/bluetooth/BluetoothCsipSetCoordinator)
- [`BluetoothDevice`](https://developer.android.com/reference/android/bluetooth/BluetoothDevice)
- [`BluetoothDevice.BluetoothAddress`](https://developer.android.com/reference/android/bluetooth/BluetoothDevice.BluetoothAddress)
- [`BluetoothGatt`](https://developer.android.com/reference/android/bluetooth/BluetoothGatt)
- [`BluetoothGattCallback`](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback)
- [`BluetoothGattCharacteristic`](https://developer.android.com/reference/android/bluetooth/BluetoothGattCharacteristic)
- [`BluetoothGattConnectionSettings`](https://developer.android.com/reference/android/bluetooth/BluetoothGattConnectionSettings)
- [`BluetoothGattConnectionSettings.Builder`](https://developer.android.com/reference/android/bluetooth/BluetoothGattConnectionSettings.Builder)
- [`BluetoothGattDescriptor`](https://developer.android.com/reference/android/bluetooth/BluetoothGattDescriptor)
- [`BluetoothGattServer`](https://developer.android.com/reference/android/bluetooth/BluetoothGattServer)
- [`BluetoothGattServerCallback`](https://developer.android.com/reference/android/bluetooth/BluetoothGattServerCallback)
- [`BluetoothGattService`](https://developer.android.com/reference/android/bluetooth/BluetoothGattService)
- [`BluetoothHeadset`](https://developer.android.com/reference/android/bluetooth/BluetoothHeadset)
- [`BluetoothHealth`](https://developer.android.com/reference/android/bluetooth/BluetoothHealth)
- [`BluetoothHealthAppConfiguration`](https://developer.android.com/reference/android/bluetooth/BluetoothHealthAppConfiguration)
- [`BluetoothHealthCallback`](https://developer.android.com/reference/android/bluetooth/BluetoothHealthCallback)
- [`BluetoothHearingAid`](https://developer.android.com/reference/android/bluetooth/BluetoothHearingAid)
- [`BluetoothHidDevice`](https://developer.android.com/reference/android/bluetooth/BluetoothHidDevice)
- [`BluetoothHidDevice.Callback`](https://developer.android.com/reference/android/bluetooth/BluetoothHidDevice.Callback)
- [`BluetoothHidDeviceAppQosSettings`](https://developer.android.com/reference/android/bluetooth/BluetoothHidDeviceAppQosSettings)
- [`BluetoothHidDeviceAppSdpSettings`](https://developer.android.com/reference/android/bluetooth/BluetoothHidDeviceAppSdpSettings)
- [`BluetoothLeAudio`](https://developer.android.com/reference/android/bluetooth/BluetoothLeAudio)
- [`BluetoothLeAudioCodecConfig`](https://developer.android.com/reference/android/bluetooth/BluetoothLeAudioCodecConfig)
- [`BluetoothLeAudioCodecConfig.Builder`](https://developer.android.com/reference/android/bluetooth/BluetoothLeAudioCodecConfig.Builder)
- [`BluetoothLeAudioCodecStatus`](https://developer.android.com/reference/android/bluetooth/BluetoothLeAudioCodecStatus)
- [`BluetoothManager`](https://developer.android.com/reference/android/bluetooth/BluetoothManager)
- [`BluetoothServerSocket`](https://developer.android.com/reference/android/bluetooth/BluetoothServerSocket)
- [`BluetoothSocket`](https://developer.android.com/reference/android/bluetooth/BluetoothSocket)
- [`BluetoothSocketSettings`](https://developer.android.com/reference/android/bluetooth/BluetoothSocketSettings)
- [`BluetoothSocketSettings.Builder`](https://developer.android.com/reference/android/bluetooth/BluetoothSocketSettings.Builder)
- [`BluetoothStatusCodes`](https://developer.android.com/reference/android/bluetooth/BluetoothStatusCodes)
- [`BondStatus`](https://developer.android.com/reference/android/bluetooth/BondStatus)
- [`EncryptionStatus`](https://developer.android.com/reference/android/bluetooth/EncryptionStatus)

### Exceptions

- [`BluetoothSocketException`](https://developer.android.com/reference/android/bluetooth/BluetoothSocketException)

## android.bluetooth.le

Official package summary:

- URL: <https://developer.android.com/reference/android/bluetooth/le/package-summary.html>
- Added in API level 21
- Last updated by Google: 2025-02-10 UTC

### Classes

- [`AdvertiseCallback`](https://developer.android.com/reference/android/bluetooth/le/AdvertiseCallback)
- [`AdvertiseData`](https://developer.android.com/reference/android/bluetooth/le/AdvertiseData)
- [`AdvertiseData.Builder`](https://developer.android.com/reference/android/bluetooth/le/AdvertiseData.Builder)
- [`AdvertiseSettings`](https://developer.android.com/reference/android/bluetooth/le/AdvertiseSettings)
- [`AdvertiseSettings.Builder`](https://developer.android.com/reference/android/bluetooth/le/AdvertiseSettings.Builder)
- [`AdvertisingSet`](https://developer.android.com/reference/android/bluetooth/le/AdvertisingSet)
- [`AdvertisingSetCallback`](https://developer.android.com/reference/android/bluetooth/le/AdvertisingSetCallback)
- [`AdvertisingSetParameters`](https://developer.android.com/reference/android/bluetooth/le/AdvertisingSetParameters)
- [`AdvertisingSetParameters.Builder`](https://developer.android.com/reference/android/bluetooth/le/AdvertisingSetParameters.Builder)
- [`BluetoothLeAdvertiser`](https://developer.android.com/reference/android/bluetooth/le/BluetoothLeAdvertiser)
- [`BluetoothLeScanner`](https://developer.android.com/reference/android/bluetooth/le/BluetoothLeScanner)
- [`PeriodicAdvertisingParameters`](https://developer.android.com/reference/android/bluetooth/le/PeriodicAdvertisingParameters)
- [`PeriodicAdvertisingParameters.Builder`](https://developer.android.com/reference/android/bluetooth/le/PeriodicAdvertisingParameters.Builder)
- [`ScanCallback`](https://developer.android.com/reference/android/bluetooth/le/ScanCallback)
- [`ScanFilter`](https://developer.android.com/reference/android/bluetooth/le/ScanFilter)
- [`ScanFilter.Builder`](https://developer.android.com/reference/android/bluetooth/le/ScanFilter.Builder)
- [`ScanRecord`](https://developer.android.com/reference/android/bluetooth/le/ScanRecord)
- [`ScanResult`](https://developer.android.com/reference/android/bluetooth/le/ScanResult)
- [`ScanSettings`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings)
- [`ScanSettings.Builder`](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder)
- [`TransportBlock`](https://developer.android.com/reference/android/bluetooth/le/TransportBlock)
- [`TransportDiscoveryData`](https://developer.android.com/reference/android/bluetooth/le/TransportDiscoveryData)

## Notes For Implementation

- This gives us the package-level symbol inventory for the Android framework Bluetooth surface.
- The next useful follow-up is a member-level extraction pass for high-value types first:
  `BluetoothAdapter`, `BluetoothDevice`, `BluetoothGatt`, `BluetoothGattCallback`, `BluetoothGattCharacteristic`,
  `BluetoothGattDescriptor`, `BluetoothGattService`, `BluetoothManager`, `BluetoothLeScanner`,
  `BluetoothLeAdvertiser`, `ScanResult`, `ScanRecord`, `ScanSettings`, and `ScanFilter`.
- Deprecated symbols are intentionally kept in the inventory because the official docs still list them as public API.
