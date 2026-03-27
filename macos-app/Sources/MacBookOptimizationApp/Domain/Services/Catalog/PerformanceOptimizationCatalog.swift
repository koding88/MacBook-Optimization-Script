import Foundation

extension OptimizationCatalog {
    static let performanceActions: [OptimizationAction] = [
        OptimizationAction(id: "spotlight", titleKey: "action.spotlight.title", descriptionKey: "action.spotlight.description", category: .performance, symbolName: "magnifyingglass", statusFeatureID: "spotlight", isRisky: true, estimatedTime: "10-20 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "mdutil -a -i off", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "dashboard", titleKey: "action.dashboard.title", descriptionKey: "action.dashboard.description", category: .performance, symbolName: "square.grid.2x2", statusFeatureID: "dashboard", isRisky: false, estimatedTime: "5-10 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "defaults write com.apple.dashboard mcx-disabled -boolean YES", requiresAdministrator: false),
            CommandRequest(command: "killall Dock", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "animations", titleKey: "action.animations.title", descriptionKey: "action.animations.description", category: .performance, symbolName: "sparkles", statusFeatureID: "animations", isRisky: false, estimatedTime: "5-10 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false", requiresAdministrator: false),
            CommandRequest(command: "defaults write NSGlobalDomain NSWindowResizeTime -float 0.001", requiresAdministrator: false),
            CommandRequest(command: "defaults write com.apple.dock launchanim -bool false", requiresAdministrator: false),
            CommandRequest(command: "killall Dock", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "dock_optimization", titleKey: "action.dock_optimization.title", descriptionKey: "action.dock_optimization.description", category: .performance, symbolName: "dock.rectangle", statusFeatureID: "dock_optimization", isRisky: false, estimatedTime: "5-10 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "defaults write com.apple.dock launchanim -bool false", requiresAdministrator: false),
            CommandRequest(command: "defaults write com.apple.dock expose-animation-duration -float 0", requiresAdministrator: false),
            CommandRequest(command: "defaults write com.apple.dock springboard-show-duration -int 0", requiresAdministrator: false),
            CommandRequest(command: "defaults write com.apple.dock springboard-hide-duration -int 0", requiresAdministrator: false),
            CommandRequest(command: "killall Dock", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil)
    ]
}
