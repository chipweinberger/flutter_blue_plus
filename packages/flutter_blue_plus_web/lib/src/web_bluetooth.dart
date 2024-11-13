// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// API docs from [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web).
// Attributions and copyright licensing by Mozilla Contributors is licensed
// under [CC-BY-SA 2.5](https://creativecommons.org/licenses/by-sa/2.5/.

// Generated from Web IDL definitions.

// ignore_for_file: unintended_html_in_doc_comment

@JS()
library;

import 'dart:js_interop';

import 'package:web/web.dart' show AbortSignal, BufferSource, Event, EventHandler, EventInit, EventTarget, PermissionStatus;

typedef UUID = String;
typedef BluetoothServiceUUID = JSAny;
typedef BluetoothCharacteristicUUID = JSAny;
typedef BluetoothDescriptorUUID = JSAny;
extension type BluetoothDataFilterInit._(JSObject _) implements JSObject {
  external factory BluetoothDataFilterInit({
    BufferSource dataPrefix,
    BufferSource mask,
  });

  external BufferSource get dataPrefix;
  external set dataPrefix(BufferSource value);
  external BufferSource get mask;
  external set mask(BufferSource value);
}
extension type BluetoothManufacturerDataFilterInit._(JSObject _)
    implements BluetoothDataFilterInit, JSObject {
  external factory BluetoothManufacturerDataFilterInit({
    BufferSource dataPrefix,
    BufferSource mask,
    required int companyIdentifier,
  });

  external int get companyIdentifier;
  external set companyIdentifier(int value);
}
extension type BluetoothServiceDataFilterInit._(JSObject _)
    implements BluetoothDataFilterInit, JSObject {
  external factory BluetoothServiceDataFilterInit({
    BufferSource dataPrefix,
    BufferSource mask,
    required BluetoothServiceUUID service,
  });

  external BluetoothServiceUUID get service;
  external set service(BluetoothServiceUUID value);
}
extension type BluetoothLEScanFilterInit._(JSObject _) implements JSObject {
  external factory BluetoothLEScanFilterInit({
    JSArray<BluetoothServiceUUID> services,
    String name,
    String namePrefix,
    JSArray<BluetoothManufacturerDataFilterInit> manufacturerData,
    JSArray<BluetoothServiceDataFilterInit> serviceData,
  });

  external JSArray<BluetoothServiceUUID> get services;
  external set services(JSArray<BluetoothServiceUUID> value);
  external String get name;
  external set name(String value);
  external String get namePrefix;
  external set namePrefix(String value);
  external JSArray<BluetoothManufacturerDataFilterInit> get manufacturerData;
  external set manufacturerData(
      JSArray<BluetoothManufacturerDataFilterInit> value);
  external JSArray<BluetoothServiceDataFilterInit> get serviceData;
  external set serviceData(JSArray<BluetoothServiceDataFilterInit> value);
}
extension type RequestDeviceOptions._(JSObject _) implements JSObject {
  external factory RequestDeviceOptions({
    JSArray<BluetoothLEScanFilterInit> filters,
    JSArray<BluetoothLEScanFilterInit> exclusionFilters,
    JSArray<BluetoothServiceUUID> optionalServices,
    JSArray<JSNumber> optionalManufacturerData,
    bool acceptAllDevices,
  });

  external JSArray<BluetoothLEScanFilterInit> get filters;
  external set filters(JSArray<BluetoothLEScanFilterInit> value);
  external JSArray<BluetoothLEScanFilterInit> get exclusionFilters;
  external set exclusionFilters(JSArray<BluetoothLEScanFilterInit> value);
  external JSArray<BluetoothServiceUUID> get optionalServices;
  external set optionalServices(JSArray<BluetoothServiceUUID> value);
  external JSArray<JSNumber> get optionalManufacturerData;
  external set optionalManufacturerData(JSArray<JSNumber> value);
  external bool get acceptAllDevices;
  external set acceptAllDevices(bool value);
}

/// The **`Bluetooth`** interface of the
/// [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)
/// provides methods to query Bluetooth availability and request access to
/// devices.
///
/// ---
///
/// API documentation sourced from
/// [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/Bluetooth).
extension type Bluetooth._(JSObject _) implements EventTarget, JSObject {
  /// The **`getAvailability()`** method of the [Bluetooth] interface
  /// _nominally_ returns `true` if the user agent can support Bluetooth
  /// (because the device has a Bluetooth adapter), and `false` otherwise.
  ///
  /// The word "nominally" is used because if permission to use the Web
  /// Bluetooth API is disallowed by the [`Permissions-Policy:
  /// bluetooth`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Permissions-Policy/bluetooth)
  /// permission, the method will always return `false`.
  /// In addition, a user can configure their browser to return `false` from a
  /// `getAvailability()` call even if the browser does have an operational
  /// Bluetooth adapter, and vice versa. This setting value ignored if access is
  /// blocked by the permission.
  ///
  /// Even if `getAvailability()` returns `true` and the device actually has a
  /// Bluetooth adaptor, this does not necessarily mean that calling
  /// [Bluetooth.requestDevice] will resolve with a [BluetoothDevice].
  /// The Bluetooth adapter may not be powered, and a user might deny permission
  /// to use the API when prompted.
  external JSPromise<JSBoolean> getAvailability();

  /// The **`getDevices()`** method of the [Bluetooth] interface returns an
  /// array containing the Bluetooth devices that this origin is allowed to
  /// access — including those that are out of range and powered off.
  external JSPromise<JSArray<BluetoothDevice>> getDevices();

  /// The **`Bluetooth.requestDevice()`** method of the [Bluetooth] interface
  /// returns a `Promise` that fulfills with a [BluetoothDevice] object matching
  /// the specified options.
  /// If there is no chooser UI, this method returns the first device matching
  /// the criteria.
  external JSPromise<BluetoothDevice> requestDevice(
      [RequestDeviceOptions options]);
  external EventHandler get onavailabilitychanged;
  external set onavailabilitychanged(EventHandler value);
  external BluetoothDevice? get referringDevice;
  external EventHandler get ongattserverdisconnected;
  external set ongattserverdisconnected(EventHandler value);
  external EventHandler get oncharacteristicvaluechanged;
  external set oncharacteristicvaluechanged(EventHandler value);
  external EventHandler get onserviceadded;
  external set onserviceadded(EventHandler value);
  external EventHandler get onservicechanged;
  external set onservicechanged(EventHandler value);
  external EventHandler get onserviceremoved;
  external set onserviceremoved(EventHandler value);
}
extension type AllowedBluetoothDevice._(JSObject _) implements JSObject {
  external factory AllowedBluetoothDevice({
    required String deviceId,
    required bool mayUseGATT,
    required JSAny allowedServices,
    required JSArray<JSNumber> allowedManufacturerData,
  });

  external String get deviceId;
  external set deviceId(String value);
  external bool get mayUseGATT;
  external set mayUseGATT(bool value);
  external JSAny get allowedServices;
  external set allowedServices(JSAny value);
  external JSArray<JSNumber> get allowedManufacturerData;
  external set allowedManufacturerData(JSArray<JSNumber> value);
}
extension type BluetoothPermissionStorage._(JSObject _) implements JSObject {
  external factory BluetoothPermissionStorage(
      {required JSArray<AllowedBluetoothDevice> allowedDevices});

  external JSArray<AllowedBluetoothDevice> get allowedDevices;
  external set allowedDevices(JSArray<AllowedBluetoothDevice> value);
}
extension type BluetoothPermissionResult._(JSObject _)
    implements PermissionStatus, JSObject {
  external JSArray<BluetoothDevice> get devices;
  external set devices(JSArray<BluetoothDevice> value);
}
extension type ValueEvent._(JSObject _) implements Event, JSObject {
  external factory ValueEvent(
    String type, [
    ValueEventInit initDict,
  ]);

  external JSAny? get value;
}
extension type ValueEventInit._(JSObject _) implements EventInit, JSObject {
  external factory ValueEventInit({
    bool bubbles,
    bool cancelable,
    bool composed,
    JSAny? value,
  });

  external JSAny? get value;
  external set value(JSAny? value);
}

/// The BluetoothDevice interface of the
/// [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)
/// represents a Bluetooth device inside a particular script execution
/// environment.
///
/// ---
///
/// API documentation sourced from
/// [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/BluetoothDevice).
extension type BluetoothDevice._(JSObject _) implements EventTarget, JSObject {
  external JSPromise<JSAny?> forget();
  external JSPromise<JSAny?> watchAdvertisements(
      [WatchAdvertisementsOptions options]);

  /// The **`BluetoothDevice.id`** read-only property returns a
  /// string that uniquely identifies a device.
  external String get id;

  /// The **`BluetoothDevice.name`** read-only property returns a
  /// string that provides a human-readable name for the device.
  external String? get name;

  /// The
  /// **`BluetoothDevice.gatt`** read-only property returns
  /// a reference to the device's [BluetoothRemoteGATTServer].
  external BluetoothRemoteGATTServer? get gatt;
  external bool get watchingAdvertisements;
  external EventHandler get onadvertisementreceived;
  external set onadvertisementreceived(EventHandler value);
  external EventHandler get ongattserverdisconnected;
  external set ongattserverdisconnected(EventHandler value);
  external EventHandler get oncharacteristicvaluechanged;
  external set oncharacteristicvaluechanged(EventHandler value);
  external EventHandler get onserviceadded;
  external set onserviceadded(EventHandler value);
  external EventHandler get onservicechanged;
  external set onservicechanged(EventHandler value);
  external EventHandler get onserviceremoved;
  external set onserviceremoved(EventHandler value);
}
extension type WatchAdvertisementsOptions._(JSObject _) implements JSObject {
  external factory WatchAdvertisementsOptions({AbortSignal signal});

  external AbortSignal get signal;
  external set signal(AbortSignal value);
}
extension type BluetoothManufacturerDataMap._(JSObject _) implements JSObject {}
extension type BluetoothServiceDataMap._(JSObject _) implements JSObject {}
extension type BluetoothAdvertisingEvent._(JSObject _)
    implements Event, JSObject {
  external factory BluetoothAdvertisingEvent(
    String type,
    BluetoothAdvertisingEventInit init,
  );

  external BluetoothDevice get device;
  external JSArray<JSString> get uuids;
  external String? get name;
  external int? get appearance;
  external int? get txPower;
  external int? get rssi;
  external BluetoothManufacturerDataMap get manufacturerData;
  external BluetoothServiceDataMap get serviceData;
}
extension type BluetoothAdvertisingEventInit._(JSObject _)
    implements EventInit, JSObject {
  external factory BluetoothAdvertisingEventInit({
    bool bubbles,
    bool cancelable,
    bool composed,
    required BluetoothDevice device,
    JSArray<JSAny> uuids,
    String name,
    int appearance,
    int txPower,
    int rssi,
    BluetoothManufacturerDataMap manufacturerData,
    BluetoothServiceDataMap serviceData,
  });

  external BluetoothDevice get device;
  external set device(BluetoothDevice value);
  external JSArray<JSAny> get uuids;
  external set uuids(JSArray<JSAny> value);
  external String get name;
  external set name(String value);
  external int get appearance;
  external set appearance(int value);
  external int get txPower;
  external set txPower(int value);
  external int get rssi;
  external set rssi(int value);
  external BluetoothManufacturerDataMap get manufacturerData;
  external set manufacturerData(BluetoothManufacturerDataMap value);
  external BluetoothServiceDataMap get serviceData;
  external set serviceData(BluetoothServiceDataMap value);
}

/// The **`BluetoothRemoteGATTServer`** interface of the
/// [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)
/// represents a GATT
/// Server on a remote device.
///
/// ---
///
/// API documentation sourced from
/// [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/BluetoothRemoteGATTServer).
extension type BluetoothRemoteGATTServer._(JSObject _) implements JSObject {
  /// The
  /// **`BluetoothRemoteGATTServer.connect()`** method causes the
  /// script execution environment to connect to `this.device`.
  external JSPromise<BluetoothRemoteGATTServer> connect();

  /// The **`BluetoothRemoteGATTServer.disconnect()`** method causes
  /// the script execution environment to disconnect from `this.device`.
  external void disconnect();

  /// The **`BluetoothRemoteGATTServer.getPrimaryService()`** method
  /// returns a promise to the primary [BluetoothRemoteGATTService] offered by
  /// the
  /// Bluetooth device for a specified bluetooth service UUID.
  external JSPromise<BluetoothRemoteGATTService> getPrimaryService(
      BluetoothServiceUUID service);

  /// The **BluetoothRemoteGATTServer.getPrimaryServices()** method returns a
  /// promise to a list of primary [BluetoothRemoteGATTService] objects offered
  /// by the
  /// Bluetooth device for a specified `BluetoothServiceUUID`.
  external JSPromise<JSArray<BluetoothRemoteGATTService>> getPrimaryServices(
      [BluetoothServiceUUID service]);

  /// The **`BluetoothRemoteGATTServer.device`** read-only property
  /// returns a reference to the [BluetoothDevice] running the server.
  external BluetoothDevice get device;

  /// The **`BluetoothRemoteGATTServer.connected`** read-only
  /// property returns a boolean value that returns true while this script
  /// execution
  /// environment is connected to `this.device`. It can be false while the user
  /// agent is physically connected.
  external bool get connected;
}

/// The `BluetoothRemoteGATTService` interface of the
/// [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)
/// represents a
/// service provided by a GATT server, including a device, a list of referenced
/// services,
/// and a list of the characteristics of this service.
///
/// ---
///
/// API documentation sourced from
/// [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/BluetoothRemoteGATTService).
extension type BluetoothRemoteGATTService._(JSObject _)
    implements EventTarget, JSObject {
  /// The **`BluetoothGATTService.getCharacteristic()`** method
  /// returns a `Promise` to an instance of
  /// [BluetoothRemoteGATTCharacteristic] for a given universally unique
  /// identifier
  /// (UUID).
  external JSPromise<BluetoothRemoteGATTCharacteristic> getCharacteristic(
      BluetoothCharacteristicUUID characteristic);

  /// The **`BluetoothGATTService.getCharacteristics()`** method
  /// returns a `Promise` to a list of [BluetoothRemoteGATTCharacteristic]
  /// instances for a given universally unique identifier (UUID).
  external JSPromise<JSArray<BluetoothRemoteGATTCharacteristic>>
      getCharacteristics([BluetoothCharacteristicUUID characteristic]);
  external JSPromise<BluetoothRemoteGATTService> getIncludedService(
      BluetoothServiceUUID service);
  external JSPromise<JSArray<BluetoothRemoteGATTService>> getIncludedServices(
      [BluetoothServiceUUID service]);

  /// The **`BluetoothGATTService.device`** read-only property
  /// returns information about a Bluetooth device through an instance of
  /// [BluetoothDevice].
  external BluetoothDevice get device;

  /// The **`BluetoothGATTService.uuid`** read-only property
  /// returns a string representing the UUID of this service.
  external UUID get uuid;

  /// The **`BluetoothGATTService.isPrimary`** read-only property
  /// returns a boolean value that indicates whether this is a primary service.
  /// If it
  /// is not a primary service, it is a secondary service.
  external bool get isPrimary;
  external EventHandler get oncharacteristicvaluechanged;
  external set oncharacteristicvaluechanged(EventHandler value);
  external EventHandler get onserviceadded;
  external set onserviceadded(EventHandler value);
  external EventHandler get onservicechanged;
  external set onservicechanged(EventHandler value);
  external EventHandler get onserviceremoved;
  external set onserviceremoved(EventHandler value);
}

/// The `BluetoothRemoteGattCharacteristic` interface of the
/// [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)
/// represents a GATT Characteristic, which is a basic data element that
/// provides further information about a peripheral's service.
///
/// ---
///
/// API documentation sourced from
/// [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/BluetoothRemoteGATTCharacteristic).
extension type BluetoothRemoteGATTCharacteristic._(JSObject _)
    implements EventTarget, JSObject {
  /// The **`BluetoothRemoteGATTCharacteristic.getDescriptor()`** method
  /// returns a `Promise` that resolves to the
  /// first [BluetoothRemoteGATTDescriptor] for a given descriptor UUID.
  external JSPromise<BluetoothRemoteGATTDescriptor> getDescriptor(
      BluetoothDescriptorUUID descriptor);

  /// The **`BluetoothRemoteGATTCharacteristic.getDescriptors()`** method
  /// returns a `Promise` that resolves to an `Array` of all
  /// [BluetoothRemoteGATTDescriptor] objects for a given descriptor UUID.
  external JSPromise<JSArray<BluetoothRemoteGATTDescriptor>> getDescriptors(
      [BluetoothDescriptorUUID descriptor]);

  /// The **`BluetoothRemoteGATTCharacteristic.readValue()`** method
  /// returns a `Promise` that resolves to a `DataView` holding a
  /// duplicate of the `value` property if it is available and supported.
  /// Otherwise
  /// it throws an error.
  external JSPromise<JSDataView> readValue();

  /// Use [BluetoothRemoteGATTCharacteristic.writeValueWithResponse] and
  /// [BluetoothRemoteGATTCharacteristic.writeValueWithoutResponse] instead.
  ///
  /// The **`BluetoothRemoteGATTCharacteristic.writeValue()`** method sets a
  /// [BluetoothRemoteGATTCharacteristic] object's `value` property to the bytes
  /// contained in a given `ArrayBuffer`, calls
  /// [`WriteCharacteristicValue`(_this_=`this`, _value=value_,
  /// _response_=`"optional"`)](https://webbluetoothcg.github.io/web-bluetooth/#writecharacteristicvalue),
  /// and returns the resulting `Promise`.
  external JSPromise<JSAny?> writeValue(BufferSource value);

  /// The **`BluetoothRemoteGATTCharacteristic.writeValueWithResponse()`**
  /// method sets a [BluetoothRemoteGATTCharacteristic] object's `value`
  /// property to the bytes contained in a given `ArrayBuffer`, calls
  /// [`WriteCharacteristicValue`(_this_=`this`, _value=value_,
  /// _response_=`"required"`)](https://webbluetoothcg.github.io/web-bluetooth/#writecharacteristicvalue),
  /// and returns the resulting `Promise`.
  external JSPromise<JSAny?> writeValueWithResponse(BufferSource value);

  /// The **`BluetoothRemoteGATTCharacteristic.writeValueWithoutResponse()`**
  /// method sets a [BluetoothRemoteGATTCharacteristic] object's `value`
  /// property to the bytes contained in a given `ArrayBuffer`, calls
  /// [`WriteCharacteristicValue`(_this_=`this`, _value=value_,
  /// _response_=`"never"`)](https://webbluetoothcg.github.io/web-bluetooth/#writecharacteristicvalue),
  /// and returns the resulting `Promise`.
  external JSPromise<JSAny?> writeValueWithoutResponse(BufferSource value);

  /// The **`BluetoothRemoteGATTCharacteristic.startNotifications()`** method
  /// returns a `Promise` to the BluetoothRemoteGATTCharacteristic instance when
  /// there is an active notification on it.
  external JSPromise<BluetoothRemoteGATTCharacteristic> startNotifications();

  /// The **`BluetoothRemoteGATTCharacteristic.stopNotifications()`** method
  /// returns a `Promise` to the BluetoothRemoteGATTCharacteristic instance when
  /// there is no longer an active notification on it.
  external JSPromise<BluetoothRemoteGATTCharacteristic> stopNotifications();

  /// The **`BluetoothRemoteGATTCharacteristic.service`** read-only
  /// property returns the [BluetoothRemoteGATTService] this characteristic
  /// belongs to.
  external BluetoothRemoteGATTService get service;

  /// The **`BluetoothRemoteGATTCharacteristic.uuid`** read-only
  /// property returns a string containing the UUID of the characteristic, for
  /// example `'00002a37-0000-1000-8000-00805f9b34fb'` for the Heart Rate
  /// Measurement characteristic.
  external UUID get uuid;

  /// The **`BluetoothRemoteGATTCharacteristic.properties`**
  /// read-only property returns a [BluetoothCharacteristicProperties] instance
  /// containing the properties of this characteristic.
  external BluetoothCharacteristicProperties get properties;

  /// The **`BluetoothRemoteGATTCharacteristic.value`** read-only
  /// property returns currently cached characteristic value. This value gets
  /// updated when the
  /// value of the characteristic is read or updated via a notification or
  /// indication.
  external JSDataView? get value;
  external EventHandler get oncharacteristicvaluechanged;
  external set oncharacteristicvaluechanged(EventHandler value);
}

/// The **`BluetoothCharacteristicProperties`** interface of the
/// [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)
/// provides the operations that are valid on the given
/// [BluetoothRemoteGATTCharacteristic].
///
/// This interface is returned by calling
/// [BluetoothRemoteGATTCharacteristic.properties].
///
/// ---
///
/// API documentation sourced from
/// [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/BluetoothCharacteristicProperties).
extension type BluetoothCharacteristicProperties._(JSObject _)
    implements JSObject {
  /// The **`broadcast`** read-only property of the
  /// [BluetoothCharacteristicProperties] interface returns a
  /// `boolean` that is `true` if the broadcast of the characteristic
  /// value is permitted using the Server Characteristic Configuration
  /// Descriptor.
  external bool get broadcast;

  /// The **`read`** read-only property of the
  /// [BluetoothCharacteristicProperties] interface returns a
  /// `boolean` that is `true` if the reading of the characteristic
  /// value is permitted.
  external bool get read;

  /// The **`writeWithoutResponse`** read-only
  /// property of the [BluetoothCharacteristicProperties] interface returns a
  /// `boolean` that is `true` if the writing to the characteristic
  /// without response is permitted.
  external bool get writeWithoutResponse;

  /// The **`write`** read-only property of the
  /// [BluetoothCharacteristicProperties] interface returns a
  /// `boolean` that is `true` if the writing to the characteristic with
  /// response is permitted.
  external bool get write;

  /// The **`notify`** read-only property of the
  /// [BluetoothCharacteristicProperties] interface returns a
  /// `boolean` that is `true` if notifications of the characteristic
  /// value without acknowledgement is permitted.
  external bool get notify;

  /// The **`indicate`** read-only property of the
  /// [BluetoothCharacteristicProperties] interface returns a
  /// `boolean` that is `true` if indications of the characteristic
  /// value with acknowledgement is permitted.
  external bool get indicate;

  /// The **`authenticatedSignedWrites`** read-only
  /// property of the [BluetoothCharacteristicProperties] interface returns a
  /// `boolean` that is `true` if signed writing to the characteristic
  /// value is permitted.
  external bool get authenticatedSignedWrites;

  /// The **`reliableWrite`** read-only property of
  /// the [BluetoothCharacteristicProperties] interface returns a
  /// `boolean` that is `true` if reliable writes to the characteristic
  /// is permitted.
  external bool get reliableWrite;

  /// The **`writableAuxiliaries`** read-only
  /// property of the [BluetoothCharacteristicProperties] interface returns a
  /// `boolean` that is `true` if reliable writes to the characteristic
  /// descriptor is permitted.
  external bool get writableAuxiliaries;
}

/// The `BluetoothRemoteGATTDescriptor` interface of the
/// [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)
/// provides a GATT Descriptor,
/// which provides further information about a characteristic's value.
///
/// ---
///
/// API documentation sourced from
/// [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/BluetoothRemoteGATTDescriptor).
extension type BluetoothRemoteGATTDescriptor._(JSObject _) implements JSObject {
  /// The
  /// **`BluetoothRemoteGATTDescriptor.readValue()`**
  /// method returns a `Promise` that resolves to
  /// an `ArrayBuffer` holding a duplicate of the `value` property if
  /// it is available and supported. Otherwise it throws an error.
  external JSPromise<JSDataView> readValue();

  /// The **`BluetoothRemoteGATTDescriptor.writeValue()`**
  /// method sets the value property to the bytes contained in
  /// an `ArrayBuffer` and returns a `Promise`.
  external JSPromise<JSAny?> writeValue(BufferSource value);

  /// The **`BluetoothRemoteGATTDescriptor.characteristic`**
  /// read-only property returns the [BluetoothRemoteGATTCharacteristic] this
  /// descriptor belongs to.
  external BluetoothRemoteGATTCharacteristic get characteristic;

  /// The **`BluetoothRemoteGATTDescriptor.uuid`** read-only property returns
  /// the  of the characteristic descriptor.
  /// For example '`00002902-0000-1000-8000-00805f9b34fb`' for theClient
  /// Characteristic Configuration descriptor.
  external UUID get uuid;

  /// The **`BluetoothRemoteGATTDescriptor.value`**
  /// read-only property returns an `ArrayBuffer` containing the currently
  /// cached
  /// descriptor value. This value gets updated when the value of the descriptor
  /// is read.
  external JSDataView? get value;
}

/// The **`BluetoothUUID`** interface of the [Web Bluetooth API] provides a way
/// to look up Universally Unique Identifier (UUID) values by name in the
/// [registry](https://www.bluetooth.com/specifications/assigned-numbers/)
/// maintained by the Bluetooth SIG.
///
/// ---
///
/// API documentation sourced from
/// [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/BluetoothUUID).
extension type BluetoothUUID._(JSObject _) implements JSObject {
  /// The **`getService()`** static method of the [BluetoothUUID] interface
  /// returns a UUID representing a registered service when passed a name or the
  /// 16- or 32-bit UUID alias.
  external static UUID getService(JSAny name);

  /// The **`getCharacteristic()`** static method of the [BluetoothUUID]
  /// interface returns a UUID representing a registered characteristic when
  /// passed a name or the 16- or 32-bit UUID alias.
  external static UUID getCharacteristic(JSAny name);

  /// The **`getDescriptor()`** static method of the [BluetoothUUID] interface
  /// returns a UUID representing a registered descriptor when passed a name or
  /// the 16- or 32-bit UUID alias.
  external static UUID getDescriptor(JSAny name);

  /// The **`canonicalUUID()`** static method of the [BluetoothUUID] interface
  /// returns the 128-bit UUID when passed a 16- or 32-bit UUID alias.
  external static UUID canonicalUUID(int alias);
}
