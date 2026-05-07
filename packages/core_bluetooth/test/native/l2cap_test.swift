import CoreBluetooth
import Foundation
import FlutterMacOS
import Darwin

private final class L2CAPCentralDouble: NSObject {
    @objc let state = 5
    @objc func stopScan() {}
    @objc func cancelPeripheralConnection(_ peripheral: CBPeripheral) {}
}

private final class L2CAPPeripheralManagerDouble: NSObject {
    var unpublished: [UInt16] = []
    @objc func stopAdvertising() {}
    @objc(unpublishL2CAPChannel:) func unpublish(_ psm: UInt16) { unpublished.append(psm) }
}

private final class L2CAPPeripheralDouble: NSObject {
    @objc let identifier = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!
    @objc let state = 2
    @objc let name = "L2CAP peer"
    @objc let canSendWriteWithoutResponse = true
    @objc weak var delegate: AnyObject?
    var opened: [UInt16] = []
    @objc(openL2CAPChannel:) func open(_ psm: UInt16) { opened.append(psm) }
}

private final class L2CAPChannelDouble: NSObject {
    @objc(PSM) let psm: UInt16 = 1234
    @objc let peer: NSObject
    @objc var inputStream: InputStream?
    @objc var outputStream: OutputStream?

    init(peer: NSObject, input: Bool = true, output: Bool = true) {
        self.peer = peer
        inputStream = input ? InputStream(data: Data([1, 2, 3])) : nil
        outputStream = output ? OutputStream.toMemory() : nil
        super.init()
        inputStream?.open()
        outputStream?.open()
    }
}

private func requireL2CAP(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

private func requireSuccess(_ result: Any?) {
    requireL2CAP(result == nil, "L2CAP operation must succeed: \(String(describing: result))")
}

private func readBytes(_ result: Any?) -> [UInt8] {
    guard let bytes = result as? FlutterStandardTypedData else {
        preconditionFailure("L2CAP reads must return typed byte buffers")
    }
    return Array(bytes.data)
}

private func waitForL2CAP(_ condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(3)
    while !condition() && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.005))
    }
    requireL2CAP(condition(), "L2CAP asynchronous operation timed out")
}

@discardableResult
private func awaitL2CAP(_ operation: (@escaping FlutterResult) -> Void) -> Any? {
    var completed = false
    var value: Any?
    operation {
        requireL2CAP(Thread.isMainThread, "Flutter results must be delivered on the main thread")
        value = $0
        completed = true
    }
    waitForL2CAP { completed }
    return value
}

private final class L2CAPFixture {
    let plugin = CoreBluetoothPlugin()
    let firstPeer = L2CAPPeripheralDouble()
    let secondPeer = L2CAPPeripheralDouble()
    let server = L2CAPPeripheralManagerDouble()
    private var openedHandles: [String] = []

    init() {
        plugin.eventSink = { [weak self] event in
            let data = event as? [String: Any?]
            let payload = data?["payload"] as? [String: Any?]
            let channel = payload?["channel"] as? [String: Any?]
            if let handle = channel?["handle"] as? String { self?.openedHandles.append(handle) }
        }
        let first = CentralManagerBox(identifier: 1,
                                     centralManager: unsafeBitCast(L2CAPCentralDouble(), to: CBCentralManager.self))
        let second = CentralManagerBox(identifier: 2,
                                      centralManager: unsafeBitCast(L2CAPCentralDouble(), to: CBCentralManager.self))
        plugin.managers = [1: first, 2: second]
        plugin.remember(unsafeBitCast(firstPeer, to: CBPeripheral.self), for: first)
        plugin.remember(unsafeBitCast(secondPeer, to: CBPeripheral.self), for: second)
        plugin.peripheralManagers[3] = unsafeBitCast(server, to: CBPeripheralManager.self)
    }

    func open(_ channel: L2CAPChannelDouble, managerId: Int = 1) -> String {
        let native = unsafeBitCast(channel, to: CBL2CAPChannel.self)
        let previousCount = openedHandles.count
        if managerId == 3 {
            plugin.peripheralManager(unsafeBitCast(server, to: CBPeripheralManager.self), didOpen: native, error: nil)
        } else {
            let peer = managerId == 1 ? firstPeer : secondPeer
            plugin.peripheral(unsafeBitCast(peer, to: CBPeripheral.self), didOpen: native, error: nil)
        }
        return openedHandles.count > previousCount ? openedHandles.last! : ""
    }
}

private func testL2CAPStreamClosure() {
    for inputFirst in [false, true] {
        let fixture = L2CAPFixture()
        let plugin = fixture.plugin
        for _ in 0..<10 {
            weak var released: L2CAPChannelDouble?
            autoreleasepool {
                let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
                released = channel
                let handle = fixture.open(channel)
                let args = ["channelHandle": handle]
                if inputFirst {
                    plugin.closeL2CAPInputStream(arguments: args, result: requireSuccess)
                    plugin.closeL2CAPInputStream(arguments: args, result: requireSuccess)
                    let written = awaitL2CAP { reply in
                        plugin.writeL2CAPOutputStream(arguments: ["channelHandle": handle,
                            "value": FlutterStandardTypedData(bytes: Data([7, 8]))], result: reply)
                    }
                    requireL2CAP(written as? Int == 2, "closing input must leave output usable")
                    requireL2CAP(plugin.l2capChannels[handle] != nil, "one closed stream must retain the channel")
                    requireSuccess(awaitL2CAP { plugin.closeL2CAPOutputStream(arguments: args, result: $0) })
                } else {
                    plugin.closeL2CAPOutputStream(arguments: args, result: requireSuccess)
                    plugin.closeL2CAPOutputStream(arguments: args, result: requireSuccess)
                    let bytes = awaitL2CAP { reply in
                        plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 3], result: reply)
                    }
                    requireL2CAP(readBytes(bytes) == [1, 2, 3], "closing output must leave input usable")
                    requireL2CAP(plugin.l2capChannels[handle] != nil, "one closed stream must retain the channel")
                    requireSuccess(awaitL2CAP { plugin.closeL2CAPInputStream(arguments: args, result: $0) })
                }
                requireL2CAP(plugin.l2capChannels.isEmpty, "two closed streams must release their channel")
                plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 1]) {
                    requireL2CAP(($0 as? FlutterError)?.code == "invalid_args", "released handles must stop resolving")
                }
            }
            requireL2CAP(released == nil, "closed native channels must actually deallocate")
        }
    }
}

private func testL2CAPManagerDisposal() {
    let fixture = L2CAPFixture()
    let plugin = fixture.plugin
    let first = L2CAPChannelDouble(peer: fixture.firstPeer)
    let second = L2CAPChannelDouble(peer: fixture.secondPeer)
    let server = L2CAPChannelDouble(peer: fixture.firstPeer)
    let firstHandle = fixture.open(first)
    let secondHandle = fixture.open(second, managerId: 2)
    let serverHandle = fixture.open(server, managerId: 3)
    plugin.closeL2CAPInputStream(arguments: ["channelHandle": firstHandle], result: requireSuccess)
    requireSuccess(awaitL2CAP { plugin.disposeCentralManager(arguments: ["managerId": 1], result: $0) })
    requireL2CAP(plugin.l2capChannels[firstHandle] == nil, "central disposal must release its channels")
    requireL2CAP(first.inputStream?.streamStatus == .closed && first.outputStream?.streamStatus == .closed,
                 "central disposal must close both streams")
    requireL2CAP(plugin.l2capChannels[secondHandle] != nil && plugin.l2capChannels[serverHandle] != nil,
                 "central disposal must preserve other managers' channels")
    requireL2CAP(second.inputStream?.streamStatus == .open && server.outputStream?.streamStatus == .open,
                 "unrelated streams must remain open")
    requireSuccess(awaitL2CAP { plugin.disposePeripheralManager(arguments: ["managerId": 3], result: $0) })
    requireL2CAP(plugin.l2capChannels[serverHandle] == nil, "peripheral-manager disposal must release its channels")
    requireL2CAP(server.inputStream?.streamStatus == .closed && server.outputStream?.streamStatus == .closed,
                 "peripheral-manager disposal must close both streams")
    requireL2CAP(plugin.l2capChannels[secondHandle] != nil, "another central's channel must remain registered")
    requireSuccess(awaitL2CAP { plugin.disposeCentralManager(arguments: ["managerId": 2], result: $0) })
    requireL2CAP(plugin.l2capChannels.isEmpty, "disposing all managers must leave no channels")
    _ = fixture.open(first)
    _ = fixture.open(server, managerId: 3)
    requireL2CAP(plugin.l2capChannels.isEmpty, "late callbacks must not recreate disposed managers' channels")
}

private func testL2CAPSharedOwnership() {
    let fixture = L2CAPFixture()
    let plugin = fixture.plugin
    plugin.remember(unsafeBitCast(fixture.firstPeer, to: CBPeripheral.self), for: plugin.managers[2]!)
    let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
    let handle = fixture.open(channel)
    plugin.closeL2CAPInputStream(arguments: ["channelHandle": handle], result: requireSuccess)
    _ = fixture.open(channel)
    requireSuccess(awaitL2CAP { plugin.disposeCentralManager(arguments: ["managerId": 1], result: $0) })
    requireL2CAP(plugin.l2capChannels[handle] != nil && channel.outputStream?.streamStatus == .open,
                 "disposing one owner must preserve a shared native channel")
    requireSuccess(awaitL2CAP { plugin.disposeCentralManager(arguments: ["managerId": 2], result: $0) })
    requireL2CAP(plugin.l2capChannels[handle] == nil && channel.outputStream?.streamStatus == .closed,
                 "disposing the final owner must close and release the channel")

    let other = L2CAPFixture()
    let repeated = L2CAPChannelDouble(peer: other.firstPeer)
    let repeatedHandle = other.open(repeated)
    other.plugin.closeL2CAPInputStream(arguments: ["channelHandle": repeatedHandle], result: requireSuccess)
    _ = other.open(repeated)
    other.plugin.closeL2CAPOutputStream(arguments: ["channelHandle": repeatedHandle], result: requireSuccess)
    requireL2CAP(other.plugin.l2capChannels.isEmpty, "repeated snapshots must not reset stream-close state")
}

private func testL2CAPMissingStream() {
    for inputMissing in [false, true] {
        let fixture = L2CAPFixture()
        let channel = L2CAPChannelDouble(peer: fixture.firstPeer, input: !inputMissing, output: inputMissing)
        let handle = fixture.open(channel)
        if inputMissing {
            fixture.plugin.closeL2CAPOutputStream(arguments: ["channelHandle": handle], result: requireSuccess)
        } else {
            fixture.plugin.closeL2CAPInputStream(arguments: ["channelHandle": handle], result: requireSuccess)
        }
        requireL2CAP(fixture.plugin.l2capChannels.isEmpty, "an absent stream must not prevent channel release")
    }
}

private func testL2CAPRetiredHandles() {
    let fixture = L2CAPFixture()
    let plugin = fixture.plugin
    let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
    let retiredHandle = fixture.open(channel)
    plugin.closeL2CAPInputStream(arguments: ["channelHandle": retiredHandle], result: requireSuccess)
    plugin.closeL2CAPOutputStream(arguments: ["channelHandle": retiredHandle], result: requireSuccess)
    _ = fixture.open(channel)
    requireL2CAP(plugin.l2capChannels.isEmpty, "a late snapshot of a fully closed channel must not retain it again")

    // Reuse the same address to model a new native allocation after release.
    channel.inputStream = InputStream(data: Data())
    channel.outputStream = OutputStream.toMemory()
    channel.inputStream?.open()
    channel.outputStream?.open()
    let currentHandle = fixture.open(channel)
    requireL2CAP(currentHandle != retiredHandle, "native address reuse must not revive a retired handle")
    plugin.closeL2CAPOutputStream(arguments: ["channelHandle": retiredHandle]) {
        requireL2CAP(($0 as? FlutterError)?.code == "invalid_args", "retired handles must be rejected")
    }
    requireL2CAP(channel.outputStream?.streamStatus == .open, "a stale handle must not close a new channel's stream")
    requireSuccess(awaitL2CAP { plugin.disposeCentralManager(arguments: ["managerId": 1], result: $0) })
}

private func testL2CAPReadErrorsAndEOF() {
    let fixture = L2CAPFixture()
    let plugin = fixture.plugin
    let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
    channel.inputStream = InputStream(url: URL(fileURLWithPath: "/private/tmp/l2cap-missing-\(UUID().uuidString)"))!
    let handle = fixture.open(channel)
    let result = awaitL2CAP { plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 16], result: $0) }
    let error = result as? FlutterError
    let details = error?.details as? [String: Any]
    requireL2CAP(error?.code == "stream_error" && error?.message?.isEmpty == false &&
                 details?["domain"] as? String != nil && details?["code"] as? Int != nil,
                 "read errors must preserve the native message, domain and code")
    requireSuccess(awaitL2CAP { plugin.closeL2CAPInputStream(arguments: ["channelHandle": handle], result: $0) })
    requireSuccess(awaitL2CAP { plugin.closeL2CAPOutputStream(arguments: ["channelHandle": handle], result: $0) })

    let empty = L2CAPChannelDouble(peer: fixture.firstPeer)
    empty.inputStream = InputStream(data: Data())
    let emptyHandle = fixture.open(empty)
    for _ in 0..<2 {
        let bytes = awaitL2CAP {
            plugin.readL2CAPInputStream(arguments: ["channelHandle": emptyHandle, "maxLength": 16], result: $0)
        }
        requireL2CAP(readBytes(bytes) == [], "clean EOF must keep returning empty bytes")
    }
    requireSuccess(awaitL2CAP { plugin.disposeCentralManager(arguments: ["managerId": 1], result: $0) })
}

private func testL2CAPReadResponsivenessAndOrder() {
    let fixture = L2CAPFixture()
    let plugin = fixture.plugin
    var descriptors: [Int32] = [0, 0]
    requireL2CAP(Darwin.pipe(&descriptors) == 0, "create a local pipe")
    defer { Darwin.close(descriptors[0]); Darwin.close(descriptors[1]) }
    let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
    channel.inputStream = InputStream(fileAtPath: "/dev/fd/\(descriptors[0])")!
    let handle = fixture.open(channel)
    let writer = descriptors[1]
    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) {
        let bytes: [UInt8] = [7, 8]
        _ = bytes.withUnsafeBufferPointer { Darwin.write(writer, $0.baseAddress!, $0.count) }
    }
    var progress: [String] = []
    var values: [[UInt8]] = []
    DispatchQueue.main.async { progress.append("main") }
    for index in 0..<2 {
        plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 1]) {
            requireL2CAP(Thread.isMainThread, "read results must return on the main thread")
            requireL2CAP(index == values.count, "queued reads must finish in submission order")
            values.append(readBytes($0))
            progress.append("read")
        }
    }
    waitForL2CAP { values.count == 2 }
    requireL2CAP(progress.first == "main" && values == [[7], [8]], "waiting for data must not block the main thread")
    requireSuccess(awaitL2CAP { plugin.disposeCentralManager(arguments: ["managerId": 1], result: $0) })
}

private func testL2CAPWriteOrderAndPartialCounts() {
    let fixture = L2CAPFixture()
    let plugin = fixture.plugin
    let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
    let handle = fixture.open(channel)
    var counts: [Int] = []
    for byte: UInt8 in [1, 2, 3] {
        plugin.writeL2CAPOutputStream(arguments: ["channelHandle": handle,
            "value": FlutterStandardTypedData(bytes: Data([byte]))]) {
            requireL2CAP(Thread.isMainThread, "write results must return on the main thread")
            counts.append($0 as! Int)
        }
    }
    waitForL2CAP { counts.count == 3 }
    requireSuccess(awaitL2CAP { plugin.closeL2CAPOutputStream(arguments: ["channelHandle": handle], result: $0) })
    let data = channel.outputStream?.property(forKey: .dataWrittenToMemoryStreamKey) as? Data
    requireL2CAP(counts == [1, 1, 1] && data == Data([1, 2, 3]), "writes must preserve order and byte counts")

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    defer { buffer.deallocate() }
    buffer.initialize(repeating: 0, count: 2)
    let direct = OutputStream(toBuffer: buffer, capacity: 2)
    direct.open()
    let submitted: [UInt8] = [4, 5, 6, 7]
    let expected = submitted.withUnsafeBufferPointer { direct.write($0.baseAddress!, maxLength: $0.count) }
    direct.close()
    let expectedBytes = [buffer[0], buffer[1]]
    buffer.update(repeating: 0, count: 2)
    let partial = L2CAPChannelDouble(peer: fixture.firstPeer)
    partial.outputStream = OutputStream(toBuffer: buffer, capacity: 2)
    let partialHandle = fixture.open(partial)
    let written = awaitL2CAP {
        plugin.writeL2CAPOutputStream(arguments: ["channelHandle": partialHandle,
            "value": FlutterStandardTypedData(bytes: Data([4, 5, 6, 7]))], result: $0)
    }
    requireL2CAP(written as? Int == expected,
                 "writes must preserve native counts (got \(String(describing: written)), expected \(expected))")
    requireSuccess(awaitL2CAP { plugin.disposeCentralManager(arguments: ["managerId": 1], result: $0) })
    requireL2CAP([buffer[0], buffer[1]] == expectedBytes, "bounded writes must preserve submitted bytes")
}

private func testL2CAPReadCancellation() {
    for managerId in [0, 1, 3] {
        let fixture = L2CAPFixture()
        let plugin = fixture.plugin
        var input: InputStream?
        var peer: OutputStream?
        Stream.getBoundStreams(withBufferSize: 1024, inputStream: &input, outputStream: &peer)
        let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
        channel.inputStream = input
        let handle = fixture.open(channel, managerId: managerId == 3 ? 3 : 1)
        var results: [String] = []
        for _ in 0..<3 {
            plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 16]) {
                requireL2CAP(Thread.isMainThread, "cancellation results must return on main")
                results.append(($0 as? FlutterError)?.code ?? "unexpected data")
            }
        }
        var closed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(30)) {
            requireL2CAP(results.isEmpty, "idle reads must stay pending until data or cancellation")
            let completion: FlutterResult = {
                requireSuccess($0)
                closed = true
            }
            if managerId == 0 {
                plugin.closeL2CAPInputStream(arguments: ["channelHandle": handle], result: completion)
            } else if managerId == 1 {
                plugin.disposeCentralManager(arguments: ["managerId": managerId], result: completion)
            } else {
                plugin.disposePeripheralManager(arguments: ["managerId": managerId], result: completion)
            }
        }
        waitForL2CAP { closed && results.count == 3 }
        requireL2CAP(results == ["stream_closed", "stream_closed", "stream_closed"],
                     "close and manager disposal must cancel every pending read exactly once")
        if managerId == 0 {
            let written = awaitL2CAP {
                plugin.writeL2CAPOutputStream(arguments: ["channelHandle": handle,
                    "value": FlutterStandardTypedData(bytes: Data([9]))], result: $0)
            }
            requireL2CAP(written as? Int == 1, "canceling input must leave output usable")
            requireSuccess(awaitL2CAP { plugin.closeL2CAPOutputStream(arguments: ["channelHandle": handle], result: $0) })
        }
        requireL2CAP(plugin.l2capChannels.isEmpty, "closed channels must release their registry entry")
        peer?.close()
    }
}

private func testL2CAPWriteCancellation() {
    let fixture = L2CAPFixture()
    let plugin = fixture.plugin
    var peer: InputStream?
    var output: OutputStream?
    Stream.getBoundStreams(withBufferSize: 1024, inputStream: &peer, outputStream: &output)
    peer!.open()
    let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
    channel.outputStream = output
    let handle = fixture.open(channel)
    var finished = 0
    var canceled = 0
    for _ in 0..<32 {
        plugin.writeL2CAPOutputStream(arguments: ["channelHandle": handle,
            "value": FlutterStandardTypedData(bytes: Data(repeating: 7, count: 1024))]) {
            requireL2CAP(Thread.isMainThread, "write cancellation results must return on main")
            if let error = $0 as? FlutterError {
                requireL2CAP(error.code == "stream_closed", "pending writes must receive the closed-stream error")
                canceled += 1
            } else {
                requireL2CAP(($0 as? Int ?? -1) >= 0, "writes before backpressure must report their native count")
            }
            finished += 1
        }
    }
    var closed = false
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(30)) {
        requireL2CAP(finished < 32, "the undrained bound stream must leave writes pending")
        plugin.closeL2CAPOutputStream(arguments: ["channelHandle": handle]) {
            requireSuccess($0)
            closed = true
        }
    }
    waitForL2CAP { closed && finished == 32 }
    requireL2CAP(canceled > 0, "closing output must cancel writes waiting for space")
    requireSuccess(awaitL2CAP { plugin.closeL2CAPInputStream(arguments: ["channelHandle": handle], result: $0) })
    peer?.close()
}

private func testL2CAPEmptyOperations() {
    let fixture = L2CAPFixture()
    let plugin = fixture.plugin
    let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
    let handle = fixture.open(channel)
    for length in [0, -1] {
        let bytes = awaitL2CAP { plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": length], result: $0) }
        requireL2CAP(readBytes(bytes) == [], "empty reads must preserve the existing result")
    }
    let bytes = awaitL2CAP { plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 1], result: $0) }
    requireL2CAP(readBytes(bytes) == [1], "empty reads must not consume any input")
    let count = awaitL2CAP {
        plugin.writeL2CAPOutputStream(arguments: ["channelHandle": handle,
            "value": FlutterStandardTypedData(bytes: Data())], result: $0)
    }
    requireL2CAP(count as? Int == 0, "empty writes must keep returning zero")
    requireSuccess(awaitL2CAP { plugin.disposeCentralManager(arguments: ["managerId": 1], result: $0) })
}

private func testL2CAPClosingSnapshot() {
    let fixture = L2CAPFixture()
    let plugin = fixture.plugin
    let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
    let handle = fixture.open(channel)
    _ = awaitL2CAP { plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 1], result: $0) }
    _ = awaitL2CAP { plugin.writeL2CAPOutputStream(arguments: ["channelHandle": handle,
        "value": FlutterStandardTypedData(bytes: Data([1]))], result: $0) }
    var completed = 0
    let reply: FlutterResult = { requireSuccess($0); completed += 1 }
    plugin.closeL2CAPInputStream(arguments: ["channelHandle": handle], result: reply)
    plugin.closeL2CAPOutputStream(arguments: ["channelHandle": handle], result: reply)
    requireL2CAP(fixture.open(channel) == handle && plugin.l2capChannels.count == 1,
                 "a closing channel must keep its existing lifetime until close completes")
    waitForL2CAP { completed == 2 }
    requireL2CAP(plugin.l2capChannels.isEmpty, "the final stream close must release the channel")
    _ = fixture.open(channel)
    requireL2CAP(plugin.l2capChannels.isEmpty, "a completed close must not be revived by a late snapshot")
}

private func testL2CAPOwnerRelease() {
    weak var plugin: CoreBluetoothPlugin?
    var fixture: L2CAPFixture? = L2CAPFixture()
    plugin = fixture!.plugin
    var input: InputStream?
    var peer: OutputStream?
    Stream.getBoundStreams(withBufferSize: 1024, inputStream: &input, outputStream: &peer)
    let channel = L2CAPChannelDouble(peer: fixture!.firstPeer)
    channel.inputStream = input
    let handle = fixture!.open(channel)
    var code: String?
    fixture!.plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 16]) {
        code = ($0 as? FlutterError)?.code
    }
    fixture = nil
    requireL2CAP(plugin == nil, "pending stream I/O must not retain the owning plugin")
    waitForL2CAP { code != nil }
    requireL2CAP(code == "stream_closed", "releasing the channel owner must cancel its pending read")
    peer?.close()
}

private func testL2CAPPSMRange() {
    let fixture = L2CAPFixture()
    let plugin = fixture.plugin
    let identifier = fixture.firstPeer.identifier.uuidString
    let valid: [UInt16] = [0, 1, 129, UInt16.max]
    for psm in valid {
        plugin.openL2CAPChannel(arguments: ["managerId": 1, "peripheralIdentifier": identifier, "psm": psm], result: requireSuccess)
        plugin.unpublishL2CAPChannel(arguments: ["managerId": 3, "psm": psm], result: requireSuccess)
    }
    requireL2CAP(fixture.firstPeer.opened == valid && fixture.server.unpublished == valid,
                 "valid 16-bit PSM arguments must reach native unchanged")
    let invalid: [NSNumber] = [NSNumber(value: -1), NSNumber(value: 65536), NSNumber(value: 65665),
        NSNumber(value: Int64.min), NSNumber(value: Int64.max), NSNumber(value: UInt64.max),
        NSNumber(value: 129.5), NSNumber(value: Double.nan), NSNumber(value: Double.infinity)]
    var replies = 0
    let reject: FlutterResult = {
        replies += 1
        requireL2CAP(($0 as? FlutterError)?.code == "invalid_args", "invalid PSMs must fail normally")
    }
    for psm in invalid {
        plugin.openL2CAPChannel(arguments: ["managerId": 1, "peripheralIdentifier": identifier, "psm": psm], result: reject)
        plugin.unpublishL2CAPChannel(arguments: ["managerId": 3, "psm": psm], result: reject)
    }
    plugin.openL2CAPChannel(arguments: ["managerId": 1, "peripheralIdentifier": identifier], result: reject)
    plugin.unpublishL2CAPChannel(arguments: ["managerId": 3], result: reject)
    requireL2CAP(replies == invalid.count * 2 + 2, "each invalid request must receive one reply")
    requireL2CAP(fixture.firstPeer.opened == valid && fixture.server.unpublished == valid,
                 "invalid PSMs must not open or unpublish any native channel")
}

private func testL2CAPTypedReadBuffers() {
    let fixture = L2CAPFixture()
    let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
    let payload = Data((0..<8192).map { UInt8(truncatingIfNeeded: $0 / 32) })
    channel.inputStream = InputStream(data: payload)
    let handle = fixture.open(channel)
    let first = awaitL2CAP {
        fixture.plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 4096], result: $0)
    }
    requireL2CAP(readBytes(first) == Array(payload.prefix(4096)), "typed reads must preserve the full byte payload")
    let encoded = FlutterStandardMethodCodec.sharedInstance().encodeSuccessEnvelope(first)
    requireL2CAP(encoded.count <= 4096 + 16, "platform-channel reads must use compact binary encoding")
    let second = awaitL2CAP {
        fixture.plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 4096], result: $0)
    }
    requireL2CAP(readBytes(second) == Array(payload.suffix(4096)), "successive typed reads must advance through input")
    let eof = awaitL2CAP {
        fixture.plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 4096], result: $0)
    }
    requireL2CAP(readBytes(eof).isEmpty, "clean EOF must also use an empty typed byte buffer")
    requireSuccess(awaitL2CAP { fixture.plugin.disposeCentralManager(arguments: ["managerId": 1], result: $0) })
}

private func testL2CAPBoundedReadBuffers() {
    let fixture = L2CAPFixture()
    let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
    let chunkSize = 64 * 1024
    let payload = Data((0..<(2 * chunkSize + 37)).map { UInt8(truncatingIfNeeded: $0 / 13) })
    channel.inputStream = InputStream(data: payload)
    let handle = fixture.open(channel)
    func read(_ length: Int) -> [UInt8] {
        readBytes(awaitL2CAP {
            fixture.plugin.readL2CAPInputStream(
                arguments: ["channelHandle": handle, "maxLength": NSNumber(value: length)], result: $0)
        })
    }

    // Fail safely on the old implementation before exercising the unallocatable upper bound.
    let first = read(2 * 1024 * 1024)
    requireL2CAP(first.count == chunkSize && first == Array(payload.prefix(chunkSize)),
                 "large read bounds must return a bounded partial chunk")
    let second = read(Int.max)
    requireL2CAP(second.count == chunkSize, "Int.max must not become an allocation size")
    let last = read(Int.max)
    requireL2CAP(last.count == 37 && first + second + last == Array(payload),
                 "successive large reads must preserve every byte in order without padding")
    requireL2CAP(read(Int.max).isEmpty && read(4096).isEmpty,
                 "large and ordinary requests must preserve clean EOF")
    requireSuccess(awaitL2CAP { fixture.plugin.disposeCentralManager(arguments: ["managerId": 1], result: $0) })
}

private func testL2CAPReadSizeBoundaries() {
    let chunkSize = 64 * 1024
    let payload = Data((0..<(chunkSize + 7)).map { UInt8(truncatingIfNeeded: $0) })
    for length in [1, 4096, chunkSize - 1, chunkSize, chunkSize + 1, Int.max] {
        let fixture = L2CAPFixture()
        let channel = L2CAPChannelDouble(peer: fixture.firstPeer)
        channel.inputStream = InputStream(data: payload)
        let handle = fixture.open(channel)
        let bytes = readBytes(awaitL2CAP {
            fixture.plugin.readL2CAPInputStream(
                arguments: ["channelHandle": handle, "maxLength": NSNumber(value: length)], result: $0)
        })
        requireL2CAP(bytes == Array(payload.prefix(min(length, chunkSize))),
                     "reads must respect smaller bounds and bound scratch space for larger ones")
        let next = readBytes(awaitL2CAP {
            fixture.plugin.readL2CAPInputStream(arguments: ["channelHandle": handle, "maxLength": 1], result: $0)
        })
        requireL2CAP(next == [payload[bytes.count]], "partial reads must leave the remaining bytes available")
        requireSuccess(awaitL2CAP { fixture.plugin.disposeCentralManager(arguments: ["managerId": 1], result: $0) })
    }
}

func testL2CAPLifetime() {
    testL2CAPStreamClosure()
    testL2CAPManagerDisposal()
    testL2CAPSharedOwnership()
    testL2CAPMissingStream()
    testL2CAPRetiredHandles()
    testL2CAPReadErrorsAndEOF()
    testL2CAPReadResponsivenessAndOrder()
    testL2CAPWriteOrderAndPartialCounts()
    testL2CAPReadCancellation()
    testL2CAPWriteCancellation()
    testL2CAPEmptyOperations()
    testL2CAPClosingSnapshot()
    testL2CAPOwnerRelease()
    testL2CAPPSMRange()
    testL2CAPTypedReadBuffers()
    testL2CAPBoundedReadBuffers()
    testL2CAPReadSizeBoundaries()
}
