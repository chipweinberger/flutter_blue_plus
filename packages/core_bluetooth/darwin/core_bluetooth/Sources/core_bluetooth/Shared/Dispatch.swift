import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

extension CoreBluetoothPlugin {
    func handleCentralManagerMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "centralManager.authorization":
            result(Self.authorizationRawValue)
        case "centralManager.supports":
            result(supports(arguments: call.arguments))
        case "centralManager.create":
            createCentralManager(arguments: call.arguments, result: result)
        case "centralManager.dispose":
            disposeCentralManager(arguments: call.arguments, result: result)
        case "centralManager.scanForPeripherals":
            scanForPeripherals(arguments: call.arguments, result: result)
        case "centralManager.stopScan":
            stopScan(arguments: call.arguments, result: result)
        case "centralManager.connect":
            connect(arguments: call.arguments, result: result)
        case "centralManager.cancelPeripheralConnection":
            cancelPeripheralConnection(arguments: call.arguments, result: result)
        case "centralManager.retrievePeripherals":
            retrievePeripherals(arguments: call.arguments, result: result)
        case "centralManager.retrieveConnectedPeripherals":
            retrieveConnectedPeripherals(arguments: call.arguments, result: result)
        case "centralManager.registerForConnectionEvents":
            registerForConnectionEvents(arguments: call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func handlePeripheralMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "peripheral.discoverServices":
            discoverServices(arguments: call.arguments, result: result)
        case "peripheral.discoverCharacteristics":
            discoverCharacteristics(arguments: call.arguments, result: result)
        case "peripheral.discoverIncludedServices":
            discoverIncludedServices(arguments: call.arguments, result: result)
        case "peripheral.discoverDescriptors":
            discoverDescriptors(arguments: call.arguments, result: result)
        case "peripheral.readValueForCharacteristic":
            readValueForCharacteristic(arguments: call.arguments, result: result)
        case "peripheral.readValueForDescriptor":
            readValueForDescriptor(arguments: call.arguments, result: result)
        case "peripheral.writeValueForCharacteristic":
            writeValueForCharacteristic(arguments: call.arguments, result: result)
        case "peripheral.writeValueForDescriptor":
            writeValueForDescriptor(arguments: call.arguments, result: result)
        case "peripheral.setNotifyValue":
            setNotifyValue(arguments: call.arguments, result: result)
        case "peripheral.readRSSI":
            readRSSI(arguments: call.arguments, result: result)
        case "peripheral.openL2CAPChannel":
            openL2CAPChannel(arguments: call.arguments, result: result)
        case "peripheral.maximumWriteValueLength":
            maximumWriteValueLength(arguments: call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func handlePeripheralManagerMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "peripheralManager.authorization":
            result(Self.peripheralManagerAuthorizationRawValue)
        case "peripheralManager.create":
            createPeripheralManager(arguments: call.arguments, result: result)
        case "peripheralManager.dispose":
            disposePeripheralManager(arguments: call.arguments, result: result)
        case "peripheralManager.startAdvertising":
            startAdvertising(arguments: call.arguments, result: result)
        case "peripheralManager.stopAdvertising":
            stopAdvertising(arguments: call.arguments, result: result)
        case "peripheralManager.addService":
            addService(arguments: call.arguments, result: result)
        case "peripheralManager.removeService":
            removeService(arguments: call.arguments, result: result)
        case "peripheralManager.removeAllServices":
            removeAllServices(arguments: call.arguments, result: result)
        case "peripheralManager.updateValue":
            updateValue(arguments: call.arguments, result: result)
        case "peripheralManager.respondToRequest":
            respondToRequest(arguments: call.arguments, result: result)
        case "peripheralManager.setDesiredConnectionLatency":
            setDesiredConnectionLatency(arguments: call.arguments, result: result)
        case "peripheralManager.publishL2CAPChannel":
            publishL2CAPChannel(arguments: call.arguments, result: result)
        case "peripheralManager.unpublishL2CAPChannel":
            unpublishL2CAPChannel(arguments: call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func handleL2CAPChannelMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "l2capChannel.readInputStream":
            readL2CAPInputStream(arguments: call.arguments, result: result)
        case "l2capChannel.writeOutputStream":
            writeL2CAPOutputStream(arguments: call.arguments, result: result)
        case "l2capChannel.closeInputStream":
            closeL2CAPInputStream(arguments: call.arguments, result: result)
        case "l2capChannel.closeOutputStream":
            closeL2CAPOutputStream(arguments: call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
