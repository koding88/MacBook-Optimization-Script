import Foundation

enum ActionCategory: String, CaseIterable, Identifiable {
    case system = "System"
    case network = "Network"
    case storage = "Storage"
    case performance = "Performance"
    case maintenance = "Maintenance"
    case monitoring = "Monitoring"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .system: "cpu"
        case .network: "network"
        case .storage: "internaldrive"
        case .performance: "speedometer"
        case .maintenance: "wrench.and.screwdriver"
        case .monitoring: "waveform.path.ecg"
        }
    }
}

enum ActionStatus: String {
    case ready = "Ready"
    case running = "Running"
    case enabled = "Enabled"
    case failed = "Failed"
    case needsReview = "Needs Review"

    var badgeLabel: String { rawValue.uppercased() }
}

enum ActionKind {
    case command([CommandRequest])
    case dynamic((SystemContext) async throws -> [CommandRequest])
    case manual(String)
    case statuses
}

struct OptimizationAction: Identifiable, Hashable {
    let id: String
    let titleKey: String
    let descriptionKey: String
    let category: ActionCategory
    let symbolName: String
    let statusFeatureID: String?
    let isRisky: Bool
    let estimatedTime: String
    let requiresRestart: Bool
    let kind: ActionKind
    var status: ActionStatus
    var lastRunDescription: String?

    static func == (lhs: OptimizationAction, rhs: OptimizationAction) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func replacing(commandRequests: [CommandRequest]) -> OptimizationAction {
        OptimizationAction(
            id: id,
            titleKey: titleKey,
            descriptionKey: descriptionKey,
            category: category,
            symbolName: symbolName,
            statusFeatureID: statusFeatureID,
            isRisky: isRisky,
            estimatedTime: estimatedTime,
            requiresRestart: requiresRestart,
            kind: .command(commandRequests),
            status: status,
            lastRunDescription: lastRunDescription
        )
    }
}

struct FeatureState {
    let status: String
    let timestamp: String
}

enum AppPane: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case allStatuses = "All Statuses"
    case cpu = "CPU Snapshot"
    case memory = "Memory Snapshot"
    case battery = "Battery Snapshot"
    case mdm = "MDM Status"

    var id: String { rawValue }
}

struct CommandRequest: Hashable {
    let command: String
    let requiresAdministrator: Bool
}

struct CommandExecutionResult {
    let output: String
    let exitCode: Int32
}

enum ToastType: String, Equatable {
    case info
    case success
    case warning
    case error
}

struct ToastMessage: Identifiable, Equatable {
    let id: UUID
    let type: ToastType
    let title: String
    let message: String
    let summaryLines: [String]
    let timestamp: Date
    let dismissAfter: TimeInterval?

    init(
        id: UUID = UUID(),
        type: ToastType,
        title: String,
        message: String,
        summaryLines: [String] = [],
        timestamp: Date = .now,
        dismissAfter: TimeInterval? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.summaryLines = summaryLines
        self.timestamp = timestamp
        self.dismissAfter = dismissAfter
    }
}

struct ActionResultSummary: Equatable {
    struct LineItem: Equatable {
        let labelKey: LocalizedKey
        let value: String
    }

    let primaryValue: String
    let secondaryValues: [LineItem]
}

struct ActionExecutionResult {
    let status: ActionStatus
    let toast: ToastMessage
    let activityEvent: ActivityEvent
    let summary: ActionResultSummary?
    let debugLog: String?
    let output: String

    init(
        status: ActionStatus,
        toast: ToastMessage,
        activityEvent: ActivityEvent,
        summary: ActionResultSummary? = nil,
        debugLog: String? = nil
    ) {
        self.status = status
        self.toast = toast
        self.activityEvent = activityEvent
        self.summary = summary
        self.debugLog = debugLog
        self.output = debugLog ?? ""
    }

    init(output: String, status: ActionStatus) {
        let title = status.badgeLabel
        let message = output.isEmpty ? "Action completed." : output
        let toastType: ToastType = status == .failed ? .error : .info
        let activityType: ActivityEventType = status == .failed ? .error : .info

        self.status = status
        self.toast = ToastMessage(
            type: toastType,
            title: title,
            message: message
        )
        self.activityEvent = ActivityEvent(
            type: activityType,
            title: title,
            message: message
        )
        self.summary = nil
        self.debugLog = output
        self.output = output
    }
}

struct SystemContext {
    let commandExecutor: SystemCommandExecuting
    let stateStore: StateStoreProtocol
}

extension ActionKind {
    var requiresAdministrator: Bool {
        switch self {
        case .command(let commands):
            return commands.contains(where: \.requiresAdministrator)
        case .dynamic:
            return true
        case .manual, .statuses:
            return false
        }
    }

    var commandRequests: [CommandRequest]? {
        guard case .command(let commands) = self else { return nil }
        return commands
    }
}
