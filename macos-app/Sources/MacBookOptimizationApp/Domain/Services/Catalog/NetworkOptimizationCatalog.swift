import Foundation

extension OptimizationCatalog {
    static let networkActions: [OptimizationAction] = [
        OptimizationAction(id: "network_optimization", titleKey: "action.network_optimization.title", descriptionKey: "action.network_optimization.description", category: .network, symbolName: "network", statusFeatureID: "network_optimization", isRisky: true, estimatedTime: "20-40 seconds", requiresRestart: false, restoreBehavior: .capturedSysctl(keys: [
            "net.inet.tcp.delayed_ack",
            "net.inet.tcp.mssdflt",
            "net.inet.tcp.blackhole",
            "net.inet.icmp.icmplim",
            "net.inet.tcp.path_mtu_discovery",
            "net.inet.tcp.tcp_keepalive"
        ]), kind: .command([
            CommandRequest(command: "sysctl -w net.inet.tcp.delayed_ack=0", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w net.inet.tcp.mssdflt=1440", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w net.inet.tcp.blackhole=2", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w net.inet.icmp.icmplim=50", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w net.inet.tcp.path_mtu_discovery=1", requiresAdministrator: true),
            CommandRequest(command: "sysctl -w net.inet.tcp.tcp_keepalive=1", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "dns_flush", titleKey: "action.dns_flush.title", descriptionKey: "action.dns_flush.description", category: .network, symbolName: "arrow.clockwise.icloud", statusFeatureID: "dns_flush", isRisky: false, estimatedTime: "5-10 seconds", requiresRestart: false, restoreBehavior: .notRestorableInspection(reasonKey: "restore.reason.oneShot"), kind: .command([
            CommandRequest(command: "dscacheutil -flushcache", requiresAdministrator: true),
            CommandRequest(command: "killall -HUP mDNSResponder", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil),
        OptimizationAction(id: "firewall", titleKey: "action.firewall.title", descriptionKey: "action.firewall.description", category: .network, symbolName: "shield.lefthalf.filled", statusFeatureID: "firewall", isRisky: false, estimatedTime: "5-10 seconds", requiresRestart: false, restoreBehavior: .staticCommands([
            CommandRequest(command: "/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off", requiresAdministrator: true)
        ]), kind: .command([
            CommandRequest(command: "/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on", requiresAdministrator: true)
        ]), status: .ready, lastRunDescription: nil)
    ]
}
