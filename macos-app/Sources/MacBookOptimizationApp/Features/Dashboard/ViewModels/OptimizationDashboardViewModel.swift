import Combine
import Foundation
import SwiftUI

enum SidebarDestination: Hashable {
    case category(ActionCategory)
    case dashboard
    case statuses
    case activity
    case logs
    case cpu
    case memory
    case battery
    case mdm
}

@MainActor
final class OptimizationDashboardViewModel: ObservableObject {
    enum ActivityTimeFilter: String, CaseIterable, Identifiable {
        case last5Minutes
        case all
        case lastHour
        case today

        var id: String { rawValue }

        func includes(_ date: Date, now: Date = .now) -> Bool {
            switch self {
            case .last5Minutes:
                return date >= now.addingTimeInterval(-300)
            case .all:
                return true
            case .lastHour:
                return date >= now.addingTimeInterval(-3_600)
            case .today:
                return Calendar.current.isDate(date, inSameDayAs: now)
            }
        }
    }

    private enum ExecutionIntent {
        case run(OptimizationAction)
        case restore(action: OptimizationAction, affectedActionIDs: [String])

        var action: OptimizationAction {
            switch self {
            case .run(let action):
                return action
            case .restore(let action, _):
                return action
            }
        }

        var affectedActionIDs: [String] {
            switch self {
            case .run(let action):
                return [action.id]
            case .restore(_, let affectedActionIDs):
                return affectedActionIDs
            }
        }

        var reviewMode: SystemActionReviewMode {
            switch self {
            case .run:
                return .run
            case .restore:
                return .restore
            }
        }
    }

    @Published var selectedDestination: SidebarDestination = .dashboard
    @Published var actions: [OptimizationAction]
    @Published var machineSummary: MachineSummary?
    @Published var debugOutput = ""
    @Published var debugLogEntries: [DebugLogEntry] = []
    @Published var isRunningActionID: String?
    @Published var pendingSystemActionReview: SystemActionReviewPlan?
    @Published var pendingConfirmationAction: OptimizationAction?
    @Published var presentedActionResult: PresentedActionResult?
    @Published var isShowingSettings = false
    @Published var toasts: [ToastMessage] = []
    @Published var activityFilter: ActivityTimeFilter = .all
    @Published var activityFeed: [ActivityItem] = [
        ActivityItem(
            title: AppLocalizer(language: .english).text(.appReadyTitle),
            message: AppLocalizer(language: .english).text(.appReadyMessage),
            date: .now,
            kind: .info,
            symbolName: "checkmark.circle"
        )
    ]

    private let engine: OptimizationExecuting
    private let stateStore: StateStoreProtocol
    private let restoreBaselineStore: RestoreBaselineStoreProtocol
    private let settings: AppSettingsStore
    private let systemInfoProvider: SystemInfoProviding
    private let commandExecutor: SystemCommandExecuting
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTask: Task<Void, Never>?
    private var pendingConfirmationIntent: ExecutionIntent?
    @Published private var latestQuickPanelStates: [String: QuickPanelState] = [:]

    private var localizer: AppLocalizer {
        AppLocalizer(language: settings.language)
    }

    init(
        engine: (any OptimizationExecuting)? = nil,
        stateStore: StateStoreProtocol = StateStore(),
        restoreBaselineStore: RestoreBaselineStoreProtocol = RestoreBaselineStore(),
        settings: AppSettingsStore = AppSettingsStore(),
        systemInfoProvider: SystemInfoProviding? = nil,
        commandExecutor: SystemCommandExecuting = SystemCommandExecutor()
    ) {
        self.stateStore = stateStore
        self.restoreBaselineStore = restoreBaselineStore
        self.settings = settings
        self.systemInfoProvider = systemInfoProvider ?? SystemInfoProvider(localizer: AppLocalizer(language: settings.language))
        self.commandExecutor = commandExecutor
        self.engine = engine ?? OptimizationEngine(
            commandExecutor: commandExecutor,
            stateStore: stateStore,
            feedbackPresenter: ActionFeedbackPresenter(localizer: AppLocalizer(language: settings.language)),
            localizer: AppLocalizer(language: settings.language)
        )
        self.actions = OptimizationCatalog.actions()
        loadStatusesFromDisk()
        setupBindings()

        Task {
            await loadMachineSummary()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var selectedCategory: ActionCategory {
        switch selectedDestination {
        case .category(let category):
            return category
        default:
            return .system
        }
    }

    var visibleActions: [OptimizationAction] {
        switch selectedDestination {
        case .category(let category):
            return actions.filter { $0.category == category }
        default:
            return []
        }
    }

    var selectedQuickPanelAction: OptimizationAction? {
        let actionID: String?
        switch selectedDestination {
        case .cpu:
            actionID = "system_check_cpu"
        case .memory:
            actionID = "system_check_memory"
        case .battery:
            actionID = "system_check_battery"
        case .mdm:
            actionID = "mdm_status"
        default:
            actionID = nil
        }

        guard let actionID else { return nil }
        return actions.first(where: { $0.id == actionID })
    }

    var filteredActivity: [ActivityItem] {
        activityFeed.filter { activityFilter.includes($0.date) }
    }

    var logsTranscript: String {
        guard !debugLogEntries.isEmpty else {
            return localizer.text(.noOutputYet)
        }

        return debugLogEntries
            .sorted { $0.timestamp < $1.timestamp }
            .map { entry in
                let timestamp = entry.timestamp.formatted(date: .omitted, time: .standard)
                return "# \(timestamp) • \(entry.title)\n\(entry.transcript)"
            }
            .joined(separator: "\n\n")
    }

    var shouldConfirmQuit: Bool {
        isRunningActionID != nil
            || pendingSystemActionReview != nil
            || pendingConfirmationAction != nil
            || presentedActionResult != nil
    }

    func quitConfirmationMessage() -> String {
        if isRunningActionID != nil {
            return localizer.text(.quitConfirmRunningMessage)
        }
        if pendingSystemActionReview != nil {
            return localizer.text(.quitConfirmReviewMessage)
        }
        if pendingConfirmationAction != nil {
            return localizer.text(.quitConfirmPrivilegeMessage)
        }
        if presentedActionResult != nil {
            return localizer.text(.quitConfirmResultMessage)
        }
        return localizer.text(.quitConfirmGenericMessage)
    }

    func quickPanelState(for actionID: String) -> QuickPanelState? {
        latestQuickPanelStates[actionID]
    }

    func latestLogEntry(for actionID: String) -> DebugLogEntry? {
        debugLogEntries.last(where: { $0.actionID == actionID })
    }

    func isActionAvailable(_ action: OptimizationAction) -> Bool {
        action.isSupported(on: machineSummary)
    }

    func unavailableMessage(for action: OptimizationAction) -> String? {
        guard !isActionAvailable(action) else { return nil }

        switch action.availability {
        case .allMacs:
            return localizer.text(.unavailable)
        case .intelOnly:
            return localizer.text(.intelOnlyHint)
        }
    }

    func restoreMessage(for action: OptimizationAction) -> String? {
        guard isActionAvailable(action) else {
            return unavailableMessage(for: action)
        }

        switch action.restoreBehavior {
        case .staticCommands:
            return nil
        case .capturedSysctl:
            if (try? restoreBaselineStore.loadBaseline(for: action.id)) != nil {
                return nil
            }
            return localizer.text(.restoreRunFirstRequired)
        case .notRestorableInspection(let reasonKey), .notRestorableIrreversible(let reasonKey):
            return localizer.string(reasonKey)
        }
    }

    func canRestore(_ action: OptimizationAction) -> Bool {
        restoreMessage(for: action) == nil
    }

    func showDestination(_ destination: SidebarDestination) {
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedDestination = destination
        }
    }

    func openSettings() {
        isShowingSettings = true
    }

    func resetStoredStatuses() {
        do {
            try stateStore.resetStates()
            loadStatusesFromDisk()
            appendActivity(
                title: localizer.text(.statusReset),
                message: localizer.text(.statusResetMessage),
                kind: .success,
                symbolName: "arrow.counterclockwise.circle"
            )
            showPresentedResult(
                PresentedActionResult(
                    kind: .info,
                    title: localizer.text(.panelAllStatuses),
                    message: localizer.text(.statusResetMessage),
                    symbolName: "list.bullet.rectangle",
                    layout: .compact
                )
            )
        } catch {
            debugOutput = error.localizedDescription
            appendActivity(
                title: localizer.text(.statusReset),
                message: localizer.text(.statusResetFailedMessage),
                kind: .failure,
                symbolName: "exclamationmark.triangle"
            )
            showPresentedResult(
                PresentedActionResult(
                    kind: .error,
                    title: localizer.text(.panelAllStatuses),
                    message: localizer.text(.statusResetFailedMessage),
                    symbolName: "exclamationmark.triangle",
                    details: error.localizedDescription,
                    layout: .medium
                )
            )
        }
    }

    func dismissPresentedActionResult() {
        withAnimation(.easeInOut(duration: 0.18)) {
            presentedActionResult = nil
        }
    }

    func dismissToast(id: ToastMessage.ID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            toasts.removeAll { $0.id == id }
        }
    }

    func deleteActivity(id: ActivityItem.ID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            activityFeed.removeAll { $0.id == id }
        }
    }

    func clearAllActivity() {
        withAnimation(.easeInOut(duration: 0.16)) {
            activityFeed.removeAll()
        }
    }

    func run(actionID: String) async {
        guard let action = actions.first(where: { $0.id == actionID }), isRunningActionID == nil else { return }

        guard isActionAvailable(action) else {
            presentUnavailableResult(for: action)
            return
        }

        if let review = SystemActionReviewPlan.build(for: action, localizer: localizer) {
            pendingSystemActionReview = review
            return
        }

        let intent = ExecutionIntent.run(action)
        if settings.confirmPrivilegedActions && (action.isRisky || action.kind.requiresAdministrator) {
            queueConfirmation(intent)
            return
        }

        await execute(intent)
    }

    func restore(actionID: String) {
        guard let action = actions.first(where: { $0.id == actionID }) else { return }
        guard isActionAvailable(action) else {
            presentUnavailableResult(for: action)
            return
        }
        guard let requests = resolveRestoreRequests(for: action) else {
            presentRestoreUnavailableResult(for: action)
            return
        }
        guard let review = SystemActionReviewPlan.buildRestore(for: action, requests: requests, localizer: localizer) else {
            presentRestoreUnavailableResult(for: action)
            return
        }
        pendingSystemActionReview = review
    }

    func restoreSelectedCategory() {
        let category = selectedCategory
        let actionRequests = restoreCandidates(in: category)
        guard !actionRequests.isEmpty else {
            presentNoRestorableActionsResult(title: localizer.format(.restoreCategoryTitle, category.rawValue))
            return
        }
        pendingSystemActionReview = SystemActionReviewPlan.buildRestoreCategory(
            category: category,
            actionRequests: actionRequests,
            localizer: localizer
        )
    }

    func resetAllToDefaults() {
        let actionRequests = restoreCandidates(in: nil)
        guard !actionRequests.isEmpty else {
            presentNoRestorableActionsResult(title: localizer.text(.resetDefaultsAllTitle))
            return
        }
        pendingSystemActionReview = SystemActionReviewPlan.buildRestoreAll(
            actionRequests: actionRequests,
            localizer: localizer
        )
    }

    func confirmPendingAction() {
        guard let intent = pendingConfirmationIntent else { return }
        pendingConfirmationAction = nil
        pendingConfirmationIntent = nil
        Task { await execute(intent) }
    }

    func cancelSystemActionReview() {
        pendingSystemActionReview = nil
    }

    func toggleSystemActionReviewStep(id: SystemActionReviewStep.ID) {
        guard var review = pendingSystemActionReview else { return }
        if review.selectedStepIDs.contains(id) {
            review.selectedStepIDs.remove(id)
        } else {
            review.selectedStepIDs.insert(id)
        }
        pendingSystemActionReview = review
    }

    func selectAllSystemActionReviewSteps() {
        guard var review = pendingSystemActionReview else { return }
        review.selectedStepIDs = Set(review.steps.map(\.id))
        pendingSystemActionReview = review
    }

    func clearSystemActionReviewSteps() {
        guard var review = pendingSystemActionReview else { return }
        review.selectedStepIDs.removeAll()
        pendingSystemActionReview = review
    }

    func confirmSystemActionReview() {
        guard let review = pendingSystemActionReview, review.hasSelection else { return }
        pendingSystemActionReview = nil

        let preparedAction = review.action.replacing(commandRequests: review.selectedRequests)
        let intent: ExecutionIntent
        switch review.mode {
        case .run:
            intent = .run(preparedAction)
        case .restore:
            intent = .restore(action: preparedAction, affectedActionIDs: review.affectedActionIDs)
        }

        if settings.confirmPrivilegedActions && preparedAction.kind.requiresAdministrator {
            queueConfirmation(intent)
            return
        }

        Task { await execute(intent) }
    }

    func cancelPendingAction() {
        guard let action = pendingConfirmationAction else { return }
        appendActivity(
            title: localizer.text(.actionCancelledTitle),
            message: localizer.format(.actionCancelledMessage, localizer.string(action.titleKey)),
            kind: .info,
            symbolName: "xmark.circle"
        )
        pendingConfirmationAction = nil
        pendingConfirmationIntent = nil
    }

    func refreshStatuses() async {
        loadStatusesFromDisk()
        await loadMachineSummary()
        enqueueToast(
            .timed(
                type: .info,
                title: localizer.text(.statusRefreshedTitle),
                message: localizer.text(.statusRefreshedMessage)
            )
        )
        appendActivity(
            title: localizer.text(.statusRefreshedTitle),
            message: localizer.text(.statusRefreshedMessage),
            kind: .info,
            symbolName: "arrow.clockwise.circle"
        )
    }

    private func queueConfirmation(_ intent: ExecutionIntent) {
        pendingConfirmationAction = intent.action
        pendingConfirmationIntent = intent
    }

    private func execute(_ intent: ExecutionIntent) async {
        let action = intent.action
        let previousStatuses = statusSnapshot(for: intent.affectedActionIDs)

        if case .run(let runAction) = intent {
            await captureRestoreBaselineIfNeeded(for: runAction)
        }

        presentedActionResult = nil
        beginRunning(for: intent)
        appendActivity(
            title: intent.reviewMode == .restore ? localizer.text(.restoreActivityTitle) : localizer.text(.runningActionTitle),
            message: intent.reviewMode == .restore
                ? localizer.format(.restoreActivityMessage, localizer.string(action.titleKey))
                : localizer.format(.runningActionMessage, localizer.string(action.titleKey)),
            kind: .info,
            symbolName: intent.reviewMode == .restore ? "arrow.uturn.backward.circle" : "play.circle"
        )

        if action.kind.requiresAdministrator {
            let actionTitle = localizer.string(action.titleKey)
            enqueueToast(
                .timed(
                    type: .info,
                    title: localizer.text(.privilegedPromptToastTitle),
                    message: localizer.format(.privilegedPromptToastMessage, actionTitle),
                    dismissAfter: 5
                )
            )
            appendActivity(
                title: localizer.text(.privilegedPromptTitle),
                message: localizer.format(.privilegedPromptMessage, actionTitle),
                kind: .info,
                symbolName: "key.horizontal"
            )
        }

        do {
            let result = try await engine.execute(action)
            debugOutput = result.output.isEmpty ? localizer.text(.actionCompletedWithoutOutput) : result.output
            recordDebugOutput(
                actionID: originalActionID(for: intent),
                title: localizer.string(action.titleKey),
                symbolName: action.symbolName,
                kind: intent.reviewMode == .restore ? .success : (result.summary == nil ? .success : .info),
                prompt: prompt(for: intent, title: localizer.string(action.titleKey)),
                output: debugOutput
            )

            switch intent {
            case .run(let originalAction):
                finishRunResult(result, for: originalAction)
            case .restore(_, let affectedActionIDs):
                try applyRestoreSuccess(to: affectedActionIDs)
                presentActionResult(
                    result,
                    for: action,
                    message: localizer.text(.restoreCompletedMessage),
                    kind: .success
                )
            }

            appendActivity(event: result.activityEvent)
        } catch {
            debugOutput = error.localizedDescription
            recordDebugOutput(
                actionID: originalActionID(for: intent),
                title: localizer.string(action.titleKey),
                symbolName: action.symbolName,
                kind: .error,
                prompt: prompt(for: intent, title: localizer.string(action.titleKey)),
                output: error.localizedDescription
            )
            handleExecutionError(
                error,
                for: action,
                previousStatuses: previousStatuses,
                reviewMode: intent.reviewMode
            )
            presentExecutionError(error, for: action, reviewMode: intent.reviewMode)
        }
    }

    private func beginRunning(for intent: ExecutionIntent) {
        switch intent {
        case .run(let action):
            updateStatus(for: action.id, to: .running)
        case .restore(let action, let affectedActionIDs):
            if affectedActionIDs.count == 1, let actionID = affectedActionIDs.first {
                updateStatus(for: actionID, to: .running)
            } else {
                isRunningActionID = action.id
            }
        }
    }

    private func finishRunResult(_ result: ActionExecutionResult, for action: OptimizationAction) {
        updateStatus(for: action.id, to: result.status)
        loadStatusesFromDisk()
        if let resultState = makeQuickPanelState(from: result, action: action) {
            latestQuickPanelStates[action.id] = resultState
        }
        presentActionResult(result, for: action)
    }

    private func applyRestoreSuccess(to actionIDs: [String]) throws {
        isRunningActionID = nil
        for actionID in actionIDs {
            if let featureID = actions.first(where: { $0.id == actionID })?.statusFeatureID {
                try stateStore.removeState(featureID: featureID)
            }
        }
        try restoreBaselineStore.removeBaselines(for: actionIDs)
        loadStatusesFromDisk()
        for actionID in actionIDs {
            guard let index = actions.firstIndex(where: { $0.id == actionID }) else { continue }
            actions[index].status = .ready
            actions[index].lastRunDescription = nil
        }
    }

    private func updateStatus(for actionID: String, to newStatus: ActionStatus) {
        isRunningActionID = newStatus == .running ? actionID : nil
        guard let index = actions.firstIndex(where: { $0.id == actionID }) else { return }
        actions[index].status = newStatus
    }

    private func appendActivity(title: String, message: String, kind: ActivityKind, symbolName: String) {
        appendActivity(
            event: ActivityEvent(
                timestamp: .now,
                type: ActivityEventType(kind: kind),
                title: title,
                message: message,
                symbolName: symbolName
            )
        )
    }

    private func appendActivity(event: ActivityEvent) {
        activityFeed.insert(ActivityItem(event: event), at: 0)
        activityFeed = Array(activityFeed.prefix(80))
    }

    private func presentUnavailableResult(for action: OptimizationAction) {
        let actionTitle = localizer.string(action.titleKey)
        let message: String

        switch action.availability {
        case .allMacs:
            message = localizer.text(.unavailable)
        case .intelOnly:
            message = localizer.text(.resultDialogIntelOnlyMessage)
        }

        debugOutput = message
        appendActivity(
            title: localizer.text(.actionUnavailableTitle),
            message: localizer.format(.actionUnavailableIntelOnlyMessage, actionTitle),
            kind: .warning,
            symbolName: "exclamationmark.triangle"
        )
        showPresentedResult(
            PresentedActionResult(
                kind: .warning,
                title: actionTitle,
                message: message,
                symbolName: action.symbolName,
                layout: .compact
            )
        )
        latestQuickPanelStates[action.id] = QuickPanelState(
            title: actionTitle,
            symbolName: action.symbolName,
            details: message,
            resultKind: .warning
        )
    }

    private func presentRestoreUnavailableResult(for action: OptimizationAction) {
        let message = restoreMessage(for: action) ?? localizer.text(.restoreUnavailableMessage)
        appendActivity(
            title: localizer.text(.restoreUnavailableTitle),
            message: message,
            kind: .warning,
            symbolName: "arrow.uturn.backward.circle.badge.exclamationmark"
        )
        showPresentedResult(
            PresentedActionResult(
                kind: .warning,
                title: localizer.format(.restoreActionTitle, localizer.string(action.titleKey)),
                message: message,
                symbolName: action.symbolName,
                layout: .compact
            )
        )
    }

    private func presentNoRestorableActionsResult(title: String) {
        showPresentedResult(
            PresentedActionResult(
                kind: .warning,
                title: title,
                message: localizer.text(.restoreNothingAvailableMessage),
                symbolName: "arrow.uturn.backward.circle",
                layout: .compact
            )
        )
    }

    private func enqueueToast(_ toast: ToastMessage) {
        toasts.insert(toast, at: 0)
        toasts = Array(toasts.prefix(5))
    }

    private func showPresentedResult(_ result: PresentedActionResult) {
        withAnimation(.easeInOut(duration: 0.18)) {
            toasts.removeAll()
            presentedActionResult = result
        }
    }

    private func presentActionResult(
        _ result: ActionExecutionResult,
        for action: OptimizationAction,
        message: String? = nil,
        kind: PresentedActionResultKind? = nil
    ) {
        let details = result.debugLog?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSummary = result.summary != nil
        let resolvedKind: PresentedActionResultKind = kind ?? (hasSummary ? .info : .success)
        let trimmedDetails = details?.isEmpty == true ? nil : details
        let resolvedMessage = message ?? defaultResultMessage(for: action, hasSummary: hasSummary)

        showPresentedResult(
            PresentedActionResult(
                kind: resolvedKind,
                title: localizer.string(action.titleKey),
                message: resolvedMessage,
                symbolName: action.symbolName,
                summary: result.summary,
                details: trimmedDetails,
                layout: layoutStyle(for: action, summary: result.summary, details: trimmedDetails)
            )
        )
    }

    private func defaultResultMessage(for action: OptimizationAction, hasSummary: Bool) -> String {
        switch action.kind {
        case .manual:
            return localizer.text(.resultDialogGuidanceMessage)
        default:
            return hasSummary
                ? localizer.text(.resultDialogInspectionMessage)
                : localizer.text(.resultDialogCompletedMessage)
        }
    }

    private func layoutStyle(
        for action: OptimizationAction,
        summary: ActionResultSummary?,
        details: String?
    ) -> PresentedActionResultLayout {
        let detailLineCount = details?.split(whereSeparator: \.isNewline).count ?? 0

        switch action.kind {
        case .manual:
            return .large
        default:
            break
        }

        if summary != nil {
            return details == nil ? .medium : (detailLineCount >= 8 ? .large : .medium)
        }

        if detailLineCount >= 10 {
            return .large
        }

        if detailLineCount >= 4 {
            return .medium
        }

        return .compact
    }

    private func presentExecutionError(
        _ error: Error,
        for action: OptimizationAction,
        reviewMode: SystemActionReviewMode
    ) {
        let title = localizer.string(action.titleKey)
        let kind: PresentedActionResultKind
        let message: String
        let details: String?

        if let systemError = error as? SystemCommandExecutorError {
            switch systemError {
            case .administratorAuthorizationCancelled:
                kind = .warning
                message = reviewMode == .restore
                    ? localizer.text(.restoreAdministratorCancelledMessage)
                    : localizer.text(.resultDialogAdministratorCancelledMessage)
                details = nil
            case .administratorExecutionFailed(let output):
                kind = .error
                message = reviewMode == .restore
                    ? localizer.text(.restoreFailedMessage)
                    : localizer.text(.resultDialogFailedMessage)
                details = output.trimmingCharacters(in: .whitespacesAndNewlines)
            case .invalidCommand(let command):
                kind = .error
                message = reviewMode == .restore
                    ? localizer.text(.restoreFailedMessage)
                    : localizer.text(.resultDialogFailedMessage)
                details = command.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            kind = .error
            message = reviewMode == .restore
                ? localizer.text(.restoreFailedMessage)
                : localizer.text(.resultDialogFailedMessage)
            details = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let trimmedDetails = details?.isEmpty == true ? nil : details
        showPresentedResult(
            PresentedActionResult(
                kind: kind,
                title: title,
                message: message,
                symbolName: action.symbolName,
                details: trimmedDetails,
                layout: trimmedDetails == nil ? .compact : .medium
            )
        )
        latestQuickPanelStates[action.id] = QuickPanelState(
            title: title,
            symbolName: action.symbolName,
            details: trimmedDetails ?? message,
            resultKind: kind
        )
    }

    private func handleExecutionError(
        _ error: Error,
        for action: OptimizationAction,
        previousStatuses: [String: ActionStatus],
        reviewMode: SystemActionReviewMode
    ) {
        let actionTitle = localizer.string(action.titleKey)

        if let systemError = error as? SystemCommandExecutorError {
            switch systemError {
            case .administratorAuthorizationCancelled:
                restoreStatuses(previousStatuses)
                appendActivity(
                    title: localizer.text(.administratorCancelledTitle),
                    message: reviewMode == .restore
                        ? localizer.format(.restoreAdministratorCancelledDetail, actionTitle)
                        : localizer.format(.administratorCancelledMessage, actionTitle),
                    kind: .warning,
                    symbolName: "xmark.shield"
                )
                return
            case .administratorExecutionFailed:
                restoreStatuses(previousStatuses, failedActionID: action.id)
                appendActivity(
                    title: reviewMode == .restore ? localizer.text(.restoreFailedTitle) : localizer.text(.actionFailedTitle),
                    message: reviewMode == .restore
                        ? localizer.format(.restoreFailedDetail, actionTitle)
                        : localizer.format(.actionFailedAdministratorMessage, actionTitle),
                    kind: .failure,
                    symbolName: "xmark.octagon"
                )
                return
            case .invalidCommand:
                break
            }
        }

        restoreStatuses(previousStatuses, failedActionID: action.id)
        appendActivity(
            title: reviewMode == .restore ? localizer.text(.restoreFailedTitle) : localizer.text(.actionFailedTitle),
            message: reviewMode == .restore
                ? localizer.format(.restoreFailedDetail, actionTitle)
                : localizer.format(.actionFailedMessage, actionTitle),
            kind: .failure,
            symbolName: "xmark.octagon"
        )
    }

    private func loadStatusesFromDisk() {
        do {
            let states = try stateStore.loadStates()
            actions = actions.map { action in
                guard let feature = action.statusFeatureID,
                      let state = states[feature] else {
                    var untouched = action
                    untouched.lastRunDescription = nil
                    if untouched.status != .running {
                        untouched.status = untouched.isRisky ? .needsReview : .ready
                    }
                    return untouched
                }

                var updated = action
                updated.status = state.status == "enabled" ? .enabled : .failed
                updated.lastRunDescription = state.timestamp
                return updated
            }
        } catch {
            debugOutput = error.localizedDescription
            appendActivity(
                title: localizer.text(.statusLoadFailedTitle),
                message: localizer.text(.statusLoadFailedMessage),
                kind: .failure,
                symbolName: "exclamationmark.triangle"
            )
        }
    }

    private func loadMachineSummary() async {
        machineSummary = await systemInfoProvider.machineSummary()
    }

    private func setupBindings() {
        settings.$refreshIntervalMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] minutes in
                self?.configureAutoRefresh(minutes: minutes)
            }
            .store(in: &cancellables)

        configureAutoRefresh(minutes: settings.refreshIntervalMinutes)
    }

    private func configureAutoRefresh(minutes: Int) {
        refreshTask?.cancel()
        guard minutes > 0 else { return }
        let seconds = TimeInterval(minutes * 60)

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self?.refreshStatuses()
            }
        }
    }

    private func captureRestoreBaselineIfNeeded(for action: OptimizationAction) async {
        guard engine is OptimizationEngine else { return }
        guard case .capturedSysctl(let keys, _) = action.restoreBehavior else { return }
        guard (try? restoreBaselineStore.loadBaseline(for: action.id)) == nil else { return }

        var values: [String: String] = [:]
        for key in keys {
            do {
                let result = try await commandExecutor.execute(
                    CommandRequest(command: "sysctl -n \(key)", requiresAdministrator: false)
                )
                let value = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    values[key] = value
                }
            } catch {
                continue
            }
        }

        guard !values.isEmpty else { return }
        try? restoreBaselineStore.saveBaseline(
            RestoreBaseline(capturedAt: .now, values: values),
            for: action.id
        )
    }

    private func resolveRestoreRequests(for action: OptimizationAction) -> [CommandRequest]? {
        switch action.restoreBehavior {
        case .staticCommands(let requests):
            return requests
        case .capturedSysctl(_, let additionalRequests):
            guard let baseline = try? restoreBaselineStore.loadBaseline(for: action.id) else {
                return nil
            }

            let sysctlRequests = baseline.values
                .sorted { $0.key < $1.key }
                .map { key, value in
                    CommandRequest(command: "sysctl -w \(key)=\(value)", requiresAdministrator: true)
                }

            return sysctlRequests + additionalRequests
        case .notRestorableInspection, .notRestorableIrreversible:
            return nil
        }
    }

    private func restoreCandidates(in category: ActionCategory?) -> [(OptimizationAction, [CommandRequest])] {
        let candidateActions = actions.filter { action in
            if let category {
                return action.category == category
            }
            return true
        }

        return candidateActions.compactMap { action in
            guard isActionAvailable(action), let requests = resolveRestoreRequests(for: action) else {
                return nil
            }
            return (action, requests)
        }
    }

    private func restoreStatuses(_ previousStatuses: [String: ActionStatus], failedActionID: String? = nil) {
        isRunningActionID = nil
        for (actionID, status) in previousStatuses {
            if failedActionID == actionID {
                updateStatus(for: actionID, to: .failed)
            } else {
                updateStatus(for: actionID, to: status)
            }
        }
    }

    private func statusSnapshot(for actionIDs: [String]) -> [String: ActionStatus] {
        Dictionary(uniqueKeysWithValues: actionIDs.compactMap { actionID in
            guard let action = actions.first(where: { $0.id == actionID }) else { return nil }
            return (actionID, action.status)
        })
    }

    private func makeQuickPanelState(from result: ActionExecutionResult, action: OptimizationAction) -> QuickPanelState? {
        guard ["system_check_cpu", "system_check_memory", "system_check_battery", "mdm_status"].contains(action.id) else {
            return nil
        }

        return QuickPanelState(
            title: localizer.string(action.titleKey),
            symbolName: action.symbolName,
            summary: result.summary,
            details: result.debugLog,
            resultKind: result.summary == nil ? .success : .info
        )
    }

    private func recordDebugOutput(
        actionID: String?,
        title: String,
        symbolName: String,
        kind: PresentedActionResultKind,
        prompt: String,
        output: String
    ) {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else { return }

        let entry = DebugLogEntry(
            actionID: actionID,
            title: title,
            symbolName: symbolName,
            kind: kind,
            prompt: prompt,
            output: trimmedOutput
        )
        debugLogEntries.append(entry)
        debugLogEntries = Array(debugLogEntries.suffix(120))
    }

    private func prompt(for intent: ExecutionIntent, title: String) -> String {
        switch intent {
        case .run:
            return "run \(title)"
        case .restore:
            return "restore \(title)"
        }
    }

    private func originalActionID(for intent: ExecutionIntent) -> String? {
        switch intent {
        case .run(let action):
            return action.id
        case .restore(_, let actionIDs):
            return actionIDs.count == 1 ? actionIDs.first : nil
        }
    }
}
