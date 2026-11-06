import AppKit
import BrewBarCore
import Observation

@MainActor
@Observable
final class CheckModel {
    private(set) var packages: [OutdatedPackage] = []
    private(set) var error: BrewError?
    private(set) var updateWarning: BrewError?
    private(set) var launchError: String?
    private(set) var lastBrewUpdate: Date?
    private(set) var hasChecked = false
    private(set) var isBusy = false

    var greedy: Bool = CheckModel.savedFlag(greedyKey, default: false) {
        didSet { UserDefaults.standard.set(greedy, forKey: CheckModel.greedyKey) }
    }

    var skipsConfirmation: Bool = CheckModel.savedFlag(skipsConfirmationKey, default: true) {
        didSet { UserDefaults.standard.set(skipsConfirmation, forKey: CheckModel.skipsConfirmationKey) }
    }

    private let client = BrewClient()
    private let lock = RunLock()

    private static let greedyKey = "greedy"
    private static let skipsConfirmationKey = "skipsConfirmation"
    private static let updateInterval = Duration.seconds(15 * 60)
    private static let checkInterval = Duration.seconds(60)
    private static let updateDelay = Duration.seconds(30)

    private static func savedFlag(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }

    init() {
        startLoops()
        refreshOnWake()
    }

    /// What the menu shows. Casks that update themselves only appear with greedy.
    var visiblePackages: [OutdatedPackage] {
        packages.filter { $0.isVisible(greedy: greedy) }
    }

    var count: Int {
        packages.filter { $0.isCounted(greedy: greedy) }.count
    }

    var title: String { Formatting.title(count: count) }

    var showsWarning: Bool { error != nil }

    var formulae: [OutdatedPackage] { visiblePackages.filter { $0.kind == .formula } }
    var casks: [OutdatedPackage] { visiblePackages.filter { $0.kind == .cask } }

    /// Fetches new package definitions (`brew update`). Waits if another command is running.
    func update() async {
        await exclusively(wait: true) { await fetchDefinitions() }
    }

    /// Lists what is outdated. Skipped if another command is running, the next check catches up.
    func check() async {
        await exclusively(wait: false) { await loadOutdated() }
    }

    /// Both one after the other, without another command in between.
    func refresh() async {
        await exclusively(wait: true) {
            await fetchDefinitions()
            await loadOutdated()
        }
    }

    func upgrade(_ command: UpgradeCommand) {
        let source = TerminalLauncher.appleScript(for: command, skipConfirmation: skipsConfirmation)
        let script = NSAppleScript(source: source)
        var info: NSDictionary?
        script?.executeAndReturnError(&info)
        if let info {
            let message = info[NSAppleScript.errorMessage] as? String ?? "Could Not Open Terminal"
            launchError = message
            FileHandle.standardError.write(Data("BrewBar: \(message)\n".utf8))
        } else {
            launchError = nil
        }
    }

    private func exclusively(wait: Bool, _ work: () async -> Void) async {
        if wait {
            await lock.acquire()
        } else if await !lock.tryAcquire() {
            return
        }
        isBusy = true
        await work()
        isBusy = false
        await lock.release()
    }

    private func fetchDefinitions() async {
        let previous = updateWarning
        updateWarning = nil
        do {
            try await client.update()
            lastBrewUpdate = .now
        } catch where error != .busy {
            updateWarning = error
            if error != previous { log(error) }
        } catch {}
    }

    private func loadOutdated() async {
        do {
            packages = try await client.outdated()
            error = nil
            hasChecked = true
        } catch {
            if error != self.error { log(error) }
            self.error = error
        }
    }

    private func log(_ error: BrewError) {
        FileHandle.standardError.write(Data("BrewBar: \(error.message)\n".utf8))
    }

    private func startLoops() {
        Task {
            try? await Task.sleep(for: Self.updateDelay)
            while !Task.isCancelled {
                await update()
                try? await Task.sleep(for: Self.updateInterval)
            }
        }
        Task {
            while !Task.isCancelled {
                await check()
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    private func refreshOnWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(10))
                await self?.refresh()
            }
        }
    }
}
