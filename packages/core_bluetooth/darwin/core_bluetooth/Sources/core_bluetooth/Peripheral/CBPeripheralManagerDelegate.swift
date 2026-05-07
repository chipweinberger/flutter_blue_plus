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

        emit(
            kind: "peripheralManagerDidAddService",
            payload: [
                "service": serviceSnapshot(service),
                "error": serialize(error: error)
            ],
            peripheralManagerId: identifier
        )
    }

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard let (identifier, peripheralManager) = peripheralManagerEntry(for: peripheral) else {
            return
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
        let restoredServices = (dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] ?? []).map(
            serviceSnapshot
        )

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

        register(characteristic: characteristic)

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

        register(characteristic: characteristic)

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

        register(characteristic: request.characteristic)

        emit(
            kind: "peripheralManagerDidReceiveRead",
            payload: attRequestSnapshot(request),
            peripheralManagerId: identifier
        )
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let (identifier, _) = peripheralManagerEntry(for: peripheral) else {
            return
        }

        requests.forEach { register(characteristic: $0.characteristic) }

        emit(
            kind: "peripheralManagerDidReceiveWrite",
            payload: [
                "requests": requests.map(attRequestSnapshot)
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

        emit(
            kind: "peripheralManagerDidOpenL2CAPChannel",
            payload: [
                "channel": channel.map(l2capChannelSnapshot),
                "error": serialize(error: error)
            ],
            peripheralManagerId: identifier
        )
    }
}
