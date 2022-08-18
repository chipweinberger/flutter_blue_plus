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
