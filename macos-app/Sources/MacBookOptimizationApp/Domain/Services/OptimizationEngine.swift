import Foundation

final class OptimizationEngine: OptimizationExecuting {
    private let commandExecutor: SystemCommandExecuting
    private let stateStore: StateStoreProtocol
    private let feedbackPresenter: any ActionFeedbackPresenting

    init(
        commandExecutor: SystemCommandExecuting,
        stateStore: StateStoreProtocol,
        feedbackPresenter: any ActionFeedbackPresenting = ActionFeedbackPresenter(
            localizer: AppLocalizer(language: .english)
        )
    ) {
        self.commandExecutor = commandExecutor
        self.stateStore = stateStore
        self.feedbackPresenter = feedbackPresenter
    }

    func execute(_ action: OptimizationAction) async throws -> ActionExecutionResult {
        let context = SystemContext(commandExecutor: commandExecutor, stateStore: stateStore)
        let status: ActionStatus
        let result: ActionExecutionResult

        switch action.kind {
        case .command(let requests):
            let commandResult = try await executeCommands(requests)
            status = commandResult.exitCode == 0 ? .enabled : .failed
            result = feedbackPresenter.presentMutation(
                action: action,
                status: status,
                debugLog: commandResult.output
            )
        case .dynamic(let resolver):
            let requests = try await resolver(context)
            let commandResult = try await executeCommands(requests)
            status = commandResult.exitCode == 0 ? .enabled : .failed
            result = feedbackPresenter.presentMutation(
                action: action,
                status: status,
                debugLog: commandResult.output
            )
        case .manual(let instructions):
            status = .enabled
            result = ActionExecutionResult(output: instructions, status: status)
        case .statuses:
            let states = try stateStore.loadStates()
            status = .enabled
            result = ActionExecutionResult(output: render(states: states), status: status)
        }

        if let featureID = action.statusFeatureID {
            try stateStore.updateState(featureID: featureID, status: status, timestamp: .now)
        }

        return result
    }

    private func executeCommands(_ requests: [CommandRequest]) async throws -> CommandExecutionResult {
        var combinedOutput: [String] = []
        var finalExitCode: Int32 = 0

        for request in coalescedRequests(requests) {
            let result = try await commandExecutor.execute(request)
            if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                combinedOutput.append("$ \(request.command)\n\(result.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            } else {
                combinedOutput.append("$ \(request.command)")
            }

            finalExitCode = result.exitCode
            if result.exitCode != 0 {
                break
            }
        }

        return CommandExecutionResult(output: combinedOutput.joined(separator: "\n\n"), exitCode: finalExitCode)
    }

    private func coalescedRequests(_ requests: [CommandRequest]) -> [CommandRequest] {
        guard !requests.isEmpty else { return [] }

        var batched: [CommandRequest] = []
        var current = requests[0]

        for request in requests.dropFirst() {
            if request.requiresAdministrator == current.requiresAdministrator {
                current = CommandRequest(
                    command: current.command + "\n" + request.command,
                    requiresAdministrator: current.requiresAdministrator
                )
            } else {
                batched.append(current)
                current = request
            }
        }

        batched.append(current)
        return batched
    }

    private func render(states: [String: FeatureState]) -> String {
        guard !states.isEmpty else {
            return "No optimizations have been run yet."
        }

        return states
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(key): \(value.status) | \(value.timestamp)"
            }
            .joined(separator: "\n")
    }
}
