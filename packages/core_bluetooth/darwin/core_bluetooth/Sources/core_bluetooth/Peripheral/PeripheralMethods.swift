import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin {
    func descriptor(from arguments: Any?) -> CBDescriptor? {
        guard let descriptorHandle = map(arguments)?["descriptorHandle"] as? String else {
            return nil
        }
        return descriptors[descriptorHandle]
    }

    func discoverCharacteristics(arguments: Any?, result: FlutterResult) {
        guard let peripheral = peripheral(from: arguments),
              let serviceHandle = map(arguments)?["serviceHandle"] as? String,
              let service = services[serviceHandle] else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or service", details: nil))
            return
        }

        let uuids = (map(arguments)?["characteristicUUIDs"] as? [String])?.map(CBUUID.init(string:))
        peripheral.discoverCharacteristics(uuids, for: service)
        result(nil)
    }

    func discoverIncludedServices(arguments: Any?, result: FlutterResult) {
        guard let peripheral = peripheral(from: arguments),
              let serviceHandle = map(arguments)?["serviceHandle"] as? String,
              let service = services[serviceHandle] else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or service", details: nil))
            return
        }

        let uuids = (map(arguments)?["includedServiceUUIDs"] as? [String])?.map(CBUUID.init(string:))
        peripheral.discoverIncludedServices(uuids, for: service)
        result(nil)
    }

    func discoverDescriptors(arguments: Any?, result: FlutterResult) {
        guard let peripheral = peripheral(from: arguments),
              let characteristicHandle = map(arguments)?["characteristicHandle"] as? String,
              let characteristic = characteristics[characteristicHandle] else {
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
              let rawPsm = (map(arguments)?["psm"] as? NSNumber)?.uint16Value else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or PSM", details: nil))
            return
        }

        if #available(iOS 11.0, macOS 10.13, *) {
            peripheral.openL2CAPChannel(rawPsm)
            result(nil)
            return
        }

        result(nil)
    }

    func readL2CAPInputStream(arguments: Any?, result: FlutterResult) {
        guard let channelHandle = map(arguments)?["channelHandle"] as? String,
              let channel = l2capChannels[channelHandle],
              let inputStream = channel.inputStream,
              let maxLength = (map(arguments)?["maxLength"] as? NSNumber)?.intValue else {
            result(FlutterError(code: "invalid_args", message: "Missing L2CAP channel or maxLength", details: nil))
            return
        }

        if inputStream.streamStatus == .notOpen {
            inputStream.open()
        }

        var buffer = [UInt8](repeating: 0, count: max(0, maxLength))
        let bytesRead = inputStream.read(&buffer, maxLength: buffer.count)
        if bytesRead <= 0 {
            result([UInt8]())
            return
        }

        result(Array(buffer.prefix(bytesRead)))
    }

    func writeL2CAPOutputStream(arguments: Any?, result: FlutterResult) {
        guard let channelHandle = map(arguments)?["channelHandle"] as? String,
              let channel = l2capChannels[channelHandle],
              let outputStream = channel.outputStream,
              let value = map(arguments)?["value"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "invalid_args", message: "Missing L2CAP channel or value", details: nil))
            return
        }

        if outputStream.streamStatus == .notOpen {
            outputStream.open()
        }

        let bytes = [UInt8](value.data)
        let bytesWritten = bytes.withUnsafeBufferPointer { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else {
                return 0
            }
            return outputStream.write(baseAddress, maxLength: bufferPointer.count)
        }
        result(bytesWritten)
    }

    func closeL2CAPInputStream(arguments: Any?, result: FlutterResult) {
        guard let channelHandle = map(arguments)?["channelHandle"] as? String,
              let channel = l2capChannels[channelHandle] else {
            result(FlutterError(code: "invalid_args", message: "Missing L2CAP channel", details: nil))
            return
        }

        channel.inputStream?.close()
        result(nil)
    }

    func closeL2CAPOutputStream(arguments: Any?, result: FlutterResult) {
        guard let channelHandle = map(arguments)?["channelHandle"] as? String,
              let channel = l2capChannels[channelHandle] else {
            result(FlutterError(code: "invalid_args", message: "Missing L2CAP channel", details: nil))
            return
        }

        channel.outputStream?.close()
        result(nil)
    }

    func peripheral(from arguments: Any?) -> CBPeripheral? {
        guard let identifierString = map(arguments)?["peripheralIdentifier"] as? String,
              let identifier = UUID(uuidString: identifierString) else {
            return nil
        }
        return peripherals[identifier]
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
        guard let characteristicHandle = map(arguments)?["characteristicHandle"] as? String,
              let characteristic = characteristics[characteristicHandle],
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
        guard let characteristicHandle = map(arguments)?["characteristicHandle"] as? String,
              let characteristic = characteristics[characteristicHandle],
              let peripheral = peripheral(from: arguments),
              let enabled = map(arguments)?["enabled"] as? Bool else {
            result(FlutterError(code: "invalid_args", message: "Missing peripheral or characteristic", details: nil))
            return
        }

        peripheral.setNotifyValue(enabled, for: characteristic)
        result(nil)
    }

    func writeValueForCharacteristic(arguments: Any?, result: FlutterResult) {
        guard let characteristicHandle = map(arguments)?["characteristicHandle"] as? String,
              let characteristic = characteristics[characteristicHandle],
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
