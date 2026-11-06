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

    public static func appleScript(for command: UpgradeCommand, skipConfirmation: Bool = false) -> String {
        let escaped = shellCommand(for: command, skipConfirmation: skipConfirmation)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
    }

    static func shellQuoted(_ argument: String) -> String {
        let safe = argument.allSatisfy { $0.isLetter || $0.isNumber || "-_./@+=".contains($0) }
        if safe, !argument.isEmpty { return argument }
        return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
