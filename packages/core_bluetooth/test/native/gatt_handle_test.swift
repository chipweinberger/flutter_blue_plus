import CoreBluetooth
import Foundation
import FlutterMacOS

// Deliberately retain no services here: lifetime tests must allow allocator reuse.
private final class HandleTestServer: NSObject {
    @objc let state = 5
    @objc let isAdvertising = false
    var removals = 0
    var updates = 0
    @objc(addService:) func add(_ service: CBMutableService) {}
    @objc(removeService:) func remove(_ service: CBMutableService) { removals += 1 }
    @objc(updateValue:forCharacteristic:onSubscribedCentrals:)
    func update(_ value: NSData, characteristic: CBMutableCharacteristic, centrals: [CBCentral]?) -> Bool {
        updates += 1
        return true
    }
}

private final class EqualObjects: NSObject {
    override var hash: Int { 1 }
    override func isEqual(_ object: Any?) -> Bool { object is EqualObjects }
}

private func requireHandle(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

private func handleSuccess(_ result: Any?) {
    requireHandle(result == nil, "expected successful native operation")
}

private func retiredHandle(_ result: Any?) {
    requireHandle((result as? FlutterError)?.code == "invalid_args", "stale handles must be rejected")
}

private func testHandleIdentity() {
    let plugin = CoreBluetoothPlugin()
    let first = EqualObjects()
    let second = EqualObjects()
    requireHandle(first.isEqual(second), "the fixture must exercise equal objects with different identities")
    let firstHandle = plugin.objectKey(first)
    requireHandle(plugin.objectKey(first) == firstHandle, "live object handles must remain stable")
    requireHandle(plugin.objectKey(second) != firstHandle, "equal objects must still have distinct handles")
    weak var released: CBMutableService?
    autoreleasepool {
        let service = CBMutableService(type: CBUUID(string: "180f"), primary: true)
        released = service
        _ = plugin.objectKey(service)
    }
    requireHandle(released == nil, "identity lookup must not retain native GATT objects")
}

private func testLocalHandleLifetimes() {
    let plugin = CoreBluetoothPlugin()
    plugin.eventSink = { _ in }
    let server = HandleTestServer()
    let native = unsafeBitCast(server, to: CBPeripheralManager.self)
    plugin.peripheralManagers[1] = native
    var seen = Set<String>()
    var addresses: [UInt: String] = [:]
    var reusedAddresses = 0
    var retired: [String]?
    for iteration in 0..<2000 {
        weak var releasedService: CBMutableService?
        weak var releasedCharacteristic: CBCharacteristic?
        weak var releasedDescriptor: CBDescriptor?
        autoreleasepool {
            let raw: [String: Any] = ["uuid": iteration % 2 == 0 ? "180f" : "180a", "isPrimary": true,
                "clientReference": "service", "characteristics": [["uuid": "2a19", "properties": 18,
                    "permissions": 1, "clientReference": "characteristic", "descriptors": [
                        ["uuid": "2901", "value": "Value", "clientReference": "descriptor"]]]]]
            plugin.addService(arguments: ["managerId": 1, "service": raw], result: handleSuccess)
            let service = plugin.localServices[1]!.values.first!
            let characteristic = service.characteristics!.first!
            let descriptor = characteristic.descriptors!.first!
            releasedService = service
            releasedCharacteristic = characteristic
            releasedDescriptor = descriptor
            plugin.peripheralManager(native, didAdd: service, error: nil)
            let objects: [AnyObject] = [service, characteristic, descriptor]
            let handles = objects.map(plugin.objectKey)
            for (object, handle) in zip(objects, handles) {
                requireHandle(seen.insert(handle).inserted, "new native object lifetimes must never reuse handles")
                requireHandle(plugin.objectKey(object) == handle, "repeated lookup must preserve live identity")
                let address = UInt(bitPattern: Unmanaged.passUnretained(object).toOpaque())
                if let previous = addresses[address] {
                    reusedAddresses += 1
                    requireHandle(previous != handle, "allocator address reuse must not reuse a handle")
                }
                addresses[address] = handle
            }
            let snapshot = plugin.serviceSnapshot(service)
            let snapshotCharacteristics = snapshot["characteristics"] as! [[String: Any?]]
            let snapshotDescriptors = snapshotCharacteristics[0]["descriptors"] as! [[String: Any?]]
            requireHandle(snapshot["handle"] as? String == handles[0] &&
                          snapshotCharacteristics[0]["handle"] as? String == handles[1] &&
                          snapshotDescriptors[0]["handle"] as? String == handles[2],
                          "snapshots and local ownership graphs must use the same opaque handles")
            if let old = retired {
                let removals = server.removals
                let updates = server.updates
                plugin.removeService(arguments: ["managerId": 1, "serviceHandle": old[0]], result: retiredHandle)
                plugin.updateValue(arguments: ["managerId": 1, "characteristicHandle": old[1],
                    "value": FlutterStandardTypedData(bytes: Data([9]))], result: retiredHandle)
                requireHandle(plugin.descriptors[old[2]] == nil && server.removals == removals && server.updates == updates,
                              "stale handles must not reach replacement GATT objects")
            }
            plugin.updateValue(arguments: ["managerId": 1, "characteristicHandle": handles[1],
                "value": FlutterStandardTypedData(bytes: Data([1]))]) {
                requireHandle($0 as? Bool == true, "the replacement characteristic must remain usable")
            }
            plugin.removeService(arguments: ["managerId": 1, "serviceHandle": handles[0]], result: handleSuccess)
            requireHandle(plugin.services.isEmpty && plugin.characteristics.isEmpty && plugin.descriptors.isEmpty &&
                          plugin.serviceClientReferences.isEmpty && plugin.characteristicClientReferences.isEmpty &&
                          plugin.descriptorClientReferences.isEmpty && plugin.publishedLocalServices.isEmpty,
                          "removal must still release the complete local graph and metadata")
            retired = handles
        }
        requireHandle(releasedService == nil && releasedCharacteristic == nil && releasedDescriptor == nil,
                      "retired framework service, characteristic and descriptor objects must deallocate")
    }
    // Handle uniqueness is asserted for every lifetime even on allocators that
    // choose not to reuse addresses during this run; avoid an allocator-dependent test failure.
    print("GATT lifetime tests passed (6000 released attributes, \(reusedAddresses) reused addresses)")
}

func testGattHandleLifetimes() {
    testHandleIdentity()
    testLocalHandleLifetimes()
}
