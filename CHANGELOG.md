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
