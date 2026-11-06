import AppKit
import SwiftUI

@main
struct BrewBarApp: App {
    @State private var model = CheckModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.showsWarning ? "exclamationmark.triangle.fill" : "shippingbox")
                if !model.title.isEmpty {
                    Text("\u{2009}" + model.title)
                }
            }
        }
    }
}
