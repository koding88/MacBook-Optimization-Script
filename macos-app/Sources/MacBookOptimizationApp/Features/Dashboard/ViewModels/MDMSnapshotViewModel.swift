import Foundation

@MainActor
final class MDMSnapshotViewModel: ObservableObject {
    @Published var currentMetrics: MDMMetrics?
    @Published var isLoading = false
    @Published var error: String?
    @Published var rawOutput: String = ""
    
    private let commandExecutor: SystemCommandExecuting
    
    init(commandExecutor: SystemCommandExecuting = SystemCommandExecutor()) {
        self.commandExecutor = commandExecutor
    }
    
    func refresh() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                // Get the MDM check action from catalog
                guard let mdmAction = OptimizationCatalog.actions().first(where: { $0.id == "mdm_status" }),
                      case .command(let requests) = mdmAction.kind else {
                    throw MDMSnapshotError.actionNotFound
                }
                
                // Execute commands
                var combinedOutput: [String] = []
                
                for request in requests {
                    let result = try await commandExecutor.execute(request)
                    if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        combinedOutput.append("$ \(request.command)\n\(result.output.trimmingCharacters(in: .whitespacesAndNewlines))")
                    }
                    
                    if result.exitCode != 0 {
                        break
                    }
                }
                
                let output = combinedOutput.joined(separator: "\n\n")
                self.rawOutput = output
                
                // Parse metrics
                if let metrics = MDMMetricsParser.parse(output) {
                    self.currentMetrics = metrics
                } else {
                    throw MDMSnapshotError.parsingFailed
                }
                
                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

enum MDMSnapshotError: LocalizedError {
    case actionNotFound
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .actionNotFound:
            return "MDM status action not found in catalog."
        case .parsingFailed:
            return "Unable to parse MDM status output."
        }
    }
}
