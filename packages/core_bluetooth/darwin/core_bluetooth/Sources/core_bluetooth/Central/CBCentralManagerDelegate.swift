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

        emit(kind: "didUpdateState", managerId: manager.identifier, payload: managerSnapshot(for: manager))
    }

    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        let restoredPeripherals = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]) ?? []
        restoredPeripherals.forEach {
            peripherals[$0.identifier] = $0
            peripheralManagerIdsByPeripheralIdentifier[$0.identifier] = manager.identifier
            $0.delegate = self
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
                "peripherals": restoredPeripherals.map(peripheralSnapshot),
                "scanServices": scanServices,
                "scanOptions": scanOptions
            ]
        )
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let manager = managers.values.first(where: { $0.centralManager === central }) else {
            return
        }

        peripherals[peripheral.identifier] = peripheral
        peripheralManagerIdsByPeripheralIdentifier[peripheral.identifier] = manager.identifier
        peripheral.delegate = self
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

        emit(
            kind: "didDisconnectPeripheral",
            managerId: manager.identifier,
            payload: [
                "peripheral": peripheralSnapshot(peripheral),
                "error": serialize(error: error)
            ]
        )
    }

    @available(iOS 17.0, macOS 10.14, *)
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
        peripherals[peripheral.identifier] = peripheral
        peripheralManagerIdsByPeripheralIdentifier[peripheral.identifier] = manager.identifier
        peripheral.delegate = self

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

        peripherals[peripheral.identifier] = peripheral
        peripheralManagerIdsByPeripheralIdentifier[peripheral.identifier] = manager.identifier
        peripheral.delegate = self

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

        peripherals[peripheral.identifier] = peripheral
        peripheralManagerIdsByPeripheralIdentifier[peripheral.identifier] = manager.identifier
        peripheral.delegate = self

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

        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            result["serviceData"] = Dictionary(uniqueKeysWithValues: serviceData.map { key, value in
                (key.uuidString.lowercased(), value)
            })
        }

        return result
    }
}
