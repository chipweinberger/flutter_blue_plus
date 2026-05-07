import CoreBluetooth
import Foundation

final class CentralManagerBox {
    init(identifier: Int, centralManager: CBCentralManager) {
        self.identifier = identifier
        self.centralManager = centralManager
    }

    let identifier: Int
    let centralManager: CBCentralManager
    var isScanning = false
}
