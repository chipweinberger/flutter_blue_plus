import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin {
    func manager(from arguments: Any?) -> CentralManagerBox? {
        guard let managerId = (map(arguments)?["managerId"] as? NSNumber)?.intValue else {
            return nil
        }
        return managers[managerId]
    }

    func hasOwner(_ peripheral: CBPeripheral) -> Bool {
        managers.values.contains { $0.peripherals[peripheral.identifier] === peripheral }
    }

    func remember(_ peripheral: CBPeripheral, for manager: CentralManagerBox) {
        manager.peripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
    }

    func removeRemoteAttributes(for peripheral: CBPeripheral) {
        pruneRemoteAttributes(for: peripheral, keeping: [])
    }

    func pruneRemoteAttributes(for peripheral: CBPeripheral) {
        pruneRemoteAttributes(for: peripheral, keeping: peripheral.services ?? [])
    }

    func removeL2CAPChannels(for managerId: Int, completion: @escaping () -> Void) {
        let group = DispatchGroup()
        for (handle, entry) in l2capChannels {
            guard entry.managerIds.remove(managerId) != nil, entry.managerIds.isEmpty else { continue }
            group.enter()
            entry.close {
                self.l2capChannels.removeValue(forKey: handle)
                group.leave()
            }
        }
        group.notify(queue: .main, execute: completion)
    }

    func map(_ arguments: Any?) -> [String: Any?]? {
        arguments as? [String: Any?]
    }

    func l2capPSM(from arguments: Any?) -> CBL2CAPPSM? {
        guard let number = map(arguments)?["psm"] as? NSNumber else { return nil }
        return CBL2CAPPSM(exactly: number.doubleValue)
    }

    func objectKey(_ object: AnyObject) -> String {
        if let handle = objectHandles.object(forKey: object) { return handle as String }
        let handle = UUID().uuidString.lowercased()
        objectHandles.setObject(handle as NSString, forKey: object)
        return handle
    }

    func localGatt(for managerId: Int) -> LocalGattGraph {
        let roots = localServices[managerId] ?? [:]
        return LocalGattGraph(Array(roots.values), key: objectKey)
    }

    func rememberLocalService(_ service: CBMutableService, for managerId: Int) {
        localServices[managerId, default: [:]][objectKey(service)] = service
        register(service: service)
        for characteristic in LocalGattGraph([service], key: objectKey).characteristics.values {
            (characteristic as? CBMutableCharacteristic)?.subscribedCentrals?.forEach {
                remember($0, forPeripheralManager: managerId)
            }
        }
    }

    func remember(_ central: CBCentral, forPeripheralManager managerId: Int) {
        guard peripheralManagers[managerId] != nil else { return }
        peripheralManagerCentrals[managerId, default: [:]][central.identifier] = central
    }

    func removeLocalServices(for managerId: Int, serviceHandle: String? = nil) {
        let previous = localGatt(for: managerId)
        if let handle = serviceHandle {
            localServices[managerId]?.removeValue(forKey: handle)
            publishedLocalServices[managerId]?.remove(handle)
            if publishedLocalServices[managerId]?.isEmpty == true {
                publishedLocalServices.removeValue(forKey: managerId)
            }
        } else {
            localServices.removeValue(forKey: managerId)
            publishedLocalServices.removeValue(forKey: managerId)
        }
        pruneLocalAttributes(previous)
    }

    func register(characteristic: CBCharacteristic) {
        characteristics[objectKey(characteristic)] = characteristic
        characteristic.descriptors?.forEach(register(descriptor:))
    }

    func register(descriptor: CBDescriptor) {
        descriptors[objectKey(descriptor)] = descriptor
    }

    func register(service: CBService) {
        var visited = Set<String>()
        register(service: service, visited: &visited)
    }

    private func register(service: CBService, visited: inout Set<String>) {
        guard visited.insert(objectKey(service)).inserted else { return }
        services[objectKey(service)] = service
        for included in service.includedServices ?? [] {
            register(service: included, visited: &visited)
        }
        service.characteristics?.forEach(register(characteristic:))
    }

    func peripheralManagerEntry(for peripheralManager: CBPeripheralManager) -> (Int, CBPeripheralManager)? {
        guard let entry = peripheralManagers.first(where: { $0.value === peripheralManager }) else {
            return nil
        }

        return (entry.key, entry.value)
    }

    func pruneLocalAttributes(_ previous: LocalGattGraph) {
        let current = LocalGattGraph(localServices.values.flatMap { $0.values }, key: objectKey)
        for handle in previous.descriptors.keys where current.descriptors[handle] == nil {
            descriptors.removeValue(forKey: handle)
            descriptorClientReferences.removeValue(forKey: handle)
        }
        for handle in previous.characteristics.keys where current.characteristics[handle] == nil {
            characteristics.removeValue(forKey: handle)
            characteristicClientReferences.removeValue(forKey: handle)
        }
        for handle in previous.services.keys where current.services[handle] == nil {
            services.removeValue(forKey: handle)
            serviceClientReferences.removeValue(forKey: handle)
        }
    }

    private func pruneRemoteAttributes(for peripheral: CBPeripheral, keeping roots: [CBService]) {
        var serviceHandles = Set<String>()
        var characteristicHandles = Set<String>()
        var descriptorHandles = Set<String>()

        func visit(_ service: CBService) {
            guard serviceHandles.insert(objectKey(service)).inserted else { return }
            service.includedServices?.forEach(visit)
            for characteristic in service.characteristics ?? [] {
                characteristicHandles.insert(objectKey(characteristic))
                for descriptor in characteristic.descriptors ?? [] {
                    descriptorHandles.insert(objectKey(descriptor))
                }
            }
        }

        roots.forEach(visit)
        // An included service may still be reachable through another parent.
        // Remove children first, while their weak parent links still resolve.
        // Preserve local GATT and objects belonging to other peripherals.
        descriptors = descriptors.filter { handle, descriptor in
            guard let owner = descriptor.characteristic?.service?.peripheral else {
                return descriptor is CBMutableDescriptor
            }
            return owner !== peripheral || descriptorHandles.contains(handle)
        }
        characteristics = characteristics.filter { handle, characteristic in
            guard let owner = characteristic.service?.peripheral else {
                return characteristic is CBMutableCharacteristic
            }
            return owner !== peripheral || characteristicHandles.contains(handle)
        }
        services = services.filter { handle, service in
            guard let owner = service.peripheral else { return service is CBMutableService }
            return owner !== peripheral || serviceHandles.contains(handle)
        }
    }
}
