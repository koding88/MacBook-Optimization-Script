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
}

private struct MockSystemCommandExecutor: SystemCommandExecuting {
    let output: String
    let exitCode: Int32

    func execute(_ request: CommandRequest) async throws -> CommandExecutionResult {
        CommandExecutionResult(output: output, exitCode: exitCode)
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
