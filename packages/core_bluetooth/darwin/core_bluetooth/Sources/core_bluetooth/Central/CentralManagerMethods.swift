import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin {
    func cancelPeripheralConnection(arguments: Any?, result: FlutterResult) {
        guard let manager = manager(from: arguments),
              let peripheral = peripheral(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing manager or peripheral", details: nil))
            return
        }

        manager.centralManager.cancelPeripheralConnection(peripheral)
        result(nil)
    }

    func connect(arguments: Any?, result: FlutterResult) {
        guard let manager = manager(from: arguments),
              let peripheral = peripheral(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing manager or peripheral", details: nil))
            return
        }

        let optionsMap = map(arguments)?["options"] as? [String: Any?]
        manager.centralManager.connect(peripheral, options: connectOptions(from: optionsMap))
        result(nil)
    }

    func createCentralManager(arguments: Any?, result: FlutterResult) {
        let shared = map(arguments)?["shared"] as? Bool ?? false
        if shared, let id = sharedManagerId, let existing = managers[id] {
            var snapshot = managerSnapshot(for: existing)
            snapshot["wasReattached"] = true
            result(snapshot)
            return
        }
        let managerId = nextManagerId
        nextManagerId += 1

        let optionsMap = (map(arguments)?["options"] as? [String: Any?]) ?? [:]
        let manager = CBCentralManager(delegate: self, queue: nil, options: centralManagerOptions(from: optionsMap))

        let box = CentralManagerBox(
            identifier: managerId,
            centralManager: manager
        )
        managers[managerId] = box
        if shared { sharedManagerId = managerId }

        result(managerSnapshot(for: box))
    }

    func disconnectAllPeripherals(arguments: Any?, result: FlutterResult) {
        guard let manager = manager(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing manager", details: nil))
            return
        }
        let connected = manager.peripherals.values.filter { $0.state == .connected }
        if manager.centralManager.state == .poweredOn {
            manager.centralManager.stopScan()
            connected.forEach { manager.centralManager.cancelPeripheralConnection($0) }
        }
        manager.isScanning = false
        result(connected.map(peripheralSnapshot))
    }

    func centralManagerOptions(from options: [String: Any?]) -> [String: Any]? {
        var resolved: [String: Any] = [:]

        if let showPowerAlert = options["showPowerAlert"] as? Bool {
            resolved[CBCentralManagerOptionShowPowerAlertKey] = showPowerAlert
        }

        if let restoreIdentifier = options["restoreIdentifier"] as? String, restoreIdentifier.isEmpty == false {
            resolved[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier
        }

        return resolved.isEmpty ? nil : resolved
    }

    func connectOptions(from options: [String: Any?]?) -> [String: Any]? {
        guard let options else {
            return nil
        }

        var resolved: [String: Any] = [:]

        if let notifyOnConnection = options["notifyOnConnection"] as? Bool {
            resolved[CBConnectPeripheralOptionNotifyOnConnectionKey] = notifyOnConnection
        }
        if let notifyOnDisconnection = options["notifyOnDisconnection"] as? Bool {
            resolved[CBConnectPeripheralOptionNotifyOnDisconnectionKey] = notifyOnDisconnection
        }
        if let notifyOnNotification = options["notifyOnNotification"] as? Bool {
            resolved[CBConnectPeripheralOptionNotifyOnNotificationKey] = notifyOnNotification
        }
        if #available(iOS 17.0, macOS 14.0, *) {
            if let enableAutoReconnect = options["enableAutoReconnect"] as? Bool {
                resolved[CBConnectPeripheralOptionEnableAutoReconnect] = enableAutoReconnect
            }
        }
#if !os(macOS)
        if #available(iOS 13.0, *) {
            if let enableTransportBridging = options["enableTransportBridging"] as? Bool {
                resolved[CBConnectPeripheralOptionEnableTransportBridgingKey] = enableTransportBridging
            }
        }
        if #available(iOS 13.0, *) {
            if let requiresANCS = options["requiresANCS"] as? Bool {
                resolved[CBConnectPeripheralOptionRequiresANCS] = requiresANCS
            }
        }
#endif
        if let startDelay = options["startDelay"] as? Double {
            resolved[CBConnectPeripheralOptionStartDelayKey] = startDelay
        }

        return resolved.isEmpty ? nil : resolved
    }

    func disposeCentralManager(arguments: Any?, result: @escaping FlutterResult) {
        guard let managerId = (map(arguments)?["managerId"] as? NSNumber)?.intValue else {
            result(nil)
            return
        }

        guard let manager = managers.removeValue(forKey: managerId) else {
            removeL2CAPChannels(for: managerId) { result(nil) }
            return
        }
        manager.centralManager.stopScan()
        if manager.centralManager.state == .poweredOn {
            for peripheral in manager.peripherals.values where peripheral.state != .disconnected {
                manager.centralManager.cancelPeripheralConnection(peripheral)
            }
        }
        for peripheral in manager.peripherals.values {
            let stillOwned = managers.values.contains { $0.peripherals[peripheral.identifier] === peripheral }
            if !stillOwned { removeRemoteAttributes(for: peripheral) }
        }
        if sharedManagerId == managerId { sharedManagerId = nil }
        removeL2CAPChannels(for: managerId) { result(nil) }
    }

    func registerForConnectionEvents(arguments: Any?, result: FlutterResult) {
        guard let manager = manager(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing manager", details: nil))
            return
        }

#if !os(macOS)
        if #available(iOS 13.0, *) {
            let optionsMap = map(arguments)?["options"] as? [String: Any?]
            manager.centralManager.registerForConnectionEvents(
                options: connectionEventMatchingOptions(from: optionsMap)
            )
            result(nil)
            return
        }
#endif

        result(nil)
    }

    func connectionEventMatchingOptions(from options: [String: Any?]?) -> [CBConnectionEventMatchingOption: Any]? {
        guard let options else {
            return nil
        }

        var resolved: [CBConnectionEventMatchingOption: Any] = [:]

#if !os(macOS)
        if #available(iOS 13.0, *) {
            if let peripheralUUIDs = options["peripheralUUIDs"] as? [String] {
                resolved[.peripheralUUIDs] = peripheralUUIDs.compactMap(UUID.init(uuidString:))
            }
            if let serviceUUIDs = options["serviceUUIDs"] as? [String] {
                resolved[.serviceUUIDs] = serviceUUIDs.map(CBUUID.init(string:))
            }
        }
#endif

        return resolved.isEmpty ? nil : resolved
    }

    func retrieveConnectedPeripherals(arguments: Any?, result: FlutterResult) {
        guard let manager = manager(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing manager", details: nil))
            return
        }

        let uuids = ((map(arguments)?["serviceUUIDs"] as? [String]) ?? []).map(CBUUID.init(string:))
        let peripherals = manager.centralManager.retrieveConnectedPeripherals(withServices: uuids)
        peripherals.forEach { remember($0, for: manager) }
        result(peripherals.map(peripheralSnapshot))
    }

    func retrievePeripherals(arguments: Any?, result: FlutterResult) {
        guard let manager = manager(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing manager", details: nil))
            return
        }

        let identifiers = ((map(arguments)?["identifiers"] as? [String]) ?? []).compactMap(UUID.init(uuidString:))
        let peripherals = manager.centralManager.retrievePeripherals(withIdentifiers: identifiers)
        peripherals.forEach { remember($0, for: manager) }
        result(peripherals.map(peripheralSnapshot))
    }

    func scanForPeripherals(arguments: Any?, result: FlutterResult) {
        guard let manager = manager(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing manager", details: nil))
            return
        }

        let serviceUUIDs = (map(arguments)?["serviceUUIDs"] as? [String])?.map(CBUUID.init(string:))
        let optionsMap = map(arguments)?["options"] as? [String: Any?]
        let value = (map(arguments)?["advertisementDivisor"] as? NSNumber)?.doubleValue ?? 1
        guard let divisor = Int(exactly: value), divisor >= 1, divisor <= Int32.max else {
            result(FlutterError(code: "invalid_args", message: "advertisementDivisor must be between 1 and 2147483647", details: nil))
            return
        }
        manager.advertisementSampler = AdvertisementSampler(divisor: divisor)
        manager.centralManager.scanForPeripherals(withServices: serviceUUIDs, options: scanOptions(from: optionsMap))
        manager.isScanning = manager.centralManager.isScanning
        result(manager.isScanning)
    }

    func scanOptions(from options: [String: Any?]?) -> [String: Any]? {
        guard let options else {
            return nil
        }

        var resolved: [String: Any] = [:]

        if let allowDuplicates = options["allowDuplicates"] as? Bool {
            resolved[CBCentralManagerScanOptionAllowDuplicatesKey] = allowDuplicates
        }

        if let solicitedServiceUUIDs = options["solicitedServiceUUIDs"] as? [String] {
            resolved[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] = solicitedServiceUUIDs.map(CBUUID.init(string:))
        }

        return resolved.isEmpty ? nil : resolved
    }

    func stopScan(arguments: Any?, result: FlutterResult) {
        guard let manager = manager(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing manager", details: nil))
            return
        }

        manager.centralManager.stopScan()
        manager.isScanning = false
        result(nil)
    }

    func supports(arguments: Any?) -> Bool {
        guard let rawFeature = (map(arguments)?["feature"] as? NSNumber)?.uintValue else {
            return false
        }

#if !os(macOS)
        if #available(iOS 13.0, *) {
            let feature = CBCentralManager.Feature(rawValue: rawFeature)
            if feature.contains(.extendedScanAndConnect) {
                return CBCentralManager.supports(feature)
            }
        }
#else
        _ = rawFeature
#endif

        return false
    }
}
