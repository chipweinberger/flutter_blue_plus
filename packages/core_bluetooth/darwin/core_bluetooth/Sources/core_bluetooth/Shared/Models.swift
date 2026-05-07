import CoreBluetooth
import Foundation

struct OwnedATTRequest {
    let request: CBATTRequest
    let managerId: Int
    let batchId: UUID
    let handle = UUID().uuidString.lowercased()
}

struct LocalGattGraph {
    var services: [String: CBService] = [:]
    var characteristics: [String: CBCharacteristic] = [:]
    var descriptors: [String: CBDescriptor] = [:]

    init(_ roots: [CBService], key: (AnyObject) -> String) {
        func visit(_ service: CBService) {
            let handle = key(service)
            guard services[handle] == nil else { return }
            services[handle] = service
            for characteristic in service.characteristics ?? [] {
                characteristics[key(characteristic)] = characteristic
                for descriptor in characteristic.descriptors ?? [] {
                    descriptors[key(descriptor)] = descriptor
                }
            }
            service.includedServices?.forEach(visit)
        }

        roots.forEach(visit)
    }
}

final class CentralManagerBox {
    init(identifier: Int, centralManager: CBCentralManager) {
        self.identifier = identifier
        self.centralManager = centralManager
    }

    let identifier: Int
    let centralManager: CBCentralManager
    var isScanning = false
    var advertisementSampler = AdvertisementSampler()
    // The same UUID can have a different CBPeripheral in another manager.
    var peripherals: [UUID: CBPeripheral] = [:]
}
