import BrewBarCore
import Testing

struct FormattingTests {
    @Test func titleIsEmptyWithoutUpdates() {
        #expect(Formatting.title(count: 0) == "")
        #expect(Formatting.title(count: 5) == "5")
    }

    @Test func dropsCaskBuildNumbers() {
        let package = OutdatedPackage(
            name: "idea", kind: .cask, installedVersion: "2026.2.4,262.1", currentVersion: "2026.3,263.7"
        )
        #expect(Formatting.versions(for: package) == ("2026.2.4", "2026.3"))
    }

    @Test func keepsBuildNumbersWhenOnlyTheyDiffer() {
        let package = OutdatedPackage(
            name: "idea", kind: .cask, installedVersion: "2026.3,262.1", currentVersion: "2026.3,263.7"
        )
        #expect(Formatting.versions(for: package) == ("2026.3,262.1", "2026.3,263.7"))
    }

    @Test func buildsRowTitles() {
        let plain = OutdatedPackage(name: "wget", kind: .formula, installedVersion: "1.0", currentVersion: "1.1")
        let auto = OutdatedPackage(
            name: "code", kind: .cask, installedVersion: "1", currentVersion: "2", autoUpdates: true
        )
        #expect(Formatting.rowTitle(for: plain) == "wget  1.0 → 1.1")
        #expect(Formatting.rowTitle(for: auto) == "code  1 → 2 · Auto-Updates")
    }

    @Test func truncatesLongMessages() {
        #expect(Formatting.truncated("short") == "short")
        #expect(Formatting.truncated("first\nsecond") == "first")
        #expect(Formatting.truncated(String(repeating: "a", count: 100), limit: 10) == "aaaaaaaaa…")
    }

    @Test func describesStatus() {
        #expect(Formatting.status(count: 0) == "Everything Is Up to Date")
        #expect(Formatting.status(count: 1) == "1 Package Outdated")
        #expect(Formatting.status(count: 3) == "3 Packages Outdated")
    }
}
