import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

public final class CoreBluetoothPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    static let methodChannelName = "dev.core_bluetooth/methods"
    static let eventChannelName = "dev.core_bluetooth/events"

    // Flutter event streaming
    var eventSink: FlutterEventSink?
    var pendingEvents: [[String: Any?]] = []
    var sharedManagerId: Int?
    var sharedPeripheralManagerId: Int?

    // Native manager instances
    var nextManagerId = 1
    var managers: [Int: CentralManagerBox] = [:]
    var peripheralManagers: [Int: CBPeripheralManager] = [:]
    var localServices: [Int: [String: CBMutableService]] = [:]
    // Successful and restored root publications, excluding pending adds.
    var publishedLocalServices: [Int: Set<String>] = [:]
    var peripheralManagerCentrals: [Int: [UUID: CBCentral]] = [:]

    // Remote/local CoreBluetooth object registries
    // Main-queue identity lookup. Weak keys must not extend native GATT lifetimes.
    let objectHandles = NSMapTable<AnyObject, NSString>(
        keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: .strongMemory
    )
    var l2capChannels: [String: L2CAPChannelBox] = [:]
    var services: [String: CBService] = [:]
    var characteristics: [String: CBCharacteristic] = [:]
    var descriptors: [String: CBDescriptor] = [:]
    var attRequests: [String: OwnedATTRequest] = [:]

    // Dart-side identity for mutable local GATT objects
    var serviceClientReferences: [String: String] = [:]
    var characteristicClientReferences: [String: String] = [:]
    var descriptorClientReferences: [String: String] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = CoreBluetoothPlugin()

#if os(macOS)
        let messenger = registrar.messenger
#else
        let messenger = registrar.messenger()
#endif

        let methodChannel = FlutterMethodChannel(
            name: Self.methodChannelName,
            binaryMessenger: messenger
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: Self.eventChannelName,
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case let method where method.hasPrefix("centralManager."):
            handleCentralManagerMethod(call, result: result)
        case let method where method.hasPrefix("peripheral."):
            handlePeripheralMethod(call, result: result)
        case let method where method.hasPrefix("peripheralManager."):
            handlePeripheralManagerMethod(call, result: result)
        case let method where method.hasPrefix("l2capChannel."):
            handleL2CAPChannelMethod(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        let pending = pendingEvents
        pendingEvents.removeAll()
        pending.forEach(events)
        return nil
    }

    func sendEvent(_ event: [String: Any?]) {
        if let eventSink {
            eventSink(event)
        } else {
            pendingEvents.append(event)
        }
    }
}
