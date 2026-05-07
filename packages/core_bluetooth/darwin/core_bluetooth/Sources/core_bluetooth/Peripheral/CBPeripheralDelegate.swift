import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin: CBPeripheralDelegate {
    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        guard hasOwner(peripheral) else { return }
        emit(
            kind: "peripheralDidUpdateName",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral)
            ]
        )
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        guard hasOwner(peripheral) else { return }
        emit(
            kind: "peripheralIsReadyToSendWriteWithoutResponse",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral)
            ]
        )
    }

    @available(iOS 11.0, macOS 10.13, *)
    public func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        let owners = Set(managers.values
            .filter { $0.peripherals[peripheral.identifier] === peripheral }
            .map { $0.identifier })
        guard !owners.isEmpty else { return }
        emit(
            kind: "peripheralDidOpenL2CAPChannel",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "channel": channel.map { l2capChannelSnapshot($0, managerIds: owners) },
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard hasOwner(peripheral) else { return }
        register(service: service)
        let discoveredCharacteristics = service.characteristics?.map(characteristicSnapshot)
        pruneRemoteAttributes(for: peripheral)

        emit(
            kind: "peripheralDidDiscoverCharacteristicsForService",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "serviceHandle": objectKey(service),
                "characteristics": discoveredCharacteristics,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        guard hasOwner(peripheral) else { return }
        let serializedServices = invalidatedServices.map(serviceSnapshot)
        let currentServices = peripheral.services?.map(serviceSnapshot)
        pruneRemoteAttributes(for: peripheral)
        emit(
            kind: "peripheralDidModifyServices",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "invalidatedServices": serializedServices,
                "services": currentServices
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        guard hasOwner(peripheral) else { return }
        register(service: service)
        let discoveredIncludedServices = service.includedServices?.map(serviceSnapshot)
        pruneRemoteAttributes(for: peripheral)

        emit(
            kind: "peripheralDidDiscoverIncludedServicesForService",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "serviceHandle": objectKey(service),
                "includedServices": discoveredIncludedServices,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard hasOwner(peripheral) else { return }
        register(characteristic: characteristic)
        let discoveredDescriptors = characteristic.descriptors?.map(descriptorSnapshot)
        pruneRemoteAttributes(for: peripheral)

        emit(
            kind: "peripheralDidDiscoverDescriptorsForCharacteristic",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "characteristicHandle": objectKey(characteristic),
                "descriptors": discoveredDescriptors,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard hasOwner(peripheral) else { return }
        let discoveredServices = peripheral.services?.map(serviceSnapshot)
        pruneRemoteAttributes(for: peripheral)
        emit(
            kind: "peripheralDidDiscoverServices",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "services": discoveredServices,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didReadRSSI RSSI: NSNumber,
        error: Error?
    ) {
        guard hasOwner(peripheral) else { return }
        emit(
            kind: "peripheralDidReadRSSI",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "rssi": RSSI,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard hasOwner(peripheral) else { return }
        emit(
            kind: "peripheralDidUpdateNotificationStateForCharacteristic",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "characteristicHandle": objectKey(characteristic),
                "isNotifying": characteristic.isNotifying,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard hasOwner(peripheral) else { return }
        emit(
            kind: "peripheralDidUpdateValueForCharacteristic",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "characteristicHandle": objectKey(characteristic),
                "value": characteristic.value,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard hasOwner(peripheral) else { return }
        emit(
            kind: "peripheralDidUpdateValueForDescriptor",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "descriptorHandle": objectKey(descriptor),
                "value": descriptor.value,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard hasOwner(peripheral) else { return }
        emit(
            kind: "peripheralDidWriteValueForCharacteristic",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "characteristicHandle": objectKey(characteristic),
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard hasOwner(peripheral) else { return }
        emit(
            kind: "peripheralDidWriteValueForDescriptor",
            peripheral: peripheral,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "descriptorHandle": objectKey(descriptor),
                "error": serialize(error: error)
            ]
        )
    }
}
