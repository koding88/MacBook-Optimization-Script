import Foundation

enum SystemCommandExecutorError: LocalizedError {
    case invalidCommand(String)
    case administratorAuthorizationCancelled
    case administratorExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCommand(let command):
            return "Khong the phan tich command: \(command)"
        case .administratorAuthorizationCancelled:
            return "Administrator authorization was cancelled."
        case .administratorExecutionFailed(let message):
            return message
        }
    }
}

final class SystemCommandExecutor: SystemCommandExecuting {
    static let regularShellExecutablePath = "/bin/sh"
    static let administratorShellExecutablePath = "/bin/sh"

    private let authService: AuthorizationService
    
    init(authService: AuthorizationService = .shared) {
        self.authService = authService
    }
    
    func execute(_ request: CommandRequest) async throws -> CommandExecutionResult {
        if request.requiresAdministrator {
            return try await executeWithAdministratorPrivileges(request.command)
        }
        return try await executeRegular(request.command)
    }

    private func executeRegular(_ command: String) async throws -> CommandExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.regularShellExecutablePath)
        process.arguments = Self.regularShellArguments(for: command)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        return CommandExecutionResult(output: output, exitCode: process.terminationStatus)
    }

    private func executeWithAdministratorPrivileges(_ command: String) async throws -> CommandExecutionResult {
        // Use shared authorization service - no password prompt after first time
        do {
            let output = try await authService.executeWithPrivileges(
                command: Self.administratorShellExecutablePath,
                arguments: ["-c", command]
            )
            return CommandExecutionResult(output: output, exitCode: 0)
        } catch AuthorizationError.notAuthorized {
            throw SystemCommandExecutorError.administratorAuthorizationCancelled
        } catch {
            throw SystemCommandExecutorError.administratorExecutionFailed(error.localizedDescription)
        }
    }

    static func isUserCancelledAdministratorPrompt(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("user canceled")
            || normalized.contains("user cancelled")
            || normalized.contains("(-128)")
    }

    static func regularShellArguments(for command: String) -> [String] {
        ["-c", command]
    }
}
