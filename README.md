# Flutter Blue Plus

Please note that this is an unofficial fork of Flutter Blue Plus and is not endorsed by @chipweinberger.

If you find this package useful then please consider leaving a comment on [this](https://github.com/chipweinberger/flutter_blue_plus/pull/971) pull request.

This package is supported on a best efforts basis and may fall behind the upstream repository.

## Getting Started

1. Replace the existing `flutter_blue_plus` dependency with this package.

    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      flutter_blue_plus:
        git:
          url: https://github.com/tnc1997/flutter-blue-plus.git
          path: packages/flutter_blue_plus
          ref: flutter_blue_plus-v1.0.0
    ```

## Compatibility

### FlutterBluePlus API

|                  | Android | iOS | Linux | macOS | Web | Description                                                 |
|------------------|---------|-----|-------|-------|-----|-------------------------------------------------------------|
| setLogLevel      | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Configure plugin log level                                  |
| setOptions       | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Set configurable bluetooth options                          |
| isSupported      | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Checks whether the device supports Bluetooth                |
| turnOn           | ✔️      | ❌   | ✔️    | ❌     | ❌   | Turns on the bluetooth adapter                              |
| turnOff          | ✔️      | ❌   | ✔️    | ❌     | ❌   | Turns off the bluetooth adapter                             |
| adapterStateNow  | ✔️      | ✔️  | ✔️    | ✔️    | ❌   | Current state of the bluetooth adapter                      |
| adapterState     | ✔️      | ✔️  | ✔️    | ✔️    | ❌   | Stream of on & off states of the bluetooth adapter          |
| startScan        | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Starts a scan for Ble devices                               |
| stopScan         | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stop an existing scan for Ble devices                       |
| onScanResults    | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of live scan results                                 |
| scanResults      | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of live scan results or previous results             |
| lastScanResults  | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | The most recent scan results                                |
| isScanning       | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of current scanning state                            |
| isScanningNow    | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Is a scan currently running?                                |
| connectedDevices | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | List of devices connected to *your app*                     |
| systemDevices    | ✔️      | ✔️  | ✔️    | ✔️    | ❌   | List of devices connected to the system, even by other apps |
| getPhySupport    | ✔️      | ❌   | ❌     | ❌     | ❌   | Get supported bluetooth phy codings                         |

### FlutterBluePlus Events API

|                          | Android | iOS | Linux | macOS | Web | Description                                            |
|--------------------------|---------|-----|-------|-------|-----|--------------------------------------------------------|
| onConnectionStateChanged | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of connection changes of *all devices*          |
| onMtuChanged             | ✔️      | ✔️  | ❌     | ✔️    | ❌   | Stream of mtu changes of *all devices*                 |
| onReadRssi               | ✔️      | ✔️  | ✔️    | ✔️    | ❌   | Stream of rssi reads of *all devices*                  |
| onServicesReset          | ✔️      | ✔️  | ✔️    | ✔️    | ❌   | Stream of services resets of *all devices*             |
| onDiscoveredServices     | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of services discovered of *all devices*         |
| onCharacteristicReceived | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of characteristic value reads of *all devices*  |
| onCharacteristicWritten  | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of characteristic value writes of *all devices* |
| onDescriptorRead         | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of descriptor value reads of *all devices*      |
| onDescriptorWritten      | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of descriptor value writes of *all devices*     |
| onBondStateChanged       | ✔️      | ❌   | ✔️    | ❌     | ❌   | Stream of bond state changes of *all devices*          |
| onNameChanged            | ❌       | ✔️  | ✔️    | ✔️    | ❌   | Stream of name changes of *all devices*                |

### BluetoothDevice API

|                           | Android | iOS | Linux | macOS | Web | Description                                                |
|---------------------------|---------|-----|-------|-------|-----|------------------------------------------------------------|
| platformName              | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | The platform preferred name of the device                  |
| advName                   | ✔️      | ✔️  | ❌     | ✔️    | ❌   | The advertised name of the device found during scanning    |
| connect                   | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Establishes a connection to the device                     |
| disconnect                | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Cancels an active or pending connection to the device      |
| isConnected               | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Is this device currently connected to *your app*?          |
| isDisconnected            | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Is this device currently disconnected from *your app*?     |
| connectionState           | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of connection changes for the Bluetooth Device      |
| discoverServices          | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Discover services                                          |
| servicesList              | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | The current list of available services                     |
| onServicesReset           | ✔️      | ✔️  | ✔️    | ✔️    | ❌   | The services changed & must be rediscovered                |
| mtu                       | ✔️      | ✔️  | ❌     | ✔️    | ❌   | Stream of current mtu value + changes                      |
| mtuNow                    | ✔️      | ✔️  | ❌     | ✔️    | ❌   | The current mtu value                                      |
| readRssi                  | ✔️      | ✔️  | ✔️    | ✔️    | ❌   | Read RSSI from a connected device                          |
| requestMtu                | ✔️      | ❌   | ❌     | ❌     | ❌   | Request to change the MTU for the device                   |
| requestConnectionPriority | ✔️      | ❌   | ❌     | ❌     | ❌   | Request to update a high priority, low latency connection  |
| bondState                 | ✔️      | ❌   | ✔️    | ❌     | ❌   | Stream of device bond state. Can be useful on Android      |
| createBond                | ✔️      | ❌   | ✔️    | ❌     | ❌   | Force a system pairing dialogue to show, if needed         |
| removeBond                | ✔️      | ❌   | ✔️    | ❌     | ❌   | Remove Bluetooth Bond of device                            |
| setPreferredPhy           | ✔️      | ❌   | ❌     | ❌     | ❌   | Set preferred RX and TX phy for connection and phy options |
| clearGattCache            | ✔️      | ❌   | ❌     | ❌     | ❌   | Clear android cache of service discovery results           |

### BluetoothCharacteristic API

|                 | Android | iOS | Linux | macOS | Web | Description                                                     |
|-----------------|---------|-----|-------|-------|-----|-----------------------------------------------------------------|
| uuid            | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | The uuid of characteristic                                      |
| read            | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Retrieves the value of the characteristic                       |
| write           | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Writes the value of the characteristic                          |
| setNotifyValue  | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Sets notifications or indications on the characteristic         |
| isNotifying     | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Are notifications or indications currently enabled              |
| onValueReceived | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of characteristic value updates received from the device |
| lastValue       | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | The most recent value of the characteristic                     |
| lastValueStream | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of onValueReceived + writes                              |

### BluetoothDescriptor API

|                 | Android | iOS | Linux | macOS | Web | Description                               |
|-----------------|---------|-----|-------|-------|-----|-------------------------------------------|
| uuid            | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | The uuid of descriptor                    |
| read            | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Retrieves the value of the descriptor     |
| write           | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Writes the value of the descriptor        |
| onValueReceived | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of descriptor value reads & writes |
| lastValue       | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | The most recent value of the descriptor   |
| lastValueStream | ✔️      | ✔️  | ✔️    | ✔️    | ✔️  | Stream of onValueReceived + writes        |

## Interoperability

| [Upstream](https://pub.dev/packages/flutter_blue_plus) | [`flutter_blue_plus`](./packages/flutter_blue_plus) | [`flutter_blue_plus_platform_interface`](./packages/flutter_blue_plus_platform_interface) | [`flutter_blue_plus_android`](./packages/flutter_blue_plus_android) | [`flutter_blue_plus_ios`](./packages/flutter_blue_plus_ios) | [`flutter_blue_plus_linux`](./packages/flutter_blue_plus_linux) | [`flutter_blue_plus_macos`](./packages/flutter_blue_plus_macos) | [`flutter_blue_plus_web`](./packages/flutter_blue_plus_web) |
|--------------------------------------------------------|-----------------------------------------------------|-------------------------------------------------------------------------------------------|---------------------------------------------------------------------|-------------------------------------------------------------|-----------------------------------------------------------------|-----------------------------------------------------------------|-------------------------------------------------------------|
| 1.33.6                                                 | 1.0.0                                               | 1.0.0                                                                                     | 1.0.0                                                               | 1.0.0                                                       |                                                                 | 1.0.0                                                           |                                                             |
| 1.33.6                                                 | 1.1.0                                               | 1.0.0                                                                                     | 1.0.0                                                               | 1.0.0                                                       | 1.0.0                                                           | 1.0.0                                                           |                                                             |
| 1.33.6                                                 | 1.2.0                                               | 1.0.0                                                                                     | 1.0.0                                                               | 1.0.0                                                       | 1.0.0                                                           | 1.0.0                                                           | 1.0.0                                                       |
