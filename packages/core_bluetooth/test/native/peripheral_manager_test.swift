import CoreBluetooth
import Foundation
import ObjectiveC
import FlutterMacOS

private final class ServerManagerDouble: NSObject {
    var added: [CBMutableService] = []
    var removed: [CBMutableService] = []
    var updated: [CBMutableCharacteristic] = []
    var updateRecipients: [[CBCentral]?] = []
    var responses: [CBATTRequest] = []
    var latencyRequests: [(Int, CBCentral)] = []
    @objc var state = 5
    @objc var isAdvertising = false
    var stopped = false
    var cleared = false

    @objc(startAdvertising:) func startAdvertising(_ options: NSDictionary?) { isAdvertising = true }
    @objc func stopAdvertising() { stopped = true; isAdvertising = false }
    @objc func removeAllServices() { cleared = true }
    @objc(addService:) func add(_ service: CBMutableService) { added.append(service) }
    @objc(removeService:) func remove(_ service: CBMutableService) { removed.append(service) }
    @objc(updateValue:forCharacteristic:onSubscribedCentrals:)
    func update(_ value: NSData, characteristic: CBMutableCharacteristic, centrals: [CBCentral]?) -> Bool {
        updated.append(characteristic)
        updateRecipients.append(centrals)
        return true
    }
    @objc(respondToRequest:withResult:)
    func respond(_ request: CBATTRequest, result: Int) { responses.append(request) }
    @objc(setDesiredConnectionLatency:forCentral:)
    func setLatency(_ latency: Int, central: CBCentral) { latencyRequests.append((latency, central)) }
}

private final class ServerCentralDouble: NSObject {
    @objc let identifier: UUID
    @objc let maximumUpdateValueLength = 20
    init(identifier: UUID = UUID()) { self.identifier = identifier }
    override func isKind(of aClass: AnyClass) -> Bool { aClass == CBCentral.self || super.isKind(of: aClass) }
}

private final class ServerChannelDouble: NSObject {
    @objc(PSM) let psm: UInt16 = 1234
    @objc let peer: CBCentral
    @objc let inputStream: InputStream? = nil
    @objc let outputStream: OutputStream? = nil
    init(peer: CBCentral) { self.peer = peer }
}

private final class SubscribedCharacteristic: CBMutableCharacteristic {
    var subscribers: [CBCentral]?
    override var subscribedCentrals: [CBCentral]? { subscribers }
}

private final class ServerRequestDouble: NSObject {
    @objc let central: CBCentral
    @objc let characteristic: CBCharacteristic
    @objc let offset = 0
    @objc var value: Data? = Data([0])

    init(_ characteristic: CBCharacteristic,
         central: CBCentral = unsafeBitCast(ServerCentralDouble(), to: CBCentral.self)) {
        self.characteristic = characteristic
        self.central = central
    }
}

private func requireServer(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

private func serverSuccess(_ result: Any?) {
    requireServer(result == nil, "server operation must succeed: \(String(describing: result))")
}

private func serverInvalid(_ result: Any?) {
    requireServer((result as? FlutterError)?.code == "invalid_args", "foreign or retired handles must be rejected")
}

private final class ServerFixture {
    let plugin = CoreBluetoothPlugin()
    let managers = [1: ServerManagerDouble(), 2: ServerManagerDouble()]
    var events: [[String: Any?]] = []

    var payload: [String: Any?] { events.last?["payload"] as? [String: Any?] ?? [:] }

    init() {
        plugin.eventSink = { [weak self] event in
            if let event = event as? [String: Any?] { self?.events.append(event) }
        }
        for (id, manager) in managers {
            plugin.peripheralManagers[id] = unsafeBitCast(manager, to: CBPeripheralManager.self)
        }
    }

    func native(_ id: Int) -> CBPeripheralManager {
        unsafeBitCast(managers[id]!, to: CBPeripheralManager.self)
    }

    func add(_ id: Int, error: Error? = nil, complete: Bool = true) -> CBMutableService {
        let raw: [String: Any] = ["uuid": "180f", "isPrimary": true, "clientReference": "service-\(id)",
            "characteristics": [["uuid": "2a19", "properties": 10, "permissions": 3,
                "clientReference": "characteristic-\(id)",
                "descriptors": [["uuid": "2901", "value": "Test", "clientReference": "descriptor-\(id)"]]]]]
        plugin.addService(arguments: ["managerId": id, "service": raw], result: serverSuccess)
        let service = managers[id]!.added.last!
        if complete { plugin.peripheralManager(native(id), didAdd: service, error: error) }
        return service
    }

    func read(_ id: Int, characteristic: CBCharacteristic) -> (ServerRequestDouble, String) {
        let request = ServerRequestDouble(characteristic)
        plugin.peripheralManager(native(id), didReceiveRead: unsafeBitCast(request, to: CBATTRequest.self))
        return (request, payload["requestHandle"] as! String)
    }
}

private func testServerHandleOwnership() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let first = fixture.add(1)
    let second = fixture.add(2)
    let characteristic = second.characteristics!.first!
    let secondHandle = plugin.objectKey(second)
    let value = FlutterStandardTypedData(bytes: Data([7]))
    plugin.removeService(arguments: ["managerId": 1, "serviceHandle": secondHandle], result: serverInvalid)
    plugin.updateValue(arguments: ["managerId": 1, "characteristicHandle": plugin.objectKey(characteristic),
                                   "value": value], result: serverInvalid)
    requireServer(fixture.managers[1]!.removed.isEmpty && fixture.managers[1]!.updated.isEmpty,
                  "foreign handles must not reach native operations")
    plugin.updateValue(arguments: ["managerId": 2, "characteristicHandle": plugin.objectKey(characteristic),
                                   "value": value]) {
        requireServer($0 as? Bool == true, "the owning manager must still update its characteristic")
    }
    plugin.removeService(arguments: ["managerId": 1, "serviceHandle": plugin.objectKey(first)], result: serverSuccess)
    requireServer(plugin.services[plugin.objectKey(first)] == nil && plugin.services[secondHandle] === second,
                  "removing one service must preserve another manager's service")
    plugin.peripheralManager(fixture.native(1), didAdd: first, error: nil)
    requireServer(plugin.services[plugin.objectKey(first)] == nil, "a late add callback must not revive removed services")
}

private func testServerCleanupIsolation() {
    for dispose in [false, true] {
        let fixture = ServerFixture()
        let plugin = fixture.plugin
        let first = fixture.add(1)
        let second = fixture.add(2)
        let firstCharacteristic = first.characteristics!.first!
        let secondCharacteristic = second.characteristics!.first!
        let firstDescriptor = firstCharacteristic.descriptors!.first!
        let secondDescriptor = secondCharacteristic.descriptors!.first!
        if dispose {
            plugin.disposePeripheralManager(arguments: ["managerId": 1], result: serverSuccess)
        } else {
            plugin.removeAllServices(arguments: ["managerId": 1], result: serverSuccess)
        }
        requireServer(plugin.services[plugin.objectKey(first)] == nil &&
                      plugin.characteristics[plugin.objectKey(firstCharacteristic)] == nil &&
                      plugin.descriptors[plugin.objectKey(firstDescriptor)] == nil, "only the owning graph must be removed")
        requireServer(plugin.serviceClientReferences[plugin.objectKey(first)] == nil &&
                      plugin.characteristicClientReferences[plugin.objectKey(firstCharacteristic)] == nil &&
                      plugin.descriptorClientReferences[plugin.objectKey(firstDescriptor)] == nil,
                      "cleanup must release the owner's client-reference metadata")
        requireServer(plugin.services[plugin.objectKey(second)] === second &&
                      plugin.characteristics[plugin.objectKey(secondCharacteristic)] === secondCharacteristic &&
                      plugin.descriptors[plugin.objectKey(secondDescriptor)] === secondDescriptor,
                      "another manager's entire graph must remain registered")
        requireServer(plugin.serviceClientReferences[plugin.objectKey(second)] == "service-2" &&
                      plugin.characteristicClientReferences[plugin.objectKey(secondCharacteristic)] == "characteristic-2" &&
                      plugin.descriptorClientReferences[plugin.objectKey(secondDescriptor)] == "descriptor-2",
                      "another manager's identity metadata must remain intact")
    }
}

private func testServerRequestOwnership() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let first = fixture.add(1)
    let second = fixture.add(2)
    let (request, handle) = fixture.read(1, characteristic: first.characteristics!.first!)
    let value = FlutterStandardTypedData(bytes: Data([7]))
    plugin.respondToRequest(arguments: ["managerId": 2, "requestHandle": handle, "result": 0, "value": value],
                            result: serverInvalid)
    requireServer(request.value == Data([0]) && plugin.attRequests[handle] != nil && fixture.managers[2]!.responses.isEmpty,
                  "a foreign manager must not mutate, consume or respond to another manager's request")
    plugin.respondToRequest(arguments: ["managerId": 1, "requestHandle": handle, "result": 0, "value": value],
                            result: serverSuccess)
    requireServer(request.value == Data([7]) && plugin.attRequests[handle] == nil && fixture.managers[1]!.responses.count == 1,
                  "the owner must respond once and release the request handle")
    plugin.respondToRequest(arguments: ["managerId": 1, "requestHandle": handle, "result": 0], result: serverInvalid)

    // Reusing the native object after release must not reuse its retired handle.
    plugin.peripheralManager(fixture.native(1), didReceiveRead: unsafeBitCast(request, to: CBATTRequest.self))
    let replacementHandle = fixture.payload["requestHandle"] as! String
    requireServer(replacementHandle != handle, "new ATT lifetimes need distinct handles")
    let (_, otherHandle) = fixture.read(2, characteristic: second.characteristics!.first!)
    plugin.disposePeripheralManager(arguments: ["managerId": 1], result: serverSuccess)
    requireServer(plugin.attRequests[replacementHandle] == nil && plugin.attRequests[otherHandle] != nil,
                  "disposal must clear only its own pending requests")
    plugin.respondToRequest(arguments: ["managerId": 2, "requestHandle": otherHandle, "result": 0], result: serverSuccess)
    requireServer(plugin.attRequests.isEmpty, "the remaining manager's request must still be usable")
}

private func testServerPendingRequestRelease() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let service = fixture.add(1)
    let characteristic = service.characteristics!.first!
    weak var read: ServerRequestDouble?
    weak var write: ServerRequestDouble?
    autoreleasepool {
        let (request, _) = fixture.read(1, characteristic: characteristic)
        read = request
        let firstWrite = ServerRequestDouble(characteristic)
        let secondWrite = ServerRequestDouble(characteristic)
        write = firstWrite
        plugin.peripheralManager(fixture.native(1), didReceiveWrite: [
            unsafeBitCast(firstWrite, to: CBATTRequest.self), unsafeBitCast(secondWrite, to: CBATTRequest.self)])
    }
    requireServer(plugin.attRequests.count == 3 && read != nil && write != nil,
                  "read and write requests must remain available while awaiting a response")
    plugin.disposePeripheralManager(arguments: ["managerId": 1], result: serverSuccess)
    requireServer(plugin.attRequests.isEmpty && read == nil && write == nil,
                  "disposing the manager must deallocate unanswered read and write requests")
    let eventCount = fixture.events.count
    let late = ServerRequestDouble(characteristic)
    plugin.peripheralManager(fixture.native(1), didReceiveRead: unsafeBitCast(late, to: CBATTRequest.self))
    plugin.peripheralManager(fixture.native(1), didAdd: service, error: nil)
    requireServer(plugin.attRequests.isEmpty && fixture.events.count == eventCount,
                  "late callbacks must not recreate disposed manager state")
}

private func testServerFailedAndPendingAdds() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let failed = fixture.add(1, error: NSError(domain: "Test", code: 7))
    let snapshot = fixture.payload["service"] as? [String: Any?]
    requireServer(snapshot?["clientReference"] as? String == "service-1", "failed-add callbacks must preserve identity")
    requireServer(plugin.services[plugin.objectKey(failed)] == nil && plugin.publishedLocalServices.isEmpty && plugin.serviceClientReferences.isEmpty &&
                  plugin.characteristicClientReferences.isEmpty && plugin.descriptorClientReferences.isEmpty,
                  "failed adds must not retain GATT objects or client-reference metadata")
    let pending = fixture.add(1, complete: false)
    plugin.disposePeripheralManager(arguments: ["managerId": 1], result: serverSuccess)
    requireServer(plugin.services[plugin.objectKey(pending)] == nil && plugin.localServices.isEmpty &&
                  plugin.serviceClientReferences.isEmpty, "disposal must also release pending adds")
}

private func resubmit(_ service: CBMutableService, in fixture: ServerFixture) {
    fixture.plugin.addService(arguments: ["managerId": 1, "service": [
        "handle": fixture.plugin.objectKey(service), "uuid": service.uuid.uuidString, "isPrimary": service.isPrimary
    ]], result: serverSuccess)
    requireServer(fixture.managers[1]!.added.last === service, "re-adds must reuse the manager's native service")
}

private func testServerFailedReadd() {
    for restored in [false, true] {
        let fixture = ServerFixture()
        let plugin = fixture.plugin
        let service = fixture.add(1)
        let peer = fixture.add(2)
        if restored {
            plugin.peripheralManager(fixture.native(1), willRestoreState: [CBPeripheralManagerRestoredStateServicesKey: [service]])
        }
        let handle = plugin.objectKey(service)
        let characteristic = service.characteristics!.first!
        let characteristicHandle = plugin.objectKey(characteristic)
        let descriptor = characteristic.descriptors!.first!
        let (_, requestHandle) = fixture.read(1, characteristic: characteristic)
        let references = plugin.serviceClientReferences
        for _ in 0..<2 {
            resubmit(service, in: fixture)
            plugin.peripheralManager(fixture.native(1), didAdd: service, error: NSError(domain: "ReAddTest", code: 7))
            requireServer(plugin.localServices[1]?[handle] === service && plugin.publishedLocalServices[1] == [handle],
                          "a failed re-add must preserve the previous published registration")
            requireServer(plugin.characteristics[characteristicHandle] === characteristic &&
                          plugin.descriptors[plugin.objectKey(descriptor)] === descriptor && plugin.serviceClientReferences == references,
                          "re-add failure must preserve attribute handles and identity metadata")
            let error = fixture.payload["error"] as? [String: Any?]
            requireServer(error?["code"] as? Int == 7 && error?["domain"] as? String == "ReAddTest",
                          "the re-add callback must retain the original native error")
            plugin.updateValue(arguments: ["managerId": 1, "characteristicHandle": characteristicHandle,
                "value": FlutterStandardTypedData(bytes: Data([1]))]) {
                requireServer($0 as? Bool == true, "the original characteristic must remain usable")
            }
        }
        requireServer(fixture.managers[1]!.updated.count == 2 && plugin.attRequests[requestHandle] != nil,
                      "failed re-adds must preserve updates and previously received ATT requests")
        plugin.respondToRequest(arguments: ["managerId": 1, "requestHandle": requestHandle, "result": 0], result: serverSuccess)
        let (_, nextRequest) = fixture.read(1, characteristic: characteristic)
        plugin.respondToRequest(arguments: ["managerId": 1, "requestHandle": nextRequest, "result": 0], result: serverSuccess)
        plugin.removeService(arguments: ["managerId": 1, "serviceHandle": handle], result: serverSuccess)
        requireServer(plugin.publishedLocalServices[1] == nil && plugin.services[handle] == nil,
                      "explicit removal must still retire a previously published registration after a failed re-add")
        plugin.peripheralManager(fixture.native(1), didAdd: service, error: nil)
        plugin.peripheralManager(fixture.native(1), didAdd: service, error: NSError(domain: "Late", code: 8))
        requireServer(plugin.publishedLocalServices[1] == nil && plugin.services[handle] == nil &&
                      plugin.publishedLocalServices[2]?.contains(plugin.objectKey(peer)) == true,
                      "late callbacks must not revive removal or affect another manager's publication")
    }
}

private func testPublishedServiceCleanup() {
    for cleanup in ["removeAll", "poweredOff", "resetting", "restore", "dispose"] {
        let fixture = ServerFixture()
        let plugin = fixture.plugin
        let service = fixture.add(1)
        let peer = fixture.add(2)
        resubmit(service, in: fixture)
        switch cleanup {
        case "removeAll": plugin.removeAllServices(arguments: ["managerId": 1], result: serverSuccess)
        case "poweredOff", "resetting":
            fixture.managers[1]!.state = cleanup == "poweredOff" ? 4 : 1
            plugin.peripheralManagerDidUpdateState(fixture.native(1))
        case "restore":
            plugin.peripheralManager(fixture.native(1), willRestoreState: [CBPeripheralManagerRestoredStateServicesKey: [CBMutableService]()])
        default: plugin.disposePeripheralManager(arguments: ["managerId": 1], result: serverSuccess)
        }
        plugin.peripheralManager(fixture.native(1), didAdd: service, error: nil)
        plugin.peripheralManager(fixture.native(1), didAdd: service, error: NSError(domain: "Late", code: 7))
        requireServer(plugin.publishedLocalServices[1] == nil && plugin.services[plugin.objectKey(service)] == nil,
                      "cleanup must retire publication metadata and reject late callbacks: \(cleanup)")
        requireServer(plugin.publishedLocalServices[2]?.contains(plugin.objectKey(peer)) == true,
                      "publication cleanup must preserve other managers")
        if cleanup != "dispose" {
            fixture.managers[1]!.state = 5
            let fresh = fixture.add(1)
            plugin.peripheralManager(fixture.native(1), didAdd: service, error: NSError(domain: "Late", code: 7))
            requireServer(fresh !== service && plugin.localServices[1]?[plugin.objectKey(fresh)] === fresh &&
                          plugin.publishedLocalServices[1] == [plugin.objectKey(fresh)],
                          "a late failure must preserve the new publication after cleanup")
        }
    }
}

private func testServerSharedIncludedServices() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let first = CBMutableService(type: CBUUID(string: "180a"), primary: true)
    let second = CBMutableService(type: CBUUID(string: "180f"), primary: true)
    let included = CBMutableService(type: CBUUID(string: "1810"), primary: false)
    let characteristic = CBMutableCharacteristic(type: CBUUID(string: "2a35"), properties: [.read], value: nil,
                                                permissions: [.readable])
    included.characteristics = [characteristic]
    first.includedServices = [included]
    second.includedServices = [included]
    plugin.peripheralManager(fixture.native(1), willRestoreState: [
        CBPeripheralManagerRestoredStateServicesKey: [first, second]])
    plugin.removeService(arguments: ["managerId": 1, "serviceHandle": plugin.objectKey(first)], result: serverSuccess)
    requireServer(plugin.services[plugin.objectKey(included)] === included &&
                  plugin.characteristics[plugin.objectKey(characteristic)] === characteristic,
                  "an included service reachable through another root must remain registered")
    plugin.removeService(arguments: ["managerId": 1, "serviceHandle": plugin.objectKey(second)], result: serverSuccess)
    requireServer(plugin.services.isEmpty && plugin.characteristics.isEmpty,
                  "removing the last root must release its included graph")
}

private func testServerRestoreOwnership() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let first = fixture.add(1)
    let second = fixture.add(2)
    plugin.peripheralManager(fixture.native(1), willRestoreState: [CBPeripheralManagerRestoredStateServicesKey: [first]])
    let restored = fixture.payload["services"] as? [[String: Any?]]
    requireServer(restored?.first?["clientReference"] as? String == "service-1",
                  "restoration must preserve identity metadata for retained native services")
    plugin.peripheralManager(fixture.native(1), willRestoreState: [CBPeripheralManagerRestoredStateServicesKey: [CBMutableService]()])
    requireServer(plugin.services[plugin.objectKey(first)] == nil && plugin.services[plugin.objectKey(second)] === second,
                  "restoring a replacement graph must release only that manager's obsolete services")
}

private func testServerWriteBatchResponses() {
    for result in [0, 3] {
        for replyIndex in [0, 1] {
            let fixture = ServerFixture()
            let plugin = fixture.plugin
            let firstService = fixture.add(1)
            let secondService = fixture.add(2)
            let characteristic = firstService.characteristics!.first!
            var handles: [String] = []
            weak var sibling: ServerRequestDouble?
            autoreleasepool {
                let requests = [ServerRequestDouble(characteristic), ServerRequestDouble(characteristic)]
                sibling = requests[1 - replyIndex]
                plugin.peripheralManager(fixture.native(1), didReceiveWrite: requests.map {
                    unsafeBitCast($0, to: CBATTRequest.self)
                })
                let snapshots = fixture.payload["requests"] as! [[String: Any?]]
                handles = snapshots.map { $0["requestHandle"] as! String }
            }
            let (_, readHandle) = fixture.read(1, characteristic: characteristic)
            let (_, otherManagerHandle) = fixture.read(2, characteristic: secondService.characteristics!.first!)
            let otherWrite = ServerRequestDouble(characteristic)
            plugin.peripheralManager(fixture.native(1), didReceiveWrite: [unsafeBitCast(otherWrite, to: CBATTRequest.self)])
            let otherBatch = fixture.payload["requests"] as! [[String: Any?]]
            let otherBatchHandle = otherBatch.first!["requestHandle"] as! String

            plugin.respondToRequest(arguments: ["managerId": 2, "requestHandle": handles[replyIndex], "result": result],
                                    result: serverInvalid)
            requireServer(plugin.attRequests.count == 5 && sibling != nil, "a foreign response must not retire the batch")
            plugin.respondToRequest(arguments: ["managerId": 1, "requestHandle": handles[replyIndex], "result": result,
                "value": FlutterStandardTypedData(bytes: Data([9]))], result: serverSuccess)
            requireServer(handles.allSatisfy { plugin.attRequests[$0] == nil } && sibling == nil,
                          "one response must release every member of the write batch")
            requireServer(fixture.managers[1]!.responses.count == 1 && fixture.managers[1]!.responses.first?.value == Data([9]),
                          "the selected request must reach native exactly once with its submitted value")
            requireServer(plugin.attRequests[readHandle] != nil && plugin.attRequests[otherManagerHandle] != nil &&
                          plugin.attRequests[otherBatchHandle] != nil, "unrelated reads, batches and managers must remain pending")
            for handle in handles {
                plugin.respondToRequest(arguments: ["managerId": 1, "requestHandle": handle, "result": result],
                                        result: serverInvalid)
            }
            requireServer(fixture.managers[1]!.responses.count == 1, "completed batches must reject further native responses")
            plugin.disposePeripheralManager(arguments: ["managerId": 1], result: serverSuccess)
            plugin.respondToRequest(arguments: ["managerId": 2, "requestHandle": otherManagerHandle, "result": 0],
                                    result: serverSuccess)
            requireServer(plugin.attRequests.isEmpty, "unrelated requests must retain their normal response and cleanup paths")
        }
    }
}

private func testNotificationRecipients() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let first = unsafeBitCast(ServerCentralDouble(), to: CBCentral.self)
    let second = unsafeBitCast(ServerCentralDouble(), to: CBCentral.self)
    let characteristic = SubscribedCharacteristic(type: CBUUID(string: "2a19"), properties: [.notify],
                                                 value: nil, permissions: [.readable])
    characteristic.subscribers = [first, second]
    let service = CBMutableService(type: CBUUID(string: "180f"), primary: true)
    service.characteristics = [characteristic]
    plugin.rememberLocalService(service, for: 1)
    let arguments: [String: Any] = ["managerId": 1, "characteristicHandle": plugin.objectKey(characteristic),
                                    "value": FlutterStandardTypedData(bytes: Data([7]))]
    func send(_ selection: Any?, expected: [CBCentral]?) {
        var selected = arguments
        selected["centralIdentifiers"] = selection
        let before = fixture.managers[1]!.updated.count
        plugin.updateValue(arguments: selected) { requireServer($0 as? Bool == true, "update result must be preserved") }
        requireServer(fixture.managers[1]!.updated.count == before + 1, "the update must reach the native manager once")
        let actual = fixture.managers[1]!.updateRecipients.last!
        if let expected {
            requireServer(actual != nil && actual!.count == expected.count && zip(actual!, expected).allSatisfy { $0 === $1 },
                          "explicit recipients must retain the exact subscribed native objects")
        } else {
            requireServer(actual == nil, "only absent/null recipients request all subscribers")
        }
    }
    send(nil, expected: nil)
    send(NSNull(), expected: nil)
    send([String](), expected: [])
    send([second.identifier.uuidString], expected: [second])
    send([first.identifier.uuidString, second.identifier.uuidString], expected: [first, second])
    send([first.identifier.uuidString, first.identifier.uuidString], expected: [first])
    send([UUID().uuidString], expected: [])
    send(["invalid-uuid"], expected: [])
    characteristic.subscribers = nil
    send([first.identifier.uuidString], expected: [])
}

private func testPublishedIncludedServiceReuse() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let leaf = fixture.add(1)
    let leafHandle = plugin.objectKey(leaf)
    let characteristic = leaf.characteristics!.first!
    let descriptor = characteristic.descriptors!.first!
    let snapshot = plugin.serviceSnapshot(leaf)
    var parents: [CBMutableService] = []
    for index in 1...2 {
        plugin.addService(arguments: ["managerId": 1, "service": [
            "uuid": "180a", "isPrimary": true, "clientReference": "parent-\(index)", "includedServices": [snapshot]
        ]], result: serverSuccess)
        let parent = fixture.managers[1]!.added.last!
        parents.append(parent)
        requireServer(parent.includedServices?.first === leaf, "parent publication must reuse its owned included service")
        plugin.peripheralManager(fixture.native(1), didAdd: parent, error: nil)
        let published = fixture.payload["service"] as! [String: Any?]
        let included = published["includedServices"] as! [[String: Any?]]
        requireServer(included.first?["handle"] as? String == leafHandle, "callbacks must preserve the published handle")
    }
    plugin.addService(arguments: ["managerId": 1, "service": [
        "uuid": "180a", "isPrimary": true, "clientReference": "failed-parent", "includedServices": [snapshot]
    ]], result: serverSuccess)
    let failed = fixture.managers[1]!.added.last!
    plugin.peripheralManager(fixture.native(1), didAdd: failed, error: NSError(domain: "Test", code: 7))
    requireServer(plugin.services[plugin.objectKey(failed)] == nil && plugin.services[leafHandle] === leaf,
                  "a failed parent must release its own root without pruning the reused included service")
    plugin.removeService(arguments: ["managerId": 1, "serviceHandle": leafHandle], result: serverSuccess)
    plugin.removeService(arguments: ["managerId": 1, "serviceHandle": plugin.objectKey(parents[0])], result: serverSuccess)
    requireServer(plugin.services[leafHandle] === leaf && plugin.characteristics[plugin.objectKey(characteristic)] === characteristic &&
                  plugin.descriptors[plugin.objectKey(descriptor)] === descriptor,
                  "shared service attributes must remain available through the remaining parent")
    plugin.removeService(arguments: ["managerId": 1, "serviceHandle": plugin.objectKey(parents[1])], result: serverSuccess)
    requireServer(plugin.services.isEmpty && plugin.characteristics.isEmpty && plugin.descriptors.isEmpty &&
                  plugin.serviceClientReferences.isEmpty && plugin.characteristicClientReferences.isEmpty &&
                  plugin.descriptorClientReferences.isEmpty, "the final root must release the entire graph and identity metadata")
}

private func testIncludedServiceReferencesAndOwnership() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let pending = fixture.add(1, complete: false)
    let withoutHandle: [String: Any?] = ["uuid": "180f", "isPrimary": true, "clientReference": "service-1"]
    plugin.addService(arguments: ["managerId": 1, "service": [
        "uuid": "180a", "isPrimary": true, "clientReference": "parent", "includedServices": [withoutHandle]
    ]], result: serverSuccess)
    requireServer(fixture.managers[1]!.added.last!.includedServices?.first === pending,
                  "an add before the child's callback must resolve its client reference")
    let parent = fixture.managers[1]!.added.last!
    let stale = plugin.serviceSnapshot(parent)
    plugin.removeAllServices(arguments: ["managerId": 1], result: serverSuccess)
    plugin.addService(arguments: ["managerId": 1, "service": stale], result: serverSuccess)
    requireServer(fixture.managers[1]!.added.last! !== parent &&
                  fixture.managers[1]!.added.last!.includedServices?.first !== pending,
                  "a retired graph must still be publishable as fresh objects")

    let foreign = fixture.add(2)
    let foreignSnapshot = plugin.serviceSnapshot(foreign)
    let before = fixture.managers[1]!.added.count
    let references = plugin.serviceClientReferences
    let characteristicReferences = plugin.characteristicClientReferences
    let descriptorReferences = plugin.descriptorClientReferences
    let fresh: [String: Any?] = ["uuid": "1810", "isPrimary": false, "clientReference": "not-created",
        "characteristics": [["uuid": "2a35", "clientReference": "not-created-c",
            "descriptors": [["uuid": "2901", "clientReference": "not-created-d", "value": "test"]]]]]
    plugin.addService(arguments: ["managerId": 1, "service": foreignSnapshot], result: serverInvalid)
    plugin.addService(arguments: ["managerId": 1, "service": [
        "uuid": "180a", "isPrimary": true, "clientReference": "rejected-parent",
        "includedServices": [fresh, foreignSnapshot]
    ]], result: serverInvalid)
    requireServer(fixture.managers[1]!.added.count == before && plugin.serviceClientReferences == references &&
                  plugin.characteristicClientReferences == characteristicReferences &&
                  plugin.descriptorClientReferences == descriptorReferences,
                  "foreign service handles must be rejected before creating or publishing any graph")
}

private func testNewGraphSharedReferences() {
    let fixture = ServerFixture()
    let shared: [String: Any] = ["uuid": "1810", "isPrimary": false, "clientReference": "shared-leaf"]
    let branches = (1...2).map { index -> [String: Any] in
        ["uuid": "180a", "isPrimary": false, "clientReference": "branch-\(index)", "includedServices": [shared]]
    }
    fixture.plugin.addService(arguments: ["managerId": 1, "service": [
        "uuid": "180f", "isPrimary": true, "clientReference": "root", "includedServices": branches
    ]], result: serverSuccess)
    let root = fixture.managers[1]!.added.last!
    requireServer(root.includedServices![0].includedServices!.first === root.includedServices![1].includedServices!.first,
                  "repeated references in a new graph must create only one included native service")
}

private func testLatencyFromObservedCentrals() {
    for source in ["read", "write", "subscribe", "unsubscribe", "l2cap", "restored"] {
        let fixture = ServerFixture()
        let plugin = fixture.plugin
        let service = fixture.add(1)
        let characteristic = service.characteristics!.first!
        let central = unsafeBitCast(ServerCentralDouble(), to: CBCentral.self)
        switch source {
        case "read", "write":
            let request = ServerRequestDouble(characteristic, central: central)
            let native = unsafeBitCast(request, to: CBATTRequest.self)
            if source == "read" {
                plugin.peripheralManager(fixture.native(1), didReceiveRead: native)
            } else {
                plugin.peripheralManager(fixture.native(1), didReceiveWrite: [native])
            }
            let handle = plugin.attRequests.values.first!.handle
            plugin.respondToRequest(arguments: ["managerId": 1, "requestHandle": handle, "result": 0], result: serverSuccess)
            requireServer(plugin.attRequests.isEmpty, "latency support must not retain answered ATT requests")
        case "subscribe":
            plugin.peripheralManager(fixture.native(1), central: central, didSubscribeTo: characteristic)
        case "unsubscribe":
            plugin.peripheralManager(fixture.native(1), central: central, didUnsubscribeFrom: characteristic)
        case "l2cap":
            let channel = ServerChannelDouble(peer: central)
            plugin.peripheralManager(fixture.native(1), didOpen: unsafeBitCast(channel, to: CBL2CAPChannel.self), error: nil)
        default:
            let subscribed = SubscribedCharacteristic(type: CBUUID(string: "2a19"), properties: [.notify], value: nil,
                                                      permissions: [.readable])
            subscribed.subscribers = [central]
            let restored = CBMutableService(type: CBUUID(string: "180f"), primary: true)
            restored.characteristics = [subscribed]
            plugin.peripheralManager(fixture.native(1), willRestoreState: [CBPeripheralManagerRestoredStateServicesKey: [restored]])
        }
        let arguments: [String: Any] = ["managerId": 1, "centralIdentifier": central.identifier.uuidString, "latency": 2]
        plugin.setDesiredConnectionLatency(arguments: arguments, result: serverSuccess)
        let received = fixture.managers[1]!.latencyRequests.last!
        requireServer(received.0 == 2 && received.1 === central, "\(source) centrals must reach native latency unchanged")
        plugin.setDesiredConnectionLatency(arguments: ["managerId": 2,
            "centralIdentifier": central.identifier.uuidString, "latency": 2], result: serverInvalid)
        requireServer(fixture.managers[2]!.latencyRequests.isEmpty, "centrals must not cross manager ownership")
    }
}

private func testObservedCentralCleanup() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let firstService = fixture.add(1)
    let secondService = fixture.add(2)
    let identifier = UUID()
    weak var released: ServerCentralDouble?
    autoreleasepool {
        let first = ServerCentralDouble(identifier: identifier)
        let second = ServerCentralDouble(identifier: identifier)
        released = first
        plugin.peripheralManager(fixture.native(1), central: unsafeBitCast(first, to: CBCentral.self),
                                 didSubscribeTo: firstService.characteristics!.first!)
        plugin.peripheralManager(fixture.native(2), central: unsafeBitCast(second, to: CBCentral.self),
                                 didSubscribeTo: secondService.characteristics!.first!)
        requireServer(plugin.peripheralManagerCentrals[1]?[identifier] !== plugin.peripheralManagerCentrals[2]?[identifier],
                      "matching central UUIDs must retain separate native objects across managers")
    }
    requireServer(released != nil, "the manager must retain observed centrals while usable")
    fixture.managers[1]!.state = 4
    plugin.peripheralManagerDidUpdateState(fixture.native(1))
    requireServer(plugin.peripheralManagerCentrals[1] == nil && released == nil && plugin.peripheralManagerCentrals[2] != nil,
                  "leaving powered-on must release only that manager's observed centrals")
    plugin.setDesiredConnectionLatency(arguments: ["managerId": 1,
        "centralIdentifier": identifier.uuidString, "latency": 0], result: serverInvalid)
    plugin.disposePeripheralManager(arguments: ["managerId": 2], result: serverSuccess)
    requireServer(plugin.peripheralManagerCentrals.isEmpty, "disposal must release remaining observed centrals")
    let central = unsafeBitCast(ServerCentralDouble(), to: CBCentral.self)
    plugin.peripheralManager(fixture.native(2), central: central, didSubscribeTo: secondService.characteristics!.first!)
    requireServer(plugin.peripheralManagerCentrals.isEmpty, "late callbacks must not recreate disposed central tracking")
}

private func testServerAdapterInvalidation() {
    for state in [1, 4] {
        let fixture = ServerFixture()
        let plugin = fixture.plugin
        let first = fixture.add(1)
        let second = fixture.add(2)
        let pending = fixture.add(1, complete: false)
        let (_, firstHandle) = fixture.read(1, characteristic: first.characteristics!.first!)
        let (_, secondHandle) = fixture.read(2, characteristic: second.characteristics!.first!)
        fixture.managers[1]!.state = state
        plugin.peripheralManagerDidUpdateState(fixture.native(1))
        requireServer(plugin.localServices[1] == nil && plugin.localServices[2] != nil,
                      "power-off/reset must retire only that manager's published and pending services")
        for service in [first, pending] {
            requireServer(plugin.services[plugin.objectKey(service)] == nil &&
                          plugin.serviceClientReferences[plugin.objectKey(service)] == nil,
                          "retired local services and client references must be released")
            let characteristic = service.characteristics!.first!
            requireServer(plugin.characteristics[plugin.objectKey(characteristic)] == nil &&
                          plugin.descriptors[plugin.objectKey(characteristic.descriptors!.first!)] == nil,
                          "retired local attributes must be released")
        }
        requireServer(plugin.attRequests[firstHandle] == nil && plugin.attRequests[secondHandle] != nil,
                      "adapter loss must retire only that manager's pending requests")
        plugin.respondToRequest(arguments: ["managerId": 1, "requestHandle": firstHandle, "result": 0], result: serverInvalid)
        requireServer(fixture.managers[1]!.responses.isEmpty, "retired ATT requests must not reach CoreBluetooth")
        plugin.peripheralManager(fixture.native(1), didAdd: pending, error: nil)
        requireServer(plugin.localServices[1] == nil && plugin.services[plugin.objectKey(pending)] == nil,
                      "late add callbacks must not revive the cleared database")
        fixture.managers[1]!.state = 5
        plugin.peripheralManagerDidUpdateState(fixture.native(1))
        requireServer(plugin.localServices[1] == nil, "power-on must not implicitly republish services")
        let fresh = fixture.add(1)
        requireServer(plugin.localGatt(for: 1).services[plugin.objectKey(fresh)] === fresh,
                      "explicit publication after recovery must still work")
        requireServer(plugin.localGatt(for: 2).services[plugin.objectKey(second)] === second,
                      "recovery must preserve another server's database")
        plugin.respondToRequest(arguments: ["managerId": 2, "requestHandle": secondHandle, "result": 0], result: serverSuccess)
    }
}

private func testLocalAttributeMetadataRoundTrip() {
    let permissionSets: [CBAttributePermissions] = [[.readable, .writeable], [.readEncryptionRequired, .writeEncryptionRequired], []]
    let format = Data([4, 0, 0, 0x27, 1, 0, 0])
    for permissions in permissionSets {
        let fixture = ServerFixture()
        let plugin = fixture.plugin
        let raw: [String: Any] = ["uuid": "180f", "isPrimary": true, "clientReference": "metadata-service",
            "characteristics": [["uuid": "2a19", "clientReference": "metadata-c", "properties": 10,
                "permissions": permissions.rawValue, "descriptors": [
                    ["uuid": "2901", "clientReference": "description", "value": "Battery"],
                    ["uuid": "2904", "clientReference": "format", "value": FlutterStandardTypedData(bytes: format)]
                ]]]]
        plugin.addService(arguments: ["managerId": 1, "service": raw], result: serverSuccess)
        let service = fixture.managers[1]!.added.last!
        let characteristic = service.characteristics!.first as! CBMutableCharacteristic
        requireServer(characteristic.permissions == permissions, "publication must preserve every configured permission bit")
        requireServer(characteristic.descriptors![0].value as? String == "Battery" &&
                      characteristic.descriptors![1].value as? Data == format,
                      "string descriptors must stay strings and typed byte descriptors must become native Data")
        plugin.peripheralManager(fixture.native(1), didAdd: service, error: nil)
        var snapshot = fixture.payload["service"] as! [String: Any?]
        var characteristics = snapshot["characteristics"] as! [[String: Any?]]
        requireServer((characteristics[0]["permissions"] as? NSNumber)?.uintValue == permissions.rawValue,
                      "add callbacks must include local characteristic permissions")
        var descriptors = characteristics[0]["descriptors"] as! [[String: Any?]]
        requireServer(descriptors[1]["value"] as? Data == format, "callback snapshots must preserve descriptor bytes")
        // StandardMethodCodec decodes a Dart Uint8List as FlutterStandardTypedData.
        descriptors[1]["value"] = FlutterStandardTypedData(bytes: format)
        characteristics[0]["descriptors"] = descriptors
        snapshot["characteristics"] = characteristics
        plugin.removeAllServices(arguments: ["managerId": 1], result: serverSuccess)
        plugin.addService(arguments: ["managerId": 1, "service": snapshot], result: serverSuccess)
        let republished = fixture.managers[1]!.added.last!
        let rebuilt = republished.characteristics!.first as! CBMutableCharacteristic
        requireServer(republished !== service && rebuilt.permissions == permissions &&
                      rebuilt.descriptors![1].value as? Data == format,
                      "republication must create fresh native objects with the same permissions and descriptor bytes")
        plugin.peripheralManager(fixture.native(1), willRestoreState: [CBPeripheralManagerRestoredStateServicesKey: [republished]])
        let restored = fixture.payload["services"] as! [[String: Any?]]
        let restoredCharacteristics = restored[0]["characteristics"] as! [[String: Any?]]
        requireServer((restoredCharacteristics[0]["permissions"] as? NSNumber)?.uintValue == permissions.rawValue,
                      "restoration snapshots must retain local characteristic permissions")
    }
}

private func testInvalidDescriptorValues() {
    let fixture = ServerFixture()
    let plugin = fixture.plugin
    let existing = fixture.add(1)
    let serviceReferences = plugin.serviceClientReferences
    let characteristicReferences = plugin.characteristicClientReferences
    let descriptorReferences = plugin.descriptorClientReferences
    let serviceHandles = Set(plugin.services.keys)
    let characteristicHandles = Set(plugin.characteristics.keys)
    let descriptorHandles = Set(plugin.descriptors.keys)
    let customUUID = "12345678-1234-5678-1234-567812345678"
    let invalid: [(String, Any?)] = [
        ("2901", NSNull()), ("2901", 42), ("2901", FlutterStandardTypedData(bytes: Data([1]))),
        ("2904", NSNull()), ("2904", "wrong type"), ("2904", 42),
        ("00002901-0000-1000-8000-00805f9b34fb", NSNull()),
        ("00002904-0000-1000-8000-00805f9b34fb", "wrong type"),
        (customUUID, nil), (customUUID, NSNull()), (customUUID, "wrong type"), (customUUID, 42),
        ("2906", nil), ("2906", NSNull()), ("2906", "wrong type"), ("2906", 42),
        ("2906", FlutterStandardTypedData(bytes: Data([1]))), ("2906", Data([1, 2, 3])),
        ("00002906-0000-1000-8000-00805f9b34fb", FlutterStandardTypedData(bytes: Data([1, 2, 3])))
    ]
    let valid: [String: Any?] = ["uuid": "180a", "isPrimary": false, "clientReference": "valid-child",
        "characteristics": [["uuid": "2a29", "clientReference": "valid-c", "descriptors": [
            ["uuid": "2901", "value": "Valid", "clientReference": "valid-d"]]]]]
    for (uuid, value) in invalid {
        let descriptor: [String: Any?] = ["uuid": uuid, "value": value, "clientReference": "rejected-d"]
        let invalidChild: [String: Any?] = ["uuid": "180f", "isPrimary": false, "clientReference": "invalid-child",
            "characteristics": [["uuid": "2a19", "clientReference": "invalid-c", "descriptors": [descriptor]]]]
        for nested in [false, true] {
            let raw: [String: Any?] = nested
                ? ["uuid": "180f", "isPrimary": true, "clientReference": "rejected-root", "includedServices": [valid, invalidChild]]
                : ["uuid": "180f", "isPrimary": true, "clientReference": "rejected-root",
                   "includedServices": [valid], "characteristics": invalidChild["characteristics"] ?? nil]
            var replies = 0
            plugin.addService(arguments: ["managerId": 1, "service": raw]) {
                replies += 1
                requireServer(($0 as? FlutterError)?.code == "invalid_args", "invalid descriptor values must report normal errors")
            }
            requireServer(replies == 1 && fixture.managers[1]!.added.count == 1 &&
                          plugin.localServices[1]?.count == 1 && plugin.localServices[1]?[plugin.objectKey(existing)] === existing,
                          "rejected definitions must not publish or remove any service")
            requireServer(Set(plugin.services.keys) == serviceHandles && Set(plugin.characteristics.keys) == characteristicHandles &&
                          Set(plugin.descriptors.keys) == descriptorHandles && plugin.serviceClientReferences == serviceReferences &&
                          plugin.characteristicClientReferences == characteristicReferences &&
                          plugin.descriptorClientReferences == descriptorReferences,
                          "validation must precede all graph allocations and identity registration")
        }
        requireServer(plugin.mutableDescriptor(from: descriptor) == nil, "direct descriptor construction must also avoid native exceptions")
    }
    requireServer(plugin.mutableDescriptor(from: ["uuid": "2901"]) == nil &&
                  plugin.mutableDescriptor(from: ["uuid": "2904"]) == nil &&
                  plugin.mutableDescriptor(from: ["uuid": "2906"]) == nil &&
                  plugin.mutableDescriptor(from: ["uuid": customUUID]) == nil, "absent values must also be rejected")

    // Correcting a rejected definition must allow publication with native or channel byte values.
    for uuid in ["2901", "00002901-0000-1000-8000-00805f9b34fb"] {
        requireServer(plugin.mutableDescriptor(from: ["uuid": uuid, "value": "Battery"])?.value as? String == "Battery",
                      "expanded User Description UUIDs must still accept strings")
    }
    for uuid in [customUUID, "2906", "00002906-0000-1000-8000-00805f9b34fb"] {
        let values = uuid == customUUID
            ? [Data(), Data([1]), Data([1, 2]), Data([1, 2, 3])]
            : [Data(), Data([1, 2]), Data([1, 2, 3, 4])]
        for bytes in values {
            for value: Any in [bytes, FlutterStandardTypedData(bytes: bytes)] {
                let fixture = ServerFixture()
                let raw: [String: Any] = ["uuid": "180f", "isPrimary": true, "characteristics": [
                    ["uuid": "2a19", "descriptors": [["uuid": uuid, "value": value]]]]]
                fixture.plugin.addService(arguments: ["managerId": 1, "service": raw], result: serverSuccess)
                let service = fixture.managers[1]!.added.last!
                let descriptor = service.characteristics!.first!.descriptors!.first!
                requireServer(descriptor.value as? Data == bytes, "valid binary descriptors must retain their bytes")
                requireServer(fixture.plugin.descriptorSnapshot(descriptor)["value"] as? Data == bytes,
                              "valid binary descriptor snapshots must retain their bytes")
            }
        }
    }

    // Reusing a published service must not validate or apply edits to its immutable native definition.
    var reused = plugin.serviceSnapshot(existing)
    reused["characteristics"] = [["uuid": "2a19", "descriptors": [["uuid": "2901", "value": NSNull()]]]]
    plugin.addService(arguments: ["managerId": 1, "service": [
        "uuid": "180a", "isPrimary": true, "clientReference": "parent", "includedServices": [reused]
    ]], result: serverSuccess)
    requireServer(fixture.managers[1]!.added.last!.includedServices?.first === existing &&
                  existing.characteristics!.first!.descriptors!.first!.value as? String == "Test",
                  "reuse must keep the previously published native descriptor untouched")
}

private func testSharedPeripheralManagerReattachment() {
    // Exercise native creation/reattachment without contacting the Bluetooth daemon.
    let method = class_getInstanceMethod(CBPeripheralManager.self,
                                        NSSelectorFromString("initWithDelegate:queue:options:"))!
    var creations = 0
    let factory: @convention(block) (AnyObject, AnyObject?, AnyObject?, AnyObject?) -> UnsafeMutableRawPointer = { _, _, _, _ in
        creations += 1
        // An Objective-C init returns an owned object, unlike an ordinary block result.
        return Unmanaged.passRetained(ServerManagerDouble()).toOpaque()
    }
    let replacement = imp_implementationWithBlock(factory)
    let original = method_setImplementation(method, replacement)
    defer { method_setImplementation(method, original); imp_removeBlock(replacement) }
    let plugin = CoreBluetoothPlugin()
    func create(shared: Bool) -> [String: Any?] {
        var snapshot: [String: Any?] = [:]
        plugin.createPeripheralManager(arguments: ["shared": shared]) { snapshot = $0 as! [String: Any?] }
        return snapshot
    }
    let first = create(shared: true)
    let id = first["managerId"] as! Int
    let native = plugin.peripheralManagers[id]!
    let manager = unsafeBitCast(native, to: ServerManagerDouble.self)
    let isolatedId = create(shared: false)["managerId"] as! Int
    let published = CBMutableService(type: CBUUID(string: "180f"), primary: true)
    let pending = CBMutableService(type: CBUUID(string: "1810"), primary: true)
    plugin.rememberLocalService(published, for: id)
    plugin.peripheralManager(native, didAdd: published, error: nil)
    plugin.rememberLocalService(pending, for: id)
    plugin.startAdvertising(arguments: ["managerId": id], result: serverSuccess)
    _ = plugin.onCancel(withArguments: nil)
    _ = plugin.onListen(withArguments: nil, eventSink: { _ in })
    for _ in 0..<3 {
        let attached = create(shared: true)
        requireServer(attached["managerId"] as? Int == id && creations == 2,
                      "reattachment must reuse the shared native manager without allocating another")
        requireServer(attached["isAdvertising"] as? Bool == true, "reattachment must report actual advertising")
        let services = attached["services"] as! [[String: Any?]]
        let pendingServices = attached["pendingServices"] as! [[String: Any?]]
        requireServer(services.count == 1 && services[0]["handle"] as? String == plugin.objectKey(published),
                      "reattachment must recover published roots with their existing handles")
        requireServer(pendingServices.count == 1 && pendingServices[0]["handle"] as? String == plugin.objectKey(pending),
                      "pending additions must remain distinct from published services")
    }
    plugin.stopAdvertising(arguments: ["managerId": id], result: serverSuccess)
    requireServer(manager.stopped && !manager.isAdvertising, "replacement Dart owner must stop the original advertiser")
    plugin.disposePeripheralManager(arguments: ["managerId": id], result: serverSuccess)
    requireServer(plugin.peripheralManagers[id] == nil && plugin.localServices[id] == nil,
                  "shared disposal must release its native registration and services")
    requireServer(plugin.peripheralManagers[isolatedId] != nil, "shared disposal must preserve isolated managers")
    let fresh = create(shared: true)
    requireServer(fresh["managerId"] as? Int != id && creations == 3,
                  "disposing shared must allow a fresh native registration")
}

func testPeripheralManagerOwnership() {
    testSharedPeripheralManagerReattachment()
    testServerHandleOwnership()
    testServerCleanupIsolation()
    testServerRequestOwnership()
    testServerPendingRequestRelease()
    testServerFailedAndPendingAdds()
    testServerFailedReadd()
    testPublishedServiceCleanup()
    testServerSharedIncludedServices()
    testServerRestoreOwnership()
    testServerWriteBatchResponses()
    testNotificationRecipients()
    testPublishedIncludedServiceReuse()
    testIncludedServiceReferencesAndOwnership()
    testNewGraphSharedReferences()
    testLatencyFromObservedCentrals()
    testObservedCentralCleanup()
    testServerAdapterInvalidation()
    testLocalAttributeMetadataRoundTrip()
    testInvalidDescriptorValues()
}
