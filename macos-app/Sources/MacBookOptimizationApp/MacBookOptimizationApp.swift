import SwiftUI

@main
struct MacBookOptimizationApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var model: OptimizationDashboardViewModel

    init() {
        let settingsStore = AppSettingsStore()
        let dashboardModel = OptimizationDashboardViewModel(settings: settingsStore)
        _settings = StateObject(wrappedValue: settingsStore)
        _model = StateObject(wrappedValue: dashboardModel)
        appDelegate.onTerminate = {
            dashboardModel.stopAllMonitoring()
        }
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(model)
                .environmentObject(settings)
                .frame(minWidth: 1240, minHeight: 780)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                model.stopAllMonitoring()
            }
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
