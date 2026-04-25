import XCTest
@testable import MacBookOptimizationApp

@MainActor
final class MDMSnapshotViewModelTests: XCTestCase {
    func testInitialStateDoesNotAutoStartOrShowError() {
        let viewModel = MDMSnapshotViewModel(commandExecutor: StubSystemCommandExecutor(results: []))

        XCTAssertNil(viewModel.currentMetrics)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.loadingState, .idle)
    }

    func testCancelledAdministratorPromptResetsToIdleWithoutError() async {
        let executor = StubSystemCommandExecutor(results: [
            .success(CommandExecutionResult(output: "Historical local traces:\nDEP trace files: Absent\nHistorical MDM traces: Absent", exitCode: 0)),
            .success(CommandExecutionResult(output: "Hosts advisory entries:\nNo MDM-related host overrides found.", exitCode: 0)),
            .failure(CancellationError())
        ])
        let viewModel = MDMSnapshotViewModel(commandExecutor: executor)

        viewModel.refresh()
        await executor.waitForExecutions(count: 3)
        await Task.yield()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.currentMetrics)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.loadingState, .idle)
    }

    func testAppleScriptCancelErrorResetsToIdleWithoutError() async {
        let executor = StubSystemCommandExecutor(results: [
            .success(CommandExecutionResult(output: "Historical local traces:\nDEP trace files: Absent\nHistorical MDM traces: Absent", exitCode: 0)),
            .success(CommandExecutionResult(output: "Hosts advisory entries:\nNo MDM-related host overrides found.", exitCode: 0)),
            .failure(NSError(domain: "osascript", code: -128, userInfo: [NSLocalizedDescriptionKey: "Command failed: 0:1216: execution error: User canceled. (-128)"]))
        ])
        let viewModel = MDMSnapshotViewModel(commandExecutor: executor)

        viewModel.refresh()
        await executor.waitForExecutions(count: 3)
        await Task.yield()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.currentMetrics)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.loadingState, .idle)
    }
}

private actor StubExecutionState {
    var queue: [Result<CommandExecutionResult, Error>]
    var executions = 0

    init(queue: [Result<CommandExecutionResult, Error>]) {
        self.queue = queue
    }

    func next() throws -> CommandExecutionResult {
        executions += 1
        if queue.isEmpty {
            return CommandExecutionResult(output: "", exitCode: 0)
        }
        let result = queue.removeFirst()
        return try result.get()
    }

    func executionCount() -> Int {
        executions
    }
}

private final class StubSystemCommandExecutor: SystemCommandExecuting {
    private let state: StubExecutionState

    init(results: [Result<CommandExecutionResult, Error>]) {
        self.state = StubExecutionState(queue: results)
    }

    func execute(_ request: CommandRequest) async throws -> CommandExecutionResult {
        try await state.next()
    }

    func waitForExecutions(count: Int) async {
        for _ in 0..<100 {
            let current = await state.executionCount()
            if current >= count {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
