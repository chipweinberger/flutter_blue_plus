// Copyright 2023, Manuel Reischer.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// BluetoothManager's aim is to handle multiple devices and their Streams

part of flutter_blue_plus;

/// DeviceModel represents the device and its corresponding Services and Characteristics
/// A device is unique to a DeviceModel, There can be multiple Services and Characteristics per DeviceModel
class DeviceModel {
  final BluetoothDevice device;
  final List<BluetoothService> services;
  final List<CharacteristicStream> characteristicsStream;
  DeviceModel(this.device, this.services, this.characteristicsStream);
}

/// CharacteristicsStream contains the BluetoothCharacteristic and Info wether it's Stream is initialized
class CharacteristicStream {
  final BluetoothCharacteristic characteristic;
  bool isInitialized;
  CharacteristicStream({
    required this.characteristic,
    this.isInitialized = false,
  });
}

/// BluetoothManager's aim is to handle multiple devices and their Streams
class BluetoothManager {
  final deviceModel = <DeviceModel>[];
  int deviceCount = 0;

  /// Connects a Device and checks if the Device is already connected
  /// Check by remoteId if the device is already connected
  /// Connect the Device if not connected
  /// Calls "discoverDeviceServiceAndCharacteristic"
  void connectDevice(BluetoothDevice device) async {
    bool isDeviceAlreadyConnected = deviceModel.any((deviceModel) => deviceModel.device.remoteId == device.remoteId);
    if (!isDeviceAlreadyConnected) {
      await device.connect();
      discoverBluetoothServiceAndCharacteristic(device);
    } else {
      print("Device already connected!");
    }
  }

  /// Disconnects a Device
  /// Removes the device corresponding DeviceModel
  void disconnectDevice(BluetoothDevice device) async {
    await device.disconnect();
    removeDeviceModel(device);
  }

  /// Discoveres BluetoothServices and Saves it into a temporary List
  /// Gets the BluetoothCharacteristics of the Services and saves it into a temporary List
  /// Creates a DeviceModel where everything is saved till the device gets disconnected
  void discoverBluetoothServiceAndCharacteristic(BluetoothDevice device) async {
    final services = await device.discoverServices(); //discoveres Services of the BluetoothDevice
    //starts the Service loop
    final bluetoothServices = <BluetoothService>[];
    final charStream = <CharacteristicStream>[];

    for (var service in services) {
      bluetoothServices.add(service);

      for (var characteristic in service.characteristics) {
        charStream.add(CharacteristicStream(characteristic: characteristic));
      }
    }
    final dm = DeviceModel(device, bluetoothServices, charStream);
    addDeviceModel(dm);
  }

  /// Adds a DeviceModel to the List
  void addDeviceModel(DeviceModel dm) {
    deviceModel.add(dm);
  }

  /// Removes a DeviceModel from the List
  void removeDeviceModel(BluetoothDevice device) {
    deviceModel.removeWhere((deviceModel) => deviceModel.device == device);
  }

  //Returns the amount of connected devices (DeviceModels)
  int getConnectedDeviceCount() {
    deviceCount = deviceModel.length;
    return deviceCount;
  }

  /// Returns the PlatformName of a device
  getPlatformName(BluetoothDevice device) {
    return device.platformName;
  }

  /// Returns the RemoteId of a device
  getRemoteId(BluetoothDevice device) {
    return device.remoteId;
  }

  /// Returns the List of DeviceModels
  List<DeviceModel> getAllDeviceModels() {
    return deviceModel;
  }

  /// Returns a Characteristic by device and CharacteristicNumber
  /// Since it is possible to have multiple Characteristic per Service, you can get the right Characteristic
  /// by device and it's CHaracteristicNumber (Starting at 0)!
  BluetoothCharacteristic getCharacteristic(BluetoothDevice device, int characteristicNumber) {
    final dm = deviceModel.firstWhere((deviceModel) => deviceModel.device == device);
    final characteristic = dm.characteristicsStream[characteristicNumber].characteristic;
    return characteristic;
  }

  /// "Subscribes" to the CHaracteristics Stream
  /// emitts a "Stream" of List<int> (doesn't emitt Stream<List<int>>)!
  /// Set notify value only if it's not already notifying
  Stream<List<int>> subscribeToStream(BluetoothCharacteristic? characteristic) async* {
    if (!characteristic!.isNotifying) {
      await characteristic.setNotifyValue(true);
    }
    if (characteristic.properties.read) {
      await characteristic.read();
    }

    await for (var data in characteristic.lastValueStream) {
      yield data;
    }
  }

  /// UTF8-Decodes the received Data and returns it
  String dataParser(List<int> dataFromDevice) {
    return utf8.decode(dataFromDevice);
  }

  /// Sends Data to the Characteristic
  /// UTF8-Encodes the Data
  void writeCharacteristicData(String characteristicData, BluetoothCharacteristic characteristic) async {
    List<int> bytes = utf8.encode(characteristicData);
    await characteristic.write(bytes);
  }

  /// Checks if the device is connected if it loses the connection by accident
  /// it removes the DeviceModel to counteract
  checkDeviceConnection() {
    for (var dm in deviceModel) {
      final device = dm.device;
      device.connectionState.asBroadcastStream().listen((event) {
        if (event == BluetoothConnectionState.disconnected) {
          disconnectDevice(device);
        }
      }, onError: (error) {}, onDone: () {});
    }
  }
}
