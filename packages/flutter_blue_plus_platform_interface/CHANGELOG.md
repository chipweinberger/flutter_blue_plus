## 4.0.2
* Added `androidCheckLocationServices` to `BmScanSettings` (#1199)

## 4.0.1
* Remove unused methods from Bluetooth messages

## 4.0.0
* Better guid equals operator (#1169)
* Add on turn on response stream (#1166)
* Don't wait for CCCD write for `setNotifyValue` on web (#1153)
* Fix conversion code for devices with service data and uuids (#1143)
* Correct casting of raw json in `BmScanAdvertisement` (#1142)
* Fix `webOptionalServices` broke scanning on Android
* Use bytes instead of hex for platform communication (#1130)

## 3.0.0
* Add support for web optional services (#1124)
* Add option to provide pairing PIN to `createBond` (#1119)

## 2.0.1
* Add log color

## 2.0.0
* Replace plugin_platform_interface with base keyword
* Return sensible defaults instead of throwing
* Replace void return types with bool return types

## 1.0.0
* Initial release
