
## 1.8.2
* android: support sdk 33 for writeCharacteristic and writeDescriptor
* android: calling connect() on already connected device is now considered success
* android: return more specific error for locateGatt issue
* android: shouldClearGattCache is now called after connection, not before

## 1.8.1
* android: characteristic properties check was incorrect (regression in 1.7.8)

## 1.8.0
* android/ios: check errors - charactersticRead
* android/ios: check errors - readDescriptor
* android/ios: check errors - discoverServices
* android/ios: check errors - mtu
* android/ios: check errors - readRssi
* android/ios: pass error string - setNotifyValue
* android/ios: pass error string - charactersticWrite
* android/ios: pass error string - writeDescriptor

## 1.7.8
* android: add more useful errors for read and write characterist errors

## 1.7.7
* android: set autoConnect to false by default
* dart: scanning: fix Bad state: Cannot add event after closing.
* example: remove pubspec.lock so users default to latest version

## 1.7.6
* dart: BmBluetoothService.is_primary was not set (regression in 1.7.0)
* android: BmAdvertisementData.connectable was not set (regression in 1.7.0)
* android: success was not set for writeCharacteristic, setNotification, writeDescriptor  (regression in 1.7.0) 
* android: update to gradle 8
* android: dont request ACCESS_FINE_LOCATION by default (Android 12+)

## 1.7.5
* android: fix BluetoothState not being updated
* Dart: remove analysis_options.yaml
* Example: fix deprecations

## 1.7.4
* android: fix Android 13 access fine location error

## 1.7.3
* android: fix exception thrown when descriptor.write is called (regression in 1.7.0)

## 1.7.2
* android: fix exception thrown when characteristic.write is called (regression in 1.7.0)
* android: bmCharacteristicProperties was not being set correctly (regression in 1.7.0)

## 1.7.1
* iOS: fix when connecting, exception is thrown (regression in 1.7.0)

## 1.7.0
* internal: removed protobuf dependency 
* Android: compileSdkVersion 31 -> 33
* Android: increase minSdkVersion 19 -> 21 to remove lollipop checks
* Android: FineLocation permission is now optional. See startScan
* Android: fix turnOn and turnOff regression in 1.6.1
* iOS: allow connecting without scanning if you save and reuse the remote_id
* dart: fix guid exception with serviceUUID is empty

## 1.6.1
* Android: fix compile error (regression in 1.6.0)
* Adnroid: significantly clean up all code

## 1.6.0
* Dart: close BufferStream listen on stopScan
* Dart: don't repropogate Mutex error
* Dart: Characteristic Read/Write: improve stacktrace on error
* Windows: add support for windows. thanks @Yongle-Fu
* MacOS: use symbolic links to iOS version, to keep internal code in sync
* Android: reformat code


## 1.5.2
* fix: android setNotification was throwing exception (regression)

## 1.5.1
* fix: fix issue where startScan can hang forever (regression)
* fix: some scanResults could be missed due to race condition (theoretically)
* api: dont export util classes & functions. they've been made library-private.
* iOS: prepend all ios logs with '[FBP-iOS]' prefix
* iOS: log errors on failure
* iOS: logs now adhere to logLevel

## 1.5.0
* api: Add isScanningNow variable
* fix: writeCharacteristic (and other similar functions) exception could be missed
* fix: setNotifyValue should check for success and throw error on failure
* fix: race conditions in connect(), disconnect(), readRssi(), writeCharacteristic(), readCharacteristic()
* macOS: add support for macOS
* android: replace deprecated bluetooth enable with 'Enable-Intent'
* android: Removed maxSdkVersion=30 in manifest
* android: Add function: setPreferredPh
* android: Add function: removeBond
* android: Add function: requestConnectionPriority 
* android: allow for simultaneous MAC and ServiceUuid ScanFilters
* android: request location permission on Android 12+ when scanning (needed on some phones)
* ios: Fixed Bluetooth adapter being stuck in unknown state
* ios: Fixed dropping packets during bulk write without response
* ios: Use CBCentralManagerOptionShowPowerAlertKey for better UI popups
* example: fix android permissions
* dart: Removed RxDart and other dependencies


## 1.4.0
* Android: Add clear gatt cache method #142 (thanks to joistaus)
* Android: Opt-out of the `neverForLocation` permission flag for the `BLUETOOTH_SCAN` permission. (thanks to navaronbracke)

  If `neverForLocation` is desired,
  opt back into the old behavior by adding an explicit entry to your Android Manifest:
  ```
  <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
  ```
* Android: Scan BLE long range -devices #139 (thanks to jonik-dev)
* Android: Prevent deprecation warnings #107 (thanks to sqcsabbey)
* Allow native implementation to handle pairing request #109 (thanks to JRazek)

## 1.3.1
* Reverted: Ios: fixed manufacturer data parsing #104 (thanks to sqcsabbey)

## 1.3.0
* Ios: fixed manufacturer data parsing #104 (thanks to sqcsabbey)
* Ios: Fixed an error when calling the connect method of a connected device #106 (thanks to figureai)
* Android: Scan Filter by Mac Address #57 (thanks to  Zyr00)
* Upgrading to linter 2.0.1, excluding generated ProtoBuf files from linting. (thanks to MrCsabaToth)

## 1.2.0
* connect timeout fixed (thanks to crazy-rodney, sophisticode, SkuggaEdward, MousyBusiness and cthurston)
* Add timestamp field to ScanResult class #59 (thanks to simon-iversen)
* Add FlutterBlue.name to get the human readable device name #93 (thanks to mvo5)
* Fix bug where if there were multiple subscribers to FlutterBlue.state and one cancelled it would accidentally cancel all subscribers (thank to MacMalainey and MrCsabaToth)

## 1.1.3
* Read RSSI from a connected BLE device #1 (thanks to sophisticode)
* Fixed a crash on Android OS 12 (added check for BLUETOOTH_CONNECT permission) (fixed by dspells)
* Added BluetoothDevice constructor from id (MAC address) (thanks to tanguypouriel)
* The previous version wasn't disconnecting properly and the device could be still connected under the hood as the cancel() was not called. (fixed by killalad)
* dependencies update (min micro version updating)

## 1.1.2
* Remove connect to BLE device after BLE device has disconnected #11 (fixed by sophisticode)
* fixed Dart Analysis warnings

## 1.1.1
* Copyright reverted to Paul DeMarco

## 1.1.0

* Possible crash fix caused by wrong raw data (fixed by narrit)
* Ios : try reconnect on unexpected disconnection (fixed by EB-Plum)
* Android: Add missing break in switch, which causes exceptions (fixed by russelltg)
* Android: Enforcing maxSdkVersion on the ACCESS_FINE_LOCATION permission will create issues for Android 12 devices that use location for purposes other than Bluetooth (such as using packages that actually need location). (fixed by rickcasson)

## 1.0.0

* First public release

## Versions made while fixing bugs in fork https://github.com/boskokg/flutter_blue:

## 0.12.0

Supporting Android 12 Bluetooth permissions. #940

## 0.12.0

Delay Bluetooth permission & turn-on-Bluetooth system popups on iOS #964

## 0.11.0

The timeout was throwing out of the Future's scope #941
Expose onValueChangedStream #882
Android: removed V1Embedding
Android: removed graddle.properties
Android: enable background usage
Android: cannot handle devices that do not set CCCD_ID (2902) includes BLUNO #185 #797
Android: add method for getting bonded devices #586
Ios: remove support only for x86_64 simulators
Ios: Don't initialize CBCentralManager until needed #599

## 0.10.0

mtuRequest returns the negotiated MTU
Android: functions to turn on/off bluetooth
Android: add null check if channel is already teared down
Android: code small refactoring (fixed AS warnings)
Android: add null check if channel is already teared down
Ios: widen protobuf version allowed

## 0.9.0

Android migrate to mavenCentral.
Android support build on Macs M1
Android protobuf-gradle-plugin:0.8.15 -> 0.8.17
Ios example upgrade to latest flutter 2.5
deprecated/removed widgets fixed in example
