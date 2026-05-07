import CoreBluetooth
import Foundation
import FlutterMacOS

private func requireDelivery(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

private final class DeliveryManagerDouble: NSObject {
    @objc var state = 5
    @objc var isScanning = false
    var starts = 0
    @objc(scanForPeripheralsWithServices:options:)
    func scan(_ services: [CBUUID]?, options: [String: Any]?) { starts += 1; isScanning = true }
    @objc func stopScan() { isScanning = false }
}

private final class DeliveryPeripheralDouble: NSObject {
    @objc let identifier = UUID()
    @objc let state = 0
    @objc let canSendWriteWithoutResponse = true
    @objc weak var delegate: AnyObject?
    var snapshots = 0
    @objc var name: String { snapshots += 1; return "Device" }
}

private final class DeliveryFixture {
    let plugin = CoreBluetoothPlugin()
    let native = DeliveryManagerDouble()
    let a = DeliveryPeripheralDouble()
    let b = DeliveryPeripheralDouble()
    var events: [[String: Any?]] = []
    var central: CBCentralManager { unsafeBitCast(native, to: CBCentralManager.self) }

    init() {
        plugin.managers[1] = CentralManagerBox(identifier: 1, centralManager: central)
        plugin.eventSink = { [weak self] in self?.events.append($0 as! [String: Any?]) }
    }

    func start(divisor: Int = 1) {
        plugin.scanForPeripherals(arguments: ["managerId": 1, "advertisementDivisor": divisor]) {
            requireDelivery($0 as? Bool == true, "the divisor must allow scan submission")
        }
    }

    func emit(_ device: DeliveryPeripheralDouble, _ number: Int, advertisement: [String: Any] = [:]) {
        plugin.centralManager(central, didDiscover: unsafeBitCast(device, to: CBPeripheral.self),
                              advertisementData: advertisement, rssi: NSNumber(value: number))
    }

    var delivered: [Int] {
        events.map { (($0["payload"] as! [String: Any?])["rssi"] as! NSNumber).intValue }
    }
}

private func testDeliveryBeforeSerialization() {
    let fixture = DeliveryFixture()
    fixture.start(divisor: 10)
    for index in 1...1000 { fixture.emit(fixture.a, index) }
    requireDelivery(fixture.delivered == Array(stride(from: 1, through: 1000, by: 10)),
                    "only the first and every tenth result may reach the event sink")
    requireDelivery(fixture.a.snapshots == 100, "skipped advertisements must not build peripheral channel snapshots")
    requireDelivery(fixture.plugin.managers[1]!.peripherals[fixture.a.identifier] != nil,
                    "sampling must preserve native peripheral ownership")
    fixture.start(divisor: 10)
    fixture.emit(fixture.a, 1001)
    requireDelivery(fixture.delivered.last == 1001, "each scan submission must reset its counters")
    fixture.start()
    for index in 1002...1005 { fixture.emit(fixture.a, index) }
    requireDelivery(fixture.delivered.suffix(4) == [1002, 1003, 1004, 1005], "default delivery must remain unfiltered")
}

private func testPerDeviceSampling() {
    let fixture = DeliveryFixture()
    fixture.start(divisor: 3)
    fixture.emit(fixture.a, 0, advertisement: [CBAdvertisementDataLocalNameKey: "other"])
    fixture.emit(fixture.a, 1, advertisement: [CBAdvertisementDataLocalNameKey: "keep"])
    fixture.emit(fixture.a, 2, advertisement: [CBAdvertisementDataLocalNameKey: "KEEP"])
    fixture.emit(fixture.b, 3, advertisement: [CBAdvertisementDataLocalNameKey: "keep"])
    fixture.emit(fixture.a, 4, advertisement: [CBAdvertisementDataLocalNameKey: "keep"])
    fixture.emit(fixture.a, 5, advertisement: [CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: "180f")]])
    fixture.emit(fixture.a, 6, advertisement: [CBAdvertisementDataLocalNameKey: "keep"])
    requireDelivery(fixture.delivered == [0, 3, 4], "every discovery must advance its device's counter regardless of name or service data")
    requireDelivery(fixture.a.snapshots == 2 && fixture.b.snapshots == 1, "sampled-out discoveries must not serialize")

    let other = DeliveryManagerDouble()
    let central = unsafeBitCast(other, to: CBCentralManager.self)
    fixture.plugin.managers[2] = CentralManagerBox(identifier: 2, centralManager: central)
    fixture.plugin.scanForPeripherals(arguments: ["managerId": 2, "advertisementDivisor": 3]) { _ in }
    fixture.plugin.centralManager(central, didDiscover: unsafeBitCast(fixture.a, to: CBPeripheral.self),
                                  advertisementData: [:], rssi: 7)
    requireDelivery(fixture.delivered.last == 7 && fixture.events.last?["managerId"] as? Int == 2,
                    "another manager must begin with its own first advertisement")
}

private func testInvalidDeliveryOptions() {
    let fixture = DeliveryFixture()
    fixture.start(divisor: 3)
    fixture.emit(fixture.a, 1)
    for value in [0.0, -1, 1.5, Double.nan, Double.infinity, 2147483648] {
        fixture.plugin.scanForPeripherals(arguments: ["managerId": 1, "advertisementDivisor": value]) {
            requireDelivery(($0 as? FlutterError)?.code == "invalid_args", "invalid divisors must return normal errors")
        }
    }
    requireDelivery(fixture.native.starts == 1, "invalid options must not alter the radio scan")
    fixture.emit(fixture.a, 2)
    requireDelivery(fixture.delivered == [1], "invalid options must preserve existing counter state")
}

func testScanDelivery() {
    testDeliveryBeforeSerialization()
    testPerDeviceSampling()
    testInvalidDeliveryOptions()
}
