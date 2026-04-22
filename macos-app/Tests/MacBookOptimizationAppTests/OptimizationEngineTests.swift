import XCTest
@testable import MacBookOptimizationApp

final class OptimizationEngineTests: XCTestCase {
    func testMutationActionReturnsStructuredFeedbackAndSeparateDebugLog() async throws {
        let executor = MockSystemCommandExecutor(output: "raw shell transcript", exitCode: 0)
        let engine = OptimizationEngine(
            commandExecutor: executor,
            stateStore: InMemoryStateStore(),
            feedbackPresenter: ActionFeedbackPresenter(localizer: AppLocalizer(language: .english))
        )

        let action = OptimizationCatalog.actions().first(where: { $0.id == "dns_flush" })!
        let result = try await engine.execute(action)

        XCTAssertEqual(result.status, .enabled)
        XCTAssertEqual(result.debugLog?.contains("raw shell transcript"), true)
        XCTAssertFalse(result.toast.message.contains("raw shell transcript"))
        XCTAssertFalse(result.activityEvent.message.contains("raw shell transcript"))
    }

    func testConsecutiveAdministratorCommandsAreBatchedIntoSingleExecution() async throws {
        let executor = RecordingSystemCommandExecutor()
        let engine = OptimizationEngine(
            commandExecutor: executor,
            stateStore: InMemoryStateStore(),
            feedbackPresenter: ActionFeedbackPresenter(localizer: AppLocalizer(language: .english))
        )
        let action = OptimizationAction(
            id: "power_saving_test",
            titleKey: "action.power_saving.title",
            descriptionKey: "action.power_saving.description",
            category: .monitoring,
            symbolName: "battery.100percent",
            statusFeatureID: nil,
            isRisky: false,
            estimatedTime: "5-10 seconds",
            requiresRestart: false,
            kind: .command([
                CommandRequest(command: "pmset -a lowpowermode 1", requiresAdministrator: true),
                CommandRequest(command: "pmset -a displaysleep 5", requiresAdministrator: true),
                CommandRequest(command: "pmset -a sleep 10", requiresAdministrator: true)
            ]),
            status: .ready,
            lastRunDescription: nil
        )

        _ = try await engine.execute(action)

        XCTAssertEqual(executor.requests.count, 1)
        XCTAssertEqual(
            executor.requests.first?.command,
            """
            pmset -a lowpowermode 1
            pmset -a displaysleep 5
            pmset -a sleep 10
            """
        )
    }

    func testCpuInspectionActionReturnsStructuredSummaryAndPreservesTranscript() async throws {
        let executor = MockSystemCommandExecutor(
            output: """
            CPU Model: Apple M2 Pro
            CPU Cores: 12
            CPU usage: 4.6% user, 9.1% sys, 86.3% idle
            """,
            exitCode: 0
        )
        let engine = OptimizationEngine(
            commandExecutor: executor,
            stateStore: InMemoryStateStore(),
            feedbackPresenter: ActionFeedbackPresenter(localizer: AppLocalizer(language: .english))
        )

        let action = OptimizationCatalog.actions().first(where: { $0.id == "system_check_cpu" })!
        let result = try await engine.execute(action)

        XCTAssertEqual(result.summary?.primaryValue, "Apple M2 Pro")
        XCTAssertEqual(result.summary?.secondaryValues.first?.value, "12")
        XCTAssertTrue(result.summary?.secondaryValues.last?.value.contains("86.3% idle") == true)
        XCTAssertTrue(result.debugLog?.contains("CPU Model: Apple M2 Pro") == true)
        XCTAssertEqual(result.toast.summaryLines.first, "Apple M2 Pro")
    }
}

private struct MockSystemCommandExecutor: SystemCommandExecuting {
    let output: String
    let exitCode: Int32

    func execute(_ request: CommandRequest) async throws -> CommandExecutionResult {
        CommandExecutionResult(output: output, exitCode: exitCode)
    }
}

private final class RecordingSystemCommandExecutor: SystemCommandExecuting {
    private(set) var requests: [CommandRequest] = []

    func execute(_ request: CommandRequest) async throws -> CommandExecutionResult {
        requests.append(request)
        return CommandExecutionResult(output: "", exitCode: 0)
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
        states[featureID] = FeatureState(status: status.rawValue.lowercased(), timestamp: formatter.string(from: timestamp))
    }
}
