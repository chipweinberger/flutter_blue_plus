import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin {
    func sharedPeripheralManagerSnapshot(for identifier: Int, peripheralManager: CBPeripheralManager) -> [String: Any?] {
        var snapshot = peripheralManagerSnapshot(for: identifier, peripheralManager: peripheralManager)
        let roots = localServices[identifier] ?? [:]
        let published = publishedLocalServices[identifier] ?? []
        snapshot["services"] = roots.filter { published.contains($0.key) }.values.map(serviceSnapshot)
        snapshot["pendingServices"] = roots.filter { !published.contains($0.key) }.values.map(serviceSnapshot)
        return snapshot
    }

    func createPeripheralManager(arguments: Any?, result: FlutterResult) {
        let shared = map(arguments)?["shared"] as? Bool ?? false
        if shared, let identifier = sharedPeripheralManagerId, let manager = peripheralManagers[identifier] {
            result(sharedPeripheralManagerSnapshot(for: identifier, peripheralManager: manager))
            return
        }
        let managerId = nextManagerId
        nextManagerId += 1

        let optionsMap = (map(arguments)?["options"] as? [String: Any?]) ?? [:]
        let peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: peripheralManagerOptions(from: optionsMap)
        )
        peripheralManagers[managerId] = peripheralManager
        if shared { sharedPeripheralManagerId = managerId }

        result(peripheralManagerSnapshot(for: managerId, peripheralManager: peripheralManager))
    }

    func peripheralManagerOptions(from options: [String: Any?]) -> [String: Any]? {
        var resolved: [String: Any] = [:]

        if let showPowerAlert = options["showPowerAlert"] as? Bool {
            resolved[CBPeripheralManagerOptionShowPowerAlertKey] = showPowerAlert
        }

        if let restoreIdentifier = options["restoreIdentifier"] as? String, restoreIdentifier.isEmpty == false {
            resolved[CBPeripheralManagerOptionRestoreIdentifierKey] = restoreIdentifier
        }

        return resolved.isEmpty ? nil : resolved
    }

    func disposePeripheralManager(arguments: Any?, result: @escaping FlutterResult) {
        guard let managerId = (map(arguments)?["managerId"] as? NSNumber)?.intValue else {
            result(nil)
            return
        }

        if let peripheralManager = peripheralManagers.removeValue(forKey: managerId) {
            peripheralManager.stopAdvertising()
        }
        if sharedPeripheralManagerId == managerId { sharedPeripheralManagerId = nil }
        removeLocalServices(for: managerId)
        peripheralManagerCentrals.removeValue(forKey: managerId)
        attRequests = attRequests.filter { $0.value.managerId != managerId }
        removeL2CAPChannels(for: managerId) { result(nil) }
    }

    func peripheralManager(from arguments: Any?) -> (id: Int, peripheralManager: CBPeripheralManager)? {
        guard let managerId = (map(arguments)?["managerId"] as? NSNumber)?.intValue,
              let peripheralManager = peripheralManagers[managerId] else {
            return nil
        }

        return (managerId, peripheralManager)
    }

    func startAdvertising(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager", details: nil))
            return
        }

        let advertisingData = advertisingData(from: map(arguments)?["advertisementData"] as? [String: Any?])
        peripheralManagerEntry.peripheralManager.startAdvertising(advertisingData)
        result(nil)
    }

    func addService(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments),
              let rawService = map(arguments)?["service"] as? [String: Any?] else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager or service", details: nil))
            return
        }

        let owned = localGatt(for: peripheralManagerEntry.id).services
        guard canBuildService(rawService, owned: owned) else {
            result(FlutterError(code: "invalid_args", message: "Service belongs to another manager", details: nil))
            return
        }
        var byReference: [String: CBMutableService] = [:]
        for (handle, service) in owned {
            if let reference = serviceClientReferences[handle], let service = service as? CBMutableService {
                byReference[reference] = service
            }
        }
        var checkedReferences = Set(byReference.keys)
        if let error = serviceDescriptorError(in: rawService, owned: owned, checkedReferences: &checkedReferences) {
            result(FlutterError(code: "invalid_args", message: error, details: nil))
            return
        }
        guard let service = mutableService(from: rawService, owned: owned, byReference: &byReference) else {
            result(FlutterError(code: "invalid_args", message: "Missing service UUID or primary flag", details: nil))
            return
        }

        rememberLocalService(service, for: peripheralManagerEntry.id)
        peripheralManagerEntry.peripheralManager.add(service)
        result(nil)
    }

    func removeService(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments),
              let serviceHandle = map(arguments)?["serviceHandle"] as? String,
              let service = localServices[peripheralManagerEntry.id]?[serviceHandle] else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager or service", details: nil))
            return
        }

        peripheralManagerEntry.peripheralManager.remove(service)
        removeLocalServices(for: peripheralManagerEntry.id, serviceHandle: serviceHandle)
        result(nil)
    }

    func removeAllServices(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager", details: nil))
            return
        }

        removeLocalServices(for: peripheralManagerEntry.id)
        peripheralManagerEntry.peripheralManager.removeAllServices()
        result(nil)
    }

    func updateValue(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments),
              let characteristicHandle = map(arguments)?["characteristicHandle"] as? String,
              let characteristic = localGatt(for: peripheralManagerEntry.id).characteristics[characteristicHandle]
                as? CBMutableCharacteristic,
              let value = map(arguments)?["value"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager, characteristic, or value", details: nil))
            return
        }

        let centrals: [CBCentral]?
        if let identifiers = map(arguments)?["centralIdentifiers"] as? [String] {
            let selected = Set(identifiers.compactMap(UUID.init(uuidString:)))
            centrals = (characteristic.subscribedCentrals ?? []).filter { selected.contains($0.identifier) }
        } else {
            // Only an omitted/null list requests all subscribers. An empty selection stays empty.
            centrals = nil
        }
        result(peripheralManagerEntry.peripheralManager.updateValue(value.data, for: characteristic, onSubscribedCentrals: centrals))
    }

    func respondToRequest(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments),
              let requestHandle = map(arguments)?["requestHandle"] as? String,
              let entry = attRequests[requestHandle], entry.managerId == peripheralManagerEntry.id,
              let rawResult = (map(arguments)?["result"] as? NSNumber)?.intValue,
              let attResult = CBATTError.Code(rawValue: rawResult) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager, request, or result", details: nil))
            return
        }

        let request = entry.request
        if let value = map(arguments)?["value"] as? FlutterStandardTypedData {
            request.value = value.data
        } else if map(arguments)?["value"] is NSNull {
            request.value = nil
        }

        peripheralManagerEntry.peripheralManager.respond(to: request, withResult: attResult)
        // CoreBluetooth accepts one reply for the entire didReceiveWrite batch.
        attRequests = attRequests.filter { $0.value.managerId != entry.managerId || $0.value.batchId != entry.batchId }
        result(nil)
    }

    func setDesiredConnectionLatency(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments),
              let centralIdentifierString = map(arguments)?["centralIdentifier"] as? String,
              let centralIdentifier = UUID(uuidString: centralIdentifierString),
              let rawLatency = (map(arguments)?["latency"] as? NSNumber)?.intValue,
              let latency = CBPeripheralManagerConnectionLatency(rawValue: rawLatency) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager, central, or latency", details: nil))
            return
        }

        let subscribedCentrals = localGatt(for: peripheralManagerEntry.id).characteristics.values
            .compactMap { $0 as? CBMutableCharacteristic }
            .flatMap { $0.subscribedCentrals ?? [] }
        // Restored subscribers may not have produced a subscription callback in this session.
        subscribedCentrals.forEach { remember($0, forPeripheralManager: peripheralManagerEntry.id) }
        guard let central = peripheralManagerCentrals[peripheralManagerEntry.id]?[centralIdentifier] else {
            result(FlutterError(code: "invalid_args", message: "Central is not known to this peripheral manager", details: nil))
            return
        }

        peripheralManagerEntry.peripheralManager.setDesiredConnectionLatency(latency, for: central)
        result(nil)
    }

    func publishL2CAPChannel(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments),
              let withEncryption = map(arguments)?["withEncryption"] as? Bool else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager or encryption flag", details: nil))
            return
        }

        if #available(iOS 11.0, macOS 10.13, *) {
            peripheralManagerEntry.peripheralManager.publishL2CAPChannel(withEncryption: withEncryption)
        }
        result(nil)
    }

    func unpublishL2CAPChannel(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments),
              let rawPsm = l2capPSM(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager or invalid PSM (expected an integer from 0 to 65535)", details: nil))
            return
        }

        if #available(iOS 11.0, macOS 10.13, *) {
            peripheralManagerEntry.peripheralManager.unpublishL2CAPChannel(rawPsm)
        }
        result(nil)
    }

    func stopAdvertising(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager", details: nil))
            return
        }

        peripheralManagerEntry.peripheralManager.stopAdvertising()
        result(nil)
    }

    func advertisingData(from data: [String: Any?]?) -> [String: Any]? {
        guard let data else {
            return nil
        }

        var resolved: [String: Any] = [:]

        if let localName = data["localName"] as? String {
            resolved[CBAdvertisementDataLocalNameKey] = localName
        }

        if let serviceUUIDs = data["serviceUUIDs"] as? [String] {
            resolved[CBAdvertisementDataServiceUUIDsKey] = serviceUUIDs.map(CBUUID.init(string:))
        }

        return resolved.isEmpty ? nil : resolved
    }

    func descriptorValueError(in map: [String: Any?]) -> String? {
        guard let uuidString = map["uuid"] as? String else { return nil }
        let type = CBUUID(string: uuidString)
        let value = map["value"] ?? nil
        let data = (value as? FlutterStandardTypedData)?.data ?? value as? Data
        if type == CBUUID(string: CBUUIDCharacteristicUserDescriptionString) {
            return value is String ? nil : "User Description descriptor (0x2901) requires a String value"
        }
        if type == CBUUID(string: CBUUIDCharacteristicFormatString), data == nil {
            return "Presentation Format descriptor (0x2904) requires byte data"
        }
        if type == CBUUID(string: "2906") {
            guard let data, data.count.isMultiple(of: 2) else {
                return "Valid Range descriptor (0x2906) requires an even number of bytes"
            }
        }
        if type.data.count == 16, data == nil {
            return "128-bit descriptors require byte data"
        }
        return nil
    }

    func mutableDescriptor(from map: [String: Any?]) -> CBMutableDescriptor? {
        guard let uuidString = map["uuid"] as? String, descriptorValueError(in: map) == nil else {
            return nil
        }

        let value: Any?
        if let bytes = map["value"] as? FlutterStandardTypedData {
            value = bytes.data
        } else {
            value = map["value"] ?? nil
        }
        let descriptor = CBMutableDescriptor(
            type: CBUUID(string: uuidString),
            value: value
        )
        if let clientReference = map["clientReference"] as? String {
            descriptorClientReferences[objectKey(descriptor)] = clientReference
        }
        return descriptor
    }

    func mutableCharacteristic(from map: [String: Any?]) -> CBMutableCharacteristic? {
        guard let uuidString = map["uuid"] as? String else {
            return nil
        }

        let value = (map["value"] as? FlutterStandardTypedData)?.data
        let properties = CBCharacteristicProperties(rawValue: (map["properties"] as? NSNumber)?.uintValue ?? 0)
        let permissions = CBAttributePermissions(rawValue: (map["permissions"] as? NSNumber)?.uintValue ?? 0)
        let descriptors = ((map["descriptors"] as? [[String: Any?]]) ?? []).compactMap(mutableDescriptor)

        let characteristic = CBMutableCharacteristic(
            type: CBUUID(string: uuidString),
            properties: properties,
            value: value,
            permissions: permissions
        )
        characteristic.descriptors = descriptors.isEmpty ? nil : descriptors
        if let clientReference = map["clientReference"] as? String {
            characteristicClientReferences[objectKey(characteristic)] = clientReference
        }
        return characteristic
    }

    func canBuildService(_ map: [String: Any?], owned: [String: CBService]) -> Bool {
        if let handle = map["handle"] as? String, services[handle] != nil, owned[handle] == nil {
            return false
        }
        let included = (map["includedServices"] as? [[String: Any?]]) ?? []
        return included.allSatisfy { canBuildService($0, owned: owned) }
    }

    func serviceDescriptorError(in map: [String: Any?], owned: [String: CBService],
                                checkedReferences: inout Set<String>) -> String? {
        // The builder reuses these objects and ignores their serialized definitions.
        if let handle = map["handle"] as? String, owned[handle] is CBMutableService { return nil }
        if let reference = map["clientReference"] as? String, checkedReferences.contains(reference) { return nil }
        guard map["uuid"] is String, map["isPrimary"] is Bool else { return nil }
        if let reference = map["clientReference"] as? String { checkedReferences.insert(reference) }
        for included in (map["includedServices"] as? [[String: Any?]]) ?? [] {
            if let error = serviceDescriptorError(in: included, owned: owned, checkedReferences: &checkedReferences) {
                return error
            }
        }
        for characteristic in (map["characteristics"] as? [[String: Any?]]) ?? [] {
            guard characteristic["uuid"] is String else { continue }
            for descriptor in (characteristic["descriptors"] as? [[String: Any?]]) ?? [] {
                if let error = descriptorValueError(in: descriptor) { return error }
            }
        }
        return nil
    }

    func mutableService(from map: [String: Any?], owned: [String: CBService],
                        byReference: inout [String: CBMutableService]) -> CBMutableService? {
        if let handle = map["handle"] as? String, let service = owned[handle] as? CBMutableService {
            return service
        }
        if let reference = map["clientReference"] as? String, let service = byReference[reference] {
            return service
        }
        guard let uuidString = map["uuid"] as? String,
              let isPrimary = map["isPrimary"] as? Bool else {
            return nil
        }

        let service = CBMutableService(type: CBUUID(string: uuidString), primary: isPrimary)
        if let clientReference = map["clientReference"] as? String {
            serviceClientReferences[objectKey(service)] = clientReference
            byReference[clientReference] = service
        }
        let includedServices = ((map["includedServices"] as? [[String: Any?]]) ?? []).compactMap {
            mutableService(from: $0, owned: owned, byReference: &byReference)
        }
        let characteristics = ((map["characteristics"] as? [[String: Any?]]) ?? []).compactMap(mutableCharacteristic)
        service.includedServices = includedServices.isEmpty ? nil : includedServices
        service.characteristics = characteristics.isEmpty ? nil : characteristics
        return service
    }
}
