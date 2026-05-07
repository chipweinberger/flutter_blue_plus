import CoreBluetooth
import Foundation
import FlutterMacOS

// Framework objects cannot be constructed without a Bluetooth session. These
// NSObject doubles implement only the Objective-C selectors used by the tests.
private final class PeripheralDouble: NSObject {
    @objc let identifier: UUID
    @objc let name = "Test peripheral"
    @objc var state = 2
    @objc let canSendWriteWithoutResponse = true
    @objc weak var delegate: AnyObject?
    @objc var services: [CBService] = []
    var reads = 0
    var characteristicReads = 0
    var descriptorReads = 0

    init(identifier: UUID) { self.identifier = identifier }
    @objc func readRSSI() { reads += 1 }
    @objc(readValueForCharacteristic:) func readCharacteristic(_ characteristic: CBCharacteristic) { characteristicReads += 1 }
    @objc(readValueForDescriptor:) func readDescriptor(_ descriptor: CBDescriptor) { descriptorReads += 1 }
}

private final class ManagerDouble: NSObject {
    @objc var state = 5
    @objc var isScanning = false
    var acceptsScan = true
    var scanRequests = 0
    var lastScanServices: [CBUUID]?
    var lastScanOptions: [String: Any]?
    var lastConnectOptions: [String: Any]?
    var connections = 0
    var cancellations = 0
    @objc func stopScan() { isScanning = false }
    @objc(scanForPeripheralsWithServices:options:)
    func scan(_ services: [CBUUID]?, options: [String: Any]?) {
        scanRequests += 1
        lastScanServices = services
        lastScanOptions = options
        isScanning = state == 5 && acceptsScan
    }
    @objc(connectPeripheral:options:)
    func connect(_ peripheral: CBPeripheral, options: [String: Any]?) {
        connections += 1
        lastConnectOptions = options
    }
    @objc func cancelPeripheralConnection(_ peripheral: CBPeripheral) { cancellations += 1 }
}

private final class ServiceDouble: NSObject {
    @objc(UUID) let uuid = CBUUID(string: "180f")
    @objc let isPrimary = true
    @objc weak var peripheral: CBPeripheral?
    @objc var includedServices: [CBService] = []
    @objc var characteristics: [CBCharacteristic] = []
    init(_ peripheral: CBPeripheral) { self.peripheral = peripheral }
}

private final class CharacteristicDouble: NSObject {
    @objc(UUID) let uuid = CBUUID(string: "2a19")
    @objc var properties: UInt = 2
    @objc var isBroadcasted = false
    @objc(isNotifying) let notifying = false
    @objc let value: Data? = nil
    @objc weak var service: CBService?
    @objc var descriptors: [CBDescriptor] = []
    init(_ service: CBService) { self.service = service }
}

private final class DescriptorDouble: NSObject {
    @objc(UUID) let uuid = CBUUID(string: "2901")
    @objc let value: NSNumber = 0
    @objc weak var characteristic: CBCharacteristic?
    init(_ characteristic: CBCharacteristic) { self.characteristic = characteristic }
}

private final class RemoteGatt {
    let nativeService: ServiceDouble
    let nativeCharacteristic: CharacteristicDouble
    let nativeDescriptor: DescriptorDouble
    let service: CBService
    let characteristic: CBCharacteristic
    let descriptor: CBDescriptor

    init(_ peripheral: CBPeripheral) {
        nativeService = ServiceDouble(peripheral)
        service = unsafeBitCast(nativeService, to: CBService.self)
        nativeCharacteristic = CharacteristicDouble(service)
        characteristic = unsafeBitCast(nativeCharacteristic, to: CBCharacteristic.self)
        nativeDescriptor = DescriptorDouble(characteristic)
        descriptor = unsafeBitCast(nativeDescriptor, to: CBDescriptor.self)
        nativeService.characteristics = [characteristic]
        nativeCharacteristic.descriptors = [descriptor]
    }
}

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

private final class NullablePeripheralDouble: NSObject {
    @objc let identifier = UUID()
    @objc let name = "Nullable discovery"
    @objc let state = 2
    @objc let canSendWriteWithoutResponse = true
    @objc weak var delegate: AnyObject?
    @objc var services: [CBService]?
}

private func testNullableDiscoveryCollections() {
    let plugin = CoreBluetoothPlugin()
    let central = unsafeBitCast(ManagerDouble(), to: CBCentralManager.self)
    let manager = CentralManagerBox(identifier: 1, centralManager: central)
    plugin.managers[1] = manager
    let nativePeer = NullablePeripheralDouble()
    let peer = unsafeBitCast(nativePeer, to: CBPeripheral.self)
    plugin.remember(peer, for: manager)
    let service = CBMutableService(type: CBUUID(string: "180f"), primary: true)
    let characteristic = CBMutableCharacteristic(type: CBUUID(string: "2a19"), properties: .read,
                                                 value: nil, permissions: .readable)
    var payload: [String: Any?] = [:]
    plugin.eventSink = { event in
        payload = (event as? [String: Any?])?["payload"] as? [String: Any?] ?? [:]
    }
    func verify(_ snapshot: [String: Any?], _ key: String, empty: Bool) {
        let codec = FlutterStandardMessageCodec.sharedInstance()
        let decoded = codec.decode(codec.encode(snapshot)!) as! [String: Any]
        if empty {
            check((decoded[key] as? [Any])?.isEmpty == true, "native empty \(key) must remain empty")
        } else {
            check(decoded[key] is NSNull, "native nil \(key) must remain null through the platform codec")
        }
    }
    for empty in [false, true] {
        service.characteristics = empty ? [] : nil
        service.includedServices = empty ? [] : nil
        characteristic.descriptors = empty ? [] : nil
        nativePeer.services = empty ? [] : nil
        let snapshot = plugin.serviceSnapshot(service)
        verify(snapshot, "characteristics", empty: empty)
        verify(snapshot, "includedServices", empty: empty)
        verify(plugin.characteristicSnapshot(characteristic), "descriptors", empty: empty)
        for failed in [false, true] {
            let error = failed ? NSError(domain: "CBATTErrorDomain", code: 10) : nil
            plugin.peripheral(peer, didDiscoverServices: error)
            verify(payload, "services", empty: empty)
            check((payload["error"] as? [String: Any?])?["code"] as? Int == (failed ? 10 : nil),
                  "nullable discovery must preserve the native error")
            plugin.peripheral(peer, didDiscoverCharacteristicsFor: service, error: error)
            verify(payload, "characteristics", empty: empty)
            plugin.peripheral(peer, didDiscoverIncludedServicesFor: service, error: error)
            verify(payload, "includedServices", empty: empty)
            plugin.peripheral(peer, didDiscoverDescriptorsFor: characteristic, error: error)
            verify(payload, "descriptors", empty: empty)
        }
        plugin.centralManager(central, willRestoreState: [CBCentralManagerRestoredStatePeripheralsKey: [peer]])
        let restored = (payload["peripherals"] as! [[String: Any?]])[0]
        verify(restored, "services", empty: empty)
    }
}

private func checkRegistered(_ plugin: CoreBluetoothPlugin, _ graph: RemoteGatt, _ expected: Bool) {
    check((plugin.services[plugin.objectKey(graph.service)] != nil) == expected, "unexpected service registration")
    check((plugin.characteristics[plugin.objectKey(graph.characteristic)] != nil) == expected,
          "unexpected characteristic registration")
    check((plugin.descriptors[plugin.objectKey(graph.descriptor)] != nil) == expected, "unexpected descriptor registration")
}

private func testNativeBroadcastState() {
    let plugin = CoreBluetoothPlugin()
    let peripheral = PeripheralDouble(identifier: UUID())
    let graph = RemoteGatt(unsafeBitCast(peripheral, to: CBPeripheral.self))
    graph.nativeCharacteristic.properties = CBCharacteristicProperties.broadcast.rawValue
    for broadcasted in [false, true, false] {
        graph.nativeCharacteristic.isBroadcasted = broadcasted
        let snapshot = plugin.serviceSnapshot(graph.service)
        let characteristics = snapshot["characteristics"] as! [[String: Any?]]
        let characteristic = characteristics[0]
        check(characteristic["isBroadcasted"] as? Bool == broadcasted,
              "snapshots must forward native broadcast state independently of broadcast capability")
        check((characteristic["properties"] as? NSNumber)?.uintValue == CBCharacteristicProperties.broadcast.rawValue,
              "broadcast state must not change the capability flags")
    }
    let local = CBMutableCharacteristic(type: CBUUID(string: "2a19"), properties: .read, value: nil, permissions: .readable)
    check(plugin.characteristicSnapshot(local)["isBroadcasted"] as? Bool == false,
          "actual local CoreBluetooth characteristics must include their inactive broadcast state")
}

private func testRemoteGattPruning() {
    let plugin = CoreBluetoothPlugin()
    var lastEvent: [String: Any?] = [:]
    plugin.eventSink = { lastEvent = $0 as? [String: Any?] ?? [:] }
    let manager = ManagerDouble()
    let box = CentralManagerBox(identifier: 1, centralManager: unsafeBitCast(manager, to: CBCentralManager.self))
    let peerManager = ManagerDouble()
    let peerBox = CentralManagerBox(identifier: 2, centralManager: unsafeBitCast(peerManager, to: CBCentralManager.self))
    plugin.managers = [1: box, 2: peerBox]
    let uuid = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!
    let nativePeripheral = PeripheralDouble(identifier: uuid)
    let peripheral = unsafeBitCast(nativePeripheral, to: CBPeripheral.self)
    let nativePeer = PeripheralDouble(identifier: uuid)
    let peer = unsafeBitCast(nativePeer, to: CBPeripheral.self)
    plugin.remember(peripheral, for: box)
    plugin.remember(peer, for: peerBox)

    // Remote pruning must preserve another manager's same-UUID objects and local GATT.
    let peerGraph = RemoteGatt(peer)
    nativePeer.services = [peerGraph.service]
    plugin.peripheral(peer, didDiscoverServices: nil)
    let localService = CBMutableService(type: CBUUID(string: "180a"), primary: true)
    let localCharacteristic = CBMutableCharacteristic(type: CBUUID(string: "2a29"), properties: [.read],
                                                    value: nil, permissions: [.readable])
    let localDescriptor = CBMutableDescriptor(type: CBUUID(string: "2901"), value: "Local")
    localCharacteristic.descriptors = [localDescriptor]
    localService.characteristics = [localCharacteristic]
    plugin.register(service: localService)

    let old = RemoteGatt(peripheral)
    nativePeripheral.services = [old.service]
    plugin.peripheral(peripheral, didDiscoverServices: nil)
    checkRegistered(plugin, old, true)
    let root = RemoteGatt(peripheral)
    nativePeripheral.services = [root.service]
    plugin.peripheral(peripheral, didDiscoverServices: nil)
    checkRegistered(plugin, old, false)
    checkRegistered(plugin, root, true)

    let removedIncluded = RemoteGatt(peripheral)
    let sharedIncluded = RemoteGatt(peripheral)
    root.nativeService.includedServices = [removedIncluded.service, sharedIncluded.service]
    nativePeripheral.services = [root.service, sharedIncluded.service]
    plugin.peripheral(peripheral, didDiscoverServices: nil)
    root.nativeService.includedServices = [sharedIncluded.service]
    plugin.peripheral(peripheral, didDiscoverIncludedServicesFor: root.service, error: nil)
    checkRegistered(plugin, removedIncluded, false)
    checkRegistered(plugin, sharedIncluded, true)

    let replacementDescriptor = DescriptorDouble(root.characteristic)
    let descriptor = unsafeBitCast(replacementDescriptor, to: CBDescriptor.self)
    root.nativeCharacteristic.descriptors = [descriptor]
    plugin.peripheral(peripheral, didDiscoverDescriptorsFor: root.characteristic, error: nil)
    check(plugin.descriptors[plugin.objectKey(root.descriptor)] == nil, "replaced descriptor must be released")
    check(plugin.descriptors[plugin.objectKey(descriptor)] != nil, "current descriptor must remain registered")

    let replacementCharacteristic = CharacteristicDouble(root.service)
    let characteristic = unsafeBitCast(replacementCharacteristic, to: CBCharacteristic.self)
    root.nativeService.characteristics = [characteristic]
    plugin.peripheral(peripheral, didDiscoverCharacteristicsFor: root.service, error: nil)
    check(plugin.characteristics[plugin.objectKey(root.characteristic)] == nil, "replaced characteristic must be released")
    check(plugin.descriptors[plugin.objectKey(descriptor)] == nil, "replaced characteristic's descriptors must be released")
    check(plugin.characteristics[plugin.objectKey(characteristic)] != nil, "current characteristic must remain registered")

    // Invalidating one parent must preserve an included service still reachable elsewhere.
    nativePeripheral.services = [sharedIncluded.service]
    plugin.peripheral(peripheral, didModifyServices: [root.service])
    let payload = lastEvent["payload"] as? [String: Any?]
    let invalidated = payload?["invalidatedServices"] as? [[String: Any?]] ?? []
    let current = payload?["services"] as? [[String: Any?]] ?? []
    check(invalidated.count == 1 && invalidated.first?["handle"] as? String == plugin.objectKey(root.service),
          "pruning must preserve the invalidated-service callback snapshot")
    check(current.count == 1 && current.first?["handle"] as? String == plugin.objectKey(sharedIncluded.service),
          "pruning must preserve the current-service callback snapshot")
    check(plugin.services[plugin.objectKey(root.service)] == nil, "invalidated service must be released")
    check(plugin.characteristics[plugin.objectKey(characteristic)] == nil, "invalidated subtree must be released")
    checkRegistered(plugin, sharedIncluded, true)
    let staleArgs: [String: Any] = ["managerId": 1, "peripheralIdentifier": uuid.uuidString,
                                  "serviceHandle": plugin.objectKey(root.service)]
    check(plugin.service(from: staleArgs) == nil, "invalidated service handles must stop resolving")
    plugin.peripheral(peripheral, didDiscoverCharacteristicsFor: root.service, error: nil)
    check(plugin.service(from: staleArgs) == nil, "late discovery must not retain invalidated services again")

    let serviceCount = plugin.services.count
    let characteristicCount = plugin.characteristics.count
    let descriptorCount = plugin.descriptors.count
    for _ in 0..<10 {
        let transient = RemoteGatt(peripheral)
        nativePeripheral.services = [sharedIncluded.service, transient.service]
        plugin.peripheral(peripheral, didDiscoverServices: nil)
        nativePeripheral.services = [sharedIncluded.service]
        plugin.peripheral(peripheral, didModifyServices: [transient.service])
        checkRegistered(plugin, transient, false)
    }
    check(plugin.services.count == serviceCount && plugin.characteristics.count == characteristicCount &&
          plugin.descriptors.count == descriptorCount, "repeated invalidation must not grow the registries")
    checkRegistered(plugin, peerGraph, true)
    check(plugin.services[plugin.objectKey(localService)] === localService &&
          plugin.characteristics[plugin.objectKey(localCharacteristic)] === localCharacteristic &&
          plugin.descriptors[plugin.objectKey(localDescriptor)] === localDescriptor, "local GATT must remain registered")

    // Registry cleanup must release objects even when their parent links are weak.
    weak var releasedService: ServiceDouble?
    weak var releasedCharacteristic: CharacteristicDouble?
    weak var releasedDescriptor: DescriptorDouble?
    autoreleasepool {
        let transient = RemoteGatt(peripheral)
        releasedService = transient.nativeService
        releasedCharacteristic = transient.nativeCharacteristic
        releasedDescriptor = transient.nativeDescriptor
        nativePeripheral.services = [sharedIncluded.service, transient.service]
        plugin.peripheral(peripheral, didDiscoverServices: nil)
    }
    nativePeripheral.services = [sharedIncluded.service]
    plugin.peripheral(peripheral, didDiscoverServices: nil)
    check(releasedService == nil && releasedCharacteristic == nil && releasedDescriptor == nil,
          "obsolete native objects must be deallocated, not just disconnected from the graph")

    let orphan = RemoteGatt(peripheral)
    orphan.nativeCharacteristic.service = nil
    plugin.peripheral(peripheral, didDiscoverDescriptorsFor: orphan.characteristic, error: nil)
    check(plugin.characteristics[plugin.objectKey(orphan.characteristic)] == nil &&
          plugin.descriptors[plugin.objectKey(orphan.descriptor)] == nil,
          "late callbacks with missing remote parents must not retain orphaned attributes")

    // Included-service traversal must tolerate cycles as serialization already does.
    sharedIncluded.nativeService.includedServices = [root.service]
    root.nativeService.includedServices = [sharedIncluded.service]
    plugin.peripheral(peripheral, didDiscoverServices: nil)
    check(plugin.services[plugin.objectKey(root.service)] != nil, "reachable included service must be retained")
    sharedIncluded.nativeService.includedServices = []
    root.nativeService.includedServices = []
    plugin.peripheral(peripheral, didDiscoverIncludedServicesFor: sharedIncluded.service, error: nil)
    check(plugin.services[plugin.objectKey(root.service)] == nil, "removed cyclic branch must be released")
}

private func testDisposedRemoteAttributeRelease() {
    for shared in [false, true] {
        let plugin = CoreBluetoothPlugin()
        let manager = CentralManagerBox(identifier: 1,
            centralManager: unsafeBitCast(ManagerDouble(), to: CBCentralManager.self))
        let other = CentralManagerBox(identifier: 2,
            centralManager: unsafeBitCast(ManagerDouble(), to: CBCentralManager.self))
        plugin.managers = [1: manager, 2: other]
        let uuid = UUID()
        let nativePeripheral = PeripheralDouble(identifier: uuid)
        let peripheral = unsafeBitCast(nativePeripheral, to: CBPeripheral.self)
        let nativePeer = PeripheralDouble(identifier: uuid)
        let peer = unsafeBitCast(nativePeer, to: CBPeripheral.self)
        plugin.remember(peripheral, for: manager)
        plugin.remember(peer, for: other)
        let peerGraph = RemoteGatt(peer)
        plugin.register(service: peerGraph.service)
        let localService = CBMutableService(type: CBUUID(string: "180a"), primary: true)
        plugin.register(service: localService)
        if shared {
            let extra = CentralManagerBox(identifier: 3,
                centralManager: unsafeBitCast(ManagerDouble(), to: CBCentralManager.self))
            plugin.managers[3] = extra
            plugin.remember(peripheral, for: extra)
        }

        weak var service: ServiceDouble?
        weak var characteristic: CharacteristicDouble?
        weak var descriptor: DescriptorDouble?
        autoreleasepool {
            let graph = RemoteGatt(peripheral)
            service = graph.nativeService
            characteristic = graph.nativeCharacteristic
            descriptor = graph.nativeDescriptor
            nativePeripheral.services = [graph.service]
            plugin.register(service: graph.service)
        }
        // Exercise cleanup after the framework releases its own cached graph.
        nativePeripheral.services = []
        plugin.disposeCentralManager(arguments: ["managerId": 1]) { _ in }
        if shared {
            check(service != nil && characteristic != nil && descriptor != nil,
                  "attributes must remain while another manager owns the same native peripheral")
            plugin.disposeCentralManager(arguments: ["managerId": 3]) { _ in }
        }
        check(service == nil && characteristic == nil && descriptor == nil,
              "last-owner disposal must deallocate children before their weak parent links disappear")
        checkRegistered(plugin, peerGraph, true)
        check(plugin.services[plugin.objectKey(localService)] === localService,
              "disposing remote attributes must preserve local GATT")
        check(plugin.characteristics.count == 1 && plugin.descriptors.count == 1,
              "disposal must leave no orphaned child handles")
    }
}

private func testDisconnectedRemoteGatt() {
    for modern in [false, true] {
        let plugin = CoreBluetoothPlugin()
        var lastEvent: [String: Any?] = [:]
        plugin.eventSink = { lastEvent = $0 as? [String: Any?] ?? [:] }
        let central = unsafeBitCast(ManagerDouble(), to: CBCentralManager.self)
        let otherCentral = unsafeBitCast(ManagerDouble(), to: CBCentralManager.self)
        let box = CentralManagerBox(identifier: 1, centralManager: central)
        let otherBox = CentralManagerBox(identifier: 2, centralManager: otherCentral)
        plugin.managers = [1: box, 2: otherBox]
        let uuid = UUID()
        let native = PeripheralDouble(identifier: uuid)
        let otherNative = PeripheralDouble(identifier: uuid)
        let peripheral = unsafeBitCast(native, to: CBPeripheral.self)
        let other = unsafeBitCast(otherNative, to: CBPeripheral.self)
        plugin.remember(peripheral, for: box)
        plugin.remember(other, for: otherBox)
        let graph = RemoteGatt(peripheral)
        let included = RemoteGatt(peripheral)
        graph.nativeService.includedServices = [included.service]
        native.services = [graph.service]
        let peerGraph = RemoteGatt(other)
        otherNative.services = [peerGraph.service]
        plugin.register(service: graph.service)
        plugin.register(service: peerGraph.service)
        let local = CBMutableService(type: CBUUID(string: "180a"), primary: true)
        plugin.register(service: local)
        native.services = []
        native.state = 0
        let failure = NSError(domain: "DisconnectTest", code: 7)
        if modern {
            plugin.centralManager(central, didDisconnectPeripheral: peripheral, timestamp: 123.5, isReconnecting: true, error: failure)
        } else {
            plugin.centralManager(central, didDisconnectPeripheral: peripheral, error: failure)
        }
        checkRegistered(plugin, graph, false)
        checkRegistered(plugin, included, false)
        checkRegistered(plugin, peerGraph, true)
        check(plugin.services[plugin.objectKey(local)] === local, "disconnect must preserve local GATT")
        check(box.peripherals[uuid] === peripheral, "disconnect must retain peripheral identity")
        let payload = lastEvent["payload"] as! [String: Any?]
        check((lastEvent["managerId"] as? Int) == 1 && lastEvent["kind"] as? String == "didDisconnectPeripheral",
              "disconnect must retain its original callback route and kind")
        check((payload["error"] as? [String: Any?])?["code"] as? Int == 7, "disconnect errors must be preserved")
        if modern {
            check(payload["timestamp"] as? Double == 123.5 && payload["isReconnecting"] as? Bool == true,
                  "modern disconnect metadata must be preserved")
        }
        let args: [String: Any] = ["managerId": 1, "peripheralIdentifier": uuid.uuidString,
            "serviceHandle": plugin.objectKey(graph.service), "characteristicHandle": plugin.objectKey(graph.characteristic),
            "descriptorHandle": plugin.objectKey(graph.descriptor)]
        check(plugin.service(from: args) == nil && plugin.characteristic(from: args) == nil && plugin.descriptor(from: args) == nil,
              "retired GATT handles must be rejected")
        native.state = 2
        plugin.centralManager(central, didConnect: peripheral)
        check(plugin.characteristic(from: args) == nil, "reconnection must not revive old handles before discovery")
        let fresh = RemoteGatt(peripheral)
        native.services = [fresh.service]
        plugin.peripheral(peripheral, didDiscoverServices: nil)
        checkRegistered(plugin, fresh, true)
        checkRegistered(plugin, graph, false)
        checkRegistered(plugin, peerGraph, true)
    }
}

private func testCentralAdapterInvalidation() {
    for state in 0...4 {
        let plugin = CoreBluetoothPlugin()
        let nativeManager = ManagerDouble()
        let central = unsafeBitCast(nativeManager, to: CBCentralManager.self)
        let box = CentralManagerBox(identifier: 1, centralManager: central)
        let other = CentralManagerBox(identifier: 2, centralManager: unsafeBitCast(ManagerDouble(), to: CBCentralManager.self))
        plugin.managers = [1: box, 2: other]
        let native = PeripheralDouble(identifier: UUID())
        let peerNative = PeripheralDouble(identifier: native.identifier)
        let peripheral = unsafeBitCast(native, to: CBPeripheral.self)
        let peer = unsafeBitCast(peerNative, to: CBPeripheral.self)
        plugin.remember(peripheral, for: box)
        plugin.remember(peer, for: other)
        let graph = RemoteGatt(peripheral)
        let peerGraph = RemoteGatt(peer)
        plugin.register(service: graph.service)
        plugin.register(service: peerGraph.service)
        let local = CBMutableService(type: CBUUID(string: "180a"), primary: true)
        plugin.register(service: local)
        var kinds: [String] = []
        plugin.eventSink = { event in
            let kind = (event as! [String: Any?])["kind"] as! String
            kinds.append(kind)
            if kind == "didUpdateState" && nativeManager.state != 5 {
                checkRegistered(plugin, graph, false)
            }
        }
        nativeManager.isScanning = true
        plugin.centralManagerDidUpdateState(central)
        checkRegistered(plugin, graph, true)
        check(box.isScanning, "powered-on updates must preserve scanning")
        nativeManager.state = state
        plugin.centralManagerDidUpdateState(central)
        checkRegistered(plugin, graph, false)
        checkRegistered(plugin, peerGraph, true)
        check(!box.isScanning, "leaving powered-on must stop cached scanning")
        check(box.peripherals.isEmpty == (state < 4), "native peripherals must be retired only below poweredOff")
        check(other.peripherals[peer.identifier] === peer, "other managers must retain their peripheral ownership")
        check(plugin.services[plugin.objectKey(local)] === local, "central state changes must preserve local GATT")
        check(kinds == ["didUpdateState", "didUpdateState"], "cleanup must not invent disconnect callbacks")
        nativeManager.state = 5
        plugin.remember(peripheral, for: box)
        let fresh = RemoteGatt(peripheral)
        native.services = [fresh.service]
        plugin.peripheral(peripheral, didDiscoverServices: nil)
        checkRegistered(plugin, fresh, true)
        checkRegistered(plugin, graph, false)
    }
}

private func testNativeCentralOptions() {
    let plugin = CoreBluetoothPlugin()
    let native = ManagerDouble()
    let central = unsafeBitCast(native, to: CBCentralManager.self)
    let box = CentralManagerBox(identifier: 1, centralManager: central)
    plugin.managers[1] = box
    let nativePeripheral = PeripheralDouble(identifier: UUID())
    let peripheral = unsafeBitCast(nativePeripheral, to: CBPeripheral.self)
    plugin.remember(peripheral, for: box)
    for delay in [0.0, 0.75, 2.0] {
        plugin.connect(arguments: ["managerId": 1, "peripheralIdentifier": nativePeripheral.identifier.uuidString,
                                   "options": ["startDelay": delay, "notifyOnConnection": true]]) {
            check($0 == nil, "connection options must reach the native request")
        }
        check(native.lastConnectOptions?[CBConnectPeripheralOptionStartDelayKey] as? Double == delay &&
              native.lastConnectOptions?[CBConnectPeripheralOptionNotifyOnConnectionKey] as? Bool == true,
              "native connection options must preserve zero, fractional and positive start delays")
    }
    check(native.connections == 3, "every connect request must be submitted once")
    check(plugin.connectOptions(from: nil) == nil && plugin.connectOptions(from: [:]) == nil,
          "omitted connection options must retain the native defaults")

    for uuids in [[], ["180F", "12345678-1234-5678-1234-123456789ABC"]] {
        plugin.scanForPeripherals(arguments: ["managerId": 1, "serviceUUIDs": ["180d"],
                                              "options": ["allowDuplicates": false, "solicitedServiceUUIDs": uuids]]) {
            check($0 as? Bool == true, "scan options must reach the native request")
        }
        check(native.lastScanServices == [CBUUID(string: "180d")] &&
              native.lastScanOptions?[CBCentralManagerScanOptionAllowDuplicatesKey] as? Bool == false &&
              native.lastScanOptions?[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] as? [CBUUID] == uuids.map(CBUUID.init(string:)),
              "solicited service UUIDs must remain separate from advertised service filters")
        var restored: [String: Any?] = [:]
        plugin.eventSink = { event in
            restored = (event as! [String: Any?])["payload"] as! [String: Any?]
        }
        plugin.centralManager(central, willRestoreState: [
            CBCentralManagerRestoredStateScanOptionsKey: native.lastScanOptions!
        ])
        let options = restored["scanOptions"] as? [String: Any?]
        check(options?["solicitedServiceUUIDs"] as? [String] == uuids.map { $0.lowercased() } &&
              options?["allowDuplicates"] as? Bool == false,
              "restoration must preserve explicit empty and nonempty solicited UUID lists")
    }
    check(plugin.scanOptions(from: nil) == nil && plugin.serialize(scanOptions: nil) == nil,
          "omitted scan options must stay absent")
    let defaults = plugin.scanOptions(from: ["allowDuplicates": true])!
    check(defaults[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] == nil &&
          plugin.serialize(scanOptions: defaults)?["solicitedServiceUUIDs"] == nil,
          "an omitted solicited UUID list must stay absent")
}

private func testNativeScanState() {
    for state in 0...5 {
        for accepted in [false, true] {
            let plugin = CoreBluetoothPlugin()
            let native = ManagerDouble()
            native.state = state
            native.acceptsScan = accepted
            let box = CentralManagerBox(identifier: 1, centralManager: unsafeBitCast(native, to: CBCentralManager.self))
            box.isScanning = true
            plugin.managers[1] = box
            var replies = 0
            plugin.scanForPeripherals(arguments: ["managerId": 1, "serviceUUIDs": ["180f"],
                "options": ["allowDuplicates": true]]) { result in
                replies += 1
                check(result as? Bool == native.isScanning, "scan replies must report actual native activity")
            }
            check(replies == 1 && box.isScanning == native.isScanning,
                  "native scan activity must replace the cached state and reply exactly once")
            check(native.isScanning == (state == 5 && accepted), "refused scans must not report activity")
            check(native.scanRequests == 1 && native.lastScanServices == [CBUUID(string: "180f")] &&
                  native.lastScanOptions?[CBCentralManagerScanOptionAllowDuplicatesKey] as? Bool == true,
                  "scan submission must preserve the caller's native services and options")
        }
    }
}

private func testRemoteHandleLifetimes() {
    let plugin = CoreBluetoothPlugin()
    plugin.eventSink = { _ in }
    let central = unsafeBitCast(ManagerDouble(), to: CBCentralManager.self)
    let manager = CentralManagerBox(identifier: 1, centralManager: central)
    plugin.managers[1] = manager
    let native = PeripheralDouble(identifier: UUID())
    let peripheral = unsafeBitCast(native, to: CBPeripheral.self)
    plugin.remember(peripheral, for: manager)
    var retired: [String: Any]?
    var seen = Set<String>()
    for _ in 0..<500 {
        weak var service: ServiceDouble?
        weak var characteristic: CharacteristicDouble?
        weak var descriptor: DescriptorDouble?
        autoreleasepool {
            let graph = RemoteGatt(peripheral)
            service = graph.nativeService
            characteristic = graph.nativeCharacteristic
            descriptor = graph.nativeDescriptor
            native.state = 2
            native.services = [graph.service]
            plugin.peripheral(peripheral, didDiscoverServices: nil)
            let handles = [plugin.objectKey(graph.service), plugin.objectKey(graph.characteristic), plugin.objectKey(graph.descriptor)]
            for handle in handles { check(seen.insert(handle).inserted, "fresh remote objects must receive fresh handles") }
            let args: [String: Any] = ["managerId": 1, "peripheralIdentifier": native.identifier.uuidString,
                "serviceHandle": handles[0], "characteristicHandle": handles[1], "descriptorHandle": handles[2]]
            if let old = retired {
                check(plugin.service(from: old) == nil, "stale services must not resolve after rediscovery")
                let reject: FlutterResult = { check(($0 as? FlutterError)?.code == "invalid_args", "stale remote handles must fail") }
                let reads = native.characteristicReads + native.descriptorReads
                plugin.readValueForCharacteristic(arguments: old, result: reject)
                plugin.readValueForDescriptor(arguments: old, result: reject)
                check(native.characteristicReads + native.descriptorReads == reads,
                      "stale remote reads must not reach replacement attributes")
            }
            plugin.readValueForCharacteristic(arguments: args) { check($0 == nil, "current characteristics must remain readable") }
            plugin.readValueForDescriptor(arguments: args) { check($0 == nil, "current descriptors must remain readable") }
            native.state = 0
            native.services = []
            plugin.centralManager(central, didDisconnectPeripheral: peripheral, error: nil)
            retired = args
        }
        check(service == nil && characteristic == nil && descriptor == nil,
              "disconnected remote attributes must actually deallocate before replacement")
    }
    check(native.characteristicReads == 500 && native.descriptorReads == 500,
          "only current handles may perform remote reads")
}

private func testAdvertisementUUIDFields() {
    let plugin = CoreBluetoothPlugin()
    let native = ManagerDouble()
    native.isScanning = true
    let central = unsafeBitCast(native, to: CBCentralManager.self)
    let box = CentralManagerBox(identifier: 1, centralManager: central)
    plugin.managers[1] = box
    let peripheral = unsafeBitCast(PeripheralDouble(identifier: UUID()), to: CBPeripheral.self)
    var advertisement: [String: Any?] = [:]
    plugin.eventSink = { event in
        let frame = event as! [String: Any?]
        advertisement = (frame["payload"] as! [String: Any?])["advertisementData"] as! [String: Any?]
    }
    let full = "12345678-1234-1234-1234-123456789abc"
    plugin.centralManager(central, didDiscover: peripheral, advertisementData: [
        CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: "180F")],
        CBAdvertisementDataOverflowServiceUUIDsKey: [CBUUID(string: "1810"), CBUUID(string: full.uppercased())],
        CBAdvertisementDataSolicitedServiceUUIDsKey: [CBUUID(string: "180D")]
    ], rssi: -40)
    check(advertisement["serviceUUIDs"] as? [String] == ["180f"], "ordinary services must remain separate")
    check(advertisement["overflowServiceUUIDs"] as? [String] == ["1810", full], "overflow services must be forwarded")
    check(advertisement["solicitedServiceUUIDs"] as? [String] == ["180d"], "solicited services must be forwarded")
    plugin.centralManager(central, didDiscover: peripheral, advertisementData: [:], rssi: -40)
    check(advertisement["overflowServiceUUIDs"] == nil && advertisement["solicitedServiceUUIDs"] == nil,
          "absent UUID lists must stay absent")
    plugin.centralManager(central, didDiscover: peripheral, advertisementData: [
        CBAdvertisementDataOverflowServiceUUIDsKey: [CBUUID](), CBAdvertisementDataSolicitedServiceUUIDsKey: [CBUUID]()
    ], rssi: -40)
    check(advertisement["overflowServiceUUIDs"] as? [String] == [] && advertisement["solicitedServiceUUIDs"] as? [String] == [],
          "explicit empty UUID lists must stay empty")
}

@main
private struct RegistryTests {
    static func main() {
        let plugin = CoreBluetoothPlugin()
        let nativeManager1 = ManagerDouble()
        let nativeManager2 = ManagerDouble()
        let manager1 = CentralManagerBox(identifier: 1, centralManager: unsafeBitCast(nativeManager1, to: CBCentralManager.self))
        let manager2 = CentralManagerBox(identifier: 2, centralManager: unsafeBitCast(nativeManager2, to: CBCentralManager.self))
        plugin.managers = [1: manager1, 2: manager2]

        let uuid = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!
        let nativePeripheral1 = PeripheralDouble(identifier: uuid)
        let nativePeripheral2 = PeripheralDouble(identifier: uuid)
        let peripheral1 = unsafeBitCast(nativePeripheral1, to: CBPeripheral.self)
        let peripheral2 = unsafeBitCast(nativePeripheral2, to: CBPeripheral.self)
        plugin.remember(peripheral1, for: manager1)
        plugin.remember(peripheral2, for: manager2)
        let args1: [String: Any] = ["managerId": 1, "peripheralIdentifier": uuid.uuidString]
        let args2: [String: Any] = ["managerId": 2, "peripheralIdentifier": uuid.uuidString]
        check(plugin.peripheral(from: args1) === peripheral1, "manager 1 must retain its own peripheral")
        check(plugin.peripheral(from: args2) === peripheral2, "manager 2 must retain its own peripheral")
        plugin.readRSSI(arguments: args1) { _ in }
        check(nativePeripheral1.reads == 1 && nativePeripheral2.reads == 0, "requests must stay with their owner")

        var received: [Int] = []
        plugin.eventSink = { event in
            let data = event as! [String: Any?]
            received.append(data["managerId"] as! Int)
        }
        plugin.peripheralDidUpdateName(peripheral1)
        check(received == [1], "manager 2 must not steal manager 1 callbacks")
        received.removeAll()
        plugin.peripheralDidUpdateName(peripheral2)
        check(received == [2], "manager 1 must not receive manager 2 callbacks")

        let nativeService = ServiceDouble(peripheral1)
        let service = unsafeBitCast(nativeService, to: CBService.self)
        let nativeCharacteristic = CharacteristicDouble(service)
        let characteristic = unsafeBitCast(nativeCharacteristic, to: CBCharacteristic.self)
        let nativeDescriptor = DescriptorDouble(characteristic)
        let descriptor = unsafeBitCast(nativeDescriptor, to: CBDescriptor.self)
        plugin.services["s"] = service
        plugin.characteristics["c"] = characteristic
        plugin.descriptors["d"] = descriptor
        check(plugin.service(from: args1.merging(["serviceHandle": "s"]) { _, new in new }) === service,
              "owner must resolve its service")
        check(plugin.service(from: args2.merging(["serviceHandle": "s"]) { _, new in new }) == nil,
              "another manager must not resolve that service")
        check(plugin.characteristic(from: args1.merging(["characteristicHandle": "c"]) { _, new in new }) === characteristic,
              "owner must resolve its characteristic")
        check(plugin.characteristic(from: args2.merging(["characteristicHandle": "c"]) { _, new in new }) == nil,
              "another manager must not resolve that characteristic")
        check(plugin.descriptor(from: args1.merging(["descriptorHandle": "d"]) { _, new in new }) === descriptor,
              "owner must resolve its descriptor")
        check(plugin.descriptor(from: args2.merging(["descriptorHandle": "d"]) { _, new in new }) == nil,
              "another manager must not resolve that descriptor")

        plugin.disposeCentralManager(arguments: ["managerId": 1]) { _ in }
        check(nativeManager1.cancellations == 1, "disposing a manager must cancel its connection")
        check(nativeManager2.cancellations == 0, "disposing a manager must not cancel another manager's connection")
        check(plugin.peripheral(from: args2) === peripheral2, "remaining manager must keep its registry")
        check(plugin.services["s"] == nil && plugin.characteristics["c"] == nil && plugin.descriptors["d"] == nil,
              "retired remote attributes must be released")

        plugin.peripheral(peripheral1, didDiscoverCharacteristicsFor: service, error: nil)
        check(plugin.services["s"] == nil, "late callbacks must not repopulate a disposed manager's attributes")

        // Also handle frameworks that return one native object to both owners.
        plugin.managers[1] = manager1
        plugin.remember(peripheral1, for: manager2)
        received.removeAll()
        plugin.peripheralDidUpdateName(peripheral1)
        check(Set(received) == [1, 2], "shared native identity must notify each registered owner")
        testNullableDiscoveryCollections()
        testNativeBroadcastState()
        testRemoteGattPruning()
        testDisposedRemoteAttributeRelease()
        testDisconnectedRemoteGatt()
        testCentralAdapterInvalidation()
        testNativeCentralOptions()
        testNativeScanState()
        testScanDelivery()
        testRemoteHandleLifetimes()
        testGattHandleLifetimes()
        testAdvertisementUUIDFields()
        testL2CAPLifetime()
        testPeripheralManagerOwnership()
        print("Native registry tests passed (central/server ownership, callback routing, handles, disposal, GATT pruning, L2CAP)")
    }
}
