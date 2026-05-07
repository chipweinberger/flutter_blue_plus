import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin {
    func createPeripheralManager(arguments: Any?, result: FlutterResult) {
        let managerId = nextManagerId
        nextManagerId += 1

        let optionsMap = (map(arguments)?["options"] as? [String: Any?]) ?? [:]
        let peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: peripheralManagerOptions(from: optionsMap)
        )
        peripheralManagers[managerId] = peripheralManager

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

    func disposePeripheralManager(arguments: Any?, result: FlutterResult) {
        guard let managerId = (map(arguments)?["managerId"] as? NSNumber)?.intValue else {
            result(nil)
            return
        }

        if let peripheralManager = peripheralManagers[managerId] {
            peripheralManager.stopAdvertising()
            services.values
                .compactMap { $0 as? CBMutableService }
                .forEach(unregister(service:))
        }

        peripheralManagers.removeValue(forKey: managerId)
        result(nil)
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
              let rawService = map(arguments)?["service"] as? [String: Any?],
              let service = mutableService(from: rawService) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager or service", details: nil))
            return
        }

        peripheralManagerEntry.peripheralManager.add(service)
        result(nil)
    }

    func removeService(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments),
              let serviceHandle = map(arguments)?["serviceHandle"] as? String,
              let service = services[serviceHandle] as? CBMutableService else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager or service", details: nil))
            return
        }

        peripheralManagerEntry.peripheralManager.remove(service)
        unregister(service: service)
        result(nil)
    }

    func removeAllServices(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager", details: nil))
            return
        }

        services.values
            .compactMap { $0 as? CBMutableService }
            .forEach(unregister(service:))
        peripheralManagerEntry.peripheralManager.removeAllServices()
        result(nil)
    }

    func updateValue(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments),
              let characteristicHandle = map(arguments)?["characteristicHandle"] as? String,
              let characteristic = characteristics[characteristicHandle] as? CBMutableCharacteristic,
              let value = map(arguments)?["value"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager, characteristic, or value", details: nil))
            return
        }

        let centralIdentifiers = ((map(arguments)?["centralIdentifiers"] as? [String]) ?? []).compactMap(UUID.init(uuidString:))
        let centrals: [CBCentral]? = centralIdentifiers.isEmpty
            ? nil
            : characteristic.subscribedCentrals?.filter { centralIdentifiers.contains($0.identifier) }
        result(peripheralManagerEntry.peripheralManager.updateValue(value.data, for: characteristic, onSubscribedCentrals: centrals))
    }

    func respondToRequest(arguments: Any?, result: FlutterResult) {
        guard let peripheralManagerEntry = peripheralManager(from: arguments),
              let requestHandle = map(arguments)?["requestHandle"] as? String,
              let request = attRequests[requestHandle],
              let rawResult = (map(arguments)?["result"] as? NSNumber)?.intValue,
              let attResult = CBATTError.Code(rawValue: rawResult) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager, request, or result", details: nil))
            return
        }

        if let value = map(arguments)?["value"] as? FlutterStandardTypedData {
            request.value = value.data
        } else if map(arguments)?["value"] is NSNull {
            request.value = nil
        }

        peripheralManagerEntry.peripheralManager.respond(to: request, withResult: attResult)
        attRequests.removeValue(forKey: requestHandle)
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

        let subscribedCentrals = services.values
            .compactMap { $0 as? CBMutableService }
            .flatMap { $0.characteristics ?? [] }
            .compactMap { $0 as? CBMutableCharacteristic }
            .flatMap { $0.subscribedCentrals ?? [] }
        guard let central = subscribedCentrals.first(where: { $0.identifier == centralIdentifier }) else {
            result(FlutterError(code: "invalid_args", message: "Central is not currently subscribed", details: nil))
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
              let rawPsm = (map(arguments)?["psm"] as? NSNumber)?.uint16Value else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral manager or PSM", details: nil))
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

    func mutableDescriptor(from map: [String: Any?]) -> CBMutableDescriptor? {
        guard let uuidString = map["uuid"] as? String else {
            return nil
        }

        let descriptor = CBMutableDescriptor(
            type: CBUUID(string: uuidString),
            value: map["value"] ?? nil
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

    func mutableService(from map: [String: Any?]) -> CBMutableService? {
        guard let uuidString = map["uuid"] as? String,
              let isPrimary = map["isPrimary"] as? Bool else {
            return nil
        }

        let service = CBMutableService(type: CBUUID(string: uuidString), primary: isPrimary)
        let includedServices = ((map["includedServices"] as? [[String: Any?]]) ?? []).compactMap(mutableService)
        let characteristics = ((map["characteristics"] as? [[String: Any?]]) ?? []).compactMap(mutableCharacteristic)
        service.includedServices = includedServices.isEmpty ? nil : includedServices
        service.characteristics = characteristics.isEmpty ? nil : characteristics
        if let clientReference = map["clientReference"] as? String {
            serviceClientReferences[objectKey(service)] = clientReference
        }
        return service
    }
}
