import Foundation

extension OptimizationCatalog {
    static let systemActions: [OptimizationAction] = [
        OptimizationAction(id: "system_performance", titleKey: "action.system_performance.title", descriptionKey: "action.system_performance.description", category: .system, symbolName: "speedometer", statusFeatureID: "system_performance", isRisky: false, estimatedTime: "15-30 seconds", requiresRestart: false, restoreBehavior: .capturedSysctl(keys: [
            "kern.ipc.somaxconn",
            "kern.ipc.nmbclusters",
            "kern.maxvnodes",
            "kern.maxproc",
            "kern.maxfiles",
            "kern.maxfilesperproc"
        ]), kind: .command([
            CommandRequest(command: "sysctl -w kern.ipc.somaxconn=2048", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w kern.ipc.nmbclusters=65536", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w kern.maxvnodes=750000", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w kern.maxproc=2048", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w kern.maxfiles=200000", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w kern.maxfilesperproc=100000", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "memory_management", titleKey: "action.memory_management.title", descriptionKey: "action.memory_management.description", category: .system, symbolName: "memorychip", statusFeatureID: "memory_management", isRisky: false, estimatedTime: "20-40 seconds", requiresRestart: false, restoreBehavior: .capturedSysctl(
            keys: ["kern.maxvnodes", "kern.maxproc", "kern.maxfiles", "kern.maxfilesperproc"],
            additionalRequests: [CommandRequest(command: "pmset restoredefaults", requiresAdministrator: true)]
        ), kind: .command([
            CommandRequest(command: "purge", requiresAdministrator: true),
            CommandRequest(command: "pmset -a sms 0", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w kern.maxvnodes=750000", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w kern.maxproc=2048", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w kern.maxfiles=200000", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w kern.maxfilesperproc=100000", requiresAdministrator: true),
            CommandRequest(command: "sync", requiresAdministrator: true),
            CommandRequest(command: "purge", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "ssd_optimization", titleKey: "action.ssd_optimization.title", descriptionKey: "action.ssd_optimization.description", category: .system, symbolName: "internaldrive", statusFeatureID: "ssd_optimization", isRisky: true, estimatedTime: "1-2 minutes", requiresRestart: true, restoreBehavior: .staticCommands([
            CommandRequest(command: "trimforce disable", requiresAdministrator: true),
            CommandRequest(command: "pmset restoredefaults", requiresAdministrator: true)
        ]), kind: .command([
            CommandRequest(command: "trimforce enable", requiresAdministrator: true),
            CommandRequest(command: "pmset -a hibernatemode 0", requiresAdministrator: true),
            CommandRequest(command: "rm -f /var/vm/sleepimage", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "security_optimization", titleKey: "action.security_optimization.title", descriptionKey: "action.security_optimization.description", category: .system, symbolName: "lock.shield", statusFeatureID: "security_optimization", isRisky: false, estimatedTime: "15 seconds", requiresRestart: false, restoreBehavior: .staticCommands([
            CommandRequest(command: "/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off", requiresAdministrator: true),
            CommandRequest(command: "defaults delete /Library/Preferences/com.apple.alf stealthenabled || true", requiresAdministrator: true),
            CommandRequest(command: "defaults delete /Library/Preferences/com.apple.alf allowsignedenabled || true", requiresAdministrator: true)
        ]), kind: .command([
            CommandRequest(command: "defaults write /Library/Preferences/com.apple.alf globalstate -int 1", requiresAdministrator: true),
            CommandRequest(command: "defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1", requiresAdministrator: true),
            CommandRequest(command: "defaults write /Library/Preferences/com.apple.alf allowsignedenabled -int 1", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "power_optimization", titleKey: "action.power_optimization.title", descriptionKey: "action.power_optimization.description", category: .system, symbolName: "bolt.batteryblock", statusFeatureID: "power_optimization", isRisky: false, estimatedTime: "10-20 seconds", requiresRestart: false, restoreBehavior: .staticCommands([
            CommandRequest(command: "pmset restoredefaults", requiresAdministrator: true)
        ]), kind: .command([
            CommandRequest(command: "pmset -a displaysleep 15", requiresAdministrator: true),
            CommandRequest(command: "pmset -a disksleep 10", requiresAdministrator: true),
            CommandRequest(command: "pmset -a womp 1", requiresAdministrator: true),
            CommandRequest(command: "pmset -a networkoversleep 0", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil)
    ]
}
