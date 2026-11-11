import Foundation

public enum UpgradeCommand: Equatable, Sendable {
    case all(greedy: Bool)
    case package(OutdatedPackage)
}

/// Builds what gets typed into Terminal.app to run an upgrade.
public enum TerminalLauncher {
    /// With `skipConfirmation`, Homebrew does not ask before it upgrades (`--yes`).
    public static func shellCommand(for command: UpgradeCommand, skipConfirmation: Bool = false) -> String {
        var arguments = ["upgrade"]
        if skipConfirmation { arguments.append("--yes") }
        switch command {
        case .all(let greedy):
            if greedy { arguments.append("--greedy") }
        case .package(let package):
            switch package.kind {
            case .formula: arguments += ["--formula", package.name]
            case .cask: arguments += ["--cask", "--greedy", package.name]
            }
        }
        return ([BrewClient.brewPath] + arguments).map(shellQuoted).joined(separator: " ")
    }

    /// Closes by itself on success (if the Terminal profile allows it), waits for Enter on failure.
    public static func script(for command: UpgradeCommand, skipConfirmation: Bool = false) -> String {
        """
        #!/bin/zsh
        export PATH=/opt/homebrew/bin:/usr/local/bin:"$PATH"
        \(shellCommand(for: command, skipConfirmation: skipConfirmation))
        status=$?
        if [ $status -ne 0 ]; then
            echo
            echo "Upgrade failed (exit code $status). Press Enter to close."
            read
        fi
        rm -f -- "$0"
        exit $status

        """
    }

    public static let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BrewBar", isDirectory: true)

    /// Writes the script as an executable `.command` file, so Terminal can open it without any
    /// Automation permission. Scripts left behind by earlier runs are removed first.
    public static func writeScript(
        for command: UpgradeCommand,
        skipConfirmation: Bool = false,
        in directory: URL = directory,
        now: Date = .now
    ) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        removeStaleScripts(in: directory, olderThan: now.addingTimeInterval(-3600))
        let url = directory.appendingPathComponent("upgrade-\(UUID().uuidString).command")
        try script(for: command, skipConfirmation: skipConfirmation).write(to: url, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    static func removeStaleScripts(in directory: URL, olderThan cutoff: Date) {
        let fileManager = FileManager.default
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        for url in urls where url.pathExtension == "command" {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff { try? fileManager.removeItem(at: url) }
        }
    }

    static func shellQuoted(_ argument: String) -> String {
        let safe = argument.allSatisfy { $0.isLetter || $0.isNumber || "-_./@+=".contains($0) }
        if safe, !argument.isEmpty { return argument }
        return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
