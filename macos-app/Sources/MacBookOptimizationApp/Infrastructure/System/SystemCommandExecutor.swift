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
    func execute(_ request: CommandRequest) async throws -> CommandExecutionResult {
        if request.requiresAdministrator {
            return try await executeWithAdministratorPrivileges(request.command)
        }
        return try await executeRegular(request.command)
    }

    private func executeRegular(_ command: String) async throws -> CommandExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
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
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus != 0 {
            if Self.isUserCancelledAdministratorPrompt(output) {
                throw SystemCommandExecutorError.administratorAuthorizationCancelled
            }

            throw SystemCommandExecutorError.administratorExecutionFailed(
                output.isEmpty ? "Administrator command failed." : output
            )
        }

        return CommandExecutionResult(output: output, exitCode: process.terminationStatus)
    }

    static func isUserCancelledAdministratorPrompt(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("user canceled")
            || normalized.contains("user cancelled")
            || normalized.contains("(-128)")
    }

    static func regularShellArguments(for command: String) -> [String] {
        ["-f", "-c", command]
    }
}
