## 1.28.13
* **[Fix]** `isNotifying`` was not set to false on disconnection (regression 1.28.9)

## 1.28.12
* **[Fix]** crash if rssi was zero on android (regression 1.27.2)

## 1.28.11
* **[Rename]** `giud.uuid` -> `guid.str` & `guid.uuid128` -> `guid.str128`
* **[Add]** connect: `timeout` argument is now optional. infinite timeout is possible on iOS

## 1.28.10
* **[Perf]** android: filter out devices without names if `scan.withKeywords` is set
* **[Fix]** calling scan multiple times would breifly push `isScanning=false`
* **[Improve]** servicesList: return empty instead of null

## 1.28.9
* **[Improve]** to make FBP easier to use, never clear `knownServices`, `lastChrs`, or `lastDescs`

## 1.28.8
* **[Fix]** android: GUID issues related to scanning

## 1.28.7
* **[Fix]** android: GUID starting with 0000 were misinterpretted (regression 1.28.5)

## 1.28.6
* **[Improve]** simplify api: clear `knownServices` & `lastValues` on reconnection instead of disconnection
* **[Improve]** dont clear `bondState` cache when device is disconnected. unecessary.

## 1.28.5
* **[Internal]** use short UUID where possible

## 1.28.4
* **[Fix]** guid: uuid was returning 0000 for 16 bit uuid
* **[Guid]** guid.uuid should return lowercase

## 1.28.3
* **[Improve]** guid: add uuid short representation

## 1.28.2
* **[Improve]** add length checks to `MsdFilter` & `ServiceDataFilter`
* **[Improve]** guid: more consistent handling of 16, 32, vs 128 bit guids

## 1.28.1
* **[Feature]** scanning: add `serviceData` filter
* **[Feature]** scanning: add `msd` filter

## 1.28.0
* **[Breaking Change]** `guid.toString()` now returns 16-bit short uuid when possible
* **[Breaking Change]** return GUIDs for `advertisingData.serviceUuids` & `advertisingData.serviceData` instead of String
* **[Guid]** add support for 16-bit and 32-bit uuids
* **[Fix]** android: advertised UUIDs were 128-bit instead of the actual length

## 1.27.6
* **[Improve]** add more checks for bluetooth being off

## 1.27.5
* **[Fix]** android: typo compile error

## 1.27.4
* **[Fix]** accidentally changed advertisementData.localName to nullable

## 1.27.3
* **[Perf]** scanning: add `continuousDivisor` option to reduce platform channel & main-thread usage

## 1.27.2
* **[Perf]** scanning: only send advertisment keys over platform channel when they exist
* **[Rename]** `advertisementData.localName` -> `advertisementData.advName`

## 1.27.1
* **[Add]** android: add forceIndications option to setNotifyValue

## 1.27.0
This release improves the default scanning behavior.
* **[Breaking Change]** scanning: make `continousUpdates` false by default - it is not typically needed & hurts perf. If your app uses `startScan.removeIfGone`, or your app continually checks the value of `scanResult.timestamp` or `scanResult.rssi`, then you will need to explicitly set `continousUpdates` to true.

## 1.26.6
* **[Fix]** android: scanning would not work if `continuousUpdates` was false 

## 1.26.5
* **[Add]** scanning: `withRemoteIds`, `withNames`, `withKeywords` filters
* **[Add]** scanning: expose `androidScanMode` again
* **[Add]** scanning: `continuousUpdates` option replaces former `allowDuplicates` option

## 1.26.4
* **[Add]** cancelWhenDisconnected: option to cancel on *next* disconnection

## 1.26.3
* **[Add]** `events.onReadRssi`
* **[Add]** `events.onCharacteristicWritten`
* **[Add]** `events.onDescriptorWritten`

## 1.26.2
* **[Fix]** android: close gatt after canceling an in-progress connnection
* **[Improve]** android: wait until bonding completes for better reliability

## 1.26.1
* **[Feature]** add support for canceling an in progress connection using `device.disconnect`
* **[Fix]** connection timeouts did not actually cancel the connection attempt
* **[Fix]** android: update isScanning when onDetachedFromEngine is called

## 1.22.1 to 1.26.0
These releases changed multiple things but then changed them back. For brevity, here are the actual changes:
* **[Behavior Change]** android: listen to Services Changed characteristic to match iOS behavior
* **[Fix]** android: stop scanning when detached from engine
* **[Add]** `device.advName` returns the name found during scanning
* **[Add]** `device.mtuNow` synchronously gets the current mtu value
* **[Add]** `events.onDiscoveredServices` stream
* **[Add]** events api: add accessors for errors
* **[Rename]** events api: most functions & classes were renamed for consistency
* **[Rename]** `device.onServicesChanged` -> `device.onServicesReset`
* **[Remove]** `device.onNameChanged`, in favor of only exposing `events.onNameChanged`

## 1.22.0
This release makes `mtu` behavior more similar on android & iOS.
* **[Breaking Change]** android: request mtu of 512 by default.

## 1.21.0
This release greatly increases reliability on android & ios.
* **[Improve]** only allow a single ble operation at a time.

## 1.20.8
* **[Fix]** iOS: connect: return error for invalid remoteId
* **[Improve]** iOS: log warning if CCCD is not found, like we do on android

## 1.20.7
* **[Fix]**  events API was not accessible through `FlutterBluePlus.events`

## 1.20.6
* **[Add]** `FlutterBluePlus.events.mtu`

## 1.20.5
* **[Add]** `FlutterBluePlus.events.onNameChanged`
* **[Add]** `FlutterBluePlus.events.onServicesChanged`

## 1.20.4
* **[Rename]** `FlutterBluePlus.connectionEvents` -> `FlutterBluePlus.events.connectionState`
* **[Add]** `FlutterBluePlus.events.onCharacteristicReceived`
* **[Add]** `FlutterBluePlus.events.onDescriptorRead`
* **[Add]** `FlutterBluePlus.events.bondState`

## 1.20.3
* **[Add]** `FlutterBluePlus.connectionEvents`, a stream of all connection & disconnected events
* **[Add]** `FlutterBluePlus.connectedDevices`, to get currently connected devices
* **[Add]** `device.isConnected`, convenience accessor

## 1.20.2
* **[Fix]** cannot retrieve platform name from bondedDevices
* **[Fix]** stopScan: should clear results *after* platform method has been called

## 1.20.1
* **[Remove]** `FlutterBluePlus.connectedDevices`. This API needs more thought.

## 1.20.0
This release renames `connectedSystemDevices`.
* **[Rename]** `connectedSystemDevices` -> `systemDevices`, because they must be re-connected by *your* app

## 1.19.2
* **[Add]** new method `device.cancelWhenDisconnected(subscription)`

## 1.19.1
* **[Add]** new method `FlutterBluePlus.connectedDevices`

## 1.19.0
This release reverts most of the breaking changes made in 1.18.0.
* **[Revert]** most breaking changes made to bondState stream in 1.18.0
* **[Unchanged]** bond lost/failed are replaced by prevBondState
* **[Add]** method device.prevBondState
* **[Fix]** android: adapterName must request permission

## 1.18.3
* **[Refactor]** bondState: finish refactor started in 1.18.0

## 1.18.2
* **[Fix]** bondState: must *explicitly* check for null prevState (regression 1.18.0)

## 1.18.1
* **[Fix]** bondState: handle null prevState (regression 1.18.0)

## 1.18.0
This release improves `bondState` stream
* **[Breaking Change]** bondState: directly expose prevBond instead of lost/failed flags

## 1.17.6
* **[Fix]** scanResults: clear scan results on stopScan (regression 1.16.8)

## 1.17.5
* **[Example]** accidentally left performanceOverlay enabled (regression 1.17.4)

## 1.17.4
* **[Example]** remove PermissionHandler dependency. It is no longer needed.
* **[Example]** ScanScreen: use ListView instead of SingleChildScrollView

## 1.17.3
* **[Fix]** android: turnOn throws exception if permission denied

## 1.17.2
This bug affected mtu, lastValueStream, adapterState, & bondState.
* **[Fix]** newStreamWithInitialValue was not emitting initial value. (regression 1.16.6)

## 1.17.1
* **[Fix]** timeout when connect is called when adapter is off
* **[Fix]** android: was not calling disconnect callback when adapter turned off
* **[Fix]** android: connectable flag was not working (regression 1.7.0)
* **[Improve]** do not re-get adapterState when we already have it

## 1.17.0
This release improves `lastValue` & `lastValueStream`.
* **[Breaking Change/Fix]** should update `lastValue` & `lastValueStream` when `write()` is called
* **[Feature]** Android: support `onNameChanged` & `onServicesChanged` characteristics
* **[Fix]** iOS: `discoverServices` crash [_NSInlineData intValue]: unrecognized selector sent to instance
* **[Fix]** iOS: `descriptor.write()` would timeout or not work (regression somewhere around ~1.7.0)
* **[Fix]** `isNotifying` was not updated by `setNotifyValue(false)` (regression somewhere around ~1.9.0)

## 1.16.12
* **[Fix]** Android: onValueReceived was not working on Android 12 & lower (regression 1.16.3)

## 1.16.11
* **[Fix]** Android: onCharacteristicReceived not being called (regression 1.16.3)

## 1.16.10
* **[Fix]** BluetoothDevice: don't wait for timeout if device becomes disconnected

## 1.16.9
* **[Example]** cleaned up Characteristic tile code

## 1.16.8
* **[Fix]** `scanResults` & `isScanning` streams were not re-emitting their current value on listen (regression 1.5.0)
* **[Example]** discoverServices: stay on screen after diconnection
* **[Example]** simplified `connectingOrDisconnecting` code
* **[Example]** organize into 'screens' and 'widgets' folders

## 1.16.7
* **[Rename]** `isAvailable` -> `isSupported`

## 1.16.6
* **[Example]** Refactor: hugely refactored to use stateful widgets
* **[Example]** Fix: stream already listened to error
* **[Improve]** `connectionState` & `mtu`: use broadcast stream

## 1.16.5
* **[Fix]** iOS: iOS Unhandled Exception: type 'int' is not a subtype of type 'bool' (regression 1.16.3)
* **[Improve]** android: prepend logs with '[FBP]'
* **[Java]** rename `com.boskokg.flutter_blue_plus` -> `com.lib.flutter_blue_plus` to be more generic

## 1.16.4
* **[Fix]** `setLogLevel` would be ignored due to being called twice
* **[Improve]** android: use log level consistently
* **[Improve]** iOS: use log level macro

## 1.16.3
* **[Fix]** Android: `setNotify` would timeout if CCCD descriptor does not exist
* **[Android]** fix deprecations
* **[Improve]** removeIfGone: only push to scanResults when list changes

## 1.16.2
* **[Fix]** platform check in `onNameChanged` & `onServicesChanged` was incorrect

## 1.16.1
* **[Add]** iOS: add support for `onServicesChanged` & `onNameChanged`

## 1.16.0
This release simplifies BluetoothDevice construction.
* **[Breaking Change]** remove `BluetoothDevice.type` & `BluetoothDevice.localName` from constructor for simplicity
* **[Breaking Change]** remove `servicesStream` & `isDiscoveringServices` deprecated functions
* **[Rename]** `localName` -> `platformName` to reflect platform specific behavior
* **[Fix]** `setNotifyValue` must take `descWrite` mutex
* **[Fix]** `localName` was broken when using `connectedSystemDevices` (regression 1.15.10)
* **[Add]** Android: getPhySupport

## 1.15.10
* **[Fix]** iOS: `localName` does not match Android
* **[Fix]** flutterHotRestart: error was thrown if device did not have bluetooth adapter

## 1.15.9
* **[Fix]** iOS: adapter turnOff: edge case when adapter is turned off while scanning
* **[Fix]** iOS: adapter turnOff: disconnect handlers not firing when adapter turned off
* **[Fix]** iOS: adapter turnOff: API MISUSE when adapter is turned off
* **[Cleanup]** Hot Restart: use separate conenctedCount method for clarity

## 1.15.8
* **[Fix]** if any platform exception happens, fbp will deadlock (regression 1.14.20)

## 1.15.7
* **[Fix]** android: turning bluetooth off would not fully disconnect devices (regression 1.14.19)

## 1.15.6
* **[Fix]** iOS: turning bluetooth off would not fully disconnect devices (regression 1.14.19)
* **[Readme]** add v1.15.0 migration guides

## 1.15.5
* **[Fix]** `firstWhereOrNull` conflict (regression in 1.15.0)

## 1.15.4
* **[Fix]** some typos in disconnect exceptions (from 1.15.3)

## 1.15.3
* **[Improve]** prefer dart exceptions over platform exceptions when device is disconnected

## 1.15.2
* **[Fix]** stopScan was not awaiting for invokeMethod

## 1.15.1
* **[Fix]** FlutterBluePlus.scanResults should always return list copy to avoid iteration exceptions

## 1.15.0
## Scanning API Changes

**Overview**:
* **[Refactor]** simplify scanning api
* **[Feature]** add `removeIfGone` option to `startScan`

**Breaking Changes & Improvements:**
- **(simplify)** removed `FlutterBluePlus.scan`. Use `FlutterBluePlus.scartScan(oneByOne: true)` instead.
- **(simplify)** removed `allowDuplicates` option for `scartScan`. It is not supported on android. We always filter duplicates anyway.
- **(simplify)** removed `macAddresses` option for `scartScan`. It was not supported on iOS, and is overall not very useful.
- **(simplify)** `startScan` now returns `Future<void>` instead of `Future<List<ScanResult>>`. It was redundant and confusing.
- **(improvement)** if you `await startScan` it will complete once the scan starts, instead of when it ends
- **(improvement)** if you call `startScan` twice, it will cancel the previous scan, instead of throwing an exception

## 1.14.24
* **[Fix]** Android: setNotifyValue: (code: 5) notifications were not updated
* **[Fix]** Hot Restart: stop scanning when hot restarting

## 1.14.23
* **[Fix]** setNotifyValue & others must be cleared after disconnection (regression in 1.14.21)

## 1.14.22
* **[Fix]** Android: Hot Restart: could get stuck in infinite loop (regression in 1.14.19)

## 1.14.21
* **[Refactor]** dart: store lastValue at global level so Desc & Chr classes are fully immutable

## 1.14.20
* **[Fix]** iOS: Hot Restart: could get stuck in infinite loop (regression in 1.14.19)

## 1.14.19
* **[Fix]** Hot Restart: close all connections when dart vm is restarted

## 1.14.18
* **[Fix]** Android: crash uuid128 null deref (regression in 1.14.17)

## 1.14.17
* **[Fix]** Android: shortUUID: characteristic not found

## 1.14.16
* **[Fix]** macOS: lower required version to 10.11 (equivalent to  iOS 9.0)

## 1.14.15
* **[Rename]** allowSplits -> allowLongWrite

## 1.14.14
* **[Fix]** Android: dataLen longer than allowed (regression in 1.14.13)

## 1.14.13
* **[Fix]** iOS: onMtu was not called
* **[Feature]** iOS & Android: writeCharacteristic: add 'allowLongWrite' option to do longer writes

## 1.14.12
* **[Fix]** Android: autoconnect was not working. regressed sometimes after 1.4.0
* **[Cleanup]** Android: cleanup bmAdvertisementData
* **[Improve]** iOS: check that characteristic supports READ, WRITE, WRITE_NO_RESP properties and throw error otherwise

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
This release improves bonding support.
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
This release improves bonding support.
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
This release simplifies permissions.
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
This release removes recent changes to the API causing issues.
* **[remove]** Dart:  includeConnectedSystemDevices scan setting, it was too complicated 
* **[remove]** Dart:  servicesList (introduced in 1.10.6)
* **[rename]** Dart:  connectedDevices -> connectedSystemDevices

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
This release improves error handling and reliability.
* **[BREAKING CHANGE]** Dart: turnOn() & turnOff() now wait for completion, return void instead of bool, and can throw
* **[BREAKING CHANGE]** Dart: use static functions for FlutterBluePlus instead of FlutterBluePlus.instance. Multiple instances is not supported by any platform.
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

* **[Breaking Change/Fix]** Android: When `read()` is called `onValueChangedStream` is pushed to as well. This change was made to make both platforms behave the same way. It is an unavoidable limitation of iOS. See: https://github.com/boskokg/flutter_blue_plus/issues/419
* **[fix]** Android/iOS: mtu check minus 3 issue (reggression in 1.8.3)
* **[fix]** Dart: BluetoothCharacteristic.state variable not working (bug introduced 1.8.6)
* **[fix]** Dart: FlutterBluePlus.state variable not working (bug introduced 1.8.6)
* **[rename]** BluetoothCharacteristic.value -> lastValueStream
* **[rename]** BluetoothDescriptor.value -> lastValueStream
* **[rename]** BluetoothCharacteristic.onValueChangedStream -> onValueReceived
* **[rename]** BluetoothDescriptor.onValueChangedStream -> onValueReceived
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
This release improves error handling.
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
This release removes Protobuf.
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
This release reformats a bunch of Android code.
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
This release closes many open issues on Github.
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

---

# FORKED FLUTTER_BLUE

---

## 0.12.0

* Supporting Android 12 Bluetooth permissions. #940

## 0.12.0

* Delay Bluetooth permission & turn-on-Bluetooth system popups on iOS #964

## 0.11.0

* The timeout was throwing out of the Future's scope #941
* Expose onValueChangedStream #882
* Android: removed V1Embedding
* Android: removed graddle.properties
* Android: enable background usage
* Android: cannot handle devices that do not set CCCD_ID (2902) includes BLUNO #185 #797
* Android: add method for getting bonded devices #586
* Ios: remove support only for x86_64 simulators
* Ios: Don't initialize CBCentralManager until needed #599

## 0.10.0

* mtuRequest returns the negotiated MTU
* Android: functions to turn on/off bluetooth
* Android: add null check if channel is already teared down
* Android: code small refactoring (fixed AS warnings)
* Android: add null check if channel is already teared down
* Ios: widen protobuf version allowed

## 0.9.0

* Android migrate to mavenCentral.
* Android support build on Macs M1
* Android protobuf-gradle-plugin:0.8.15 -> 0.8.17
* Ios example upgrade to latest flutter 2.5
* deprecated/removed widgets fixed in example

## 0.8.0
* Migrate the plugin to null safety.

## 0.7.3
* Fix Android project template files to be compatible with protobuf-lite.
* Add experimental support for MacOS.

## 0.7.2
* Add `allowDuplicates` option to `startScan`.
* Fix performance issue with GUID initializers.

## 0.7.1+1
* Fix for FlutterBlue constructor when running on emulator.
* Return error when attempting to `discoverServices` while not connected.

## 0.7.1
* Fix incorrect value notification when write is performed.
* Add `toString` to each bluetooth class.
* Various other bug fixes.

## 0.7.0
* Support v2 android embedding.
* Various bug and documentation fixes.

## 0.6.3+1
* Fix compilation issue with iOS.
* Bump protobuf version to 1.0.0.

## 0.6.3
* Update project files for Android and iOS.
* Remove dependency on protoc for iOS.

## 0.6.2
* Add `mtu` and `requestMtu` to BluetoothDevice.

## 0.6.0+4
* Fix duplicate characteristic notifications when connection lost.
* Fix duplicate characteristic notifications when reconnecting.
* Add minimum SDK version of 18 for the plugin.
* Documentation updates.

## 0.6.0
* **Breaking change**. API refactoring with RxDart (see example).
* Log a more detailed warning at build time about the previous AndroidX migration.
* Ensure that all channel calls to the Dart side from the Java side are done on the UI thread.
  This change allows Transactions to work with upcoming Engine restrictions, which require
  channel calls be made on the UI thread. Note this is an Android only change,
  the iOS implementation was not impacted.

## 0.5.0
* **Breaking change**. Migrate from the deprecated original Android Support
  Library to AndroidX. This shouldn't result in any functional changes, but it
  requires any Android apps using this plugin to [also
  migrate](https://developer.android.com/jetpack/androidx/migrate) if they're
  using the original support library.

## 0.4.2+1
* Upgrade Android Gradle plugin to 3.3.0.
* Refresh iOS build files.

## 0.4.2
* Set the verbosity of log messages with `setLogLevel`.
* Updated iOS and Android project files.
* `autoConnect` now configurable for Android.
* Various bug fixes.

## 0.4.1
* Fixed bug where setNotifyValue wasn't properly awaitable.
* Various UI bug fixes to example app.
* Removed unnecessary intl dependencies in example app.

## 0.4.0
* **Breaking change**. Manufacturer Data is now a `Map` of manufacturer ID's.
* Service UUID's, service data, tx power level packets fixed in advertising data.
* Example app updated to show advertising data.
* Various other bug fixes.

## 0.3.4
* Updated to use the latest protobuf (^0.9.0+1).
* Updated other dependencies.

## 0.3.3
* `scan` `withServices` to filter by service UUID's (iOS).
* Error handled when trying to scan with adapter off (Android).

## 0.3.2
* Runtime permissions for Android.
* `scan` `withServices` to filter by service UUID's (Android).
* Scan mode can be specified (Android).
* Now targets the latest android SDK.
* Dart 2 compatibility.

## 0.3.1
* Now allows simultaneous notifications of characteristics.
* Fixed bug on iOS that was returning `discoverServices` too early.

## 0.3.0
* iOS support added.
* Bug fixed in example causing discoverServices to be called multiple times.
* Various other bug fixes.

## 0.2.4
* **Breaking change**. Upgraded to Gradle 4.1 and Android Studio Gradle plugin
  3.0.1. Older Flutter projects need to upgrade their Gradle setup as well in
  order to use this version of the plugin. Instructions can be found
  [here](https://github.com/flutter/flutter/wiki/Updating-Flutter-projects-to-Gradle-4.1-and-Android-Studio-Gradle-plugin-3.0.1).

## 0.2.3
* Bug fixes

## 0.2.2
* **Breaking changes**:
* `startScan` renamed to `scan`.
* `ScanResult` now returns a `BluetoothDevice`.
* `connect` now takes a `BluetoothDevice` and returns Stream<BluetoothDeviceState>.
* Added parameter `timeout` to `connect`.
* Automatic disconnect on deviceConnection.cancel().

## 0.2.1
* **Breaking change**. Removed `stopScan` from API, use `scanSubscription.cancel()` instead.
* Automatically stops scan when `startScan` subscription is canceled (thanks to @brianegan).
* Added `timeout` parameter to `startScan`.
* Updated example app to show new scan functionality.

## 0.2.0

* Added state and onStateChanged for BluetoothDevice.
* Updated example to show new functionality.

## 0.1.1

* Fixed image for pub.dartlang.org.

## 0.1.0

* Characteristic notifications/indications.
* Merged in Guid library, removed from pubspec.yaml.

## 0.0.1 - September 1st, 2017

* Initial Release.
