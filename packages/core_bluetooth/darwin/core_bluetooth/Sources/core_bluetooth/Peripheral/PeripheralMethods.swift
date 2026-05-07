import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin {
    func service(from arguments: Any?) -> CBService? {
        guard let peripheral = peripheral(from: arguments),
              let handle = map(arguments)?["serviceHandle"] as? String,
              let service = services[handle], service.peripheral === peripheral else { return nil }
        return service
    }

    func characteristic(from arguments: Any?) -> CBCharacteristic? {
        guard let peripheral = peripheral(from: arguments),
              let handle = map(arguments)?["characteristicHandle"] as? String,
              let characteristic = characteristics[handle],
              characteristic.service?.peripheral === peripheral else { return nil }
        return characteristic
    }

    func descriptor(from arguments: Any?) -> CBDescriptor? {
        guard let peripheral = peripheral(from: arguments),
              let handle = map(arguments)?["descriptorHandle"] as? String,
              let descriptor = descriptors[handle],
              descriptor.characteristic?.service?.peripheral === peripheral else { return nil }
        return descriptor
    }

    func discoverCharacteristics(arguments: Any?, result: FlutterResult) {
        guard let peripheral = peripheral(from: arguments),
              let service = service(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or service", details: nil))
            return
        }

        let uuids = (map(arguments)?["characteristicUUIDs"] as? [String])?.map(CBUUID.init(string:))
        peripheral.discoverCharacteristics(uuids, for: service)
        result(nil)
    }

    func discoverIncludedServices(arguments: Any?, result: FlutterResult) {
        guard let peripheral = peripheral(from: arguments),
              let service = service(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or service", details: nil))
            return
        }

        let uuids = (map(arguments)?["includedServiceUUIDs"] as? [String])?.map(CBUUID.init(string:))
        peripheral.discoverIncludedServices(uuids, for: service)
        result(nil)
    }

    func discoverDescriptors(arguments: Any?, result: FlutterResult) {
        guard let peripheral = peripheral(from: arguments),
              let characteristic = characteristic(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or characteristic", details: nil))
            return
        }

        peripheral.discoverDescriptors(for: characteristic)
        result(nil)
    }

    func discoverServices(arguments: Any?, result: FlutterResult) {
        guard let peripheral = peripheral(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral", details: nil))
            return
        }

        let uuids = (map(arguments)?["serviceUUIDs"] as? [String])?.map(CBUUID.init(string:))
        peripheral.discoverServices(uuids)
        result(nil)
    }

    func maximumWriteValueLength(arguments: Any?, result: FlutterResult) {
        guard let peripheral = peripheral(from: arguments),
              let rawType = (map(arguments)?["type"] as? NSNumber)?.intValue,
              let type = CBCharacteristicWriteType(rawValue: rawType) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or write type", details: nil))
            return
        }

        result(peripheral.maximumWriteValueLength(for: type))
    }

    func openL2CAPChannel(arguments: Any?, result: FlutterResult) {
        guard let peripheral = peripheral(from: arguments),
              let rawPsm = l2capPSM(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or invalid PSM (expected an integer from 0 to 65535)", details: nil))
            return
        }

        if #available(iOS 11.0, macOS 10.13, *) {
            peripheral.openL2CAPChannel(rawPsm)
            result(nil)
            return
        }

        result(nil)
    }

    func readL2CAPInputStream(arguments: Any?, result: @escaping FlutterResult) {
        guard let channelHandle = map(arguments)?["channelHandle"] as? String,
              let entry = l2capChannels[channelHandle],
              let maxLength = (map(arguments)?["maxLength"] as? NSNumber)?.intValue else {
            result(FlutterError(code: "invalid_args", message: "Missing L2CAP channel or maxLength", details: nil))
            return
        }

        entry.read(maxLength: maxLength, result: result)
    }

    func writeL2CAPOutputStream(arguments: Any?, result: @escaping FlutterResult) {
        guard let channelHandle = map(arguments)?["channelHandle"] as? String,
              let entry = l2capChannels[channelHandle],
              let value = map(arguments)?["value"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "invalid_args", message: "Missing L2CAP channel or value", details: nil))
            return
        }

        entry.write(value.data, result: result)
    }

    func closeL2CAPInputStream(arguments: Any?, result: @escaping FlutterResult) {
        guard let channelHandle = map(arguments)?["channelHandle"] as? String,
              let entry = l2capChannels[channelHandle] else {
            result(FlutterError(code: "invalid_args", message: "Missing L2CAP channel", details: nil))
            return
        }

        entry.closeInput {
            if entry.isReleased { self.l2capChannels.removeValue(forKey: channelHandle) }
            result(nil)
        }
    }

    func closeL2CAPOutputStream(arguments: Any?, result: @escaping FlutterResult) {
        guard let channelHandle = map(arguments)?["channelHandle"] as? String,
              let entry = l2capChannels[channelHandle] else {
            result(FlutterError(code: "invalid_args", message: "Missing L2CAP channel", details: nil))
            return
        }

        entry.closeOutput {
            if entry.isReleased { self.l2capChannels.removeValue(forKey: channelHandle) }
            result(nil)
        }
    }

    func peripheral(from arguments: Any?) -> CBPeripheral? {
        guard let identifierString = map(arguments)?["peripheralIdentifier"] as? String,
              let identifier = UUID(uuidString: identifierString) else {
            return nil
        }
        return manager(from: arguments)?.peripherals[identifier]
    }

    func readRSSI(arguments: Any?, result: FlutterResult) {
        guard let peripheral = peripheral(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral", details: nil))
            return
        }

        peripheral.readRSSI()
        result(nil)
    }

    func readValueForCharacteristic(arguments: Any?, result: FlutterResult) {
        guard let characteristic = characteristic(from: arguments),
              let peripheral = peripheral(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or characteristic", details: nil))
            return
        }

        peripheral.readValue(for: characteristic)
        result(nil)
    }

    func readValueForDescriptor(arguments: Any?, result: FlutterResult) {
        guard let descriptor = descriptor(from: arguments),
              let peripheral = peripheral(from: arguments) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or descriptor", details: nil))
            return
        }

        peripheral.readValue(for: descriptor)
        result(nil)
    }

    func setNotifyValue(arguments: Any?, result: FlutterResult) {
        guard let characteristic = characteristic(from: arguments),
              let peripheral = peripheral(from: arguments),
              let enabled = map(arguments)?["enabled"] as? Bool else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or characteristic", details: nil))
            return
        }

        peripheral.setNotifyValue(enabled, for: characteristic)
        result(nil)
    }

    func writeValueForCharacteristic(arguments: Any?, result: FlutterResult) {
        guard let characteristic = characteristic(from: arguments),
              let peripheral = peripheral(from: arguments),
              let value = map(arguments)?["value"] as? FlutterStandardTypedData,
              let rawType = (map(arguments)?["type"] as? NSNumber)?.intValue,
              let type = CBCharacteristicWriteType(rawValue: rawType) else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral, characteristic, or value", details: nil))
            return
        }

        peripheral.writeValue(value.data, for: characteristic, type: type)
        result(nil)
    }

    func writeValueForDescriptor(arguments: Any?, result: FlutterResult) {
        guard let descriptor = descriptor(from: arguments),
              let peripheral = peripheral(from: arguments),
              let value = map(arguments)?["value"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral, descriptor, or value", details: nil))
            return
        }

        peripheral.writeValue(value.data, for: descriptor)
        result(nil)
    }
}
