import Foundation

extension OptimizationCatalog {
    static let monitoringActions: [OptimizationAction] = [
        OptimizationAction(id: "power_saving", titleKey: "action.power_saving.title", descriptionKey: "action.power_saving.description", category: .monitoring, symbolName: "battery.100percent", statusFeatureID: "power_saving", isRisky: false, estimatedTime: "5-10 seconds", requiresRestart: false, kind: .dynamic { context in
            let result = try await context.commandExecutor.execute(CommandRequest(command: "pmset -g | awk '/lowpowermode/{print $2}'", requiresAdministrator: false))
            let isEnabled = result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
            if isEnabled {
                return [CommandRequest(command: "pmset -a lowpowermode 0", requiresAdministrator: true)]
            }
            return [
                CommandRequest(command: "pmset -a lowpowermode 1", requiresAdministrator: true),
                CommandRequest(command: "pmset -a displaysleep 5", requiresAdministrator: true),
                CommandRequest(command: "pmset -a disksleep 5", requiresAdministrator: true),
                CommandRequest(command: "pmset -a sleep 10", requiresAdministrator: true),
                CommandRequest(command: "pmset -a lessbright 1", requiresAdministrator: true),
                CommandRequest(command: "pmset -a halfdim 1", requiresAdministrator: true)
            ]
        }, status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "autoboot", titleKey: "action.autoboot.title", descriptionKey: "action.autoboot.description", category: .monitoring, symbolName: "play.square", statusFeatureID: "autoboot", isRisky: true, estimatedTime: "5-10 seconds", requiresRestart: true, kind: .command([
            CommandRequest(command: "nvram -p | grep 'AutoBoot' || echo 'AutoBoot status not found'", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "mdm_status", titleKey: "action.mdm_status.title", descriptionKey: "action.mdm_status.description", category: .monitoring, symbolName: "building.2.crop.circle", statusFeatureID: nil, isRisky: false, estimatedTime: "10-20 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "printf 'Checking /etc/hosts for MDM entries...\\n' && grep -E 'deviceenrollment.apple.com|mdmenrollment.apple.com|iprofiles.apple.com' /etc/hosts || true", requiresAdministrator: false),
            CommandRequest(command: "profiles show -type enrollment", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "system_check_cpu", titleKey: "action.system_check_cpu.title", descriptionKey: "action.system_check_cpu.description", category: .monitoring, symbolName: "cpu", statusFeatureID: nil, isRisky: false, estimatedTime: "5 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "printf 'CPU Model: '; sysctl -n machdep.cpu.brand_string", requiresAdministrator: false),
            CommandRequest(command: "printf 'CPU Cores: '; sysctl -n hw.ncpu", requiresAdministrator: false),
            CommandRequest(command: "top -l 1 | awk '/^CPU/ {print}'", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "system_check_memory", titleKey: "action.system_check_memory.title", descriptionKey: "action.system_check_memory.description", category: .monitoring, symbolName: "memorychip.fill", statusFeatureID: nil, isRisky: false, estimatedTime: "5 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "printf 'Total RAM: '; sysctl -n hw.memsize | awk '{print $1 / 1024/1024/1024 \"GB\"}'", requiresAdministrator: false),
            CommandRequest(command: "vm_stat", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "system_check_battery", titleKey: "action.system_check_battery.title", descriptionKey: "action.system_check_battery.description", category: .monitoring, symbolName: "battery.75percent", statusFeatureID: nil, isRisky: false, estimatedTime: "5 seconds", requiresRestart: false, kind: .command([
            CommandRequest(command: "pmset -g batt", requiresAdministrator: false),
            CommandRequest(command: "system_profiler SPPowerDataType | grep -E 'Cycle Count|Condition|Charge Remaining|Charging|Full Charge Capacity|Battery Installed'", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil)
    ]
}
