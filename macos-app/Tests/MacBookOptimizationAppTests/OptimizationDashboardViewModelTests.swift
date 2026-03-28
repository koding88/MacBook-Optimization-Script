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

        let action: OptimizationAction = try! XCTUnwrap(model.actions.first(where: { $0.id == "spotlight" }))

        await model.run(actionID: action.id)

        XCTAssertEqual(model.pendingConfirmationAction?.id, action.id)
        XCTAssertFalse(model.activityFeed.contains { $0.title == "Action Cancelled" })
    }

    @MainActor
    func testSystemActionShowsStepReviewBeforeExecution() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: "app.confirmPrivilegedActions")

        let engine = RecordingOptimizationEngine()
        let model = OptimizationDashboardViewModel(
            engine: engine,
            stateStore: InMemoryStateStore(),
            settings: AppSettingsStore(defaults: defaults),
            systemInfoProvider: MockSystemInfoProvider()
        )

        await model.run(actionID: "system_performance")

        XCTAssertEqual(model.pendingSystemActionReview?.action.id, "system_performance")
        XCTAssertEqual(model.pendingSystemActionReview?.selectedCount, model.pendingSystemActionReview?.steps.count)
        XCTAssertNil(engine.lastAction)
    }

    @MainActor
    func testNetworkActionShowsStepReviewBeforeExecution() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: "app.confirmPrivilegedActions")

        let engine = RecordingOptimizationEngine()
        let model = OptimizationDashboardViewModel(
            engine: engine,
            stateStore: InMemoryStateStore(),
            settings: AppSettingsStore(defaults: defaults),
            systemInfoProvider: MockSystemInfoProvider()
        )

        await model.run(actionID: "network_optimization")

        XCTAssertEqual(model.pendingSystemActionReview?.action.id, "network_optimization")
        XCTAssertEqual(model.pendingSystemActionReview?.selectedCount, model.pendingSystemActionReview?.steps.count)
        XCTAssertNil(engine.lastAction)
    }

    @MainActor
    func testSystemActionReviewUsesCurrentAppLanguage() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: "app.confirmPrivilegedActions")
        defaults.set("vi", forKey: "app.language")

        let model = OptimizationDashboardViewModel(
            engine: RecordingOptimizationEngine(),
            stateStore: InMemoryStateStore(),
            settings: AppSettingsStore(defaults: defaults),
            systemInfoProvider: MockSystemInfoProvider()
        )

        await model.run(actionID: "system_performance")

        XCTAssertEqual(model.pendingSystemActionReview?.steps.first?.title, "Tăng hàng đợi kết nối")
    }

    @MainActor
    func testConfirmSystemActionReviewRunsOnlySelectedSteps() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: "app.confirmPrivilegedActions")

        let engine = RecordingOptimizationEngine()
        let model = OptimizationDashboardViewModel(
            engine: engine,
            stateStore: InMemoryStateStore(),
            settings: AppSettingsStore(defaults: defaults),
            systemInfoProvider: MockSystemInfoProvider()
        )

        await model.run(actionID: "system_performance")
        let review = try! XCTUnwrap(model.pendingSystemActionReview)
        let stepToDisable = review.steps[1].id

        model.toggleSystemActionReviewStep(id: stepToDisable)
        model.confirmSystemActionReview()

        try? await Task.sleep(nanoseconds: 50_000_000)

        let executed = try! XCTUnwrap(engine.lastAction)
        let requests = try! XCTUnwrap(executed.kind.commandRequests)
        XCTAssertEqual(requests.count, review.steps.count - 1)
        XCTAssertFalse(requests.contains(review.steps[1].request))
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

        let action: OptimizationAction = try! XCTUnwrap(model.actions.first(where: { $0.id == "spotlight" }))

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

        let action: OptimizationAction = try! XCTUnwrap(model.actions.first(where: { $0.id == "dns_flush" }))

        await model.run(actionID: action.id)
        model.confirmSystemActionReview()
        try? await Task.sleep(nanoseconds: 50_000_000)

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

        let action: OptimizationAction = try! XCTUnwrap(model.actions.first(where: { $0.id == "dns_flush" }))

        await model.run(actionID: action.id)
        model.confirmSystemActionReview()
        try? await Task.sleep(nanoseconds: 50_000_000)

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

        let action: OptimizationAction = try! XCTUnwrap(model.actions.first(where: { $0.id == "dashboard" }))

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

@MainActor
private final class RecordingOptimizationEngine: OptimizationExecuting {
    var lastAction: OptimizationAction?

    func execute(_ action: OptimizationAction) async throws -> ActionExecutionResult {
        lastAction = action
        return ActionExecutionResult(
            status: .enabled,
            toast: ToastMessage(type: .success, title: "Done", message: "Action completed."),
            activityEvent: ActivityEvent(
                type: .success,
                title: "Done",
                message: "Action completed.",
                symbolName: "checkmark.circle"
            ),
            debugLog: "recorded"
        )
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
