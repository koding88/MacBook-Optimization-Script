import Foundation

enum SystemActionReviewMode: Equatable {
    case run
    case restore
}

struct SystemActionReviewStep: Identifiable, Equatable {
    let id: String
    let actionID: String
    let title: String
    let detail: String
    let command: String
    let requiresAdministrator: Bool
    let request: CommandRequest
}

struct SystemActionReviewPlan: Identifiable, Equatable {
    let mode: SystemActionReviewMode
    let action: OptimizationAction
    let affectedActionIDs: [String]
    let steps: [SystemActionReviewStep]
    var selectedStepIDs: Set<SystemActionReviewStep.ID>

    var id: String { action.id }

    var selectedRequests: [CommandRequest] {
        steps
            .filter { selectedStepIDs.contains($0.id) }
            .map(\.request)
    }

    var selectedCount: Int {
        selectedStepIDs.count
    }

    var hasSelection: Bool {
        !selectedStepIDs.isEmpty
    }

    var runButtonTitleKey: LocalizedKey {
        switch mode {
        case .run:
            return .systemReviewRunSelected
        case .restore:
            return .restoreRunSelected
        }
    }

    static func build(for action: OptimizationAction, localizer: AppLocalizer) -> SystemActionReviewPlan? {
        guard [.system, .network, .storage, .performance, .maintenance, .monitoring].contains(action.category),
              let requests = action.kind.commandRequests,
              !requests.isEmpty else {
            return nil
        }

        let steps = requests.enumerated().map { index, request in
            let descriptor = descriptor(for: action.id, request: request, stepIndex: index, localizer: localizer, mode: .run)
            return SystemActionReviewStep(
                id: "\(action.id)-\(index)",
                actionID: action.id,
                title: descriptor.title,
                detail: descriptor.detail,
                command: request.command,
                requiresAdministrator: request.requiresAdministrator,
                request: request
            )
        }

        return SystemActionReviewPlan(
            mode: .run,
            action: action,
            affectedActionIDs: [action.id],
            steps: steps,
            selectedStepIDs: Set(steps.map(\.id))
        )
    }

    static func buildRestore(
        for action: OptimizationAction,
        requests: [CommandRequest],
        localizer: AppLocalizer
    ) -> SystemActionReviewPlan? {
        buildRestorePlan(
            action: syntheticRestoreAction(
                id: "restore-\(action.id)",
                title: localizer.format(.restoreActionTitle, localizer.string(action.titleKey)),
                symbolName: action.symbolName,
                category: action.category,
                requests: requests
            ),
            affectedActionIDs: [action.id],
            requests: requests,
            localizer: localizer
        )
    }

    static func buildRestoreCategory(
        category: ActionCategory,
        actionRequests: [(OptimizationAction, [CommandRequest])],
        localizer: AppLocalizer
    ) -> SystemActionReviewPlan? {
        let requests = actionRequests.flatMap { action, requests in
            requests.map { (action, $0) }
        }
        guard !requests.isEmpty else { return nil }

        let action = syntheticRestoreAction(
            id: "restore-category-\(category.rawValue)",
            title: localizer.format(.restoreCategoryTitle, category.rawValue),
            symbolName: category.symbolName,
            category: category,
            requests: requests.map(\.1)
        )

        return buildRestorePlan(
            action: action,
            affectedActionIDs: actionRequests.map(\.0.id),
            actionRequests: requests,
            localizer: localizer
        )
    }

    static func buildRestoreAll(
        actionRequests: [(OptimizationAction, [CommandRequest])],
        localizer: AppLocalizer
    ) -> SystemActionReviewPlan? {
        let requests = actionRequests.flatMap { action, requests in
            requests.map { (action, $0) }
        }
        guard !requests.isEmpty else { return nil }

        let action = syntheticRestoreAction(
            id: "restore-all-defaults",
            title: localizer.text(.resetDefaultsAllTitle),
            symbolName: "arrow.uturn.backward.circle",
            category: .system,
            requests: requests.map(\.1)
        )

        return buildRestorePlan(
            action: action,
            affectedActionIDs: actionRequests.map(\.0.id),
            actionRequests: requests,
            localizer: localizer
        )
    }

    private static func descriptor(
        for actionID: String,
        request: CommandRequest,
        stepIndex: Int,
        localizer: AppLocalizer,
        mode: SystemActionReviewMode
    ) -> (title: String, detail: String) {
        if mode == .restore {
            return restoreDescriptor(for: request.command, stepIndex: stepIndex, localizer: localizer)
        }

        switch actionID {
        case "system_performance":
            return systemPerformanceDescriptor(for: request.command, localizer: localizer)
        case "memory_management":
            return memoryManagementDescriptor(for: request.command, localizer: localizer)
        case "ssd_optimization":
            return ssdDescriptor(for: request.command, localizer: localizer)
        case "security_optimization":
            return securityDescriptor(for: request.command, localizer: localizer)
        case "power_optimization":
            return powerDescriptor(for: request.command, localizer: localizer)
        case "network_optimization":
            return networkOptimizationDescriptor(for: request.command, localizer: localizer)
        case "dns_flush":
            return dnsFlushDescriptor(for: request.command, localizer: localizer)
        case "firewall":
            return firewallDescriptor(for: request.command, localizer: localizer)
        case "cache_clear":
            return cacheClearDescriptor(for: request.command, localizer: localizer)
        case "language_cleanup":
            return languageCleanupDescriptor(for: request.command, localizer: localizer)
        case "font_cache":
            return fontCacheDescriptor(for: request.command, localizer: localizer)
        case "ds_store_cleanup":
            return dsStoreCleanupDescriptor(for: request.command, localizer: localizer)
        case "spotlight":
            return spotlightDescriptor(for: request.command, localizer: localizer)
        case "dashboard":
            return dashboardDescriptor(for: request.command, localizer: localizer)
        case "animations":
            return animationsDescriptor(for: request.command, localizer: localizer)
        case "dock_optimization":
            return dockOptimizationDescriptor(for: request.command, localizer: localizer)
        case "disk_permissions":
            return diskPermissionsDescriptor(for: request.command, localizer: localizer)
        case "maintenance_scripts":
            return maintenanceScriptsDescriptor(for: request.command, localizer: localizer)
        case "log_cleanup":
            return logCleanupDescriptor(for: request.command, localizer: localizer)
        case "autoboot":
            return autobootDescriptor(for: request.command, localizer: localizer)
        case "mdm_status":
            return mdmStatusDescriptor(for: request.command, localizer: localizer)
        case "system_check_cpu":
            return cpuSnapshotDescriptor(for: request.command, localizer: localizer)
        case "system_check_memory":
            return memorySnapshotDescriptor(for: request.command, localizer: localizer)
        case "system_check_battery":
            return batterySnapshotDescriptor(for: request.command, localizer: localizer)
        case "system_check_gpu":
            return gpuSnapshotDescriptor(for: request.command, localizer: localizer)
        case "system_check_disk":
            return diskSnapshotDescriptor(for: request.command, localizer: localizer)
        case "system_check_network":
            return networkSnapshotDescriptor(for: request.command, localizer: localizer)
        case "system_check_thermal":
            return thermalSnapshotDescriptor(for: request.command, localizer: localizer)
        default:
            return (
                title: localizer.format(.systemReviewStepFallbackTitle, stepIndex + 1),
                detail: localizer.text(.systemReviewStepFallbackDetail)
            )
        }
    }

    private static func buildRestorePlan(
        action: OptimizationAction,
        affectedActionIDs: [String],
        requests: [CommandRequest],
        localizer: AppLocalizer
    ) -> SystemActionReviewPlan? {
        buildRestorePlan(
            action: action,
            affectedActionIDs: affectedActionIDs,
            actionRequests: requests.map { (action, $0) },
            localizer: localizer
        )
    }

    private static func buildRestorePlan(
        action: OptimizationAction,
        affectedActionIDs: [String],
        actionRequests: [(OptimizationAction, CommandRequest)],
        localizer: AppLocalizer
    ) -> SystemActionReviewPlan? {
        guard !actionRequests.isEmpty else { return nil }

        let steps = actionRequests.enumerated().map { index, payload in
            let sourceAction = payload.0
            let request = payload.1
            let descriptor = descriptor(
                for: sourceAction.id,
                request: request,
                stepIndex: index,
                localizer: localizer,
                mode: .restore
            )

            return SystemActionReviewStep(
                id: "restore-\(sourceAction.id)-\(index)",
                actionID: sourceAction.id,
                title: descriptor.title,
                detail: descriptor.detail,
                command: request.command,
                requiresAdministrator: request.requiresAdministrator,
                request: request
            )
        }

        return SystemActionReviewPlan(
            mode: .restore,
            action: action,
            affectedActionIDs: affectedActionIDs,
            steps: steps,
            selectedStepIDs: Set(steps.map(\.id))
        )
    }

    private static func syntheticRestoreAction(
        id: String,
        title: String,
        symbolName: String,
        category: ActionCategory,
        requests: [CommandRequest]
    ) -> OptimizationAction {
        OptimizationAction(
            id: id,
            titleKey: title,
            descriptionKey: title,
            category: category,
            symbolName: symbolName,
            statusFeatureID: nil,
            isRisky: false,
            estimatedTime: "Default",
            requiresRestart: false,
            restoreBehavior: .notRestorableInspection(reasonKey: "restore.reason.inspection"),
            kind: .command(requests),
            status: .ready
        )
    }

    private static func restoreDescriptor(for command: String, stepIndex: Int, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case let command where command.hasPrefix("sysctl -w "):
            let key = command
                .replacingOccurrences(of: "sysctl -w ", with: "")
                .split(separator: "=")
                .first
                .map(String.init) ?? "setting"
            return (
                title: localizer.format(.restoreSettingTitle, key),
                detail: localizer.text(.restoreSettingDetail)
            )
        case "pmset restoredefaults":
            return (
                title: localizer.text(.restorePowerDefaultsTitle),
                detail: localizer.text(.restorePowerDefaultsDetail)
            )
        case let command where command.hasPrefix("defaults delete "):
            return (
                title: localizer.text(.restorePreferenceOverrideTitle),
                detail: localizer.text(.restorePreferenceOverrideDetail)
            )
        case "/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off":
            return (
                title: localizer.text(.restoreFirewallTitle),
                detail: localizer.text(.restoreFirewallDetail)
            )
        case "mdutil -a -i on":
            return (
                title: localizer.text(.restoreSpotlightTitle),
                detail: localizer.text(.restoreSpotlightDetail)
            )
        case "trimforce disable":
            return (
                title: localizer.text(.restoreTrimTitle),
                detail: localizer.text(.restoreTrimDetail)
            )
        case "nvram AutoBoot=%03":
            return (
                title: localizer.text(.restoreAutoBootTitle),
                detail: localizer.text(.restoreAutoBootDetail)
            )
        case "killall Dock":
            return (
                title: localizer.text(.restoreReloadDockTitle),
                detail: localizer.text(.restoreReloadDockDetail)
            )
        default:
            return (
                title: localizer.format(.restoreStepFallbackTitle, stepIndex + 1),
                detail: localizer.text(.restoreStepFallbackDetail)
            )
        }
    }

    private static func systemPerformanceDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "sysctl -w kern.ipc.somaxconn=2048":
            return localized("system.review.systemPerformance.socketBacklog", localizer: localizer)
        case "sysctl -w kern.ipc.nmbclusters=65536":
            return localized("system.review.systemPerformance.networkBufferPool", localizer: localizer)
        case "sysctl -w kern.maxvnodes=750000":
            return localized("system.review.systemPerformance.vnodeCacheLimit", localizer: localizer)
        case "sysctl -w kern.maxproc=2048":
            return localized("system.review.systemPerformance.processCeiling", localizer: localizer)
        case "sysctl -w kern.maxfiles=200000":
            return localized("system.review.systemPerformance.openFileLimit", localizer: localizer)
        case "sysctl -w kern.maxfilesperproc=100000":
            return localized("system.review.systemPerformance.perProcessFileLimit", localizer: localizer)
        default:
            return localized("system.review.systemPerformance.fallback", localizer: localizer)
        }
    }

    private static func memoryManagementDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "purge":
            return localized("system.review.memoryManagement.purgeInactiveMemory", localizer: localizer)
        case "pmset -a sms 0":
            return localized("system.review.memoryManagement.disableSuddenMotionSensor", localizer: localizer)
        case "sysctl -w kern.maxvnodes=750000":
            return localized("system.review.memoryManagement.vnodeCacheLimit", localizer: localizer)
        case "sysctl -w kern.maxproc=2048":
            return localized("system.review.memoryManagement.processCeiling", localizer: localizer)
        case "sysctl -w kern.maxfiles=200000":
            return localized("system.review.memoryManagement.openFileLimit", localizer: localizer)
        case "sysctl -w kern.maxfilesperproc=100000":
            return localized("system.review.memoryManagement.perProcessFileLimit", localizer: localizer)
        case "sync":
            return localized("system.review.memoryManagement.flushFilesystemBuffers", localizer: localizer)
        default:
            return localized("system.review.memoryManagement.fallback", localizer: localizer)
        }
    }

    private static func ssdDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "trimforce enable":
            return localized("system.review.ssdOptimization.enableTrim", localizer: localizer)
        case "pmset -a hibernatemode 0":
            return localized("system.review.ssdOptimization.disableHibernateImage", localizer: localizer)
        case "rm -f /var/vm/sleepimage":
            return localized("system.review.ssdOptimization.removeSleepImage", localizer: localizer)
        default:
            return localized("system.review.ssdOptimization.fallback", localizer: localizer)
        }
    }

    private static func securityDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "defaults write /Library/Preferences/com.apple.alf globalstate -int 1":
            return localized("system.review.securityOptimization.enableFirewall", localizer: localizer)
        case "defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1":
            return localized("system.review.securityOptimization.enableStealthMode", localizer: localizer)
        case "defaults write /Library/Preferences/com.apple.alf allowsignedenabled -int 1":
            return localized("system.review.securityOptimization.allowSignedSoftware", localizer: localizer)
        default:
            return localized("system.review.securityOptimization.fallback", localizer: localizer)
        }
    }

    private static func powerDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "pmset -a displaysleep 15":
            return localized("system.review.powerOptimization.displaySleep", localizer: localizer)
        case "pmset -a disksleep 10":
            return localized("system.review.powerOptimization.diskSleep", localizer: localizer)
        case "pmset -a womp 1":
            return localized("system.review.powerOptimization.wakeOnLan", localizer: localizer)
        case "pmset -a networkoversleep 0":
            return localized("system.review.powerOptimization.disableNetworkOverSleep", localizer: localizer)
        default:
            return localized("system.review.powerOptimization.fallback", localizer: localizer)
        }
    }

    private static func networkOptimizationDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "sysctl -w net.inet.tcp.delayed_ack=0":
            return localized("system.review.networkOptimization.delayedAck", localizer: localizer)
        case "sysctl -w net.inet.tcp.mssdflt=1440":
            return localized("system.review.networkOptimization.defaultMss", localizer: localizer)
        case "sysctl -w net.inet.tcp.blackhole=2":
            return localized("system.review.networkOptimization.tcpBlackhole", localizer: localizer)
        case "sysctl -w net.inet.icmp.icmplim=50":
            return localized("system.review.networkOptimization.icmpRateLimit", localizer: localizer)
        case "sysctl -w net.inet.tcp.path_mtu_discovery=1":
            return localized("system.review.networkOptimization.pathMtuDiscovery", localizer: localizer)
        case "sysctl -w net.inet.tcp.tcp_keepalive=1":
            return localized("system.review.networkOptimization.keepalive", localizer: localizer)
        default:
            return localized("system.review.networkOptimization.fallback", localizer: localizer)
        }
    }

    private static func dnsFlushDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "dscacheutil -flushcache":
            return localized("system.review.dnsFlush.flushDirectoryCache", localizer: localizer)
        case "killall -HUP mDNSResponder":
            return localized("system.review.dnsFlush.restartMdnsResponder", localizer: localizer)
        default:
            return localized("system.review.dnsFlush.fallback", localizer: localizer)
        }
    }

    private static func firewallDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on":
            return localized("system.review.firewall.enableFirewall", localizer: localizer)
        default:
            return localized("system.review.firewall.fallback", localizer: localizer)
        }
    }

    private static func cacheClearDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "rm -rf ~/Library/Caches/*":
            return localized("system.review.storage.cacheClear.userCaches", localizer: localizer)
        case "rm -rf /Library/Caches/*":
            return localized("system.review.storage.cacheClear.sharedCaches", localizer: localizer)
        default:
            return localized("system.review.storage.cacheClear.fallback", localizer: localizer)
        }
    }

    private static func languageCleanupDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "rm -rf '/System/Library/CoreServices/Language Chooser.app'":
            return localized("system.review.storage.languageCleanup.removeChooser", localizer: localizer)
        default:
            return localized("system.review.storage.languageCleanup.fallback", localizer: localizer)
        }
    }

    private static func fontCacheDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "atsutil databases -remove":
            return localized("system.review.storage.fontCache.removeDatabases", localizer: localizer)
        case "atsutil server -shutdown":
            return localized("system.review.storage.fontCache.shutdownServer", localizer: localizer)
        case "atsutil server -ping":
            return localized("system.review.storage.fontCache.pingServer", localizer: localizer)
        default:
            return localized("system.review.storage.fontCache.fallback", localizer: localizer)
        }
    }

    private static func dsStoreCleanupDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "find \"$HOME\" -name '.DS_Store' -delete":
            return localized("system.review.storage.dsStoreCleanup.deleteFiles", localizer: localizer)
        default:
            return localized("system.review.storage.dsStoreCleanup.fallback", localizer: localizer)
        }
    }

    private static func spotlightDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "mdutil -a -i off":
            return localized("system.review.performance.spotlight.disableIndexing", localizer: localizer)
        default:
            return localized("system.review.performance.spotlight.fallback", localizer: localizer)
        }
    }

    private static func dashboardDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "defaults write com.apple.dashboard mcx-disabled -boolean YES":
            return localized("system.review.performance.dashboard.disableLegacyDashboard", localizer: localizer)
        case "killall Dock":
            return localized("system.review.performance.dashboard.restartDock", localizer: localizer)
        default:
            return localized("system.review.performance.dashboard.fallback", localizer: localizer)
        }
    }

    private static func animationsDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false":
            return localized("system.review.performance.animations.disableWindowAnimations", localizer: localizer)
        case "defaults write NSGlobalDomain NSWindowResizeTime -float 0.001":
            return localized("system.review.performance.animations.reduceResizeTime", localizer: localizer)
        case "defaults write com.apple.dock launchanim -bool false":
            return localized("system.review.performance.animations.disableDockLaunchAnimation", localizer: localizer)
        case "killall Dock":
            return localized("system.review.performance.animations.restartDock", localizer: localizer)
        default:
            return localized("system.review.performance.animations.fallback", localizer: localizer)
        }
    }

    private static func dockOptimizationDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "defaults write com.apple.dock launchanim -bool false":
            return localized("system.review.performance.dock.disableLaunchAnimation", localizer: localizer)
        case "defaults write com.apple.dock expose-animation-duration -float 0":
            return localized("system.review.performance.dock.speedExpose", localizer: localizer)
        case "defaults write com.apple.dock springboard-show-duration -int 0":
            return localized("system.review.performance.dock.speedLaunchpadOpen", localizer: localizer)
        case "defaults write com.apple.dock springboard-hide-duration -int 0":
            return localized("system.review.performance.dock.speedLaunchpadClose", localizer: localizer)
        case "killall Dock":
            return localized("system.review.performance.dock.restartDock", localizer: localizer)
        default:
            return localized("system.review.performance.dock.fallback", localizer: localizer)
        }
    }

    private static func diskPermissionsDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "diskutil verifyVolume /":
            return localized("system.review.maintenance.diskPermissions.verifyRootVolume", localizer: localizer)
        default:
            return localized("system.review.maintenance.diskPermissions.fallback", localizer: localizer)
        }
    }

    private static func maintenanceScriptsDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "periodic daily weekly monthly":
            return localized("system.review.maintenance.maintenanceScripts.runPeriodicScripts", localizer: localizer)
        default:
            return localized("system.review.maintenance.maintenanceScripts.fallback", localizer: localizer)
        }
    }

    private static func logCleanupDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "rm -rf /var/log/*":
            return localized("system.review.maintenance.logCleanup.removeLogs", localizer: localizer)
        default:
            return localized("system.review.maintenance.logCleanup.fallback", localizer: localizer)
        }
    }

    private static func autobootDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "nvram -p | grep 'AutoBoot' || echo 'AutoBoot status not found'":
            return localized("system.review.monitoring.autoboot.inspectNvram", localizer: localizer)
        default:
            return localized("system.review.monitoring.autoboot.fallback", localizer: localizer)
        }
    }

    private static func mdmStatusDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "printf 'Historical local traces:\\n'; if [ -f /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled ]; then printf 'DEP trace files: Present\\n'; else printf 'DEP trace files: Absent\\n'; fi; if [ -f /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound ] || [ -f /var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord ] || [ -f /var/db/ConfigurationProfiles/Settings/com.apple.mdm.depnag.plist ]; then printf 'Historical MDM traces: Present\\n'; else printf 'Historical MDM traces: Absent\\n'; fi":
            return localized("system.review.monitoring.mdmStatus.readProfiles", localizer: localizer)
        case "printf '\\nHosts advisory entries:\\n' && (grep -E '^0\\.0\\.0\\.0[[:space:]]+(deviceenrollment\\.apple\\.com|mdmenrollment\\.apple\\.com|iprofiles\\.apple\\.com)([[:space:]]|$)' /etc/hosts || printf 'No MDM-related host overrides found.\\n')":
            return localized("system.review.monitoring.mdmStatus.inspectHosts", localizer: localizer)
        case "tmp_backup=$(mktemp /tmp/mbo-hosts-backup.XXXXXX); tmp_filtered=$(mktemp /tmp/mbo-hosts-filtered.XXXXXX); cp /etc/hosts \"$tmp_backup\"; awk '!($1==\"0.0.0.0\" && ($2==\"deviceenrollment.apple.com\" || $2==\"mdmenrollment.apple.com\" || $2==\"iprofiles.apple.com\"))' /etc/hosts > \"$tmp_filtered\"; restore_hosts() { cat \"$tmp_backup\" > /etc/hosts; dscacheutil -flushcache; killall -HUP mDNSResponder >/dev/null 2>&1 || true; rm -f \"$tmp_backup\" \"$tmp_filtered\"; }; trap restore_hosts EXIT INT TERM HUP; cat \"$tmp_filtered\" > /etc/hosts; dscacheutil -flushcache; killall -HUP mDNSResponder >/dev/null 2>&1 || true; printf '\\nProfiles enrollment readout (temporary hosts bypass disabled):\\n'; printf '\\nprofiles status -type enrollment:\\n'; profiles status -type enrollment 2>/dev/null || printf 'Unavailable.\\n'; printf '\\nprofiles show -type enrollment:\\n'; profiles show -type enrollment 2>/dev/null || printf 'Unavailable.\\n'; printf '\\nprofiles list:\\n'; profiles list 2>/dev/null || printf 'Unavailable.\\n'; printf '\\nprofiles show -type configuration:\\n'; profiles show -type configuration 2>/dev/null || printf 'Unavailable.\\n'":
            return localized("system.review.monitoring.mdmStatus.rawProfiles", localizer: localizer)
        default:
            return localized("system.review.monitoring.mdmStatus.fallback", localizer: localizer)
        }
    }

    private static func cpuSnapshotDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "printf 'CPU Model: '; sysctl -n machdep.cpu.brand_string":
            return localized("system.review.monitoring.cpu.model", localizer: localizer)
        case "printf 'CPU Cores: '; sysctl -n hw.ncpu":
            return localized("system.review.monitoring.cpu.cores", localizer: localizer)
        case "top -l 1 | awk '/^CPU/ {print}'":
            return localized("system.review.monitoring.cpu.liveUsage", localizer: localizer)
        default:
            return localized("system.review.monitoring.cpu.fallback", localizer: localizer)
        }
    }

    private static func memorySnapshotDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "printf 'Total RAM: '; sysctl -n hw.memsize | awk '{print $1 / 1024/1024/1024 \"GB\"}'":
            return localized("system.review.monitoring.memory.totalRam", localizer: localizer)
        case "vm_stat":
            return localized("system.review.monitoring.memory.vmStat", localizer: localizer)
        default:
            return localized("system.review.monitoring.memory.fallback", localizer: localizer)
        }
    }

    private static func batterySnapshotDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "pmset -g batt":
            return localized("system.review.monitoring.battery.batteryStatus", localizer: localizer)
        case "system_profiler SPPowerDataType | grep -E 'Cycle Count|Condition|Charge Remaining|Charging|Full Charge Capacity|Battery Installed'":
            return localized("system.review.monitoring.battery.healthDetails", localizer: localizer)
        default:
            return localized("system.review.monitoring.battery.fallback", localizer: localizer)
        }
    }

    private static func gpuSnapshotDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "system_profiler SPDisplaysDataType | awk -F': ' '/Chipset Model/{print \"GPU Model: \"$2} /Metal Support/{print \"Metal Support: \"$2; exit}'":
            return localized("system.review.monitoring.gpu.displayProfile", localizer: localizer)
        default:
            return localized("system.review.monitoring.gpu.fallback", localizer: localizer)
        }
    }

    private static func diskSnapshotDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "df -h / | tail -n 1 | awk '{print \"Disk Used: \"$3\" of \"$2\" (\"$5\" used)\"; print \"Disk Available: \"$4; print \"Mount Point: \"$9}'":
            return localized("system.review.monitoring.disk.rootVolume", localizer: localizer)
        default:
            return localized("system.review.monitoring.disk.fallback", localizer: localizer)
        }
    }

    private static func networkSnapshotDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "iface=\"$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}')\"; gateway=\"$(route get default 2>/dev/null | awk '/gateway:/{print $2; exit}')\"; if [ -n \"$iface\" ]; then printf 'Active Interface: %s\\n' \"$iface\"; [ -n \"$gateway\" ] && printf 'Gateway: %s\\n' \"$gateway\"; networksetup -listallhardwareports 2>/dev/null | awk -v target=\"$iface\" '$0 ~ /^Hardware Port:/ { port=substr($0, index($0, \":\") + 2) } $0 ~ /^Device:/ && $2 == target { print \"Hardware Port: \" port; exit }'; else printf 'Active Interface: Unavailable\\n'; fi":
            return localized("system.review.monitoring.network.defaultRoute", localizer: localizer)
        default:
            return localized("system.review.monitoring.network.fallback", localizer: localizer)
        }
    }

    private static func thermalSnapshotDescriptor(for command: String, localizer: AppLocalizer) -> (String, String) {
        switch command {
        case "pmset -g therm 2>/dev/null || printf 'Thermal diagnostics are unavailable on this Mac.\\n'":
            return localized("system.review.monitoring.thermal.pressureSnapshot", localizer: localizer)
        default:
            return localized("system.review.monitoring.thermal.fallback", localizer: localizer)
        }
    }

    private static func localized(_ baseKey: String, localizer: AppLocalizer) -> (String, String) {
        (
            localizer.string("\(baseKey).title"),
            localizer.string("\(baseKey).detail")
        )
    }
}
