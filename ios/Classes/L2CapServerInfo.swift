// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

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

class L2CapServerInfo {
    private static let defaultBufferSizeInByte = 50
    
    
    private let psm: CBL2CAPPSM
    private let readBufferSize: Int
    private var openChannels: [CBL2CAPChannel] = []

    init(psm: CBL2CAPPSM, readBufferSize: Int = defaultBufferSizeInByte) {
        self.psm = psm
        self.readBufferSize = readBufferSize
    }
    
    func getPSM() -> CBL2CAPPSM {
        return psm
    }
    
    func addConnection(l2CapChannel : CBL2CAPChannel) {
        openChannels.append(l2CapChannel)
        l2CapChannel.inputStream.open()
        l2CapChannel.outputStream.open()
    }
    
    func read(deviceIdentifier: UUID, result: FlutterResult) {
        guard let channelToRead = openChannels.first(where: { deviceIdentifier == $0.peer.identifier }) else {
            result(FlutterError(code: ErrorCodes.noOpenL2CapChannelFound, message: "No open channel found for device and psm", details: nil))
            return
        }
        let readBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: readBufferSize)
        let bytesRead = channelToRead.inputStream.read(readBuffer, maxLength: readBufferSize)
        
        let response = ReadL2CapChannelResponse(remoteId: deviceIdentifier.uuidString, psm: Int(psm), bytesRead: bytesRead, value: Data(bytes: readBuffer, count: bytesRead))
        readBuffer.deallocate()
        result(response.marshal())
    }
    
    func write(deviceIdentifier: UUID, payload: Data , result: FlutterResult) {
        guard let channelToWrite = openChannels.first(where: { deviceIdentifier == $0.peer.identifier }) else {
            result(FlutterError(code: ErrorCodes.noOpenL2CapChannelFound, message: "No open channel found for device and psm", details: nil))
            return
        }
        
        let bytesWritten = channelToWrite.outputStream.write(data: payload)
        LogUtil.log(logLevel: LogLevel.debug, message: String(format: "Send %d bytes.", bytesWritten))
        result(nil)
    }
   
    func close(deviceIdentifier: UUID) {
        guard let channelToClose = openChannels.firstIndex(where: { deviceIdentifier == $0.peer.identifier }) else {            
            LogUtil.log(logLevel: LogLevel.error, message: "No open channel found for device and psm")
            return
        }
        openChannels[channelToClose].inputStream.close()
        openChannels[channelToClose].outputStream.close()
        
        openChannels.remove(at: channelToClose)
    }
   
    func closeAllConnections() {
        openChannels.forEach { channel in
            channel.inputStream.close()
            channel.outputStream.close()
        }
        openChannels.removeAll()
    }
    
}
