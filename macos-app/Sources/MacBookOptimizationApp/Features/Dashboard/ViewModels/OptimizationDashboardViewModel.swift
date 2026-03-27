import Foundation
import SwiftUI
import Combine

enum SidebarDestination: Hashable {
    case category(ActionCategory)
    case dashboard
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

        var title: String {
            switch self {
            case .last5Minutes:
                return AppLocalizer(language: .english).text(.activityFilterLast5Minutes)
            case .all:
                return AppLocalizer(language: .english).text(.activityFilterAll)
            case .lastHour:
                return AppLocalizer(language: .english).text(.activityFilterLastHour)
            case .today:
                return AppLocalizer(language: .english).text(.activityFilterToday)
            }
        }

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

    @Published var selectedDestination: SidebarDestination = .dashboard
    @Published var actions: [OptimizationAction]
    @Published var machineSummary: MachineSummary?
    @Published var debugOutput = ""
    @Published var isRunningActionID: String?
    @Published var pendingConfirmationAction: OptimizationAction?
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
    private let settings: AppSettingsStore
    private let systemInfoProvider: SystemInfoProviding
    private let localizer: AppLocalizer
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTask: Task<Void, Never>?

    init(
        engine: OptimizationExecuting = OptimizationEngine(
            commandExecutor: SystemCommandExecutor(),
            stateStore: StateStore()
        ),
        stateStore: StateStoreProtocol = StateStore(),
        settings: AppSettingsStore = AppSettingsStore(),
        systemInfoProvider: SystemInfoProviding = SystemInfoProvider()
    ) {
        self.engine = engine
        self.stateStore = stateStore
        self.settings = settings
        self.systemInfoProvider = systemInfoProvider
        self.localizer = AppLocalizer(language: settings.language)
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
        case .cpu:
            return actions.filter { $0.id == "system_check_cpu" }
        case .memory:
            return actions.filter { $0.id == "system_check_memory" }
        case .battery:
            return actions.filter { $0.id == "system_check_battery" }
        case .mdm:
            return actions.filter { $0.id == "mdm_status" }
        default:
            return []
        }
    }

    var filteredActivity: [ActivityItem] {
        activityFeed.filter { activityFilter.includes($0.date) }
    }

    func showCategory(_ category: ActionCategory) {
        selectedDestination = .category(category)
    }

    func showDestination(_ destination: SidebarDestination) {
        selectedDestination = destination
    }

    func openSettings() {
        isShowingSettings = true
    }

    func dismissToast(id: ToastMessage.ID) {
        toasts.removeAll { $0.id == id }
    }

    func run(actionID: String) async {
        guard let action = actions.first(where: { $0.id == actionID }), isRunningActionID == nil else { return }

        if settings.confirmPrivilegedActions && (action.isRisky || action.kind.requiresAdministrator) {
            pendingConfirmationAction = action
            return
        }

        await run(action)
    }

    func confirmPendingAction() async {
        guard let action = pendingConfirmationAction else { return }
        pendingConfirmationAction = nil
        await run(action)
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
    }

    func refreshStatuses() async {
        loadStatusesFromDisk()
        await loadMachineSummary()
        appendActivity(
            title: localizer.text(.statusRefreshedTitle),
            message: localizer.text(.statusRefreshedMessage),
            kind: .info,
            symbolName: "arrow.clockwise.circle"
        )
    }

    private func run(_ action: OptimizationAction) async {
        updateStatus(for: action.id, to: .running)
        appendActivity(
            title: localizer.text(.runningActionTitle),
            message: localizer.format(.runningActionMessage, localizer.string(action.titleKey)),
            kind: .info,
            symbolName: "play.circle"
        )

        do {
            let result = try await engine.execute(action)
            debugOutput = result.output.isEmpty ? localizer.text(.actionCompletedWithoutOutput) : result.output
            updateStatus(for: action.id, to: result.status)
            loadStatusesFromDisk()
            enqueueToast(result.toast)
            appendActivity(event: result.activityEvent)
        } catch {
            debugOutput = error.localizedDescription
            updateStatus(for: action.id, to: .failed)
            appendActivity(
                title: localizer.text(.actionFailedTitle),
                message: localizer.format(.actionFailedMessage, localizer.string(action.titleKey)),
                kind: .failure,
                symbolName: "xmark.octagon"
            )
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
        activityFeed = Array(activityFeed.prefix(40))
    }

    private func enqueueToast(_ toast: ToastMessage) {
        toasts.insert(toast, at: 0)
        toasts = Array(toasts.prefix(5))
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
}

private extension ActionKind {
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
}
