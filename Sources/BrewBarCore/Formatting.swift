public enum Formatting {
    /// The text next to the icon; empty when there is nothing to upgrade.
    public static func title(count: Int) -> String {
        count > 0 ? String(count) : ""
    }

    /// Casks report versions like `1.2.3,456`. The build part is dropped unless it is all that differs.
    public static func versions(for package: OutdatedPackage) -> (installed: String, current: String) {
        let installed = shortVersion(package.installedVersion)
        let current = shortVersion(package.currentVersion)
        if installed == current { return (package.installedVersion, package.currentVersion) }
        return (installed, current)
    }

    private static func shortVersion(_ version: String) -> String {
        version.split(separator: ",", omittingEmptySubsequences: false).first.map(String.init) ?? version
    }

    public static func status(count: Int) -> String {
        switch count {
        case 0: "Everything Is Up to Date"
        case 1: "1 Package Outdated"
        default: "\(count) Packages Outdated"
        }
    }

    /// The text of a menu item: `name  installed → current`, marked when the cask updates itself.
    public static func rowTitle(for package: OutdatedPackage) -> String {
        let versions = versions(for: package)
        let title = "\(package.name)  \(versions.installed) → \(versions.current)"
        return package.autoUpdates ? title + " · Auto-Updates" : title
    }

    /// Menu items do not wrap, so long messages are cut.
    public static func truncated(_ text: String, limit: Int = 60) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return line.count > limit ? line.prefix(limit - 1) + "…" : line
    }
}
