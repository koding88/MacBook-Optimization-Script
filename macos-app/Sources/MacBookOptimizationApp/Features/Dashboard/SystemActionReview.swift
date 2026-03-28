import Foundation

struct SystemActionReviewStep: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let command: String
    let requiresAdministrator: Bool
    let request: CommandRequest
}

struct SystemActionReviewPlan: Identifiable, Equatable {
    let action: OptimizationAction
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

    static func build(for action: OptimizationAction, localizer: AppLocalizer) -> SystemActionReviewPlan? {
        guard [.system, .network].contains(action.category),
              let requests = action.kind.commandRequests,
              !requests.isEmpty else {
            return nil
        }

        let steps = requests.enumerated().map { index, request in
            let descriptor = descriptor(for: action.id, request: request, stepIndex: index, localizer: localizer)
            return SystemActionReviewStep(
                id: "\(action.id)-\(index)",
                title: descriptor.title,
                detail: descriptor.detail,
                command: request.command,
                requiresAdministrator: request.requiresAdministrator,
                request: request
            )
        }

        return SystemActionReviewPlan(
            action: action,
            steps: steps,
            selectedStepIDs: Set(steps.map(\.id))
        )
    }

    private static func descriptor(
        for actionID: String,
        request: CommandRequest,
        stepIndex: Int,
        localizer: AppLocalizer
    ) -> (title: String, detail: String) {
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
        default:
            return (
                title: localizer.format(.systemReviewStepFallbackTitle, stepIndex + 1),
                detail: localizer.text(.systemReviewStepFallbackDetail)
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

    private static func localized(_ baseKey: String, localizer: AppLocalizer) -> (String, String) {
        (
            localizer.string("\(baseKey).title"),
            localizer.string("\(baseKey).detail")
        )
    }
}
