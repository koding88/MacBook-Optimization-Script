import Foundation

enum ActionCategory: String, CaseIterable, Identifiable {
    case system = "System"
    case network = "Network"
    case storage = "Storage"
    case performance = "Performance"
    case maintenance = "Maintenance"
    case monitoring = "Monitoring"

    var id: String { rawValue }

    var localizedKey: LocalizedKey {
        switch self {
        case .system: .categorySystem
        case .network: .categoryNetwork
        case .storage: .categoryStorage
        case .performance: .categoryPerformance
        case .maintenance: .categoryMaintenance
        case .monitoring: .categoryMonitoring
        }
    }

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

enum ActionAvailability: Hashable {
    case allMacs
    case intelOnly

    func isSupported(on machineSummary: MachineSummary?) -> Bool {
        switch self {
        case .allMacs:
            return true
        case .intelOnly:
            return machineSummary?.isIntelMac == true
        }
    }
}

enum ActionRestoreBehavior: Hashable {
    case staticCommands([CommandRequest])
    case capturedSysctl(keys: [String], additionalRequests: [CommandRequest] = [])
    case notRestorableInspection(reasonKey: String)
    case notRestorableIrreversible(reasonKey: String)

    var isRestorable: Bool {
        switch self {
        case .staticCommands, .capturedSysctl:
            return true
        case .notRestorableInspection, .notRestorableIrreversible:
            return false
        }
    }
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
    let availability: ActionAvailability
    let restoreBehavior: ActionRestoreBehavior
    let kind: ActionKind
    var status: ActionStatus
    var lastRunDescription: String?

    init(
        id: String,
        titleKey: String,
        descriptionKey: String,
        category: ActionCategory,
        symbolName: String,
        statusFeatureID: String?,
        isRisky: Bool,
        estimatedTime: String,
        requiresRestart: Bool,
        availability: ActionAvailability = .allMacs,
        restoreBehavior: ActionRestoreBehavior = .notRestorableInspection(reasonKey: "restore.reason.inspection"),
        kind: ActionKind,
        status: ActionStatus,
        lastRunDescription: String? = nil
    ) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.category = category
        self.symbolName = symbolName
        self.statusFeatureID = statusFeatureID
        self.isRisky = isRisky
        self.estimatedTime = estimatedTime
        self.requiresRestart = requiresRestart
        self.availability = availability
        self.restoreBehavior = restoreBehavior
        self.kind = kind
        self.status = status
        self.lastRunDescription = lastRunDescription
    }

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
            availability: availability,
            restoreBehavior: restoreBehavior,
            kind: .command(commandRequests),
            status: status,
            lastRunDescription: lastRunDescription
        )
    }

    func isSupported(on machineSummary: MachineSummary?) -> Bool {
        availability.isSupported(on: machineSummary)
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

    var defaultDismissAfter: TimeInterval {
        switch self {
        case .info, .success:
            return 3
        case .warning:
            return 5
        case .error:
            return 7
        }
    }
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

    static func timed(
        id: UUID = UUID(),
        type: ToastType,
        title: String,
        message: String,
        summaryLines: [String] = [],
        timestamp: Date = .now,
        dismissAfter: TimeInterval? = nil
    ) -> ToastMessage {
        ToastMessage(
            id: id,
            type: type,
            title: title,
            message: message,
            summaryLines: summaryLines,
            timestamp: timestamp,
            dismissAfter: dismissAfter ?? type.defaultDismissAfter
        )
    }
}

struct DebugLogEntry: Identifiable, Equatable {
    let id: UUID
    let actionID: String?
    let title: String
    let symbolName: String
    let kind: PresentedActionResultKind
    let prompt: String
    let output: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        actionID: String? = nil,
        title: String,
        symbolName: String,
        kind: PresentedActionResultKind,
        prompt: String,
        output: String,
        timestamp: Date = .now
    ) {
        self.id = id
        self.actionID = actionID
        self.title = title
        self.symbolName = symbolName
        self.kind = kind
        self.prompt = prompt
        self.output = output
        self.timestamp = timestamp
    }

    var transcript: String {
        let promptLine = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let outputBody = output.trimmingCharacters(in: .whitespacesAndNewlines)

        if outputBody.isEmpty {
            return "$ \(promptLine)"
        }

        return "$ \(promptLine)\n\(outputBody)"
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

enum PresentedActionResultKind: Equatable {
    case success
    case info
    case warning
    case error
}

enum PresentedActionResultLayout: Equatable {
    case compact
    case medium
    case large
}

struct PresentedActionResult: Identifiable, Equatable {
    let id: UUID
    let kind: PresentedActionResultKind
    let title: String
    let message: String
    let symbolName: String
    let summary: ActionResultSummary?
    let details: String?
    let layout: PresentedActionResultLayout

    init(
        id: UUID = UUID(),
        kind: PresentedActionResultKind,
        title: String,
        message: String,
        symbolName: String,
        summary: ActionResultSummary? = nil,
        details: String? = nil,
        layout: PresentedActionResultLayout = .medium
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.message = message
        self.symbolName = symbolName
        self.summary = summary
        self.details = details
        self.layout = layout
    }
}

struct QuickPanelState: Equatable {
    let title: String
    let symbolName: String
    let summary: ActionResultSummary?
    let details: String?
    let resultKind: PresentedActionResultKind

    init(
        title: String,
        symbolName: String,
        summary: ActionResultSummary? = nil,
        details: String? = nil,
        resultKind: PresentedActionResultKind = .info
    ) {
        self.title = title
        self.symbolName = symbolName
        self.summary = summary
        self.details = details
        self.resultKind = resultKind
    }
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
