import BrewBarCore
import Foundation
import Testing

private final class FakeRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [[String]] = []
    private var results: [Result<ProcessResult, BrewError>]

    init(_ results: [Result<ProcessResult, BrewError>]) { self.results = results }

    var recordedCalls: [[String]] { lock.withLock { calls } }

    func run(
        executable: URL, arguments: [String], environment: [String: String], timeout: Duration
    ) async throws(BrewError) -> ProcessResult {
        let result = lock.withLock { () -> Result<ProcessResult, BrewError> in
            calls.append(arguments)
            return results.removeFirst()
        }
        return try result.get()
    }
}

struct BrewClientTests {
    private func client(_ runner: FakeRunner, installed: Bool = true) -> BrewClient {
        BrewClient(runner: runner, brewPath: "/fake/brew", isExecutable: { _ in installed })
    }

    private func json(_ body: String) -> Result<ProcessResult, BrewError> {
        .success(ProcessResult(exitCode: 0, stdout: Data(body.utf8)))
    }

    @Test func runsPlainAndGreedyOutdated() async throws {
        let plain = #"{ "formulae": [], "casks": [] }"#
        let greedy = #"{ "formulae": [], "casks": [{ "name": "vscode", "installed_versions": ["1"], "current_version": "2" }] }"#
        let runner = FakeRunner([json(plain), json(greedy)])
        let packages = try await client(runner).outdated()
        #expect(runner.recordedCalls == [["outdated", "--json=v2"], ["outdated", "--json=v2", "--greedy"]])
        #expect(packages.map(\.name) == ["vscode"])
        #expect(packages.first?.autoUpdates == true)
    }

    @Test func runsUpdate() async throws {
        let runner = FakeRunner([.success(ProcessResult(exitCode: 0))])
        try await client(runner).update()
        #expect(runner.recordedCalls == [["update"]])
    }

    @Test func failsWithoutBrew() async {
        let runner = FakeRunner([])
        await #expect(throws: BrewError.brewNotFound) { try await client(runner, installed: false).update() }
        #expect(runner.recordedCalls.isEmpty)
    }

    @Test func detectsLockAsBusy() async {
        let stderr = "Error: Another `brew update` process is already running."
        let runner = FakeRunner([.success(ProcessResult(exitCode: 1, stderr: stderr))])
        await #expect(throws: BrewError.busy) { try await client(runner).update() }
    }

    @Test func reportsLastErrorLine() async {
        let stderr = "Warning: something\nError: Could not resolve host: github.com\n"
        let runner = FakeRunner([.success(ProcessResult(exitCode: 1, stderr: stderr))])
        await #expect(throws: BrewError.failed("Error: Could not resolve host: github.com")) {
            try await client(runner).update()
        }
    }

    @Test func passesThroughTimeout() async {
        let runner = FakeRunner([.failure(.timeout)])
        await #expect(throws: BrewError.timeout) { try await client(runner).update() }
    }

    @Test func rejectsUnparsableOutput() async {
        let runner = FakeRunner([json("oops")])
        await #expect(throws: BrewError.unexpectedOutput) { try await client(runner).outdated() }
    }
}
