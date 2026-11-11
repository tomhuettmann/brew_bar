@testable import BrewBarCore
import Foundation
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
        #expect(!TerminalLauncher.script(for: .all(greedy: false)).contains("--yes"))
        #expect(TerminalLauncher.script(for: .all(greedy: false), skipConfirmation: true).contains("--yes"))
    }

    @Test func quotesUnusualNames() {
        #expect(TerminalLauncher.shellQuoted("a b") == "'a b'")
        #expect(TerminalLauncher.shellQuoted("it's") == "'it'\\''s'")
        #expect(TerminalLauncher.shellQuoted("") == "''")
        #expect(TerminalLauncher.shellQuoted("foo@1.2") == "foo@1.2")
    }

    @Test func scriptRunsCommandAndCleansUp() {
        let script = TerminalLauncher.script(for: .package(package("a\"b", .formula)))
        #expect(script.hasPrefix("#!/bin/zsh\n"))
        #expect(script.contains("/opt/homebrew/bin/brew upgrade --formula 'a\"b'\n"))
        #expect(script.contains("read"))
        #expect(script.contains(#"rm -f -- "$0""#))
        #expect(script.contains("exit $status"))
    }

    @Test func writesExecutableScriptAndRemovesStaleOnes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrewBarTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try TerminalLauncher.writeScript(for: .all(greedy: false), in: directory)
        #expect(FileManager.default.isExecutableFile(atPath: first.path))
        let second = try TerminalLauncher.writeScript(
            for: .all(greedy: false), in: directory, now: .now.addingTimeInterval(7200)
        )
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }
}
