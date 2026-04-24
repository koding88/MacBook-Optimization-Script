import Foundation

extension OptimizationCatalog {
    static let monitoringActions: [OptimizationAction] = [
        OptimizationAction(id: "power_saving", titleKey: "action.power_saving.title", descriptionKey: "action.power_saving.description", category: .monitoring, symbolName: "battery.100percent", statusFeatureID: "power_saving", isRisky: false, estimatedTime: "5-10 seconds", requiresRestart: false, restoreBehavior: .staticCommands([
            CommandRequest(command: "pmset restoredefaults", requiresAdministrator: true)
        ]), kind: .dynamic { context in
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
        OptimizationAction(id: "autoboot", titleKey: "action.autoboot.title", descriptionKey: "action.autoboot.description", category: .monitoring, symbolName: "play.square", statusFeatureID: "autoboot", isRisky: true, estimatedTime: "5-10 seconds", requiresRestart: true, availability: .intelOnly, restoreBehavior: .staticCommands([
            CommandRequest(command: "nvram AutoBoot=%03", requiresAdministrator: true),
            CommandRequest(command: "printf 'AutoBoot enabled. Restart required for changes to take effect.\\n'", requiresAdministrator: false),
            CommandRequest(command: "nvram -p | grep 'AutoBoot' || echo 'AutoBoot status not found'", requiresAdministrator: false)
        ]), kind: .dynamic { context in
            let cpuResult = try await context.commandExecutor.execute(
                CommandRequest(command: "sysctl -n machdep.cpu.brand_string", requiresAdministrator: false)
            )
            let isIntel = cpuResult.output.localizedCaseInsensitiveContains("Intel")

            guard isIntel else {
                return [
                    CommandRequest(
                        command: "printf 'AutoBoot toggling is only available on Intel-based Macs.\\n'",
                        requiresAdministrator: false
                    )
                ]
            }

            let currentStatus = try await context.commandExecutor.execute(
                CommandRequest(command: "nvram -p | grep 'AutoBoot' || echo 'AutoBoot status not found'", requiresAdministrator: false)
            )
            let isDisabled = currentStatus.output.contains("%00")

            if isDisabled {
                return [
                    CommandRequest(command: "nvram AutoBoot=%03", requiresAdministrator: true),
                    CommandRequest(command: "printf 'AutoBoot enabled. Restart required for changes to take effect.\\n'", requiresAdministrator: false),
                    CommandRequest(command: "nvram -p | grep 'AutoBoot' || echo 'AutoBoot status not found'", requiresAdministrator: false)
                ]
            }

            return [
                CommandRequest(command: "nvram AutoBoot=%00", requiresAdministrator: true),
                CommandRequest(command: "printf 'AutoBoot disabled. Restart required for changes to take effect.\\n'", requiresAdministrator: false),
                CommandRequest(command: "nvram -p | grep 'AutoBoot' || echo 'AutoBoot status not found'", requiresAdministrator: false)
            ]
        }, status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "system_check_disk", titleKey: "action.system_check_disk.title", descriptionKey: "action.system_check_disk.description", category: .monitoring, symbolName: "internaldrive", statusFeatureID: nil, isRisky: false, estimatedTime: "5 seconds", requiresRestart: false, restoreBehavior: .notRestorableInspection(reasonKey: "restore.reason.inspection"), kind: .command([
            CommandRequest(command: "df -h / | tail -n 1 | awk '{print \"Disk Used: \"$3\" of \"$2\" (\"$5\" used)\"; print \"Disk Available: \"$4; print \"Mount Point: \"$9}'", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "system_check_network", titleKey: "action.system_check_network.title", descriptionKey: "action.system_check_network.description", category: .monitoring, symbolName: "network", statusFeatureID: nil, isRisky: false, estimatedTime: "5-10 seconds", requiresRestart: false, restoreBehavior: .notRestorableInspection(reasonKey: "restore.reason.inspection"), kind: .command([
            CommandRequest(command: "iface=\"$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}')\"; gateway=\"$(route get default 2>/dev/null | awk '/gateway:/{print $2; exit}')\"; if [ -n \"$iface\" ]; then printf 'Active Interface: %s\\n' \"$iface\"; [ -n \"$gateway\" ] && printf 'Gateway: %s\\n' \"$gateway\"; networksetup -listallhardwareports 2>/dev/null | awk -v target=\"$iface\" '$0 ~ /^Hardware Port:/ { port=substr($0, index($0, \":\") + 2) } $0 ~ /^Device:/ && $2 == target { print \"Hardware Port: \" port; exit }'; else printf 'Active Interface: Unavailable\\n'; fi", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "system_check_thermal", titleKey: "action.system_check_thermal.title", descriptionKey: "action.system_check_thermal.description", category: .monitoring, symbolName: "thermometer.medium", statusFeatureID: nil, isRisky: false, estimatedTime: "5-10 seconds", requiresRestart: false, restoreBehavior: .notRestorableInspection(reasonKey: "restore.reason.inspection"), kind: .command([
            CommandRequest(command: "pmset -g therm 2>/dev/null || printf 'Thermal diagnostics are unavailable on this Mac.\\n'", requiresAdministrator: false)
        ]), status: .ready, lastRunDescription: nil)
    ]
}
