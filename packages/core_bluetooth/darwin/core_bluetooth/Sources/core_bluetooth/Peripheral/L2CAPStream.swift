import Foundation

#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

// Each direction owns its stream on one background run loop. Waiting for stream
// readiness leaves that loop free to process close and cancellation requests.
final class L2CAPStream: NSObject, StreamDelegate {
    private struct Request {
        let needsCapacity: Bool
        let operation: () -> Any?
        let reply: FlutterResult
    }

    private let stream: Stream
    private let hasCapacity: () -> Bool
    private let lock = NSLock()
    private var loop: CFRunLoop?
    private var startupTasks: [() -> Void] = []
    private var closing = false
    private var finished = false
    private var closeReplies: [() -> Void] = []

    // These fields are accessed only on the stream's thread.
    private var prepared = false
    private var pumping = false
    private var requests: [Request] = []

    init(input: InputStream) {
        stream = input
        hasCapacity = { input.hasBytesAvailable }
        super.init()
        start()
    }

    init(output: OutputStream) {
        stream = output
        hasCapacity = { output.hasSpaceAvailable }
        super.init()
        start()
    }

    private var isClosing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return closing
    }

    private func deliver(_ value: Any?, to reply: @escaping FlutterResult) {
        DispatchQueue.main.async { reply(value) }
    }

    private func closedError() -> FlutterError {
        FlutterError(code: "stream_closed", message: "L2CAP stream is closed", details: nil)
    }

    private func readError(_ input: InputStream) -> FlutterError {
        let error = input.streamError as NSError?
        return FlutterError(code: "stream_error", message: error?.localizedDescription ?? "L2CAP input stream read failed",
                            details: error.map { ["domain": $0.domain, "code": $0.code] })
    }

    private func start() {
        let thread = Thread { self.run() }
        thread.name = "CoreBluetooth L2CAP stream"
        thread.start()
    }

    // The caller holds lock so publishing the run loop and queuing work are atomic.
    private func schedule(_ action: @escaping () -> Void) {
        if let loop {
            CFRunLoopPerformBlock(loop, CFRunLoopMode.defaultMode.rawValue, action)
            CFRunLoopWakeUp(loop)
        } else {
            startupTasks.append(action)
        }
    }

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        stream.delegate = self
        stream.schedule(in: .current, forMode: .default)
        if stream.streamStatus == .notOpen { stream.open() }
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        pump()
    }

    func read(maxLength: Int, result: @escaping FlutterResult) {
        let input = stream as! InputStream
        enqueue(needsCapacity: maxLength > 0, result: result) {
            guard maxLength > 0 else { return FlutterStandardTypedData(bytes: Data()) }
            // maxLength is an upper bound; large requests may return a partial read.
            var buffer = [UInt8](repeating: 0, count: min(maxLength, 64 * 1024))
            let count = input.read(&buffer, maxLength: buffer.count)
            if count < 0 { return self.readError(input) }
            return FlutterStandardTypedData(bytes: Data(buffer.prefix(count)))
        }
    }

    func write(_ data: Data, result: @escaping FlutterResult) {
        let output = stream as! OutputStream
        enqueue(needsCapacity: !data.isEmpty, result: result) {
            data.withUnsafeBytes { buffer -> Int in
                guard let address = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return output.write(address, maxLength: buffer.count)
            }
        }
    }

    func close(completion: @escaping () -> Void) {
        lock.lock()
        if finished {
            lock.unlock()
            DispatchQueue.main.async(execute: completion)
            return
        }
        closeReplies.append(completion)
        if !closing {
            closing = true
            schedule { self.closeOnLoop() }
        }
        lock.unlock()
    }

    private func enqueue(needsCapacity: Bool, result: @escaping FlutterResult, operation: @escaping () -> Any?) {
        lock.lock()
        guard !closing && !finished else {
            lock.unlock()
            deliver(closedError(), to: result)
            return
        }
        schedule {
            self.requests.append(Request(needsCapacity: needsCapacity, operation: operation, reply: result))
            guard !self.isClosing else { return }
            self.prepare()
            self.pump()
        }
        lock.unlock()
    }

    private func pump() {
        guard !pumping else { return }
        pumping = true
        defer { pumping = false }
        while let request = requests.first {
            guard !isClosing else { return }
            let status = stream.streamStatus
            if status == .closed {
                requests.removeFirst()
                deliver(closedError(), to: request.reply)
                continue
            }
            if status == .notOpen || status == .opening { return }
            if request.needsCapacity && status != .atEnd && status != .error && !hasCapacity() { return }
            requests.removeFirst()
            deliver(request.operation(), to: request.reply)
        }
    }

    private func closeOnLoop() {
        stream.close()
        if prepared {
            stream.remove(from: .current, forMode: .default)
            stream.delegate = nil
        }
        for request in requests { deliver(closedError(), to: request.reply) }
        requests.removeAll()
        lock.lock()
        finished = true
        let replies = closeReplies
        closeReplies.removeAll()
        lock.unlock()
        for reply in replies { DispatchQueue.main.async(execute: reply) }
        CFRunLoopStop(CFRunLoopGetCurrent())
    }

    private func run() {
        let current = CFRunLoopGetCurrent()!
        var context = CFRunLoopSourceContext()
        context.perform = { _ in }
        let keepAlive = CFRunLoopSourceCreate(nil, 0, &context)!
        CFRunLoopAddSource(current, keepAlive, .defaultMode)
        lock.lock()
        loop = current
        let tasks = startupTasks
        startupTasks.removeAll()
        lock.unlock()
        tasks.forEach { $0() }
        lock.lock()
        let shouldRun = !finished
        lock.unlock()
        if shouldRun { CFRunLoopRun() }
        CFRunLoopRemoveSource(current, keepAlive, .defaultMode)
        lock.lock()
        loop = nil
        lock.unlock()
    }
}
