import Foundation

extension OptimizationCatalog {
    static let maintenanceActions: [OptimizationAction] = [
        OptimizationAction(id: "disk_permissions", titleKey: "action.disk_permissions.title", descriptionKey: "action.disk_permissions.description", category: .maintenance, symbolName: "checkmark.seal", statusFeatureID: "disk_permissions", isRisky: false, estimatedTime: "30-90 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "diskutil verifyVolume /", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "maintenance_scripts", titleKey: "action.maintenance_scripts.title", descriptionKey: "action.maintenance_scripts.description", category: .maintenance, symbolName: "calendar.badge.clock", statusFeatureID: "maintenance_scripts", isRisky: false, estimatedTime: "30-120 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "periodic daily weekly monthly", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "log_cleanup", titleKey: "action.log_cleanup.title", descriptionKey: "action.log_cleanup.description", category: .maintenance, symbolName: "text.append", statusFeatureID: "log_cleanup", isRisky: true, estimatedTime: "10-20 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "rm -rf /var/log/*", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "smc_reset", titleKey: "action.smc_reset.title", descriptionKey: "action.smc_reset.description", category: .maintenance, symbolName: "powerplug", statusFeatureID: "smc_reset", isRisky: false, estimatedTime: "Manual", requiresRestart: true, kind: .manual("""
Reset SMC Instructions
1. Shut down your MacBook.
2. Hold Shift + Control + Option and the power button for 10 seconds.
3. Release all keys and wait a few seconds.
4. Press the power button to turn your MacBook back on.
"""), status: .ready, lastRunDescription: nil)
    ]
}
