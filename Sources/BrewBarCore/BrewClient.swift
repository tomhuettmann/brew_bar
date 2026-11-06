import Foundation

public struct BrewClient: Sendable {
    public static let brewPath = "/opt/homebrew/bin/brew"

    private let runner: any ProcessRunning
    private let brewPath: String
    private let isExecutable: @Sendable (String) -> Bool
    private let updateTimeout: Duration
    private let outdatedTimeout: Duration

    public init(
        runner: any ProcessRunning = SystemProcessRunner(),
        brewPath: String = BrewClient.brewPath,
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        updateTimeout: Duration = .seconds(120),
        outdatedTimeout: Duration = .seconds(60)
    ) {
        self.runner = runner
        self.brewPath = brewPath
        self.isExecutable = isExecutable
        self.updateTimeout = updateTimeout
        self.outdatedTimeout = outdatedTimeout
    }

    /// Fetches the latest package definitions (`brew update`).
    public func update() async throws(BrewError) {
        _ = try await brew(["update"], timeout: updateTimeout)
    }

    /// Lists outdated packages, including casks that update themselves, which are marked as such.
    public func outdated() async throws(BrewError) -> [OutdatedPackage] {
        let plain = try OutdatedParser.parse(try await brew(["outdated", "--json=v2"], timeout: outdatedTimeout).stdout)
        let greedy = try OutdatedParser.parse(
            try await brew(["outdated", "--json=v2", "--greedy"], timeout: outdatedTimeout).stdout
        )
        return OutdatedParser.merge(plain: plain, greedy: greedy)
    }

    private func brew(_ arguments: [String], timeout: Duration) async throws(BrewError) -> ProcessResult {
        guard isExecutable(brewPath) else { throw .brewNotFound }
        let result = try await runner.run(
            executable: URL(fileURLWithPath: brewPath),
            arguments: arguments,
            environment: Self.environment,
            timeout: timeout
        )
        guard result.exitCode == 0 else { throw Self.error(for: result) }
        return result
    }

    static var environment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        environment["HOMEBREW_NO_ANALYTICS"] = "1"
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        return environment
    }

    static func error(for result: ProcessResult) -> BrewError {
        let stderr = result.stderr
        let busyHints = ["already running", "already locked", "already in progress"]
        if busyHints.contains(where: { stderr.localizedCaseInsensitiveContains($0) }) { return .busy }
        let detail = stderr
            .split(whereSeparator: \.isNewline)
            .last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return .failed(detail)
    }
}
