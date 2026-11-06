public struct OutdatedPackage: Identifiable, Equatable, Sendable {
    public enum Kind: Int, Comparable, Sendable {
        case formula
        case cask

        public static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public let name: String
    public let kind: Kind
    public let installedVersion: String
    public let currentVersion: String
    public let pinned: Bool
    /// The cask updates itself, so Homebrew only reports it with `--greedy`.
    public let autoUpdates: Bool

    public var id: String { "\(kind):\(name)" }

    public init(
        name: String,
        kind: Kind,
        installedVersion: String,
        currentVersion: String,
        pinned: Bool = false,
        autoUpdates: Bool = false
    ) {
        self.name = name
        self.kind = kind
        self.installedVersion = installedVersion
        self.currentVersion = currentVersion
        self.pinned = pinned
        self.autoUpdates = autoUpdates
    }

    /// Whether the package can be upgraded from the list.
    public var isUpgradable: Bool { !pinned }

    /// Whether the package is shown at all. Casks that update themselves only show up with greedy.
    public func isVisible(greedy: Bool) -> Bool {
        greedy || !autoUpdates
    }

    /// Whether the package is shown in the number next to the icon.
    public func isCounted(greedy: Bool) -> Bool {
        !pinned && isVisible(greedy: greedy)
    }

    func marked(autoUpdates: Bool) -> OutdatedPackage {
        OutdatedPackage(
            name: name, kind: kind, installedVersion: installedVersion,
            currentVersion: currentVersion, pinned: pinned, autoUpdates: autoUpdates
        )
    }
}
