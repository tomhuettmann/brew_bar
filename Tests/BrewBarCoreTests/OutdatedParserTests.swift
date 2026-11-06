import BrewBarCore
import Foundation
import Testing

struct OutdatedParserTests {
    private static let plain = #"""
    {
      "formulae": [
        { "name": "wget", "installed_versions": ["1.24.5"], "current_version": "1.25.0", "pinned": false, "pinned_version": null },
        { "name": "node", "installed_versions": ["22.1.0"], "current_version": "22.2.0", "pinned": true, "pinned_version": "22.1.0" }
      ],
      "casks": [
        { "name": "intellij-idea", "installed_versions": ["2026.2.4,262.11879.100"], "current_version": "2026.3,263.7307.200", "pinned": false, "pinned_version": null }
      ]
    }
    """#

    private static let greedy = #"""
    {
      "formulae": [
        { "name": "wget", "installed_versions": ["1.24.5"], "current_version": "1.25.0", "pinned": false, "pinned_version": null },
        { "name": "node", "installed_versions": ["22.1.0"], "current_version": "22.2.0", "pinned": true, "pinned_version": "22.1.0" }
      ],
      "casks": [
        { "name": "intellij-idea", "installed_versions": ["2026.2.4,262.11879.100"], "current_version": "2026.3,263.7307.200", "pinned": false, "pinned_version": null },
        { "name": "visual-studio-code", "installed_versions": ["1.145.0"], "current_version": "1.145.2", "pinned": false, "pinned_version": null }
      ]
    }
    """#

    @Test func parsesFormulaeAndCasks() throws {
        let packages = try OutdatedParser.parse(Data(Self.plain.utf8))
        #expect(packages.map(\.id) == ["formula:node", "formula:wget", "cask:intellij-idea"])
        let wget = try #require(packages.first { $0.name == "wget" })
        #expect(wget.installedVersion == "1.24.5")
        #expect(wget.currentVersion == "1.25.0")
        #expect(!wget.pinned)
    }

    @Test func readsPinned() throws {
        let packages = try OutdatedParser.parse(Data(Self.plain.utf8))
        #expect(packages.first { $0.name == "node" }?.pinned == true)
    }

    @Test func parsesEmptyResult() throws {
        #expect(try OutdatedParser.parse(Data(#"{ "formulae": [], "casks": [] }"#.utf8)).isEmpty)
        #expect(try OutdatedParser.parse(Data("{}".utf8)).isEmpty)
    }

    @Test func rejectsGarbage() {
        #expect(throws: BrewError.unexpectedOutput) { try OutdatedParser.parse(Data("not json".utf8)) }
    }

    @Test func marksPackagesThatOnlyShowUpWithGreedy() throws {
        let merged = OutdatedParser.merge(
            plain: try OutdatedParser.parse(Data(Self.plain.utf8)),
            greedy: try OutdatedParser.parse(Data(Self.greedy.utf8))
        )
        #expect(merged.count == 4)
        #expect(merged.first { $0.name == "visual-studio-code" }?.autoUpdates == true)
        #expect(merged.first { $0.name == "intellij-idea" }?.autoUpdates == false)
        #expect(merged.first { $0.name == "wget" }?.autoUpdates == false)
    }

    @Test func countsDependOnGreedyAndPinned() {
        let normal = OutdatedPackage(name: "a", kind: .formula, installedVersion: "1", currentVersion: "2")
        let auto = OutdatedPackage(name: "b", kind: .cask, installedVersion: "1", currentVersion: "2", autoUpdates: true)
        let pinned = OutdatedPackage(name: "c", kind: .formula, installedVersion: "1", currentVersion: "2", pinned: true)
        #expect(normal.isCounted(greedy: false))
        #expect(!auto.isCounted(greedy: false))
        #expect(auto.isCounted(greedy: true))
        #expect(!pinned.isCounted(greedy: true))
        #expect(!pinned.isUpgradable)
    }

    @Test func showsAutoUpdatingCasksOnlyWithGreedy() {
        let normal = OutdatedPackage(name: "a", kind: .formula, installedVersion: "1", currentVersion: "2")
        let auto = OutdatedPackage(name: "b", kind: .cask, installedVersion: "1", currentVersion: "2", autoUpdates: true)
        #expect(normal.isVisible(greedy: false))
        #expect(!auto.isVisible(greedy: false))
        #expect(auto.isVisible(greedy: true))
    }
}
