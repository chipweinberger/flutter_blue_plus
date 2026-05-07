import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin {
    func serialize(scanOptions: [String: Any]?) -> [String: Any?]? {
        guard let scanOptions else {
            return nil
        }

        var serialized: [String: Any?] = [:]

        if let allowDuplicates = scanOptions[CBCentralManagerScanOptionAllowDuplicatesKey] as? Bool {
            serialized["allowDuplicates"] = allowDuplicates
        }

        if let solicitedServiceUUIDs = scanOptions[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] as? [CBUUID] {
            serialized["solicitedServiceUUIDs"] = solicitedServiceUUIDs.map { $0.uuidString.lowercased() }
        }

        return serialized.isEmpty ? nil : serialized
    }

    func serialize(advertisingData: [String: Any]?) -> [String: Any?]? {
        guard let advertisingData else {
            return nil
        }

        var serialized: [String: Any?] = [:]

        if let localName = advertisingData[CBAdvertisementDataLocalNameKey] as? String {
            serialized["localName"] = localName
        }

        if let serviceUUIDs = advertisingData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            serialized["serviceUUIDs"] = serviceUUIDs.map { $0.uuidString.lowercased() }
        }

        return serialized.isEmpty ? nil : serialized
    }

    func serviceSnapshot(_ service: CBService) -> [String: Any?] {
        register(service: service)
        return serviceSnapshot(service, visited: [])
    }

    private func serviceSnapshot(_ service: CBService, visited: Set<String>) -> [String: Any?] {
        let path = visited.union([objectKey(service)])
        return [
            "clientReference": serviceClientReferences[objectKey(service)],
            "handle": objectKey(service),
            "uuid": service.uuid.uuidString.lowercased(),
            "isPrimary": service.isPrimary,
            "includedServices": service.includedServices?.filter { !path.contains(objectKey($0)) }.map {
                serviceSnapshot($0, visited: path)
            },
            "characteristics": service.characteristics?.map(characteristicSnapshot)
        ]
    }

    func characteristicSnapshot(_ characteristic: CBCharacteristic) -> [String: Any?] {
        register(characteristic: characteristic)
        return [
            "clientReference": characteristicClientReferences[objectKey(characteristic)],
            "handle": objectKey(characteristic),
            "uuid": characteristic.uuid.uuidString.lowercased(),
            "properties": characteristic.properties.rawValue,
            "permissions": (characteristic as? CBMutableCharacteristic)?.permissions.rawValue,
            "isBroadcasted": characteristic.isBroadcasted,
            "isNotifying": characteristic.isNotifying,
            "value": characteristic.value,
            "descriptors": characteristic.descriptors?.map(descriptorSnapshot),
            "subscribedCentrals": (characteristic as? CBMutableCharacteristic)?.subscribedCentrals?.map(centralSnapshot)
        ]
    }

    func descriptorSnapshot(_ descriptor: CBDescriptor) -> [String: Any?] {
        register(descriptor: descriptor)
        return [
            "clientReference": descriptorClientReferences[objectKey(descriptor)],
            "handle": objectKey(descriptor),
            "uuid": descriptor.uuid.uuidString.lowercased(),
            "value": descriptor.value
        ]
    }

    func centralSnapshot(_ central: CBCentral) -> [String: Any?] {
        [
            "identifier": central.identifier.uuidString.lowercased(),
            "maximumUpdateValueLength": central.maximumUpdateValueLength
        ]
    }

    func attRequestSnapshot(_ request: CBATTRequest, managerId: Int, batchId: UUID = UUID()) -> [String: Any?] {
        remember(request.central, forPeripheralManager: managerId)
        let entry = attRequests.values.first { $0.request === request && $0.managerId == managerId }
            ?? OwnedATTRequest(request: request, managerId: managerId, batchId: batchId)
        attRequests[entry.handle] = entry

        return [
            "requestHandle": entry.handle,
            "central": centralSnapshot(request.central),
            "characteristicHandle": objectKey(request.characteristic),
            "offset": request.offset,
            "value": request.value
        ]
    }

    func l2capChannelSnapshot(_ channel: CBL2CAPChannel, managerIds: Set<Int>) -> [String: Any?] {
        let entry = l2capChannels.values.first { $0.channel === channel }
            ?? L2CAPChannelBox(channel: channel, managerIds: managerIds)
        entry.managerIds.formUnion(managerIds)
        if !entry.isClosed { l2capChannels[entry.handle] = entry }
        let peerPeripheral = channel.peer as? CBPeripheral
        let peerCentral = channel.peer as? CBCentral

        return [
            "handle": entry.handle,
            "psm": channel.psm,
            "peerKind": peerPeripheral != nil ? "peripheral" : (peerCentral != nil ? "central" : nil),
            "peerIdentifier": peerPeripheral?.identifier.uuidString.lowercased() ?? peerCentral?.identifier.uuidString.lowercased(),
            "peerName": peerPeripheral?.name,
            "peerState": peerPeripheral?.state.rawValue,
            "peerCanSendWriteWithoutResponse": peerPeripheral?.canSendWriteWithoutResponse,
            "peerAncsAuthorized": {
#if !os(macOS)
                if #available(iOS 13.0, *) {
                    return peerPeripheral?.ancsAuthorized
                }
#endif
                return nil
            }(),
            "peerMaximumUpdateValueLength": peerCentral?.maximumUpdateValueLength
        ]
    }

    func emit(kind: String, managerId: Int, payload: [String: Any?]) {
        sendEvent([
            "kind": kind,
            "managerId": managerId,
            "payload": payload
        ])
    }

    func emit(kind: String, peripheral: CBPeripheral, payload: [String: Any?]) {
        for manager in managers.values where manager.peripherals[peripheral.identifier] === peripheral {
            emit(kind: kind, managerId: manager.identifier, payload: payload)
        }
    }

    func emit(kind: String, payload: [String: Any?], peripheralManagerId: Int) {
        sendEvent([
            "kind": kind,
            "peripheralManagerId": peripheralManagerId,
            "payload": payload
        ])
    }

    func serialize(error: Error?) -> [String: Any?]? {
        guard let nsError = error as NSError? else {
            return nil
        }

        return [
            "domain": nsError.domain,
            "code": nsError.code,
            "localizedDescription": nsError.localizedDescription
        ]
    }

    func managerSnapshot(for manager: CentralManagerBox) -> [String: Any?] {
        [
            "managerId": manager.identifier,
            "authorization": Self.authorizationRawValue,
            "state": manager.centralManager.state.rawValue,
            "isScanning": manager.isScanning
        ]
    }

    func peripheralManagerSnapshot(for identifier: Int, peripheralManager: CBPeripheralManager) -> [String: Any?] {
        [
            "managerId": identifier,
            "authorization": Self.peripheralManagerAuthorizationRawValue,
            "state": peripheralManager.state.rawValue,
            "isAdvertising": peripheralManager.isAdvertising
        ]
    }

    func peripheralSnapshot(_ peripheral: CBPeripheral) -> [String: Any?] {
        let ancsAuthorized: Bool = {
#if !os(macOS)
            if #available(iOS 13.0, *) {
                return peripheral.ancsAuthorized
            }
#endif
            return false
        }()

        return [
            "ancsAuthorized": ancsAuthorized,
            "canSendWriteWithoutResponse": peripheral.canSendWriteWithoutResponse,
            "identifier": peripheral.identifier.uuidString.lowercased(),
            "name": peripheral.name,
            "state": peripheral.state.rawValue
        ]
    }
}

extension CoreBluetoothPlugin {
    static var authorizationRawValue: Int {
        if #available(iOS 13.1, macOS 10.15, *) {
            return CBCentralManager.authorization.rawValue
        } else {
            return 3
        }
    }

    static var peripheralManagerAuthorizationRawValue: Int {
        if #available(iOS 13.1, macOS 10.15, *) {
            return CBPeripheralManager.authorization.rawValue
        } else {
            return CBPeripheralManager.authorizationStatus().rawValue
        }
    }
}
