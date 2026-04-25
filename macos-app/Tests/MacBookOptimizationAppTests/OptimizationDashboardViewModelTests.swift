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
    func testCompletedInspectionPresentsResultWithoutDuplicateToast() async {
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
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(model.toasts.isEmpty)
        XCTAssertNil(model.pendingSystemActionReview)
        XCTAssertEqual(model.presentedActionResult?.title, "Battery Snapshot")
        XCTAssertEqual(model.presentedActionResult?.message, "Follow the guidance below to complete this action safely.")
    }

    @MainActor
    func testCompletedActionPresentsResultSheetImmediately() async {
        let result = ActionExecutionResult(
            status: .enabled,
            toast: ToastMessage(type: .success, title: "CPU Snapshot", message: "Inspection complete"),
            activityEvent: ActivityEvent(
                timestamp: .now,
                type: .success,
                title: "CPU Snapshot",
                message: "Apple M2 Pro • CPU Cores: 12 • CPU Usage: 11%",
                symbolName: "cpu"
            ),
            summary: ActionResultSummary(
                primaryValue: "Apple M2 Pro",
                secondaryValues: [
                    .init(labelKey: .snapshotCPUCores, value: "12"),
                    .init(labelKey: .snapshotCPUUsage, value: "11%")
                ]
            ),
            debugLog: "CPU Model: Apple M2 Pro"
        )

        let model = makeModel(result: result)
        await model.run(actionID: "system_check_cpu")
        model.confirmSystemActionReview()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(model.presentedActionResult?.title, "CPU Snapshot")
        XCTAssertEqual(model.presentedActionResult?.summary?.primaryValue, "Apple M2 Pro")
        XCTAssertEqual(model.presentedActionResult?.details, "CPU Model: Apple M2 Pro")
    }

    @MainActor
    func testQuickPanelStateAndLogsStayBoundToOriginalInspectionAction() async {
        let result = ActionExecutionResult(
            status: .enabled,
            toast: ToastMessage(type: .info, title: "Check MDM Status", message: "Inspection complete"),
            activityEvent: ActivityEvent(
                timestamp: .now,
                type: .info,
                title: "Check MDM Status",
                message: "MDM inspection completed.",
                symbolName: "building.2.crop.circle"
            ),
            summary: ActionResultSummary(
                primaryValue: "Not enrolled",
                secondaryValues: [
                    .init(labelKey: .snapshotMDMHostsAdvisory, value: "No host overrides detected")
                ]
            ),
            debugLog: "MDM Enrollment Status:\nMDM enrollment: No"
        )

        let model = makeModel(result: result)
        await model.run(actionID: "mdm_status")
        model.confirmSystemActionReview()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(model.quickPanelState(for: "mdm_status")?.summary?.primaryValue, "Not enrolled")
        XCTAssertEqual(model.latestLogEntry(for: "mdm_status")?.output, "MDM Enrollment Status:\nMDM enrollment: No")
        XCTAssertNil(model.quickPanelState(for: "system_check_battery"))
        XCTAssertNil(model.latestLogEntry(for: "system_check_battery"))
    }

    @MainActor
    func testRiskyActionShowsStepReviewBeforeConfirmation() async {
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

        XCTAssertEqual(model.pendingSystemActionReview?.action.id, action.id)
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
    func testAdditionalReviewCategoriesShowStepReviewBeforeExecution() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(false, forKey: "app.confirmPrivilegedActions")

        let actionIDs = ["cache_clear", "dashboard", "disk_permissions", "system_check_cpu"]

        for actionID in actionIDs {
            let engine = RecordingOptimizationEngine()
            let model = OptimizationDashboardViewModel(
                engine: engine,
                stateStore: InMemoryStateStore(),
                settings: AppSettingsStore(defaults: defaults),
                systemInfoProvider: MockSystemInfoProvider()
            )

            await model.run(actionID: actionID)

            XCTAssertEqual(model.pendingSystemActionReview?.action.id, actionID)
            XCTAssertNil(engine.lastAction)
        }
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
        model.confirmSystemActionReview()
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

        XCTAssertTrue(model.activityFeed.contains { $0.title == "Administrator Approval Needed" })
        XCTAssertTrue(model.toasts.isEmpty)
        XCTAssertEqual(model.presentedActionResult?.kind, .success)
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
        XCTAssertTrue(model.toasts.isEmpty)
        XCTAssertEqual(model.presentedActionResult?.kind, .warning)
    }

    @MainActor
    func testAutoBootIsBlockedOnAppleSilicon() async {
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

        model.machineSummary = await MockSystemInfoProvider().machineSummary()
        let action = try! XCTUnwrap(model.actions.first(where: { $0.id == "autoboot" }))

        XCTAssertFalse(model.isActionAvailable(action))
        XCTAssertEqual(model.unavailableMessage(for: action), "This action is unavailable on Apple Silicon Macs.")

        await model.run(actionID: "autoboot")

        XCTAssertNil(engine.lastAction)
        XCTAssertNil(model.pendingConfirmationAction)
        XCTAssertEqual(model.presentedActionResult?.kind, .warning)
        XCTAssertEqual(model.presentedActionResult?.message, "This action is only available on Intel-based Macs.")
        XCTAssertTrue(model.toasts.isEmpty)
    }

    @MainActor
    func testCompletedActionPresentsResultAndFilteredActivityExcludesOlderItems() async {
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
        model.confirmSystemActionReview()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(model.toasts.isEmpty)
        XCTAssertEqual(model.activityFeed.first?.title, "Action Completed")
        XCTAssertEqual(model.presentedActionResult?.title, "Disable Dashboard")

        model.activityFilter = .lastHour

        XCTAssertTrue(model.filteredActivity.contains { $0.title == "Recent Event" })
        XCTAssertTrue(model.filteredActivity.contains { $0.title == "Action Completed" })
        XCTAssertFalse(model.filteredActivity.contains { $0.title == "Old Event" })
    }

    @MainActor
    func testResetStoredStatusesClearsTrackedStatesAndShowsFeedback() throws {
        let stateStore = InMemoryStateStore()
        try stateStore.updateState(featureID: "dns_flush", status: .enabled, timestamp: .now)

        let model = OptimizationDashboardViewModel(
            engine: MockOptimizationEngine(),
            stateStore: stateStore,
            settings: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            systemInfoProvider: MockSystemInfoProvider()
        )

        model.resetStoredStatuses()

        XCTAssertTrue(try stateStore.loadStates().isEmpty)
        XCTAssertEqual(model.presentedActionResult?.title, "All Statuses")
        XCTAssertTrue(model.toasts.isEmpty)
        XCTAssertEqual(model.presentedActionResult?.layout, .compact)
    }

    @MainActor
    func testPresentingResultClearsTransientToasts() throws {
        let stateStore = InMemoryStateStore()
        let model = OptimizationDashboardViewModel(
            engine: MockOptimizationEngine(),
            stateStore: stateStore,
            settings: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            systemInfoProvider: MockSystemInfoProvider()
        )

        model.toasts = [
            .timed(type: .info, title: "Pending", message: "Waiting")
        ]

        model.resetStoredStatuses()

        XCTAssertTrue(model.toasts.isEmpty)
        XCTAssertEqual(model.presentedActionResult?.kind, .info)
    }

    @MainActor
    func testManualGuidanceUsesLargeResultLayoutAndGuidanceCopy() async {
        let result = ActionExecutionResult(
            status: .enabled,
            toast: .timed(type: .success, title: "Reset SMC Guidance", message: "Ready"),
            activityEvent: ActivityEvent(
                timestamp: .now,
                type: .success,
                title: "Reset SMC Guidance",
                message: "Manual guidance available."
            ),
            debugLog: """
            Reset SMC Instructions
            1. Shut down your MacBook.
            2. Hold Shift + Control + Option and the power button.
            3. Release all keys and wait.
            4. Power the MacBook back on.
            """
        )

        let model = makeModel(result: result)
        await model.run(actionID: "smc_reset")
        model.confirmSystemActionReview()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(model.presentedActionResult?.message, "Follow the guidance below to complete this action safely.")
        XCTAssertEqual(model.presentedActionResult?.layout, .large)
    }

    @MainActor
    func testCapturedRestoreRequiresBaselineUntilActionHasRun() throws {
        let baselineStore = InMemoryRestoreBaselineStore()
        let model = OptimizationDashboardViewModel(
            engine: MockOptimizationEngine(),
            stateStore: InMemoryStateStore(),
            restoreBaselineStore: baselineStore,
            settings: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            systemInfoProvider: MockSystemInfoProvider()
        )

        let action = try XCTUnwrap(model.actions.first(where: { $0.id == "system_performance" }))
        XCTAssertEqual(
            model.restoreMessage(for: action),
            "Restore becomes available after this action captures the original machine settings once."
        )

        try baselineStore.saveBaseline(
            RestoreBaseline(capturedAt: .now, values: ["kern.maxproc": "1064"]),
            for: action.id
        )

        XCTAssertNil(model.restoreMessage(for: action))
    }

    @MainActor
    func testResetAllToDefaultsBuildsRestoreReviewFromEligibleActionsOnly() throws {
        let baselineStore = InMemoryRestoreBaselineStore()
        try baselineStore.saveBaseline(
            RestoreBaseline(capturedAt: .now, values: ["kern.maxproc": "1064"]),
            for: "system_performance"
        )
        try baselineStore.saveBaseline(
            RestoreBaseline(capturedAt: .now, values: ["net.inet.tcp.blackhole": "0"]),
            for: "network_optimization"
        )

        let model = OptimizationDashboardViewModel(
            engine: MockOptimizationEngine(),
            stateStore: InMemoryStateStore(),
            restoreBaselineStore: baselineStore,
            settings: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            systemInfoProvider: MockSystemInfoProvider()
        )

        model.resetAllToDefaults()

        let review = try XCTUnwrap(model.pendingSystemActionReview)
        XCTAssertEqual(review.mode, .restore)
        XCTAssertTrue(review.affectedActionIDs.contains("system_performance"))
        XCTAssertTrue(review.affectedActionIDs.contains("network_optimization"))
        XCTAssertFalse(review.affectedActionIDs.contains("cache_clear"))
        XCTAssertFalse(review.affectedActionIDs.contains("smc_reset"))
    }

    @MainActor
    func testActivityDeletionRemovesSingleEntryAndClearAllRemovesEverything() {
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
            ActivityItem(title: "One", message: "First", date: .now, kind: .info, symbolName: "1.circle"),
            ActivityItem(title: "Two", message: "Second", date: .now, kind: .info, symbolName: "2.circle")
        ]

        let firstID = model.activityFeed[0].id
        model.deleteActivity(id: firstID)
        XCTAssertEqual(model.activityFeed.count, 1)
        XCTAssertEqual(model.activityFeed.first?.title, "Two")

        model.clearAllActivity()
        XCTAssertTrue(model.activityFeed.isEmpty)
    }

    @MainActor
    func testMachineSummaryLoadsAsynchronouslyFromNilInitialState() async {
        let provider = DelayedMockSystemInfoProvider()
        let model = OptimizationDashboardViewModel(
            engine: MockOptimizationEngine(),
            stateStore: InMemoryStateStore(),
            settings: AppSettingsStore(defaults: UserDefaults(suiteName: #function)!),
            systemInfoProvider: provider
        )

        XCTAssertNil(model.machineSummary)

        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(model.machineSummary?.chipName, "Apple M3")
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

private struct DelayedMockSystemInfoProvider: SystemInfoProviding {
    func machineSummary() async -> MachineSummary {
        try? await Task.sleep(nanoseconds: 40_000_000)
        return await MockSystemInfoProvider().machineSummary()
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

    func removeState(featureID: String) throws {
        states[featureID] = nil
    }

    func resetStates() throws {
        states.removeAll()
    }
}

private final class InMemoryRestoreBaselineStore: RestoreBaselineStoreProtocol {
    private var baselines: [String: RestoreBaseline] = [:]

    func loadBaseline(for actionID: String) throws -> RestoreBaseline? {
        baselines[actionID]
    }

    func saveBaseline(_ baseline: RestoreBaseline, for actionID: String) throws {
        baselines[actionID] = baseline
    }

    func removeBaseline(for actionID: String) throws {
        baselines[actionID] = nil
    }

    func removeBaselines(for actionIDs: [String]) throws {
        for actionID in actionIDs {
            baselines[actionID] = nil
        }
    }
}
