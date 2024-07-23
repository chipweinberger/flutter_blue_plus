// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif


@objc
private enum LogLevel: Int {
    case none = 0
    case error = 1
    case warning = 2
    case info = 3
    case debug = 4
    case verbose = 5
}

@objc
private class LogUtil: NSObject {

    @objc
    public static var LOG_LEVEL: LogLevel = LogLevel.debug

    @objc
    public static func log(logLevel: LogLevel, message: String) {
        if (logLevel.rawValue <= LOG_LEVEL.rawValue) {
            NSLog("[FBP] %@", message)
        }
    }
}

@available(iOS 13.0, *)
@objc
public class L2CapChannelManager : NSObject, CBPeripheralManagerDelegate {

    private var peripheralManager: CBPeripheralManager?
    private var openL2CapChannelInfos: [L2CapServerInfo] = []
    
    private var listenL2CapChannelCallback: FlutterResult?
    private var closeL2CapChannelCallback: FlutterResult?
    
    private let deviceConnectedMethodChannel: FlutterMethodChannel
    
    private var peripheralManagerStateContinuation: CheckedContinuation<CBManagerState, Error>?
    
    @objc
    public init(deviceConnectedMethodChannel: FlutterMethodChannel) {
        self.deviceConnectedMethodChannel = deviceConnectedMethodChannel
    }
    
    @objc
    public func listenUsingL2capChannel(request: ListenL2CapChannelRequest, resultCallback: @escaping FlutterResult) {
        Task {
            do {
                let state = try await getPeripheralState()
                if state != CBManagerState.poweredOn {
                    resultCallback(FlutterError(code: ErrorCodes.bluetoothTurnedOff, message: "peripheralManager is not in poweredOn state.", details: nil))
                    return
                }
                listenL2CapChannelCallback = resultCallback
                requirePeripheralManager().publishL2CAPChannel(withEncryption: request.secure)
            } catch {
                resultCallback(
                    FlutterError(
                        code: ErrorCodes.bluetoothTurnedOff,
                        message: error.localizedDescription,
                        details: nil
                    )
                )
            }
        
        }
        
    }
    
    @objc
    public func connectToL2CapChannel(device: CBPeripheral, request: OpenL2CapChannelRequest, resultCallback: FlutterResult) {
        let peripheralManager = requirePeripheralManager()
        if peripheralManager.state != CBManagerState.poweredOn {
            resultCallback(FlutterError(code: ErrorCodes.bluetoothTurnedOff, message: "peripheralManager is not in poweredOn state.", details: nil))
            return
        }
        LogUtil.log(logLevel: LogLevel.debug, message: "The function connectToL2CapChannel is not implemented yet.")
    }
    
    @objc
    public func read(request: ReadL2CapChannelRequest, resultCallback: FlutterResult) {
        let psm = CBL2CAPPSM(request.psm)
        guard let openChannel = openL2CapChannelInfos.first(where: {$0.getPSM() == psm}) else {
            LogUtil.log(logLevel: LogLevel.debug, message: String(format: "No open channel found with PSM: %d", psm))
            resultCallback(FlutterError(code: ErrorCodes.noOpenL2CapChannelFound, message: "No open channel found for device and psm", details: nil))
            return
        }
        guard let deviceUUID = UUID(uuidString: request.remoteId) else {
            LogUtil.log(logLevel: LogLevel.debug, message: String(format: "Provided device identifier is no UUID: %s", request.remoteId))
            resultCallback(FlutterError(code: ErrorCodes.inputStreamReadFailed, message: "Provided device identifier is no UUID.", details: nil))
            return
        }
        openChannel.read(deviceIdentifier: deviceUUID, result: resultCallback)
    }
    
    @objc
    public func write(request: WriteL2CapChannelRequest, resultCallback: FlutterResult) {
        let psm = CBL2CAPPSM(request.psm)
        guard let openChannel = openL2CapChannelInfos.first(where: {$0.getPSM() == psm}) else {
            LogUtil.log(logLevel: LogLevel.debug, message: String(format: "No open channel found with PSM: %d", psm))
            resultCallback(FlutterError(code: ErrorCodes.noOpenL2CapChannelFound, message: "No open channel found for device and psm", details: nil))
            return
        }
        guard let deviceUUID = UUID(uuidString: request.remoteId) else {
            LogUtil.log(logLevel: LogLevel.debug, message: String(format: "Provided device identifier is no UUID: %s", request.remoteId))
            resultCallback(FlutterError(code: ErrorCodes.outputStreamWriteFailed, message: "Provided device identifier is no UUID.", details: nil))
            return
        }
        openChannel.write(deviceIdentifier: deviceUUID, payload: request.value, result: resultCallback)
    }
    
    @objc
    public func closeChannel(request: CloseL2CapChannelRequest,  resultCallback: @escaping FlutterResult) {
        let psm = CBL2CAPPSM(request.psm)
        guard let openChannel = openL2CapChannelInfos.first(where: {$0.getPSM() == psm}) else {
            LogUtil.log(logLevel: LogLevel.debug, message: String(format: "No open channel found with PSM: %d", psm))
            resultCallback(FlutterError(code: ErrorCodes.noOpenL2CapChannelFound, message: "No open channel found for device and psm", details: nil))
            return
        }
        guard let deviceUUID = UUID(uuidString: request.remoteId) else {
            LogUtil.log(logLevel: LogLevel.debug, message: String(format: "Provided device identifier is no UUID: %s", request.remoteId))
            return
        }
        openChannel.close(deviceIdentifier: deviceUUID)
    }
    
    @objc
    public func closeServerSocket(request: CloseL2CapServer, resultCallback: @escaping FlutterResult) {
        let peripheralManager = requirePeripheralManager()
        closeL2CapChannelCallback = resultCallback
        let psmToClose = CBL2CAPPSM(request.psm)
        LogUtil.log(logLevel: LogLevel.debug, message: String(format: "Closing L2CapChannel with PSM %d", psmToClose))
        if let channelToCloseIndex = openL2CapChannelInfos.firstIndex(where: { $0.getPSM() == psmToClose}) {
            openL2CapChannelInfos[channelToCloseIndex].closeAllConnections()
            openL2CapChannelInfos.remove(at: channelToCloseIndex)
        }
        peripheralManager.unpublishL2CAPChannel(psmToClose)
    }
    
    private func requirePeripheralManager() -> CBPeripheralManager {
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
        return peripheralManager!
    }
    
    private func getPeripheralState() async throws -> CBManagerState {
        let peripheralManager = requirePeripheralManager()
        if peripheralManager.state == .unknown {
            return try await withCheckedThrowingContinuation { continuation in
                peripheralManagerStateContinuation = continuation
            }
        }
        return peripheralManager.state
    }
 
    // MARK: Peripheral Manager Delegates
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        LogUtil.log(logLevel: LogLevel.debug, message: "peripheralManagerDidUpdateState called.")
        peripheralManagerStateContinuation?.resume(returning: peripheral.state)
        peripheralManagerStateContinuation = nil
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        if let error = error {
            NSLog("Published L2Cap channel failed: %s", error.localizedDescription)
            LogUtil.log(logLevel: LogLevel.error, message: String(format: "Published L2Cap channel failed: %s", error.localizedDescription))
            guard let listenL2CapChannelCallback = listenL2CapChannelCallback else { return }
            listenL2CapChannelCallback(error)
        } else {
            let response = ListenL2CapChannelResponse(psm: Int(PSM))
            LogUtil.log(logLevel: LogLevel.debug, message: String(format: "Published L2Cap channel with PSM %d successfully", PSM))
            openL2CapChannelInfos.append(L2CapServerInfo(psm: PSM))
            
            guard let listenL2CapChannelCallback = listenL2CapChannelCallback else { return }
            listenL2CapChannelCallback(response.marshal())
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        LogUtil.log(logLevel: LogLevel.debug, message: "ClosedL2Cap channel.")
        guard let closeL2CapChannelCallback = closeL2CapChannelCallback else { return }
        closeL2CapChannelCallback(nil)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {
        LogUtil.log(logLevel: LogLevel.debug, message: "L2Cap Channel opened.")
        if let error = error {
            LogUtil.log(logLevel: LogLevel.error, message: String(format: "didOpenL2CapChannel returns error: %s", error.localizedDescription))
        } else {
            guard let channel = channel else {
                LogUtil.log(logLevel: LogLevel.error, message: "No L2Cap channel provided. This should not happen.")
                return
            }
            handleNewConnection(channel: channel)
        }
    }
    
    private func handleNewConnection(channel : CBL2CAPChannel) {
        guard let channelInfo = openL2CapChannelInfos.first(where: { $0.getPSM() == channel.psm}) else {
            return
        }
        channelInfo.addConnection(l2CapChannel: channel)
        
        let event = DeviceConnectedToL2CapChannel(device: channel.peer, psm: Int(channelInfo.getPSM()))
        deviceConnectedMethodChannel.invokeMethod(L2CapMethodNames.deviceConnected, arguments: event.marshal())
    }
    
}
