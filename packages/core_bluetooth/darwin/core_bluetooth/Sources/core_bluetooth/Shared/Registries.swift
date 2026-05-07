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

    func map(_ arguments: Any?) -> [String: Any?]? {
        arguments as? [String: Any?]
    }

    func objectKey(_ object: AnyObject) -> String {
        String(describing: Unmanaged.passUnretained(object).toOpaque())
    }

    func register(characteristic: CBCharacteristic) {
        characteristics[objectKey(characteristic)] = characteristic
        characteristic.descriptors?.forEach(register(descriptor:))
    }

    func unregister(characteristic: CBCharacteristic) {
        characteristics.removeValue(forKey: objectKey(characteristic))
        characteristicClientReferences.removeValue(forKey: objectKey(characteristic))
        characteristic.descriptors?.forEach(unregister(descriptor:))
    }

    func register(descriptor: CBDescriptor) {
        descriptors[objectKey(descriptor)] = descriptor
    }

    func unregister(descriptor: CBDescriptor) {
        descriptors.removeValue(forKey: objectKey(descriptor))
        descriptorClientReferences.removeValue(forKey: objectKey(descriptor))
    }

    func register(service: CBService) {
        services[objectKey(service)] = service
        service.includedServices?.forEach(register(service:))
        service.characteristics?.forEach(register(characteristic:))
    }

    func unregister(service: CBService) {
        services.removeValue(forKey: objectKey(service))
        serviceClientReferences.removeValue(forKey: objectKey(service))
        service.includedServices?.forEach(unregister(service:))
        service.characteristics?.forEach(unregister(characteristic:))
    }

    func peripheralManagerEntry(for peripheralManager: CBPeripheralManager) -> (Int, CBPeripheralManager)? {
        guard let entry = peripheralManagers.first(where: { $0.value === peripheralManager }) else {
            return nil
        }

        return (entry.key, entry.value)
    }
}
