import CoreBluetooth
import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

final class L2CAPChannelBox {
    private enum State { case open, closing, closed }

    init(channel: CBL2CAPChannel, managerIds: Set<Int>) {
        self.channel = channel
        self.managerIds = managerIds
        inputState = channel.inputStream == nil || channel.inputStream?.streamStatus == .closed ? .closed : .open
        outputState = channel.outputStream == nil || channel.outputStream?.streamStatus == .closed ? .closed : .open
    }

    let handle = UUID().uuidString.lowercased()
    let channel: CBL2CAPChannel
    var managerIds: Set<Int>
    private var inputState: State
    private var outputState: State
    private var inputIO: L2CAPStream?
    private var outputIO: L2CAPStream?

    deinit {
        if inputState != .closed {
            if let inputIO { inputIO.close(completion: {}) } else { channel.inputStream?.close() }
        }
        if outputState != .closed {
            if let outputIO { outputIO.close(completion: {}) } else { channel.outputStream?.close() }
        }
    }

    var isClosed: Bool { inputState != .open && outputState != .open }
    var isReleased: Bool { inputState == .closed && outputState == .closed }

    func read(maxLength: Int, result: @escaping FlutterResult) {
        guard inputState == .open, let input = channel.inputStream else {
            result(FlutterError(code: "stream_closed", message: "L2CAP input stream is closed", details: nil))
            return
        }
        if inputIO == nil { inputIO = L2CAPStream(input: input) }
        inputIO!.read(maxLength: maxLength, result: result)
    }

    func write(_ data: Data, result: @escaping FlutterResult) {
        guard outputState == .open, let output = channel.outputStream else {
            result(FlutterError(code: "stream_closed", message: "L2CAP output stream is closed", details: nil))
            return
        }
        if outputIO == nil { outputIO = L2CAPStream(output: output) }
        outputIO!.write(data, result: result)
    }

    func closeInput(completion: @escaping () -> Void = {}) {
        guard inputState != .closed else { completion(); return }
        inputState = .closing
        if let inputIO {
            inputIO.close {
                self.inputState = .closed
                completion()
            }
        } else {
            channel.inputStream?.close()
            inputState = .closed
            completion()
        }
    }

    func closeOutput(completion: @escaping () -> Void = {}) {
        guard outputState != .closed else { completion(); return }
        outputState = .closing
        if let outputIO {
            outputIO.close {
                self.outputState = .closed
                completion()
            }
        } else {
            channel.outputStream?.close()
            outputState = .closed
            completion()
        }
    }

    func close(completion: @escaping () -> Void = {}) {
        let group = DispatchGroup()
        group.enter()
        closeInput { group.leave() }
        group.enter()
        closeOutput { group.leave() }
        group.notify(queue: .main, execute: completion)
    }
}
