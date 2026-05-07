# AndroidBluetooth BLE API contract

This contract targets the public Android SDK through API 36, with optional API 36.1 controls. Dedicated BLE operations are included even when uncommon. Callback streams have operation-specific result types with required fields. Received snapshots are immutable (Dart 3.0–3.2 byte getters return isolated typed copies); local GATT builder lists remain mutable. Close/stop is idempotent and terminal callbacks precede stream completion.

Native overloads that differ only in Context/Handler/Executor, Java builders, Parcelables and deprecated mutable-value setters are represented by Dart constructors/options and typed snapshots. Android 17/API 37 additions are not claimed by this version.

`included` means a Dart operation plus a native implementation exists. It does not promise hardware support, permissions or OEM behavior. Native integer values are preserved, including unknown future statuses. Callback names appear as `event.type` and, for GATT/default scanning, individual stream getters.

## Manager, adapter and device

| Native member | Dart surface | Availability / behavior |
|---|---|---|
| BluetoothManager.getAdapter | BluetoothManager.shared.adapter | Included |
| getConnectedDevices | getConnectedDevices(profile:) | GATT or GATT_SERVER only |
| getDevicesMatchingConnectionStates | getDevicesMatchingConnectionStates(states, profile:) | GATT or GATT_SERVER only |
| getConnectionState | getConnectionState(device, profile:) | System connection state, not client ownership |
| openGattServer | openGattServer | Independent registration per call |
| BluetoothAdapter.getState / isEnabled / getName / setName | state / isEnabled / name / setName | Included |
| getBluetoothLeScanner / getBluetoothLeAdvertiser | bluetoothLeScanner / bluetoothLeAdvertiser | Shared facade per Dart isolate |
| getBondedDevices | bondedDevices | Included; can contain dual-mode/Classic devices |
| getRemoteDevice | getRemoteDevice(address) | Address wrapper, no connection/discovery |
| getRemoteLeDevice | getRemoteLeDevice(address, addressType) | API 33 |
| isMultipleAdvertisementSupported | capabilities.isMultipleAdvertisementSupported | API 21 |
| isOffloadedFilteringSupported / isOffloadedScanBatchingSupported | corresponding capabilities | API 21 |
| isLe2MPhySupported / isLeCodedPhySupported | corresponding capabilities | API 26 |
| isLeExtendedAdvertisingSupported / isLePeriodicAdvertisingSupported | corresponding capabilities | API 26 |
| getLeMaximumAdvertisingDataLength | capabilities.leMaximumAdvertisingDataLength | API 26; 31 fallback earlier |
| ACTION_REQUEST_ENABLE | requestEnable | Explicit Activity dialog, returns Activity result |
| enable / disable | enable / disable | Deprecated; Android 13+ restricts ordinary apps |
| Settings.ACTION_BLUETOOTH_SETTINGS | openSettings | Opens platform settings |
| isDiscovering / cancelDiscovery | isDiscovering / cancelDiscovery | Stop competing Classic inquiry when needed for BLE |
| listenUsingL2capChannel / listenUsingInsecureL2capChannel | same names | API 29, LE only |
| listenUsingSocketSettings | same name | API 36, socket type forced to TYPE_LE |
| BluetoothDevice.getAddress / getName / getType / getBondState / getAlias / getUuids | address / name / type / bondState / alias / uuids | Snapshot; refresh gets current values; alias API 30 |
| getAddressType | addressType | API 35; null earlier |
| getIdentityAddressWithType | identityAddressWithType | API 36, privileged permission |
| createBond | createBond(pin:) | Optional atomic one-shot PIN; request acceptance, observe bond changes |
| synchronous pairing PIN | setPinForNextPairing(pin) | One-shot native receiver application; null cancels; cleared on use/disconnect/bond completion/adapter shutdown/reset |
| setAlias | setAlias | API 31; native permission checks and status preserved |
| setPin / setPairingConfirmation | same names | Subject to Android pairing and privilege rules |
| connectGatt | connectGatt(autoConnect:, phy:, preserveAttributeHandles:) | Explicit LE API 23+; best-effort hidden LE overload then default fallback on API 21–22 |
| createL2capChannel / createInsecureL2capChannel | same names | API 29 |
| createUsingSocketSettings | same name | API 36, LE-only socket settings |
| removeBond (hidden) | removeBond | Best effort; restricted_api / permission_denied may be thrown |

Capability apiLevel/isSupported remain available before permissions are granted; protected capability fields are null with permissionRequired=true. AssociationInfo.isSelfManaged is null before API 35.

Device property getters that require CONNECT permission may be absent from scan snapshots if the app has only SCAN permission. The address remains available. Cached UUIDs are not a replacement for this client's GATT discovery. A device obtained via a scan/typed address is used for connection; `getRemoteLeDevice` sends the address type to Android, and retains scanned native objects in a bounded engine cache for older SDKs that cannot publicly read address type.

Device broadcasts included: ACL_CONNECTED, ACL_DISCONNECTED, ACL_DISCONNECT_REQUESTED, BOND_STATE_CHANGED, NAME_CHANGED, ALIAS_CHANGED, PAIRING_REQUEST, ENCRYPTION_CHANGE (36), KEY_MISSING (36). LE_APPEARANCE_CHANGED is forwarded if supplied by a newer platform. Scalar extras are retained verbatim; typed getters cover bond state, previous state, transport, pairing variant/key and encryption status/enabled/algorithm/key size. Adapter STATE_CHANGED and LOCAL_NAME_CHANGED are included. ACL state remains distinct from a GATT registration's callbacks.

## Scanning

| Native operation / data | Included surface |
|---|---|
| startScan / stopScan / flushPendingScanResults with ScanCallback | Default scanner methods and streams |
| Multiple independent ScanCallbacks | startScanSession -> BluetoothScan.events / stop / flushPendingScanResults |
| startScan / stopScan with PendingIntent | startBackgroundScan / stopBackgroundScan, API 26 |
| ScanCallback.onScanResult / onBatchScanResults / onScanFailed | Same callback names, batches preserved |
| ScanFilter deviceName / deviceAddress | Included |
| serviceUuid + mask | Included |
| serviceDataUuid / data / mask | Included |
| manufacturerId / data / mask | Included |
| serviceSolicitationUuid + mask | API 29 |
| advertisingDataType / data / mask | API 33 |
| ScanSettings scanMode / reportDelay | Included |
| callbackType / matchMode / numOfMatches | API 23; default ALL_MATCHES works on 21–22 |
| legacy / phy | API 26 |
| scanType / rssiThreshold | Optional API 36.1 methods; reflective availability check |
| ScanResult device / rssi / timestampNanos / scanRecord | Included |
| connectable / legacy / primaryPhy / secondaryPhy / advertisingSid / txPower / periodicAdvertisingInterval / dataStatus | API 26; null earlier |
| ScanRecord raw bytes / name / flags / txPower / UUIDs / service data / manufacturers | Included |
| ScanRecord solicitation UUIDs | API 29 |
| All AD structures, including repeated/unknown types | advertisingData, parsed from original bytes |

The default scan and independent sessions each have a native callback identity. Stopping one does not stop another. Background scans require at least one filter and retain their explicit integer PendingIntent identity across engine/process recreation. Stop them explicitly; engine teardown stops only callback scans.

## GATT client

| Native operation | Dart operation |
|---|---|
| connect / disconnect / close | Same names, native registration lifetime preserved |
| getDevice | device |
| discoverServices / getServices | discoverServices / services |
| getService / characteristic / descriptor lookup | getService / getCharacteristic / getDescriptor return first UUID match |
| readCharacteristic / writeCharacteristic | Same names; value passed directly, all write types retained |
| readDescriptor / writeDescriptor | Same names, direct bytes |
| setCharacteristicNotification | Same name; local routing only |
| requestMtu / requestConnectionPriority / readRemoteRssi | Same names |
| readPhy / setPreferredPhy | Same names, API 26 |
| beginReliableWrite / executeReliableWrite / abortReliableWrite | Same names |
| requestSubrateMode | Optional API 36.1, companion association or privileged permission required |
| refresh (hidden) | refresh, best effort; invalidates handles on success unless preserveAttributeHandles was selected at connect |

Every public BLE callback through API 36 is included: onConnectionStateChange, onServicesDiscovered, onCharacteristicRead, onCharacteristicWrite, onCharacteristicChanged, onDescriptorRead, onDescriptorWrite, onReadRemoteRssi, onMtuChanged, onReliableWriteCompleted, onPhyRead, onPhyUpdate, onServiceChanged. onSubrateChange is dispatched on API 36.1 when present.

Read/change callbacks copy native byte arrays before dispatch and use the API-33 value overloads on API 33+. On older Android, deprecated object-value access is internal to the native compatibility layer. Dart does not expose shared mutable remote characteristic/descriptor values.

Service/characteristic/descriptor UUIDs, native instance IDs where available, service type, included services, properties and permissions are included. Included-service graphs are cycle-safe. Handles belong to a registration and discovery generation. Unknown, foreign, stale or removed handles fail rather than falling back to a UUID lookup. Server read/write requests arriving after service removal or clearing retain their attribute metadata in callback-only snapshots; they do not add handles back to the active registry.

## GATT server

Included methods: close, addService, removeService, clearServices, services, connect, cancelConnection, sendResponse, notifyCharacteristicChanged, readPhy and setPreferredPhy (last two API 26). Native values, offsets, request IDs and status codes are preserved. The API-33 notification value overload is used when available; earlier booleans normalize to success/errorUnknown.

Included callbacks: onConnectionStateChange, onServiceAdded, onCharacteristicReadRequest, onCharacteristicWriteRequest, onDescriptorReadRequest, onDescriptorWriteRequest, onExecuteWrite, onNotificationSent, onMtuChanged, onPhyRead and onPhyUpdate.

Local GATT constructors support primary/secondary services, included services, arbitrary characteristics and descriptors, properties and attribute permissions. Register included services first. Add one service at a time and await onServiceAdded before adding/removing/clearing another. Failed registration removes its local handles. The application owns value storage, offsets, CCCD state and prepared-write commit/abort.

## Advertising

| Native area | Included members |
|---|---|
| BluetoothLeAdvertiser legacy | startAdvertising / stopAdvertising, independent callback identity per advertisement |
| AdvertiseSettings | mode, txPowerLevel, connectable, timeoutMillis |
| AdvertiseData | service UUIDs, manufacturer data, service data, includeDeviceName, includeTxPowerLevel |
| Service solicitation UUIDs | API 31 advertising data |
| Legacy callback | onStartSuccess (settings in effect), onStartFailure |
| startAdvertisingSet / stopAdvertisingSet | API 26; returns independent AdvertisingSet |
| AdvertisingSetParameters | connectable, scannable, legacy, anonymous, includeTxPower, primary/secondary PHY, interval, TX power |
| PeriodicAdvertisingParameters | includeTxPower, interval |
| AdvertisingSet operations | enableAdvertising, setAdvertisingData, setScanResponseData, setAdvertisingParameters, setPeriodicAdvertisingParameters, setPeriodicAdvertisingData, setPeriodicAdvertisingEnabled |
| Limits | duration and maxExtendedAdvertisingEvents on start/enable |

All public AdvertisingSetCallback methods are forwarded: onAdvertisingSetStarted, onAdvertisingSetStopped, onAdvertisingEnabled, onAdvertisingDataSet, onScanResponseDataSet, onAdvertisingParametersUpdated, onPeriodicAdvertisingParametersUpdated, onPeriodicAdvertisingDataSet and onPeriodicAdvertisingEnabled. Callback status, enabled state and TX power are retained. Internal advertiser IDs are not exposed; Dart session IDs identify registrations.

## LE L2CAP

Included: secure/insecure creation and listening, connect, timed accept, close, remoteDevice, connectionType, isConnected, maxReceivePacketSize, maxTransmitPacketSize, available, read, write and flush. Socket close unblocks pending native I/O. One operation per direction is allowed; read/write can overlap, but multiple writes, multiple reads or multiple accepts on the same handle are rejected. No application framing or automatic chunking is introduced.

API-36 BluetoothSocketSettings exposes l2capPsm, authenticationRequired and encryptionRequired, always with TYPE_LE. The listener allocates its PSM unless the caller requests one using Android's privileged designated-PSM support. RFCOMM/service-name/UUID and controller offload settings are excluded.

## Companion / background

| Area | Included |
|---|---|
| AssociationRequest | BLE ScanFilters, name pattern, singleDevice; displayName/forceConfirmation API 33 |
| associate | API 26 chooser, pending/created/failure/result/cancelled callbacks; failure/cancellation completes the request stream |
| getMyAssociations / getAssociations | myAssociations: IDs and metadata on API 33+, addresses on earlier versions |
| disassociate | Address API 26, association ID API 33 |
| start/stopObservingDevicePresence | Address API 31, association ID API 36 |
| CompanionDeviceService | Appeared/disappeared and API-36 presence events, including association ID/type/UUID |
| CompanionDeviceManager.removeBond | API 36 public operation for an associated device |
| PendingIntent scan receiver | Live events or process-local buffering, explicit scan ID |
| connectedDevice foreground service | Explicit start/stop, caller-provided notification title/text/ID |
| Runtime permission state/request | Explicit lists, no implicit prompts; Activity detach resolves pending requests |

The foreground service and companion hooks do not bootstrap Flutter or claim state restoration. The app owns its engine/isolate lifecycle. Active GATT registrations, sockets and callback scans/advertisements/ranging are closed on engine detachment and Flutter hot restart. A generation guard rejects stale callbacks/results and sockets accepted by an old generation. Native/Dart startup queues have no fixed count limits; owner callbacks are retained in memory while no listener is present. Applications consume or dispose their registrations to release memory. Background PendingIntent scans and the explicitly started foreground service survive engine detachment until explicitly stopped or Android stops them. App force-stop/reboot/background restrictions still apply.

Association streams retire on `isComplete=true`, failure or cancellation. API 33+ chooser success delivers both success callbacks in either order, with only the last marked complete. Automatic approval and API 26–32 chooser completion each have one success callback. A creation callback arriving after an already-successful chooser result is still delivered even if the Activity has detached; manager presence subscriptions are independent of association attempt streams. Android documents the [two success delivery paths and automatic approval](https://developer.android.com/reference/android/companion/CompanionDeviceManager.Callback).

## BLE ranging (API 36)

Included: RangingManager register/unregisterCapabilitiesCallback and createRangingSession; BLE technology availability and channel-sounding security levels. RangingSession start/stop/close, cancelStart (the native start CancellationSignal), reconfigureRangingInterval, addDeviceToRangingSession and removeDeviceFromRangingSession.

Ranging peer addition passes RawResponderRangingConfig as required by Android; native technology support is not guaranteed. Raw peer removal is documented by Android as UWB-multicast-only and returns unsupported in this BLE wrapper. Recreate the BLE session with the desired peers instead.

Raw initiator/responder configs include RangingDevice UUID, BleCsRangingParams (peer address, update rate, security level, location/sight type) and BleRssiRangingParams (peer address, update rate). SessionConfig includes angle-of-arrival preference, measurement limit, sensor fusion and DataNotificationConfig type/near/far centimeter thresholds.

All session callbacks are included: onOpened, onOpenFailed, onClosed, onStarted, onStopped and onResults. onStarted/onStopped carry the peer UUID and technology; onOpenFailed/onClosed carry a reason. Timestamp, optional RSSI, distance/azimuth/elevation and measurement confidence are retained. Raw responders accept one peer; initiators accept multiple. Applications establish any required BLE connection and exchange peer parameters themselves.

## Intentional exclusions and restrictions

* Classic inquiry/startDiscovery, discoverability, SDP fetching, RFCOMM, SCO, audio, HID and other specialized profiles. cancelDiscovery/isDiscovering are included solely to control competing inquiry.
* Application protocols such as DFU, Mesh, heart-rate decoding and vendor commands. They can use these primitives.
* Generic Parcel/Context/Handler/Executor APIs, Java builder classes, mutable deprecated remote-value setters and integer/string format helpers. Dart options, Uint8List and snapshots replace those mechanisms.
* Unsupported BluetoothGatt/BluetoothGattServer implementations of getConnectedDevices/getConnectionState/getDevicesMatchingConnectionStates. Use BluetoothManager.
* Periodic-advertising synchronization/scanning and PAwR APIs that are absent from the public API-36 Android SDK. Periodic advertising transmission is included.
* Privileged controller/HCI/raw ACL packets, bonding keys, arbitrary connection intervals/latency/supervision timeout, raw ATT/EATT channel selection and hidden connection-update callbacks. The public SDK does not offer these to ordinary applications.
* Companion notification access, system-data sync/permission transfer, non-BLE filters and specialized device profiles.
* Ranging OOB transport negotiation, Wi-Fi and UWB. Raw BLE ranging supports application-defined peer negotiation without expanding into a general ranging library.
* API 37+ additions have not been audited. Optional API 36.1 calls fail clearly if their public methods are unavailable; they do not silently fall back.

Hardware/OS restrictions are reported rather than bypassed. Hidden removeBond/cache-refresh operations remain best effort and may disappear or be blocked. Platform availability is distinct from device support and permission eligibility.

## Delivery and disposal

Background scan/presence events are queued in Android process memory while no Flutter engine listens. Connecting a listener flushes the queue in order; sent events are removed immediately. Live events are broadcast to currently listening engines. There are no event-count caps, idle-owner eviction, disk storage, delivery IDs, paging or acknowledgment APIs. Dart owner streams buffer callbacks while no owner listener is present. Process death loses all queued events; applications own persistence if needed. Hot restart and engine detachment preserve the native background queue while the process remains alive. Global events remain a live broadcast view. Global listeners do not drain owner queues, and owner replay does not rebroadcast globally.

Malformed scan payloads are caught and logged under AndroidBluetooth; attached listeners receive background_error with owner/type/operation/exception/API-level details. Queued errors cannot cross listener replacement, engine restart or detachment. Scan receivers return normally on both success and payload failure.

Typed startup replay runs in a microtask so listeners installed in the same synchronous block can all subscribe before buffered callbacks are broadcast. Scan registrations remain available after a failed stop; retrying calls Android again.

Close/stop calls share one in-flight Future per registration, are safe to repeat, and can be retried after a native failure. Further operations are rejected while closing/closed. GATT/server/socket/scan/legacy-advertisement disposal finishes immediately after native close; advertising sets finish after their actual terminal callback. Ranging waits for a final onClosed or terminal onOpenFailed when a start is outstanding; unused sessions and sessions whose initial open failed finish after native close without manufacturing a callback. An initial ranging open failure allows retry until close; operation failures during an already-open session do not replace its final onClosed. A failed start that is terminal also finishes its streams. Failed or canceled companion requests use the shared session lifecycle: their final callback precedes stream completion and their request routing entries are retired, including callbacks received before associate returns. Locally constructed GATT builder lists can be edited; received service graphs, payload maps, arrays and callback values cannot.

After GATT client/server close begins, only another close request may use that registration, including when native close throws. This preserves cleanup retry without accepting operations whose callbacks are disabled. Received typed byte arrays are copied once when frozen and reused by getters on Dart 3.3+; Dart 3.0–3.2 getters continue to return isolated copies. Scan manufacturer/service-data masks are checked for matching data lengths before calling platform builders, including older Android versions that accept malformed filters.

Engine detach/restart cancels outstanding method replies exactly once with `engine_detached`/`engine_restarted`. Fresh requests use independent Android request codes; a stale dialog result is consumed without touching a fresh request. Codes remain reserved for canceled dialogs until their old result is consumed, without retaining the old engine.

See [development and validation](development.md) for the tested current/minimum toolchains and their test hosts.

## Wrapper and host compatibility

The library manifest contains no permissions, features or components; applications opt in explicitly (see README). Dart/Flutter minimum constraints match the existing FlutterBluePlus Android backend. Native compile SDK follows Flutter when its plugin extension is available; older Flutter hosts default to SDK 33. `androidBluetoothCompileSdk` provides an optional host override. SDK 33 builds include all existing FlutterBluePlus primitives. API 36 ranging and `BluetoothCompanionPresenceService` are optional source files included only with SDK 36; their Dart APIs remain available and report unsupported when the necessary native source was not built.

`AndroidBluetooth.isLocationEnabled` reports the actual system location setting without prompting; a wrapper decides which Android versions require it. `capabilities.hasAdapter` is independent of the BLE feature flag. `requestEnable(waitForResult: false)` separates accepted dialog launch from `onEnableResponse` and preserves immediate launch failures. `AndroidBluetooth.onDetachedFromEngine` is observable before native cleanup and closes registration streams; the event channel can be reopened on a later call after reattachment.

`preserveAttributeHandles: true` retains attribute access after refresh or Service Changed and reports the cached graph on discovery failure. Successful rediscovery still retires the previous handles. Callback handles and parent characteristic/service identities survive invalidation for routing only; strict mode never reactivates them. Routing metadata is freed on registration close. The [FlutterBluePlus compatibility checklist](flutter_blue_plus_compatibility.md) documents policy that remains in the future Dart adapter.
