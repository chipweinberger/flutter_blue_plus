import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin: CBPeripheralManagerDelegate {
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard let (identifier, _) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        let snapshot = serviceSnapshot(service)
        let handle = objectKey(service)
        if error == nil, localServices[identifier]?[handle] === service {
            publishedLocalServices[identifier, default: []].insert(handle)
        } else if error != nil, publishedLocalServices[identifier]?.contains(handle) != true {
            // A failed re-add must not retire a previously published registration.
            removeLocalServices(for: identifier, serviceHandle: handle)
        }
        // Preserve the callback snapshot without reviving a removed or failed add.
        pruneLocalAttributes(LocalGattGraph([service], key: objectKey))
        emit(
            kind: "peripheralManagerDidAddService",
            payload: [
                "service": snapshot,
                "error": serialize(error: error)
            ],
            peripheralManagerId: identifier
        )
    }

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard let (identifier, peripheralManager) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        if peripheralManager.state != .poweredOn {
            peripheralManagerCentrals.removeValue(forKey: identifier)
            attRequests = attRequests.filter { $0.value.managerId != identifier }
        }
        if peripheralManager.state == .poweredOff || peripheralManager.state == .resetting {
            removeLocalServices(for: identifier)
        }

        emit(
            kind: "peripheralManagerDidUpdateState",
            payload: peripheralManagerSnapshot(for: identifier, peripheralManager: peripheralManager),
            peripheralManagerId: identifier
        )
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        guard let (identifier, peripheralManager) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        let advertisingData = serialize(
            advertisingData: dict[CBPeripheralManagerRestoredStateAdvertisementDataKey] as? [String: Any]
        )
        let previous = localGatt(for: identifier)
        localServices[identifier] = [:]
        let restored = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] ?? []
        publishedLocalServices.removeValue(forKey: identifier)
        if !restored.isEmpty {
            publishedLocalServices[identifier] = Set(restored.map(objectKey))
        }
        restored.forEach { rememberLocalService($0, for: identifier) }
        pruneLocalAttributes(previous)
        let restoredServices = restored.map(serviceSnapshot)

        emit(
            kind: "peripheralManagerWillRestoreState",
            payload: [
                "advertisingData": advertisingData,
                "services": restoredServices
            ],
            peripheralManagerId: identifier
        )

        _ = peripheralManager
    }

    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        guard let (identifier, peripheralManager) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralManagerDidStartAdvertising",
            payload: [
                "isAdvertising": peripheralManager.isAdvertising,
                "error": serialize(error: error)
            ],
            peripheralManagerId: identifier
        )
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard let (identifier, _) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        guard localGatt(for: identifier).characteristics[objectKey(characteristic)] === characteristic else { return }

        remember(central, forPeripheralManager: identifier)

        emit(
            kind: "peripheralManagerDidSubscribeToCharacteristic",
            payload: [
                "central": centralSnapshot(central),
                "characteristicHandle": objectKey(characteristic)
            ],
            peripheralManagerId: identifier
        )
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        guard let (identifier, _) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        guard localGatt(for: identifier).characteristics[objectKey(characteristic)] === characteristic else { return }

        remember(central, forPeripheralManager: identifier)

        emit(
            kind: "peripheralManagerDidUnsubscribeFromCharacteristic",
            payload: [
                "central": centralSnapshot(central),
                "characteristicHandle": objectKey(characteristic)
            ],
            peripheralManagerId: identifier
        )
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        guard let (identifier, _) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralManagerIsReadyToUpdateSubscribers",
            payload: [:],
            peripheralManagerId: identifier
        )
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard let (identifier, _) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        guard localGatt(for: identifier).characteristics[objectKey(request.characteristic)] === request.characteristic else {
            return
        }

        emit(
            kind: "peripheralManagerDidReceiveRead",
            payload: attRequestSnapshot(request, managerId: identifier),
            peripheralManagerId: identifier
        )
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let (identifier, _) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        let owned = localGatt(for: identifier).characteristics
        guard requests.allSatisfy({ owned[objectKey($0.characteristic)] === $0.characteristic }) else { return }
        let batchId = UUID()

        emit(
            kind: "peripheralManagerDidReceiveWrite",
            payload: [
                "requests": requests.map { attRequestSnapshot($0, managerId: identifier, batchId: batchId) }
            ],
            peripheralManagerId: identifier
        )
    }

    @available(iOS 11.0, macOS 10.13, *)
    public func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        guard let (identifier, _) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralManagerDidPublishL2CAPChannel",
            payload: [
                "psm": PSM,
                "error": serialize(error: error)
            ],
            peripheralManagerId: identifier
        )
    }

    @available(iOS 11.0, macOS 10.13, *)
    public func peripheralManager(_ peripheral: CBPeripheralManager, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        guard let (identifier, _) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralManagerDidUnpublishL2CAPChannel",
            payload: [
                "psm": PSM,
                "error": serialize(error: error)
            ],
            peripheralManagerId: identifier
        )
    }

    @available(iOS 11.0, macOS 10.13, *)
    public func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard let (identifier, _) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        if let central = channel?.peer as? CBCentral {
            remember(central, forPeripheralManager: identifier)
        }

        emit(
            kind: "peripheralManagerDidOpenL2CAPChannel",
            payload: [
                "channel": channel.map { l2capChannelSnapshot($0, managerIds: [identifier]) },
                "error": serialize(error: error)
            ],
            peripheralManagerId: identifier
        )
    }
}
