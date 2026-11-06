import BrewBarCore
import Foundation
import Testing

struct ProcessRunnerTests {
    private let runner = SystemProcessRunner()

    @Test func capturesOutputAndExitCode() async throws {
        let result = try await runner.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "echo out; echo err >&2; exit 3"],
            environment: [:],
            timeout: .seconds(10)
        )
        #expect(result.exitCode == 3)
        #expect(String(decoding: result.stdout, as: UTF8.self) == "out\n")
        #expect(result.stderr == "err\n")
    }

    @Test func passesTheEnvironment() async throws {
        let result = try await runner.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "echo $BREWBAR_TEST"],
            environment: ["BREWBAR_TEST": "yes"],
            timeout: .seconds(10)
        )
        #expect(String(decoding: result.stdout, as: UTF8.self) == "yes\n")
    }

    @Test func readsLargeOutput() async throws {
        let result = try await runner.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "yes x | head -c 500000"],
            environment: [:],
            timeout: .seconds(10)
        )
        #expect(result.stdout.count == 500_000)
    }

    @Test func timesOut() async {
        await #expect(throws: BrewError.timeout) {
            try await runner.run(
                executable: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["10"],
                environment: [:],
                timeout: .seconds(1)
            )
        }
    }

    @Test func failsForMissingExecutable() async {
        await #expect(throws: BrewError.self) {
            try await runner.run(
                executable: URL(fileURLWithPath: "/nonexistent/tool"),
                arguments: [],
                environment: [:],
                timeout: .seconds(1)
            )
        }
    }
}
