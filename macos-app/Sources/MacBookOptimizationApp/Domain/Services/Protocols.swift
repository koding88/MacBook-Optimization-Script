import Foundation

protocol SystemCommandExecuting {
    func execute(_ request: CommandRequest) async throws -> CommandExecutionResult
}

protocol ActionFeedbackPresenting {
    func presentInspection(
        action: OptimizationAction,
        summary: ActionResultSummary,
        debugLog: String?,
        symbolName: String?
    ) -> ActionExecutionResult

    func presentMutation(
        action: OptimizationAction,
        status: ActionStatus,
        debugLog: String?
    ) -> ActionExecutionResult
}

protocol OptimizationExecuting {
    func execute(_ action: OptimizationAction) async throws -> ActionExecutionResult
}

protocol StateStoreProtocol {
    func loadStates() throws -> [String: FeatureState]
    func updateState(featureID: String, status: ActionStatus, timestamp: Date) throws
}

protocol SystemInfoProviding {
    func machineSummary() async -> MachineSummary
}
