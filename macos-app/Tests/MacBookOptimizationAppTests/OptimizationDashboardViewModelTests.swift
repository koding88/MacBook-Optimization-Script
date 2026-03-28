import XCTest
@testable import MacBookOptimizationApp

final class OptimizationDashboardViewModelTests: XCTestCase {
    @MainActor
    func testActivityFilterExcludesOldEvents() {
        let model = makeModel(
            result: ActionExecutionResult(
                status: .enabled,
                toast: ToastMessage(type: .success, title: "Done", message: "Action completed."),
                activityEvent: ActivityEvent(
                    type: .success,
                    title: "Done",
                    message: "Action completed.",
                    symbolName: "checkmark.circle"
                )
            )
        )

        model.activityFeed = [
            ActivityItem(
                event: ActivityEvent(
                    timestamp: .now.addingTimeInterval(-60),
                    type: .success,
                    title: "Recent",
                    message: "Visible"
                )
            ),
            ActivityItem(
                event: ActivityEvent(
                    timestamp: .now.addingTimeInterval(-10_000),
                    type: .info,
                    title: "Old",
                    message: "Hidden"
                )
            )
        ]
        model.activityFilter = .last5Minutes

        XCTAssertEqual(model.filteredActivity.count, 1)
        XCTAssertEqual(model.filteredActivity.first?.title, "Recent")
    }

    @MainActor
    func testCompletedInspectionEnqueuesToastWithStructuredSummaryLines() async {
        let toastID = UUID()
        let result = ActionExecutionResult(
            status: .enabled,
            toast: ToastMessage(
                id: toastID,
                type: .success,
                title: "Battery Snapshot",
                message: "Inspection complete",
                summaryLines: ["Battery: 97%", "Charging: Yes", "Cycle Count: 173"],
                dismissAfter: 3
            ),
            activityEvent: ActivityEvent(
                timestamp: .now,
                type: .success,
                title: "Battery Snapshot",
                message: "Battery: 97% • Charging: Yes • Cycle Count: 173"
            ),
            summary: nil,
            debugLog: nil
        )

        let model = makeModel(result: result)
        await model.run(actionID: "system_check_battery")

        XCTAssertEqual(model.toasts.first?.summaryLines.count, 3)
        model.dismissToast(id: toastID)
        XCTAssertTrue(model.toasts.isEmpty)
    }

    @MainActor
    func testRiskyActionShowsPendingConfirmationInsteadOfCancelling() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let model = OptimizationDashboardViewModel(
            engine: MockOptimizationEngine(),
            stateStore: InMemoryStateStore(),
            settings: AppSettingsStore(defaults: defaults),
            systemInfoProvider: MockSystemInfoProvider()
        )

        let action: OptimizationAction = try! XCTUnwrap(model.actions.first(where: { $0.isRisky }))

        await model.run(actionID: action.id)

        XCTAssertEqual(model.pendingConfirmationAction?.id, action.id)
        XCTAssertFalse(model.activityFeed.contains { $0.title == "Action Cancelled" })
    }

    @MainActor
    func testConfirmPendingActionStartsExecutionInsteadOfCancelling() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let toast = ToastMessage(type: .success, title: "Done", message: "Executed")
        let event = ActivityEvent(type: .success, title: "Executed", message: "Ran risky action")
        let model = OptimizationDashboardViewModel(
            engine: MockOptimizationEngine(
                result: ActionExecutionResult(
                    status: .enabled,
                    toast: toast,
                    activityEvent: event
                )
            ),
            stateStore: InMemoryStateStore(),
            settings: AppSettingsStore(defaults: defaults),
            systemInfoProvider: MockSystemInfoProvider()
        )

        let action: OptimizationAction = try! XCTUnwrap(model.actions.first(where: { $0.isRisky }))

        await model.run(actionID: action.id)
        model.confirmPendingAction()

        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(model.pendingConfirmationAction)
        XCTAssertEqual(model.activityFeed.first?.title, "Executed")
        XCTAssertFalse(model.activityFeed.contains { $0.title == "Action Cancelled" })
    }

    @MainActor
    func testPrivilegedActionShowsPasswordPromptGuidanceBeforeExecution() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: "app.confirmPrivilegedActions")

        let model = OptimizationDashboardViewModel(
            engine: MockOptimizationEngine(),
            stateStore: InMemoryStateStore(),
            settings: AppSettingsStore(defaults: defaults),
            systemInfoProvider: MockSystemInfoProvider()
        )

        let action: OptimizationAction = try! XCTUnwrap(
            model.actions.first(where: { $0.kind.requiresAdministratorForTesting })
        )

        await model.run(actionID: action.id)

        XCTAssertTrue(model.toasts.contains { $0.title == "Waiting for Password" })
        XCTAssertTrue(model.activityFeed.contains { $0.title == "Administrator Approval Needed" })
    }

    @MainActor
    func testAdministratorPromptCancellationRestoresPreviousStatusAndShowsWarning() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: "app.confirmPrivilegedActions")

        let model = OptimizationDashboardViewModel(
            engine: MockOptimizationEngine(error: SystemCommandExecutorError.administratorAuthorizationCancelled),
            stateStore: InMemoryStateStore(),
            settings: AppSettingsStore(defaults: defaults),
            systemInfoProvider: MockSystemInfoProvider()
        )

        let action: OptimizationAction = try! XCTUnwrap(
            model.actions.first(where: { $0.kind.requiresAdministratorForTesting })
        )

        await model.run(actionID: action.id)

        let updatedAction = try! XCTUnwrap(model.actions.first(where: { $0.id == action.id }))
        XCTAssertEqual(updatedAction.status, .ready)
        XCTAssertEqual(model.activityFeed.first?.title, "Administrator Prompt Cancelled")
        XCTAssertEqual(model.toasts.first?.type, .warning)
    }

    @MainActor
    func testCompletedActionEnqueuesToastAndFilteredActivityExcludesOlderItems() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: "app.confirmPrivilegedActions")

        let activityEvent = ActivityEvent(
            timestamp: .now,
            type: .success,
            title: "Action Completed",
            message: "Cache cleanup completed successfully.",
            symbolName: "checkmark.circle"
        )
        let toast = ToastMessage(
            type: .success,
            title: "Cleanup Ready",
            message: "Cache cleanup finished.",
            summaryLines: ["42 MB reclaimed"]
        )

        let model = OptimizationDashboardViewModel(
            engine: MockOptimizationEngine(
                result: ActionExecutionResult(
                    status: .enabled,
                    toast: toast,
                    activityEvent: activityEvent,
                    debugLog: "cleanup log"
                )
            ),
            stateStore: InMemoryStateStore(),
            settings: AppSettingsStore(defaults: defaults),
            systemInfoProvider: MockSystemInfoProvider()
        )

        model.activityFeed = [
            ActivityItem(
                event: ActivityEvent(
                    timestamp: Date(timeIntervalSinceNow: -7_200),
                    type: .info,
                    title: "Old Event",
                    message: "Should be filtered out.",
                    symbolName: "clock"
                )
            ),
            ActivityItem(
                event: ActivityEvent(
                    timestamp: Date(timeIntervalSinceNow: -120),
                    type: .info,
                    title: "Recent Event",
                    message: "Should stay visible.",
                    symbolName: "clock.badge.checkmark"
                )
            )
        ]

        let action: OptimizationAction = try! XCTUnwrap(model.actions.first(where: { !$0.isRisky }))

        await model.run(actionID: action.id)

        XCTAssertEqual(model.toasts.first?.title, "Cleanup Ready")
        XCTAssertEqual(model.toasts.first?.message, "Cache cleanup finished.")
        XCTAssertEqual(model.activityFeed.first?.title, "Action Completed")

        model.activityFilter = .lastHour

        XCTAssertTrue(model.filteredActivity.contains { $0.title == "Recent Event" })
        XCTAssertTrue(model.filteredActivity.contains { $0.title == "Action Completed" })
        XCTAssertFalse(model.filteredActivity.contains { $0.title == "Old Event" })
    }
}

@MainActor
private func makeModel(result: ActionExecutionResult) -> OptimizationDashboardViewModel {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    defaults.set(false, forKey: "app.confirmPrivilegedActions")

    return OptimizationDashboardViewModel(
        engine: MockOptimizationEngine(result: result),
        stateStore: InMemoryStateStore(),
        settings: AppSettingsStore(defaults: defaults),
        systemInfoProvider: MockSystemInfoProvider()
    )
}

private struct MockOptimizationEngine: OptimizationExecuting {
    var result: ActionExecutionResult = ActionExecutionResult(
        status: .enabled,
        toast: ToastMessage(type: .success, title: "Done", message: "Action completed."),
        activityEvent: ActivityEvent(
            type: .success,
            title: "Done",
            message: "Action completed.",
            symbolName: "checkmark.circle"
        ),
        debugLog: "mock output"
    )
    var error: Error?

    func execute(_ action: OptimizationAction) async throws -> ActionExecutionResult {
        if let error {
            throw error
        }
        return result
    }
}

private struct MockSystemInfoProvider: SystemInfoProviding {
    func machineSummary() async -> MachineSummary {
        MachineSummary(
            modelName: "MacBook Pro",
            chipName: "Apple M3",
            memory: "18 GB",
            storage: "512 GB",
            systemVersion: "macOS 15.0",
            battery: nil,
            serialNumber: nil
        )
    }
}

private extension ActionKind {
    var requiresAdministratorForTesting: Bool {
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

private final class InMemoryStateStore: StateStoreProtocol {
    private(set) var states: [String: FeatureState] = [:]

    func loadStates() throws -> [String: FeatureState] {
        states
    }

    func updateState(featureID: String, status: ActionStatus, timestamp: Date) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        states[featureID] = FeatureState(
            status: status.rawValue.lowercased(),
            timestamp: formatter.string(from: timestamp)
        )
    }
}
