import Foundation

/// Parses the output of `brew outdated --json=v2`.
public enum OutdatedParser {
    private struct Output: Decodable {
        var formulae: [Entry] = []
        var casks: [Entry] = []

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formulae = try container.decodeIfPresent([Entry].self, forKey: .formulae) ?? []
            casks = try container.decodeIfPresent([Entry].self, forKey: .casks) ?? []
        }

        private enum CodingKeys: String, CodingKey { case formulae, casks }
    }

    private struct Entry: Decodable {
        let name: String
        let installedVersions: [String]
        let currentVersion: String
        let pinned: Bool?

        private enum CodingKeys: String, CodingKey {
            case name
            case installedVersions = "installed_versions"
            case currentVersion = "current_version"
            case pinned
        }
    }

    public static func parse(_ data: Data) throws(BrewError) -> [OutdatedPackage] {
        let output: Output
        do {
            output = try JSONDecoder().decode(Output.self, from: data)
        } catch {
            throw .unexpectedOutput
        }
        let formulae = output.formulae.map { package($0, kind: .formula) }
        let casks = output.casks.map { package($0, kind: .cask) }
        return sorted(formulae + casks)
    }

    /// Combines the plain and the greedy result. Packages that only show up with `--greedy` update themselves.
    public static func merge(plain: [OutdatedPackage], greedy: [OutdatedPackage]) -> [OutdatedPackage] {
        let plainIDs = Set(plain.map(\.id))
        var merged = plain.map { $0.marked(autoUpdates: false) }
        for package in greedy where !plainIDs.contains(package.id) {
            merged.append(package.marked(autoUpdates: true))
        }
        return sorted(merged)
    }

    private static func package(_ entry: Entry, kind: OutdatedPackage.Kind) -> OutdatedPackage {
        OutdatedPackage(
            name: entry.name,
            kind: kind,
            installedVersion: entry.installedVersions.joined(separator: ", "),
            currentVersion: entry.currentVersion,
            pinned: entry.pinned ?? false
        )
    }

    private static func sorted(_ packages: [OutdatedPackage]) -> [OutdatedPackage] {
        packages.sorted { ($0.kind, $0.name) < ($1.kind, $1.name) }
    }
}
