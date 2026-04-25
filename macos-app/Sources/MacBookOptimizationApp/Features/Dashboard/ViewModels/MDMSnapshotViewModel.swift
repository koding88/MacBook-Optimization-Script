import Foundation

@MainActor
final class MDMSnapshotViewModel: ObservableObject {
    enum LoadingState: Equatable {
        case idle
        case requestingAuthorization
        case collecting
        case failed(String)
    }

    @Published var currentMetrics: MDMMetrics?
    @Published var isLoading = false
    @Published var error: String?
    @Published var rawOutput: String = ""
    @Published var loadingState: LoadingState = .idle

    var shouldShowInitialBlur: Bool {
        currentMetrics == nil && !isLoading && error == nil
    }
    
    private let commandExecutor: SystemCommandExecuting
    
    init(commandExecutor: SystemCommandExecuting = SystemCommandExecutor()) {
        self.commandExecutor = commandExecutor
    }
    
    var isPromptingForOSA: Bool {
        loadingState == .requestingAuthorization
    }

    func refresh() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        loadingState = .collecting
        
        Task {
            do {
                // Hardcoded MDM check commands (no longer in catalog)
                let requests = [
                    CommandRequest(command: "printf 'Historical local traces:\\n'; if [ -f /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled ]; then printf 'DEP trace files: Present\\n'; else printf 'DEP trace files: Absent\\n'; fi; if [ -f /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound ] || [ -f /var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord ] || [ -f /var/db/ConfigurationProfiles/Settings/com.apple.mdm.depnag.plist ]; then printf 'Historical MDM traces: Present\\n'; else printf 'Historical MDM traces: Absent\\n'; fi", requiresAdministrator: false),
                    CommandRequest(command: "printf '\\nHosts advisory entries:\\n' && (grep -E '^0\\.0\\.0\\.0[[:space:]]+(deviceenrollment\\.apple\\.com|mdmenrollment\\.apple\\.com|iprofiles\\.apple\\.com)([[:space:]]|$)' /etc/hosts || printf 'No MDM-related host overrides found.\\n')", requiresAdministrator: false),
                    CommandRequest(command: "tmp_backup=$(mktemp /tmp/mbo-hosts-backup.XXXXXX); tmp_filtered=$(mktemp /tmp/mbo-hosts-filtered.XXXXXX); cp /etc/hosts \"$tmp_backup\"; awk '!($1==\"0.0.0.0\" && ($2==\"deviceenrollment.apple.com\" || $2==\"mdmenrollment.apple.com\" || $2==\"iprofiles.apple.com\"))' /etc/hosts > \"$tmp_filtered\"; restore_hosts() { cat \"$tmp_backup\" > /etc/hosts; dscacheutil -flushcache; killall -HUP mDNSResponder >/dev/null 2>&1 || true; rm -f \"$tmp_backup\" \"$tmp_filtered\"; }; trap restore_hosts EXIT INT TERM HUP; cat \"$tmp_filtered\" > /etc/hosts; dscacheutil -flushcache; killall -HUP mDNSResponder >/dev/null 2>&1 || true; printf '\\nProfiles enrollment readout (temporary hosts bypass disabled):\\n'; printf '\\nprofiles status -type enrollment:\\n'; profiles status -type enrollment 2>/dev/null || printf 'Unavailable.\\n'; printf '\\nprofiles show -type enrollment:\\n'; profiles show -type enrollment 2>/dev/null || printf 'Unavailable.\\n'; printf '\\nprofiles list:\\n'; profiles list 2>/dev/null || printf 'Unavailable.\\n'; printf '\\nprofiles show -type configuration:\\n'; profiles show -type configuration 2>/dev/null || printf 'Unavailable.\\n'", requiresAdministrator: true)
                ]
                
                // Execute commands
                var combinedOutput: [String] = []
                
                for request in requests {
                    if request.requiresAdministrator {
                        self.loadingState = .requestingAuthorization
                    } else {
                        self.loadingState = .collecting
                    }

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
                    self.loadingState = .idle
                } else {
                    throw MDMSnapshotError.parsingFailed
                }
                
                self.isLoading = false
            } catch {
                if Self.isUserCancellation(error) {
                    self.error = nil
                    self.loadingState = .idle
                    self.isLoading = false
                } else {
                    self.error = error.localizedDescription
                    self.loadingState = .failed(error.localizedDescription)
                    self.isLoading = false
                }
            }
        }
    }

    private static func isUserCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        let message = nsError.localizedDescription.lowercased()
        return nsError.code == -128 || message.contains("user canceled") || message.contains("user cancelled")
    }
}

enum MDMSnapshotError: LocalizedError {
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .parsingFailed:
            return "Unable to parse MDM status output."
        }
    }
}
