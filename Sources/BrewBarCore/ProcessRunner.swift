import Foundation

public struct ProcessResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: Data
    public let stderr: String

    public init(exitCode: Int32, stdout: Data = Data(), stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol ProcessRunning: Sendable {
    func run(
        executable: URL, arguments: [String], environment: [String: String], timeout: Duration
    ) async throws(BrewError) -> ProcessResult
}

public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    public func run(
        executable: URL, arguments: [String], environment: [String: String], timeout: Duration
    ) async throws(BrewError) -> ProcessResult {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    continuation.resume(with: Result {
                        try Self.runSync(executable, arguments, environment, timeout)
                    })
                }
            }
        } catch let error as BrewError {
            throw error
        } catch {
            throw .failed(error.localizedDescription)
        }
    }

    private static func runSync(
        _ executable: URL, _ arguments: [String], _ environment: [String: String], _ timeout: Duration
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let out = Buffer()
        let err = Buffer()
        let readers = DispatchGroup()
        for (pipe, buffer) in [(outPipe, out), (errPipe, err)] {
            readers.enter()
            DispatchQueue.global().async {
                buffer.set(pipe.fileHandleForReading.readDataToEndOfFile())
                readers.leave()
            }
        }

        let timedOut = Flag()
        do {
            try process.run()
        } catch {
            try? outPipe.fileHandleForWriting.close()
            try? errPipe.fileHandleForWriting.close()
            readers.wait()
            throw BrewError.failed(error.localizedDescription)
        }

        let killer = DispatchWorkItem {
            timedOut.set()
            process.terminate()
        }
        let seconds = Double(timeout.components.seconds)
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds, execute: killer)
        process.waitUntilExit()
        killer.cancel()

        // Child processes of a killed brew may keep the pipes open, so do not wait for them forever.
        _ = readers.wait(timeout: .now() + (timedOut.value ? 2 : 30))
        if timedOut.value { throw BrewError.timeout }

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: out.value,
            stderr: String(decoding: err.value, as: UTF8.self)
        )
    }
}

private final class Buffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    var value: Data { lock.withLock { data } }
    func set(_ newValue: Data) { lock.withLock { data = newValue } }
}

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    var value: Bool { lock.withLock { flag } }
    func set() { lock.withLock { flag = true } }
}
