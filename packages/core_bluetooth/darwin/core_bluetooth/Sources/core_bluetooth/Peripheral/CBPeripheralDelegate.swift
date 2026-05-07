import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin: CBPeripheralDelegate {
    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralDidUpdateName",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral)
            ]
        )
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralIsReadyToSendWriteWithoutResponse",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral)
            ]
        )
    }

    @available(iOS 11.0, macOS 10.13, *)
    public func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralDidOpenL2CAPChannel",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "channel": channel.map(l2capChannelSnapshot),
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        register(service: service)
        let discoveredCharacteristics = (service.characteristics ?? []).map(characteristicSnapshot)

        emit(
            kind: "peripheralDidDiscoverCharacteristicsForService",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "serviceHandle": objectKey(service),
                "characteristics": discoveredCharacteristics,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        let serializedServices = invalidatedServices.map(serviceSnapshot)
        emit(
            kind: "peripheralDidModifyServices",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "invalidatedServices": serializedServices
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        register(service: service)
        let discoveredIncludedServices = (service.includedServices ?? []).map(serviceSnapshot)

        emit(
            kind: "peripheralDidDiscoverIncludedServicesForService",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "serviceHandle": objectKey(service),
                "includedServices": discoveredIncludedServices,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        register(characteristic: characteristic)
        let discoveredDescriptors = (characteristic.descriptors ?? []).map(descriptorSnapshot)

        emit(
            kind: "peripheralDidDiscoverDescriptorsForCharacteristic",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "characteristicHandle": objectKey(characteristic),
                "descriptors": discoveredDescriptors,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        let discoveredServices = (peripheral.services ?? []).map(serviceSnapshot)
        emit(
            kind: "peripheralDidDiscoverServices",
            managerId: managerId,
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
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralDidReadRSSI",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "rssi": RSSI,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralDidUpdateNotificationStateForCharacteristic",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "characteristicHandle": objectKey(characteristic),
                "isNotifying": characteristic.isNotifying,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralDidUpdateValueForCharacteristic",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "characteristicHandle": objectKey(characteristic),
                "value": characteristic.value,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralDidUpdateValueForDescriptor",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "descriptorHandle": objectKey(descriptor),
                "value": descriptor.value,
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralDidWriteValueForCharacteristic",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "characteristicHandle": objectKey(characteristic),
                "error": serialize(error: error)
            ]
        )
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard let managerId = managerId(for: peripheral) else {
            return
        }

        emit(
            kind: "peripheralDidWriteValueForDescriptor",
            managerId: managerId,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "descriptorHandle": objectKey(descriptor),
                "error": serialize(error: error)
            ]
        )
    }

    private func managerId(for peripheral: CBPeripheral) -> Int? {
        peripheralManagerIdsByPeripheralIdentifier[peripheral.identifier]
    }
}
