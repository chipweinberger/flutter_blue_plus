## 1.14.11
* **[Deprecate]** dart: isDiscoveringServices & servicesStream. They can be easily implemented yourself

## 1.14.10
* **[Fix]** iOS: scan results with empty manufacturer data was not parsed

## 1.14.9
* **[Fix]** iOS: disconnect reason code & string are mixed up

## 1.14.8
* **[Feature]** Dart: add device.disconnectReason
* **[Improve]** Dart: breaking change: rename bondState() -> bondState
* **[Fix]** Dart: calling connect or disconnect multiple times should not re-push to connectionState stream (regression in 1.14.0)
* **[Fix]** Android: calling connect or disconnect multiple times could fail(regression in 1.14.7)
* **[Fix]** Android: security exception on startScan for some phones (regression in 1.13.4)
* **[Fix]** Dart: various streams could push values out of order 

## 1.14.7
 **[Fix]** Android: connected & disconnected states not received (regression in 1.14.4)

## 1.14.6
 **[Fix]** iOS: disconnect would timeout if already disconnected (regression 1.14.0)

## 1.14.5
* **[improve]** Dart: adapterState, bondState, mtu, connectiontate could miss changes due to race conditions

## 1.14.4
* **[improve]** Dart: deprecate `disconnecting` & `connecting` states, they're not actually streamed by Android or iOS
* **[improve]** Dart: increase default connection timeout 15 -> 35 seconds to slightly exceed android & iOS defaults
* **[improve]** Example: unsubscribe snackbar showed 'Subscribe: Success' incorrectly
* **[improve]** Example: add snackbar color blue & red for success & fail
* **[improve]** Example: add spinner while connecting or disconnecting
* **[improve]** Example: do not continually call connectedSystemDevice & RSSI

## 1.14.3
* **[Fix]** Example: was using deprecated variable name

## 1.14.2
* **[improve]** Dart: knownServices should be fully cleared on disconnection
* **[improve]** Dart: error handling: return more descriptive timeout exceptions

## 1.14.1
* **[improve]** Dart: each FlutterBluePlusException should have unique code for handling

## 1.14.0
* **[feature]** Android:  expose BluetoothDevice.bondState
* **[remove]** changes regarding bond state made in 1.13.0 in favor of exposing bondState
* **[refactor]** BluetoothDevice & Android bond handling to improve reliablility & error handling.
* **[fix]** Dart: BluetoothDevice: connect & disconnect and others could incorrectly timeout (unlikely race conditions) 
* **[fix]** Dart: BluetoothDevice: getBondState, getMtu, getConnectionState could skip values (unlikely race conditions) 
* **[fix]** Dart: clear servicesList after disconnection. Android requires you call discoverServices again
* **[fix]** Example:  Subscribe button was not updating
* **[improve]** Android: prefer result.error over exceptions
* **[improve]** Example: show snackbars on success as well

## 1.13.4
* **[fix]** Android: discoverServices never returns (regression in 1.13.0)
* **[fix]** Android: turnOn & turnOff must check for permissions
* **[fix]** Android: startScan should not required BLUETOOTH_CONNECT permission

## 1.13.3
* **[fix]** Dart: be extra careful to only call connect & disconnect when necessary (regression in 1.13.0)

## 1.13.2
* **[fix]** Dart: connect should be no-op if already connected (Regression in 1.13.1)
* **[improve]** Dart: BluetoothDevice: use mutexes to prevent multiple in flight requests

## 1.13.1
* **[fix]** Android/iOS:  on connection failure, return right away
* **[improve]** Android/iOS: on connection failure, return error code and error string

## 1.13.0
This release focuses on improving bonding support.
* **[fix]** Android: discoverServices & others can fail if currently in the process of bonding
* **[improve]** Android: createBond: check for success and throw exception on failure
* **[improve]** Android: removeBond: return Future(void) instead of Future(Bool), and throw exception on failure

## 1.12.14
* **[fix]** Android: min sdk is currently 21, not 19
* **[fix]** Android: getOrDefault not available in AndroidSdkLevel < 24
* **[improve]** Android: log: BOND changes
* **[rename]** Android:  pair -> createBond

## 1.12.13
* **[fix]** iOS: FlutterBluePlus.isAvailable 'int' is not a subtype of type 'FutureOr<bool>' (regressed in 1.12.10)

## 1.12.12
* **[fix]** Android: null ptr deref during ScanResult connectionState (regressed in 1.10.6)
^^^ connectionState was added to scanResults last week. It was not a good idea, and is now fully removed.

## 1.12.11
* **[fix]** Android: potential null dereference if the platform does not have bluetooth
* **[fix]** Android: close all connections when bluetooth is turned off (DeadObjectException)

## 1.12.10
* **[fix]** iOS: isAvailable returns false the first time, incorrectly
* **[fix]** iOS: descriptors, must handle NSData, NSString, & NSNumber correctly
* **[improve]** Android: turnOff is deprecated in Android

## 1.12.9
* **[fix]** Dart: servicesStream: 'bad state: Stream has already been listened to'
* **[fix]** Dart: remove unecessary print('withoutResponse ')
* **[fix]** Android: add blank AndroidManifest.xml to fix build errors in older flutter
* **[fix]** Android/iOS: infinite recursion when included services includes itself
* **[fix]** iOS: FlutterBluePlus.isOn returns 'no' first time even though it is on
* **[improve]** Dart: mutex should make sure writes happen in the same order as called
* **[improve]** Dart: setLogLevel color now optional

## 1.12.8
* **[fix]** Android: null ptr in setPreferredPhy & setConnectionPriority (regression in 1.7.0)

## 1.12.7
* **[fix]** iOS: mtu returned on iOS was 3 too small
* **[improve]** Dart: simplify mutexes. improves throughput for chrs that support write & writeWithoutResponse

## 1.12.6
* **[improve]** Dart: verbose logging: brown == data from platform

## 1.12.5
* **[improve]** Dart: add more logging when in verbose mode, with color

## 1.12.4
* **[fix]** Android:  build error typo (Regression in 1.12.3)

## 1.12.3
* **[fix]** Android: mConnectionState & mMtu not cleared when onDetachedFromEngine (regression in 1.10.10)

## 1.12.2
* **[fix]** Example:  Android: add back INTERNET permission for debug and profile modes. needed for debugging
* **[improve]** Android: create BluetoothManager during onMethodCall, as opposed to app startup

## 1.12.1
* **[improve]** Android: simplify build.grade to not set specific gradle version. it is uneeded

## 1.12.0
* **[improve]** Android: remove permissions from plugin. It is easier for user to specify everything
* **[fix]** Dart: scan could be initiated twice causing bad state
* **[fix]** Dart: read & write mutexs must always come from the MutexFactory to properly prevent race conditions

## 1.11.8
* **[fix]** Android/iOS:  setLogLevel, getAdapterState, getAdapterName returning error when adapter not available

## 1.11.7
* **[fix]** Dart: ensure only 1 mutex per characteristic to prevent race issues and dropped packets
* **[perf]** Dart:  writeWithoutResponse should use at least 1 mutex per remoteId, to improve throughput
* **[improve]** Example: word wrapping on smaller screens

## 1.11.6
* **[fix]** Dart: writeWithoutResponse should have its own mutex to prevent dropped packets

## 1.11.5
* **[fix]** iOS: crash discoverServices() crash after bluetooth adapter is toggled on/off (regressed sometime after 1.4.0)
* **[improve]** Example: dismiss DeviceScreen when bluetooth adapter is turned off
* **[improve]** Android/iOS:  log adapterState and connectionState as strings

## 1.11.4
* **[fix]** Android: null ptr exception getting Mtu

## 1.11.3
* **[fix]** Dart: writeWithoutResponse should wait for completion, to prevent dropped packets

## 1.11.2
* **[improve]** Android: remove shouldClearGattCache connect option. It should be discouraged (called manually) (added in ~1.6.0)

## 1.11.1
* **[improve]** Dart: add back servicesList, but with simpler api

## 1.11.0
* **[rename]** Dart:  connectedDevices -> connectedSystemDevices
* **[remove]** Dart:  servicesList (introduced in 1.10.6)
* **[remove]** Dart:  includeConnectedSystemDevices scan setting, it was too complicated 

## 1.10.10
* **[fix]** Android: platform exception when scanning with includeConnectedSystemDevices (Regression in 1.10.6)
* **[fix]** Dart: characteristic write crashed for negative values (Regression in 1.7.0)
* **[fix]** Dart: connectionState should only be concerned with *our apps* connectionState

## 1.10.9
* **[fix]** Android: turnOn() and turnOff() could timeout if already on or already off

## 1.10.8
* **[fix]** Android: requestMtu (regression in 1.10.6)

## 1.10.7
* **[improve]** Dart: disconnect should wait for disconnect to complete

## 1.10.6
* **[improve]** Dart: for convenience, scan results now also include connected devices see: includeConnectedDevice
* **[improve]** Dart: add connectionState to ScanResult
* **[improve]** Dart: add BluetoothDevice.servicesList for convenience, which calls discoverServices automatically.
* **[rename]** Dart:  BluetoothDevice.services -> BluetoothDevice.servicesStream

## 1.10.5
* **[fix]** iOS: API MISUSE: Cancelling connection for unused peripheral.
* **[improve]** iOS: remove unecessary search of already connected devices during connection

## 1.10.4
* **[improve]** iOS: add remoteId to error strings when connection fails, etc

## 1.10.3
* **[improve]** Android: handle scan failure.
* **[improve]** Dart: add verbose log level and remove unused log levels

## 1.10.2
* **[fix]** Dart: setLogLevel recursion (Regression in 1.10.0)
* **[improve]** iOS: use NSError instread of obj-c exceptions to avoid uncaught exceptions

## 1.10.1
* **[improve]** Example: add error handling to descriptor read & write

## 1.10.0
This release is focused on improving error handling and reliability.
There are 2 small breaking changes. See below.
* **BREAKING CHANGE:** Dart: turnOn() & turnOff() now wait for completion, return void instead of bool, and can throw
* **BREAKING CHANGE:** Dart: use static functions for FlutterBluePlus instead of FlutterBluePlus.instance. Multiple instances is not supported by any platform.
* **[improve]** readme: add error handling section
* **[improve]** iOS: handle missing bluetooth adapter gracefully
* **[improve]** iOS: getAdapterState && getConnectionState are more robust
* **[improve]** Android: log method call in debug, and more consistent log messages
* **[improve]** Example: show nicer looking errors
* **[improve]** Example: prefer try/catch over catchError as dart debugger doesn't work with catchError as well

## 1.9.5
* **[fix]** iOS: serviceUUIDs always null in scan results (regression in 1.7.0)
* **[fix]** Example:  snackbar complaining about invalid contexts

## 1.9.4
* **[fix]** iOS: characteristic read not working. (regression in 1.9.0)
* **[improve]** Dart: handle device.readRssi failure in rssiStream gracefully

## 1.9.3
* **[fix]** iOS: setNotify returning error even though it succeeded (regression in 1.9.0)
* **[fix]** Dart: Characteristic.isNotifying was not working (regression in 1.9.0)
* **[improve]** Dart: add back uuid convenience variable for BluetoothDescriptor (deprecated in 1.8.6)
* **[improve]** Example: only show READ/WRITE/SUBSCRIBE buttons if the characteristic supports it
* **[improve]** Example: add error handling

## 1.9.2
* **[fix]** Dart: readRssi: Invalid argument: Instance of 'DeviceIdentifier' (Regression 1.9.0)

## 1.9.1
* **[fix]** Dart: crash in scanning due to assuming uuid is Guid format when it might not (Regression 1.9.0)
* **[improve]** Dart: BluetoothCharacteristic.onValueReceived should only stream successful reads (Bug in 1.9.0)
* **[improve]** Dart: add convenience accessors for BluetoothService.uuid and BluetoothCharacteristic.uuid as (deprecated in 1.8.6)
* **[improve]** Example: add macos support


## 1.9.0

This release marks the end of major work to improve reliability and
simplicity of the FlutterBluePlus codebase. Please submit bug reports.

* **ANDROID ONLY BREAKING CHANGE:** When `read()` is called `onValueChangedStream` is pushed to as well. This change was made to make both platforms behave the same way. It is an unavoidable limitation of iOS. See: https://github.com/boskokg/flutter_blue_plus/issues/419

* **[fix]** Android/iOS: mtu check minus 3 issue (reggression in 1.8.3)
* **[fix]** Dart: BluetoothCharacteristic.state variable not working (bug introduced 1.8.6)
* **[fix]** Dart: FlutterBluePlus.state variable not working (bug introduced 1.8.6)
* **[improve]** Dart: deprecate: BluetoothCharacteristic.value -> lastValueStream
* **[improve]** Dart: deprecate: BluetoothDescriptor.value -> lastValueStream
* **[improve]** Dart: deprecate: BluetoothCharacteristic.onValueChangedStream -> onValueReceived
* **[improve]** Dart: deprecate: BluetoothDescriptor.onValueChangedStream -> onValueReceived
* **[refactor]** Dart: adapterState to use methodChannel
* **[refactor]** Dart: various 'bm' message schemas to use simpler characteristic structure
* **[refactor]** Dart: BmSetNotificationResponse removed. It is simpler to reuse BmWriteDescriptorResponse
* **[refactor]** Android: move secondaryServiceUuid code its own getServicePair() function 
* **[refactor]** Android: android MessageMaker to be a bit more legible

## 1.8.8
* **[fix]** Android/iOS:connectionState not being updated (regression in 1.8.6)
* **[fix]** Android: "adapterState" to "getAdapterState"

## 1.8.7
* **[improve]** Dart: add 15 seconds default timeout for ble communication  

## 1.8.6
* **[rename]** Dart: BluetoothDevice.id -> remoteId
* **[rename]** Dart: uuid -> characteristicUuid / serviceUuid / descriptorUuid
* **[rename]** Dart: FlutterBluePlus.name -> adapterName
* **[rename]** Dart: BluetoothDevice.name -> localName
* **[rename]** Dart: FlutterBluePlus.state -> adapterState 
* **[rename]** Dart: BluetoothDevice.state -> connectionState
* **[improve]** iOS: add support for autoReconnect (iOS 17 only)

## 1.8.5
* **[fix]** iOS: check for nil peripheral. (regression in 1.8.3)
* **[fix]** Android: clean up gatt servers onDetachedFromEngine

## 1.8.4
* **[improve]** Android: make connectivity checks more robust

## 1.8.3
* **[improve]** Android: writeCharacteristic: return error if longer than mtu
* **[improve]** Android: add device connection checks
* **[improve]** iOS: add mtu size checks
* **[improve]** iOS: add device connection checks
* **[refactor]** iOS: unify try catch blocks

## 1.8.2
* **[improve]** Android: support sdk 33 for writeCharacteristic and writeDescriptor
* **[improve]** Android: calling connect() on already connected device is now considered success
* **[improve]** Android: return more specific error for locateGatt issue
* **[improve]** Android: shouldClearGattCache is now called after connection, not before

## 1.8.1
* **[fix]** Android: characteristic properties check was incorrect (regression in 1.7.8)

## 1.8.0
* **[improve]** android/ios: handle errors for charactersticRead
* **[improve]** android/ios: handle errors for readDescriptor
* **[improve]** android/ios: handle errors for discoverServices
* **[improve]** android/ios: handle errors for mtu
* **[improve]** android/ios: handle errors for readRssi
* **[improve]** android/ios: pass error string for setNotifyValue
* **[improve]** android/ios: pass error string for charactersticWrite
* **[improve]** android/ios: pass error string for writeDescriptor

## 1.7.8
* **[improve]** Android: add more useful errors for read and write characterist errors

## 1.7.7
* **[fix]** Dart: scanning: Bad state: Cannot add event after closing.
* **[improve]** Android: set autoConnect to false by default
* **[improve]** Example: remove pubspec.lock so users default to latest version

## 1.7.6
* **[fix]** Dart: BmBluetoothService.is_primary was not set (regression in 1.7.0)
* **[fix]** Android: BmAdvertisementData.connectable was not set (regression in 1.7.0)
* **[fix]** Android: success was not set for writeCharacteristic, setNotification, writeDescriptor  (regression in 1.7.0) 
* **[improve]** Android: update to gradle 8
* **[improve]** Android: dont request ACCESS_FINE_LOCATION by default (Android 12+)

## 1.7.5
* **[fix]** Android: BluetoothAdapterState not being updated
* **[improve]** Example: fix deprecations
* **[improve]** Dart: remove analysis_options.yaml

## 1.7.4
* **[fix]** Android: Android 13 access fine location error

## 1.7.3
* **[fix]** Android: exception thrown when descriptor.write is called (regression in 1.7.0)

## 1.7.2
* **[fix]** Android: exception thrown when characteristic.write is called (regression in 1.7.0)
* **[fix]** Android: bmCharacteristicProperties was not being set correctly (regression in 1.7.0)

## 1.7.1
* **[fix]** iOS: when connecting, exception is thrown (regression in 1.7.0)

## 1.7.0
* **[refactor]** removed protobuf dependency 
* **[fix]** Android: turnOn and turnOff not working (regression in 1.6.1)
* **[fix]** Dart: guid exception with serviceUUID is empty
* **[improve]** Android: compileSdkVersion 31 -> 33
* **[improve]** Android: increase minSdkVersion 19 -> 21 to remove lollipop checks
* **[improve]** Android: FineLocation permission is now optional. See startScan
* **[improve]** iOS: allow connecting without scanning if you save and reuse the remote_id

## 1.6.1
* **[fix]** Android: compile error (regression in 1.6.0)
* **[improve]** Android: significantly clean up all code

## 1.6.0
* **[fix]** Dart: close BufferStream listen on stopScan
* **[improve]** Dart: don't repropogate Mutex error
* **[improve]** Dart: better stacktrace on error for Characteristic Read/Write
* **[improve]** MacOS: use symbolic links to iOS version, to keep internal code in sync
* **[improve]** Android: reformat code


## 1.5.2
* **[fix]** Android: setNotification was throwing exception (regression)

## 1.5.1
* **[fix]** Dart: issue where startScan can hang forever (regression)
* **[fix]** Dart: some scanResults could be missed due to race condition (theoretically)
* **[improve]** Dart: dont export util classes & functions. they've been made library-private.
* **[improve]** iOS: prepend all iOS logs with '[FBP-iOS]' prefix
* **[improve]** iOS: log errors on failure
* **[improve]** iOS: logs now adhere to logLevel

## 1.5.0
* **[fix]** Dart: writeCharacteristic (and other similar functions) exception could be missed
* **[fix]** Dart: setNotifyValue should check for success and throw error on failure
* **[fix]** Dart: race conditions in connect(), disconnect(), readRssi(), writeCharacteristic(), readCharacteristic()
* **[fix]** iOS: Bluetooth adapter being stuck in unknown state
* **[fix]** iOS: dropping packets during bulk write without response
* **[fix]** Example: android permissions
* **[improve]** Dart: add isScanningNow variable
* **[improve]** add support for macOS
* **[improve]** Android: replace deprecated bluetooth enable with 'Enable-Intent'
* **[improve]** Android: Removed maxSdkVersion=30 in manifest
* **[improve]** Android: add function: setPreferredPh
* **[improve]** Android: add function: removeBond
* **[improve]** Android: add function: requestConnectionPriority 
* **[improve]** Android: allow for simultaneous MAC and ServiceUuid ScanFilters
* **[improve]** Android: request location permission on Android 12+ when scanning (needed on some phones)
* **[improve]** iOS: Use CBCentralManagerOptionShowPowerAlertKey for better UI popups
* **[improve]** Dart: Removed RxDart and other dependencies


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
