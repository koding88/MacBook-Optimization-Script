import Foundation

extension OptimizationCatalog {
    static let storageActions: [OptimizationAction] = [
        OptimizationAction(id: "cache_clear", titleKey: "action.cache_clear.title", descriptionKey: "action.cache_clear.description", category: .storage, symbolName: "trash", statusFeatureID: "cache_clear", isRisky: true, estimatedTime: "20-60 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "rm -rf ~/Library/Caches/*", requiresAdministrator: true),
            CommandRequest(command: "rm -rf /Library/Caches/*", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "language_cleanup", titleKey: "action.language_cleanup.title", descriptionKey: "action.language_cleanup.description", category: .storage, symbolName: "globe", statusFeatureID: "language_cleanup", isRisky: true, estimatedTime: "15-30 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "rm -rf '/System/Library/CoreServices/Language Chooser.app'", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "font_cache", titleKey: "action.font_cache.title", descriptionKey: "action.font_cache.description", category: .storage, symbolName: "textformat", statusFeatureID: "font_cache", isRisky: false, estimatedTime: "10-20 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "atsutil databases -remove", requiresAdministrator: true),
            CommandRequest(command: "atsutil server -shutdown", requiresAdministrator: true),
            CommandRequest(command: "atsutil server -ping", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "ds_store_cleanup", titleKey: "action.ds_store_cleanup.title", descriptionKey: "action.ds_store_cleanup.description", category: .storage, symbolName: "doc.badge.gearshape", statusFeatureID: "ds_store_cleanup", isRisky: false, estimatedTime: "10-20 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "find \"$HOME\" -name '.DS_Store' -delete", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil)
    ]
}
