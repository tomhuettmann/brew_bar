@testable import BrewBarCore
import Testing

struct TerminalLauncherTests {
    private func package(_ name: String, _ kind: OutdatedPackage.Kind) -> OutdatedPackage {
        OutdatedPackage(name: name, kind: kind, installedVersion: "1", currentVersion: "2")
    }

    @Test func buildsUpgradeAll() {
        #expect(TerminalLauncher.shellCommand(for: .all(greedy: false)) == "/opt/homebrew/bin/brew upgrade")
        #expect(TerminalLauncher.shellCommand(for: .all(greedy: true)) == "/opt/homebrew/bin/brew upgrade --greedy")
    }

    @Test func buildsFormulaUpgrade() {
        let command = TerminalLauncher.shellCommand(for: .package(package("wget", .formula)))
        #expect(command == "/opt/homebrew/bin/brew upgrade --formula wget")
    }

    @Test func buildsCaskUpgrade() {
        let command = TerminalLauncher.shellCommand(for: .package(package("visual-studio-code", .cask)))
        #expect(command == "/opt/homebrew/bin/brew upgrade --cask --greedy visual-studio-code")
    }

    @Test func skipsConfirmationOnRequest() {
        #expect(
            TerminalLauncher.shellCommand(for: .all(greedy: true), skipConfirmation: true)
                == "/opt/homebrew/bin/brew upgrade --yes --greedy"
        )
        #expect(
            TerminalLauncher.shellCommand(for: .package(package("wget", .formula)), skipConfirmation: true)
                == "/opt/homebrew/bin/brew upgrade --yes --formula wget"
        )
        #expect(!TerminalLauncher.appleScript(for: .all(greedy: false)).contains("--yes"))
        #expect(TerminalLauncher.appleScript(for: .all(greedy: false), skipConfirmation: true).contains("--yes"))
    }

    @Test func quotesUnusualNames() {
        #expect(TerminalLauncher.shellQuoted("a b") == "'a b'")
        #expect(TerminalLauncher.shellQuoted("it's") == "'it'\\''s'")
        #expect(TerminalLauncher.shellQuoted("") == "''")
        #expect(TerminalLauncher.shellQuoted("foo@1.2") == "foo@1.2")
    }

    @Test func escapesForAppleScript() {
        let script = TerminalLauncher.appleScript(for: .package(package("a\"b", .formula)))
        #expect(script.contains(#"do script "/opt/homebrew/bin/brew upgrade --formula 'a\"b'""#))
        #expect(script.contains(#"tell application "Terminal""#))
    }
}
