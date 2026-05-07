import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        manager.isScanning = central.state == .poweredOn && central.isScanning
        if central.state != .poweredOn {
            // CoreBluetooth need not send individual disconnect callbacks on power-off.
            manager.peripherals.values.forEach { removeRemoteAttributes(for: $0) }
        }
        if central.state.rawValue < CBManagerState.poweredOff.rawValue {
            // Native peripheral objects become invalid below poweredOff. UUID-based
            // Dart wrappers can be reused after explicit retrieval or discovery.
            manager.peripherals.removeAll()
        }
        emit(kind: "didUpdateState", managerId: manager.identifier, payload: managerSnapshot(for: manager))
    }

    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        let restoredPeripherals = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]) ?? []
        restoredPeripherals.forEach {
            remember($0, for: manager)
        }

        let scanServices = (dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID])?.map {
            $0.uuidString.lowercased()
        }
        let scanOptions = serialize(
            scanOptions: dict[CBCentralManagerRestoredStateScanOptionsKey] as? [String: Any]
        )

        emit(
            kind: "willRestoreState",
            managerId: manager.identifier,
            payload: [
                "peripherals": restoredPeripherals.map { peripheral in
                    var snapshot = peripheralSnapshot(peripheral)
                    snapshot.updateValue(peripheral.services?.map(serviceSnapshot), forKey: "services")
                    return snapshot
                },
                "scanServices": scanServices,
                "scanOptions": scanOptions
            ]
        )
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        remember(peripheral, for: manager)
        emit(
            kind: "didConnectPeripheral",
            managerId: manager.identifier,
            payload: ["peripheral": peripheralSnapshot(peripheral)]
        )
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        removeRemoteAttributes(for: peripheral)
        emit(
            kind: "didDisconnectPeripheral",
            managerId: manager.identifier,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "error": serialize(error: error)
            ]
        )
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        timestamp: CFAbsoluteTime,
        isReconnecting: Bool,
        error: Error?
    ) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        removeRemoteAttributes(for: peripheral)
        emit(
            kind: "didDisconnectPeripheral",
            managerId: manager.identifier,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "timestamp": timestamp,
                "isReconnecting": isReconnecting,
                "error": serialize(error: error)
            ]
        )
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        manager.isScanning = central.isScanning
        remember(peripheral, for: manager)
        guard manager.advertisementSampler.accepts(identifier: peripheral.identifier) else { return }

        emit(
            kind: "didDiscoverPeripheral",
            managerId: manager.identifier,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "advertisementData": serialize(advertisementData: advertisementData),
                "rssi": RSSI
            ]
        )
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        emit(
            kind: "didFailToConnectPeripheral",
            managerId: manager.identifier,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "error": serialize(error: error)
            ]
        )
    }

#if !os(macOS)
    @available(iOS 13.0, *)
    public func centralManager(
        _ central: CBCentralManager,
        connectionEventDidOccur event: CBConnectionEvent,
        for peripheral: CBPeripheral
    ) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        remember(peripheral, for: manager)

        emit(
            kind: "connectionEventDidOccur",
            managerId: manager.identifier,
            payload: [
                "event": event.rawValue,
                "peripheral": peripheralSnapshot(peripheral)
            ]
        )
    }
#endif

#if !os(macOS)
    @available(iOS 13.0, *)
    public func centralManager(_ central: CBCentralManager, didUpdateANCSAuthorizationFor peripheral: CBPeripheral) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        remember(peripheral, for: manager)

        emit(
            kind: "didUpdateANCSAuthorizationForPeripheral",
            managerId: manager.identifier,
            payload: [
                "peripheral": peripheralSnapshot(peripheral)
            ]
        )
    }
#endif

    private func serialize(advertisementData: [String: Any]) -> [String: Any?] {
        var result: [String: Any?] = [:]

        result["localName"] = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        result["manufacturerData"] = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        result["isConnectable"] = advertisementData[CBAdvertisementDataIsConnectable] as? Bool
        result["txPowerLevel"] = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber

        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            result["serviceUUIDs"] = serviceUUIDs.map { $0.uuidString.lowercased() }
        }
        if let serviceUUIDs = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] {
            result["overflowServiceUUIDs"] = serviceUUIDs.map { $0.uuidString.lowercased() }
        }
        if let serviceUUIDs = advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID] {
            result["solicitedServiceUUIDs"] = serviceUUIDs.map { $0.uuidString.lowercased() }
        }

        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            result["serviceData"] = Dictionary(uniqueKeysWithValues: serviceData.map { key, value in
                (key.uuidString.lowercased(), value)
            })
        }

        return result
    }
}
