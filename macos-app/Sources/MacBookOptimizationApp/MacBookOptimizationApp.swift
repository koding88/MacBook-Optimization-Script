import SwiftUI

@main
struct MacBookOptimizationApp: App {
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var model: OptimizationDashboardViewModel

    init() {
        let settingsStore = AppSettingsStore()
        _settings = StateObject(wrappedValue: settingsStore)
        _model = StateObject(wrappedValue: OptimizationDashboardViewModel(settings: settingsStore))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(model)
                .environmentObject(settings)
                .frame(minWidth: 1240, minHeight: 780)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appSettings) {
                Button(settings.language == .vietnamese ? "Cài đặt..." : "Settings...") {
                    model.openSettings()
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}
