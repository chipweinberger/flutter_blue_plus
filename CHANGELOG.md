## 1.13.4
* Android: fix: discoverServices never returns (regression in 1.13.0)
* Android: fix: turnOn & turnOff must check for permissions
* Android: fix: startScan should not required BLUETOOTH_CONNECT permission

## 1.13.3
* Dart: be extra careful to only call connect & disconnect when necessary

## 1.13.2
* Dart: fix: connect should be no-op if already connected (Regression in 1.13.1)
* Dart: BluetoothDevice: use mutexes to prevent multiple in flight requests

## 1.13.1
* Android/iOS: fix: on connection failure, return right away
* Android/iOS: improve: on connection failure, return error code and error string

## 1.13.0
This release focuses on improving bonding support.
* Android: fix: discoverServices & others can fail if currently in the process of bonding
* Android: createBond: check for success and throw exception on failure
* Android: removeBond: return Future<void> instead of Future<Bool>, and throw exception on failure

## 1.12.14
* Android: fix: min sdk is currently 21, not 19
* Android: fix: getOrDefault not available in AndroidSdkLevel < 24
* Android: log: BOND changes
* Android: rename: pair -> createBond

## 1.12.13
* iOS: fix: FlutterBluePlus.isAvailable 'int' is not a subtype of type 'FutureOr<bool>' (regressed in 1.12.10)

## 1.12.12
* Android: fix: null ptr deref during ScanResult connectionState (regressed in 1.10.6)
^ connectionState was added to scanResults last week. It was not a good idea, and is now fully removed.

## 1.12.11
* Android: fix: potential null dereference if the platform does not have bluetooth
* Android: fix: close all connections when bluetooth is turned off (DeadObjectException)

## 1.12.10
* iOS: isAvailable returns false the first time, incorrectly
* iOS: fix: descriptors, must handle NSData, NSString, & NSNumber correctly
* Android: turnOff is deprecated in Android

## 1.12.9
* dart: fix: servicesStream: 'bad state: Stream has already been listened to'
* dart: fix: remove unecessary print('withoutResponse ')
* dart: mutex should make sure writes happen in the same order as called
* dart: setLogLevel color now optional
* android: fix: add blank AndroidManifest.xml to fix build errors in older flutter
* android/iOS: fix: infinite recursion when included services includes itself
* iOS: fix: FlutterBluePlus.isOn returns 'no' first time even though it is on

## 1.12.8
* android: fix: null ptr in setPreferredPhy & setConnectionPriority (regression in 1.7.0)

## 1.12.7
* iOS: fix mtu returned on iOS was 3 too small
* dart: clean: simplify mutexes. improves throughput for chrs that support write & writeWithoutResponse

## 1.12.6
* Dart: verbose logging: brown == data from platform

## 1.12.5
* Dart: add more logging when in verbose mode, with color

## 1.12.4
* Android fix: build error typo (Regression in 1.12.3)

## 1.12.3
* Android: fix mConnectionState & mMtu not cleared when onDetachedFromEngine (regression in 1.10.10)

## 1.12.2
* example: android: add back INTERNET permission for debug and profile modes. needed for debugging
* android: create BluetoothManager during onMethodCall, as opposed to app startup

## 1.12.1
* android: simplify build.grade to not set specific gradle version. it is uneeded

## 1.12.0
* android: remove permissions from plugin. It is easier for user to specify everything
* dart: fix scan could be initiated twice causing bad state
* dart: fix: read & write mutexs must always come from the MutexFactory to properly prevent race conditions

## 1.11.8
* android/iOS: fix: setLogLevel, getAdapterState, getAdapterName returning error when adapter not available

## 1.11.7
* dart: fix: ensure only 1 mutex per characteristic to prevent race issues and dropped packets
* dart: perf: writeWithoutResponse should use at least 1 mutex per remoteId, to improve throughput
* example: improve word wrapping on smaller screens

## 1.11.6
* dart: writeWithoutResponse should have its own mutex to prevent dropped packets

## 1.11.5
* iOS: fix crash discoverServices() crash after bluetooth adapter is toggled on/off (regressed sometime after 1.4.0)
* example: dismiss DeviceScreen when bluetooth adapter is turned off
* android/iOS: log adapterState and connectionState as strings

## 1.11.4
* android: fix null ptr exception getting Mtu

## 1.11.3
* dart: writeWithoutResponse should wait for completion, to prevent dropped packets

## 1.11.2
* Android: remove shouldClearGattCache connect option. It should be discouraged, and therefore called manually (added in ~1.6.0)

## 1.11.1
* Dart: add back servicesList, but with simpler api

## 1.11.0
* Dart: rename connectedDevices -> connectedSystemDevices
* Dart: remove servicesList (introduced in 1.10.6)
* Dart: remove includeConnectedSystemDevices scan setting, it was too complicated 

## 1.10.10
* android: fix platform exception when scanning with includeConnectedSystemDevices (Regression in 1.10.6)
* dart: fix characteristic write crashed for negative values (Regression in 1.7.0)
* dart: fix connectionState should only be concerned with *our apps* connectionState

## 1.10.9
* android: turnOn() and turnOff() could timeout if already on or already off

## 1.10.8
* android: fix requestMtu (regression in 1.10.6)

## 1.10.7
* dart: disconnect will wait for disconnect to complete

## 1.10.6
* dart: for convenience, scan results now also include connected devices see: includeConnectedDevice
* dart: add connectionState to ScanResult
* dart: add BluetoothDevice.servicesList for convenience, which calls discoverServices automatically.
* dart: rename BluetoothDevice.services -> BluetoothDevice.servicesStream

## 1.10.5
* iOS: fix API MISUSE: Cancelling connection for unused peripheral.
* iOS: remove unecessary search of already connected devices during connection

## 1.10.4
* iOS: add remoteId to error strings when connection fails, etc

## 1.10.3
* android: handle scan failure.
* dart: add verbose log level and remove unused log levels

## 1.10.2
* Dart: fix setLogLevel recursion (Regression in 1.10.0)
* iOS: use NSError instread of obj-c exceptions to avoid uncaught exceptions

## 1.10.1
* example: add error handling to descriptor read & write

## 1.10.0
This release is focused on improving error handling and reliability.
There are 2 small breaking changes. See below.
* **BREAKING CHANGE:** dart: turnOn() & turnOff() now wait for completion, return void instead of bool, and can throw
* **BREAKING CHANGE:** dart: use static functions for FlutterBluePlus instead of FlutterBluePlus.instance. Multiple instances is not supported by any platform.
* readme: add error handling section
* iOS: handle missing bluetooth adapter gracefully
* iOS: getAdapterState && getConnectionState are more robust
* android: log method call in debug, and more consistent log messages
* example: show nicer looking errors
* example: prefer try/catch over catchError as dart debugger doesn't work with catchError as well

## 1.9.5
* iOS: fix serviceUUIDs always null in scan results (regression in 1.7.0)
* example: fix snackbar complaining about invalid contexts

## 1.9.4
* iOS: fix characteristic read not working. (regression in 1.9.0)
* dart: handle device.readRssi failure in rssiStream gracefully

## 1.9.3
* iOS: fix setNotify returning error even though it succeeded (regression in 1.9.0)
* dart: Characteristic.isNotifying was not working (regression in 1.9.0)
* dart: add back uuid convenience variable for BluetoothDescriptor (deprecated in 1.8.6)
* example: only show READ/WRITE/SUBSCRIBE buttons if the characteristic supports it
* example: add error handling

## 1.9.2
* dart: readRssi: fix ArgumentError (Invalid argument: Instance of 'DeviceIdentifier') (Regression 1.9.0)

## 1.9.1
* dart: fix crash in scanning due to assuming uuid is Guid format when it might not (Regression 1.9.0)
* dart: BluetoothCharacteristic.onValueReceived should only stream successful reads (Bug in 1.9.0)
* dart: add convenience accessors for BluetoothService.uuid and BluetoothCharacteristic.uuid as (deprecated in 1.8.6)
* example: add macos support


## 1.9.0

This release marks the end of major work to improve reliability and
simplicity of the FlutterBluePlus codebase. Please submit bug reports.

* **ANDROID ONLY BREAKING CHANGE:** When `read()` is called `onValueChangedStream` is pushed to as well. This change was made to make both platforms behave the same way. It is an unavoidable limitation of iOS. See: https://github.com/boskokg/flutter_blue_plus/issues/419

* Adroid/iOS: fix mtu check minus 3 issue (reggression in 1.8.3)
* deprecated: BluetoothCharacteristic.value -> lastValueStream
* deprecated: BluetoothDescriptor.value -> lastValueStream
* deprecated: BluetoothCharacteristic.onValueChangedStream -> onValueReceived
* deprecated: BluetoothDescriptor.onValueChangedStream -> onValueReceived
* dart: fix deprecated BluetoothCharacteristic.state variable not working (bug introduced 1.8.6)
* dart: fix deprecated FlutterBluePlus.state variable not working (bug introduced 1.8.6)
* internal: refactor adapterState to use methodChannel
* internal: refactor various 'bm' message schemas to use simpler characteristic structure
* internal: refactor BmSetNotificationResponse removed. It is simpler to reuse BmWriteDescriptorResponse
* internal: refactor move secondaryServiceUuid code its own getServicePair() function 
* internal: refactor android MessageMaker to be a bit more legible

## 1.8.8
* android & iOS: fix connectionState not being updated (regression in 1.8.6)
* android: fix "adapterState" to "getAdapterState"

## 1.8.7
* dart: add 15 seconds default timeout for ble communication  

## 1.8.6
* dart: rename BluetoothDevice.id -> remoteId
* dart: rename uuid -> characteristicUuid / serviceUuid / descriptorUuid
* dart: rename FlutterBluePlus.name -> adapterName
* dart: rename BluetoothDevice.name -> localName
* dart: rename FlutterBluePlus.state -> adapterState 
* dart: rename BluetoothDevice.state -> connectionState
* iOS: add support for autoReconnect (iOS 17 only)

## 1.8.5
* iOS: check for nil peripheral. (regression in 1.8.3)
* android: clean up gatt servers onDetachedFromEngine

## 1.8.4
* android: make connectivity checks more robust

## 1.8.3
* android: writeCharacteristic: return error if longer than mtu
* android: add device connection checks
* iOS: add mtu size checks
* iOS: add device connection checks
* iOS: refactor: unify try catch blocks

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
* android: fix BluetoothAdapterState not being updated
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
