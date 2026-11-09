import AppKit
import BrewBarCore
import SwiftUI

struct MenuContent: View {
    @Bindable var model: CheckModel

    var body: some View {
        Text(statusText)

        if let error = model.error {
            Text(Formatting.truncated(error.message))
        }
        if let warning = model.updateWarning {
            Text(Formatting.truncated("Update Failed: \(warning.message)"))
        }
        if let launchError = model.launchError {
            Text(Formatting.truncated(launchError))
        }

        if !model.visiblePackages.isEmpty {
            Divider()
            section("Formulae", model.formulae)
            section("Casks", model.casks)
        }

        Divider()

        Button("Upgrade All") {
            model.upgrade(.all(greedy: model.greedy))
        }
        .disabled(model.count == 0)

        Button(model.isRefreshing ? "Refreshing …" : "Refresh") {
            Task { await model.refresh() }
        }
        .keyboardShortcut("r")
        .disabled(model.isRefreshing)

        Menu("Settings") {
            Toggle("Include Auto-Updating Casks", isOn: $model.greedy)
            Toggle("Skip Upgrade Confirmation", isOn: $model.skipsConfirmation)
        }

        Divider()

        if let lastBrewUpdate = model.lastBrewUpdate {
            Text("Homebrew Updated \(lastBrewUpdate.formatted(date: .omitted, time: .shortened))")
        }

        Button("Quit BrewBar (\(appVersion))") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusText: String {
        if !model.hasChecked {
            return model.error == nil ? "Checking …" : "Check Failed"
        }
        return Formatting.status(count: model.count)
    }

    @ViewBuilder
    private func section(_ title: String, _ packages: [OutdatedPackage]) -> some View {
        if !packages.isEmpty {
            Section(title) {
                ForEach(packages) { package in
                    Button {
                        model.upgrade(.package(package))
                    } label: {
                        if package.pinned {
                            Label(Formatting.rowTitle(for: package), systemImage: "lock.fill")
                        } else {
                            Text(Formatting.rowTitle(for: package))
                        }
                    }
                    .disabled(!package.isUpgradable)
                }
            }
        }
    }
}
